import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'certificate_manager.dart';
import 'protobuf_codec.dart';

/// Volume state from the Android TV.
class VolumeInfo {
  final int level;
  final int max;
  final bool muted;
  VolumeInfo({required this.level, required this.max, required this.muted});
}

/// Primary connection strategy: Android TV Remote Protocol v2.
///
/// Implements the complete protocol lifecycle:
/// 1. Pairing on port 6467 (TLS + polo.proto)
/// 2. Remote control on port 6466 (TLS + remotemessage.proto)
///
/// Reference: tronikos/androidtvremote2 (Python)
class AndroidTvService {
  static const int pairingPort = 6467;
  static const int remotePort = 6466;

  final CertificateManager _certManager;

  SecureSocket? _pairingSocket;
  SecureSocket? _remoteSocket;
  Uint8List _remoteBuffer = Uint8List(0);
  Uint8List _pairingBuffer = Uint8List(0);

  bool _isConnected = false;
  bool _isPairing = false;
  bool _remoteReady = false;
  int _activeFeatures = RemoteCodec.defaultFeatures;
  int _imeCounter = 0;
  int _imeFieldCounter = 0;
  Timer? _idleTimer;

  // State
  bool isOn = false;
  VolumeInfo? volumeInfo;
  String currentApp = '';
  String deviceModel = '';
  String deviceVendor = '';

  bool get isConnected => _isConnected && _remoteReady;
  bool get isPairing => _isPairing;

  // Callbacks
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  final _volumeController = StreamController<VolumeInfo>.broadcast();
  Stream<VolumeInfo> get onVolumeChanged => _volumeController.stream;

  final _powerController = StreamController<bool>.broadcast();
  Stream<bool> get onPowerChanged => _powerController.stream;

  // Pairing state machine
  Completer<void>? _pairingStartCompleter;
  Completer<void>? _pairingFinishCompleter;

  AndroidTvService(this._certManager);

  // ==========================================================================
  //  PAIRING (Port 6467)
  // ==========================================================================

  /// Start the pairing process. Opens TLS to port 6467 and triggers the TV
  /// to show a 6-digit code on screen.
  Future<void> startPairing(String ip) async {
    if (_certManager.certPem == null) {
      await _certManager.initialize();
    }

    _isPairing = true;

    try {
      // Write cert/key to temp files for SecureSocket
      final tempDir = Directory.systemTemp;
      final certFile = File('${tempDir.path}/volt_cert.pem');
      final keyFile = File('${tempDir.path}/volt_key.pem');
      await certFile.writeAsString(_certManager.certPem!);
      await keyFile.writeAsString(_certManager.keyPem!);

      final context = SecurityContext(withTrustedRoots: false);
      context.useCertificateChain(certFile.path);
      context.usePrivateKey(keyFile.path);

      debugPrint('[ATV] Connecting to $ip:$pairingPort for pairing...');

      _pairingSocket = await SecureSocket.connect(
        ip,
        pairingPort,
        context: context,
        onBadCertificate: (_) => true, // Trust the TV's self-signed cert
        timeout: const Duration(seconds: 10),
      );

      debugPrint('[ATV] TLS connected to pairing port.');
      _pairingBuffer = Uint8List(0);

      _pairingSocket!.listen(
        (data) => _handlePairingData(Uint8List.fromList(data)),
        onDone: () {
          debugPrint('[ATV] Pairing socket closed.');
          _pairingSocket = null;
          if (_pairingStartCompleter != null && !_pairingStartCompleter!.isCompleted) {
            _pairingStartCompleter!.completeError(Exception('Pairing connection closed'));
          }
        },
        onError: (e) {
          debugPrint('[ATV] Pairing socket error: $e');
          _pairingSocket = null;
        },
      );

      // Send PairingRequest
      _pairingStartCompleter = Completer<void>();
      final request = PairingCodec.buildPairingRequest('VOLT Remote', 'atvremote');
      _sendFramed(_pairingSocket!, request);
      debugPrint('[ATV] Sent PairingRequest, waiting for TV to show code...');

      // Wait for configurationAck (TV is now showing the code)
      await _pairingStartCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('TV did not respond to pairing request'),
      );

      debugPrint('[ATV] Pairing started — TV is showing code on screen.');
    } catch (e) {
      _isPairing = false;
      _pairingSocket?.destroy();
      _pairingSocket = null;
      rethrow;
    }
  }

  /// Submit the 6-digit hex code shown on the TV screen.
  /// Returns true on successful pairing.
  Future<bool> submitPairingCode(String ip, String code) async {
    if (_pairingSocket == null) {
      throw StateError('Pairing not started. Call startPairing() first.');
    }

    if (code.length != 6) {
      throw ArgumentError('Pairing code must be exactly 6 characters.');
    }

    try {
      // Compute the secret hash
      final (clientMod, clientExp) = _certManager.getPublicKeyComponents();

      // Get server certificate from the TLS connection
      final serverCertDer = _pairingSocket!.peerCertificate?.der;
      if (serverCertDer == null) {
        throw StateError('Cannot read server certificate from TLS connection');
      }

      final (serverMod, serverExp) = _extractPublicKeyFromDer(serverCertDer);

      // SHA-256 hash of: clientMod + 0x00 + clientExp + serverMod + 0x00 + serverExp + code[2:]
      final digest = _computeSecret(clientMod, clientExp, serverMod, serverExp, code);

      // Verify: hash[0] must equal int(code[0:2], 16)
      final expectedFirstByte = int.parse(code.substring(0, 2), radix: 16);
      if (digest[0] != expectedFirstByte) {
        debugPrint('[ATV] Secret hash mismatch. Expected 0x${expectedFirstByte.toRadixString(16)}, got 0x${digest[0].toRadixString(16)}');
        return false;
      }

      // Send the secret
      _pairingFinishCompleter = Completer<void>();
      final secretMsg = PairingCodec.buildSecret(Uint8List.fromList(digest));
      _sendFramed(_pairingSocket!, secretMsg);
      debugPrint('[ATV] Sent secret, waiting for ack...');

      await _pairingFinishCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('TV did not acknowledge pairing'),
      );

      debugPrint('[ATV] ✓ Pairing successful!');
      _isPairing = false;

      // Store paired status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('atv_paired_$ip', true);

      // Close pairing socket
      _pairingSocket?.destroy();
      _pairingSocket = null;

      return true;
    } catch (e) {
      debugPrint('[ATV] Pairing failed: $e');
      _isPairing = false;
      _pairingSocket?.destroy();
      _pairingSocket = null;
      return false;
    }
  }

  void _handlePairingData(Uint8List data) {
    _pairingBuffer = Uint8List.fromList([..._pairingBuffer, ...data]);
    final (messages, remaining) = extractFramedMessages(_pairingBuffer);
    _pairingBuffer = remaining;

    for (final msg in messages) {
      final response = PairingCodec.parseOuterMessage(msg);
      debugPrint('[ATV] Pairing response: ${response.phase}, status: ${response.status}');

      if (response.status != PairingCodec.statusOk) {
        final errMsg = 'Pairing error: status ${response.status}';
        debugPrint('[ATV] $errMsg');
        _pairingStartCompleter?.completeError(Exception(errMsg));
        _pairingFinishCompleter?.completeError(Exception(errMsg));
        return;
      }

      switch (response.phase) {
        case PairingPhase.pairingRequestAck:
          debugPrint('[ATV] Got PairingRequestAck, sending Options...');
          _sendFramed(_pairingSocket!, PairingCodec.buildOptions());
          break;
        case PairingPhase.options:
          debugPrint('[ATV] Got Options, sending Configuration...');
          _sendFramed(_pairingSocket!, PairingCodec.buildConfiguration());
          break;
        case PairingPhase.configurationAck:
          debugPrint('[ATV] Got ConfigurationAck — TV is showing code now.');
          _pairingStartCompleter?.complete();
          break;
        case PairingPhase.secretAck:
          debugPrint('[ATV] Got SecretAck — pairing complete!');
          _pairingFinishCompleter?.complete();
          break;
        case PairingPhase.unknown:
          debugPrint('[ATV] Unknown pairing message');
          break;
      }
    }
  }

  // ==========================================================================
  //  REMOTE CONTROL (Port 6466)
  // ==========================================================================

  /// Connect to the remote control port. Must be called after successful pairing.
  Future<bool> connectRemote(String ip) async {
    if (_certManager.certPem == null) {
      await _certManager.initialize();
    }

    try {
      final tempDir = Directory.systemTemp;
      final certFile = File('${tempDir.path}/volt_cert.pem');
      final keyFile = File('${tempDir.path}/volt_key.pem');
      await certFile.writeAsString(_certManager.certPem!);
      await keyFile.writeAsString(_certManager.keyPem!);

      final context = SecurityContext(withTrustedRoots: false);
      context.useCertificateChain(certFile.path);
      context.usePrivateKey(keyFile.path);

      debugPrint('[ATV] Connecting to $ip:$remotePort for remote control...');

      _remoteSocket = await SecureSocket.connect(
        ip,
        remotePort,
        context: context,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 10),
      );

      debugPrint('[ATV] TLS connected to remote port.');
      _isConnected = true;
      _remoteReady = false;
      _remoteBuffer = Uint8List(0);

      _remoteSocket!.listen(
        (data) => _handleRemoteData(Uint8List.fromList(data)),
        onDone: () {
          debugPrint('[ATV] Remote socket closed.');
          _onRemoteDisconnect();
        },
        onError: (e) {
          debugPrint('[ATV] Remote socket error: $e');
          _onRemoteDisconnect();
        },
      );

      // Wait for the remote_start message that signals readiness
      int attempts = 0;
      while (!_remoteReady && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (_remoteReady) {
        debugPrint('[ATV] ✓ Remote connection ready!');
        _connectionController.add(true);
        _resetIdleTimer();
        return true;
      } else {
        debugPrint('[ATV] Remote connection timed out waiting for readiness.');
        _remoteSocket?.destroy();
        _isConnected = false;
        return false;
      }
    } catch (e) {
      debugPrint('[ATV] Remote connection failed: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  void _handleRemoteData(Uint8List data) {
    _remoteBuffer = Uint8List.fromList([..._remoteBuffer, ...data]);
    final (messages, remaining) = extractFramedMessages(_remoteBuffer);
    _remoteBuffer = remaining;

    for (final msg in messages) {
      final response = RemoteCodec.parseRemoteMessage(msg);
      _resetIdleTimer();

      switch (response.type) {
        case RemoteMessageType.configure:
          debugPrint('[ATV] Got Configure: features=${response.features}, model=${response.deviceModel}');
          deviceModel = response.deviceModel;
          deviceVendor = response.deviceVendor;
          // Intersect features
          _activeFeatures = RemoteCodec.defaultFeatures & response.features;
          // Send our configure response
          final resp = RemoteCodec.buildConfigureResponse(_activeFeatures);
          _sendFramed(_remoteSocket!, resp);
          break;

        case RemoteMessageType.setActive:
          debugPrint('[ATV] Got SetActive');
          final resp = RemoteCodec.buildSetActiveResponse(_activeFeatures);
          _sendFramed(_remoteSocket!, resp);
          break;

        case RemoteMessageType.pingRequest:
          // Respond to keepalive pings
          final resp = RemoteCodec.buildPingResponse(response.pingVal);
          _sendFramed(_remoteSocket!, resp);
          break;

        case RemoteMessageType.start:
          debugPrint('[ATV] Got RemoteStart: isOn=${response.isOn}');
          isOn = response.isOn;
          _remoteReady = true;
          _powerController.add(isOn);
          break;

        case RemoteMessageType.volumeLevel:
          volumeInfo = VolumeInfo(
            level: response.volumeLevel,
            max: response.volumeMax,
            muted: response.volumeMuted,
          );
          _volumeController.add(volumeInfo!);
          break;

        case RemoteMessageType.imeKeyInject:
          currentApp = response.currentApp;
          break;

        case RemoteMessageType.imeBatchEdit:
          _imeCounter = response.imeCounter;
          _imeFieldCounter = response.imeFieldCounter;
          break;

        case RemoteMessageType.error:
          debugPrint('[ATV] Received error from TV');
          break;

        default:
          break;
      }
    }
  }

  // ==========================================================================
  //  COMMAND SENDING
  // ==========================================================================

  /// Send a key press command. Fire-and-forget, no Future.
  void sendKeyCode(int keyCode, {int direction = RemoteCodec.directionShort}) {
    if (_remoteSocket == null || !_isConnected) return;
    final msg = RemoteCodec.buildKeyInject(keyCode, direction: direction);
    _sendFramed(_remoteSocket!, msg);
    _resetIdleTimer();
  }

  /// Send text input to the TV's text field.
  void sendText(String text) {
    if (_remoteSocket == null || !_isConnected || text.isEmpty) return;
    final msg = RemoteCodec.buildTextInput(text, _imeCounter, _imeFieldCounter);
    _sendFramed(_remoteSocket!, msg);
  }

  /// Launch an app via deep link.
  void launchApp(String appLink) {
    if (_remoteSocket == null || !_isConnected) return;
    final msg = RemoteCodec.buildAppLinkLaunch(appLink);
    _sendFramed(_remoteSocket!, msg);
  }

  // ==========================================================================
  //  CONNECTION MANAGEMENT
  // ==========================================================================

  void disconnect() {
    _idleTimer?.cancel();
    _remoteSocket?.destroy();
    _remoteSocket = null;
    _pairingSocket?.destroy();
    _pairingSocket = null;
    _isConnected = false;
    _remoteReady = false;
    _isPairing = false;
    _connectionController.add(false);
  }

  void _onRemoteDisconnect() {
    _isConnected = false;
    _remoteReady = false;
    _remoteSocket = null;
    _idleTimer?.cancel();
    _connectionController.add(false);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    // Server pings every ~5s, close if no message for 16s
    _idleTimer = Timer(const Duration(seconds: 16), () {
      debugPrint('[ATV] Idle timeout — disconnecting.');
      disconnect();
    });
  }

  void _sendFramed(SecureSocket socket, Uint8List message) {
    try {
      socket.add(frameMessage(message));
    } catch (e) {
      debugPrint('[ATV] Send error: $e');
    }
  }

  // ==========================================================================
  //  CRYPTO HELPERS
  // ==========================================================================

  /// Compute the secret hash for pairing verification.
  List<int> _computeSecret(
    BigInt clientMod, BigInt clientExp,
    BigInt serverMod, BigInt serverExp,
    String code,
  ) {
    // The hash is SHA-256 of:
    // client_modulus_hex_bytes + 0x00 + client_exponent_hex_bytes +
    // server_modulus_hex_bytes + 0x00 + server_exponent_hex_bytes +
    // code[2:6] decoded as hex bytes
    final sha256 = SHA256Digest();

    final data = <int>[];
    data.addAll(_bigIntToBytes(clientMod));
    data.addAll(_bigIntToBytes(clientExp, padToEven: true));
    data.addAll(_bigIntToBytes(serverMod));
    data.addAll(_bigIntToBytes(serverExp, padToEven: true));
    data.addAll(_hexToBytes(code.substring(2)));

    return sha256.process(Uint8List.fromList(data)).toList();
  }

  List<int> _bigIntToBytes(BigInt value, {bool padToEven = false}) {
    var hex = value.toRadixString(16).toUpperCase();
    if (padToEven && hex.length.isOdd) {
      hex = '0$hex';
    }
    return _hexToBytes(hex);
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Extract RSA public key (modulus, exponent) from a DER-encoded X.509 certificate.
  (BigInt, BigInt) _extractPublicKeyFromDer(Uint8List der) {
    // Parse the X.509 DER certificate using ASN.1
    // Certificate → TBSCertificate → SubjectPublicKeyInfo → RSAPublicKey
    try {
      final parser = _SimpleDerParser(der);
      final certSeq = parser.parseSequence();
      final tbsSeq = _SimpleDerParser(certSeq[0]).parseSequence();

      // Find SubjectPublicKeyInfo (index depends on whether version field exists)
      // Version is context-tagged [0], so check if first element starts with 0xA0
      int spkiIndex = 6;
      if (tbsSeq[0].isNotEmpty && tbsSeq[0][0] == 0xA0) {
        spkiIndex = 6;
      }

      final spkiData = tbsSeq[spkiIndex];
      final spkiSeq = _SimpleDerParser(spkiData).parseSequence();

      // The public key is in a BIT STRING (element 1 of SPKI)
      final bitString = spkiSeq[1];
      // Skip the tag (0x03), length, and unused-bits byte
      final pubKeyBytes = _skipBitStringHeader(bitString);

      final pubKeySeq = _SimpleDerParser(pubKeyBytes).parseSequence();
      final modulus = _derIntegerToBigInt(pubKeySeq[0]);
      final exponent = _derIntegerToBigInt(pubKeySeq[1]);

      return (modulus, exponent);
    } catch (e) {
      debugPrint('[ATV] Failed to extract public key from DER: $e');
      rethrow;
    }
  }

  Uint8List _skipBitStringHeader(Uint8List data) {
    // BIT STRING: tag=0x03, length, unused_bits, content
    if (data[0] != 0x03) return data;
    int pos = 1;
    int length = data[pos++];
    if (length & 0x80 != 0) {
      final numBytes = length & 0x7F;
      length = 0;
      for (int i = 0; i < numBytes; i++) {
        length = (length << 8) | data[pos++];
      }
    }
    pos++; // Skip unused bits byte
    return Uint8List.sublistView(data, pos);
  }

  BigInt _derIntegerToBigInt(Uint8List data) {
    // INTEGER: tag=0x02, length, value
    if (data[0] != 0x02) return BigInt.zero;
    int pos = 1;
    int length = data[pos++];
    if (length & 0x80 != 0) {
      final numBytes = length & 0x7F;
      length = 0;
      for (int i = 0; i < numBytes; i++) {
        length = (length << 8) | data[pos++];
      }
    }
    final valueBytes = Uint8List.sublistView(data, pos, pos + length);
    // Convert to BigInt
    BigInt result = BigInt.zero;
    for (final b in valueBytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _volumeController.close();
    _powerController.close();
  }
}

// ============================================================================
//  Minimal DER parser for extracting public keys from server certificates.
// ============================================================================

class _SimpleDerParser {
  final Uint8List data;
  int _pos = 0;

  _SimpleDerParser(this.data);

  /// Parse a SEQUENCE and return the raw bytes of each element.
  List<Uint8List> parseSequence() {
    final elements = <Uint8List>[];
    if (_pos >= data.length) return elements;

    // Expect SEQUENCE tag (0x30) or skip if we're parsing inner content
    if (data[_pos] == 0x30) {
      _pos++; // Skip tag
      final seqLen = _readLength();
      final end = _pos + seqLen;

      while (_pos < end && _pos < data.length) {
        final elemStart = _pos;
        _skipElement();
        elements.add(Uint8List.sublistView(data, elemStart, _pos));
      }
    }
    return elements;
  }

  void _skipElement() {
    if (_pos >= data.length) return;
    _pos++; // Skip tag
    final len = _readLength();
    _pos += len;
  }

  int _readLength() {
    if (_pos >= data.length) return 0;
    int length = data[_pos++];
    if (length & 0x80 != 0) {
      final numBytes = length & 0x7F;
      length = 0;
      for (int i = 0; i < numBytes && _pos < data.length; i++) {
        length = (length << 8) | data[_pos++];
      }
    }
    return length;
  }
}
