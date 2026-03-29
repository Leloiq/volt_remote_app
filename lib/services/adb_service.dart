import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Fallback 2: ADB over WiFi.
///
/// Sends key events via `input keyevent` shell commands.
/// Requires the TV to have Developer Options + Wireless Debugging enabled.
class AdbService {
  static const int adbPort = 5555;

  Socket? _socket;
  bool _isConnected = false;
  String? _ip;
  Completer<void>? _authCompleter;

  bool get isConnected => _isConnected;

  /// Standard ADB keycode mapping (same as Android KeyEvent constants).
  static const Map<String, int> keycodeMap = {
    'up': 19,
    'down': 20,
    'left': 21,
    'right': 22,
    'center': 23,
    'select': 23,
    'back': 4,
    'home': 3,
    'menu': 82,
    'power': 26,
    'volume_up': 24,
    'volume_down': 25,
    'mute': 164,
    'play_pause': 85,
    'play': 126,
    'pause': 127,
    'stop': 86,
    'next': 87,
    'previous': 88,
    'rewind': 89,
    'fast_forward': 90,
    'enter': 66,
    'search': 84,
    'settings': 176,
  };

  /// Try to connect to ADB on the TV.
  Future<bool> connect(String ip) async {
    _ip = ip;
    try {
      debugPrint('[ADB] Connecting to $ip:$adbPort...');

      _socket = await Socket.connect(ip, adbPort,
          timeout: const Duration(seconds: 5));

      // Send ADB CONNECT message
      final connectMsg = _buildAdbMessage(
        0x434e584e, // CNXN
        0x01000000, // version
        4096,       // max data
        'host::VOLT Remote\x00',
      );
      _socket!.add(connectMsg);

      _authCompleter = Completer<void>();

      _socket!.listen(
        (data) => _handleAdbData(Uint8List.fromList(data)),
        onDone: () {
          debugPrint('[ADB] Socket closed.');
          _isConnected = false;
          _socket = null;
        },
        onError: (e) {
          debugPrint('[ADB] Socket error: $e');
          _isConnected = false;
        },
      );

      // Wait for AUTH/OKAY response
      try {
        await _authCompleter!.future.timeout(const Duration(seconds: 5));
      } catch (e) {
        // Timeout is OK — some implementations just connect
      }

      _isConnected = _socket != null;
      if (_isConnected) {
        debugPrint('[ADB] ✓ Connected!');
      }
      return _isConnected;
    } catch (e) {
      debugPrint('[ADB] Connection failed: $e');
      return false;
    }
  }

  /// Send a key event via ADB shell.
  Future<bool> sendKeyEvent(String key) async {
    final keycode = keycodeMap[key];
    if (keycode == null) {
      debugPrint('[ADB] Unknown key: $key');
      return false;
    }
    return sendKeyCodeRaw(keycode);
  }

  /// Send a raw keycode via ADB shell.
  Future<bool> sendKeyCodeRaw(int keycode) async {
    if (!_isConnected || _socket == null) return false;
    try {
      final cmd = 'shell:input keyevent $keycode\x00';
      final msg = _buildAdbMessage(
        0x4f50454e, // OPEN
        1,           // local-id
        0,           // remote-id
        cmd,
      );
      _socket!.add(msg);
      return true;
    } catch (e) {
      debugPrint('[ADB] Send failed: $e');
      return false;
    }
  }

  void _handleAdbData(Uint8List data) {
    if (data.length < 4) return;
    final command = ByteData.sublistView(data, 0, 4).getUint32(0, Endian.little);

    switch (command) {
      case 0x434e584e: // CNXN
        debugPrint('[ADB] Connection acknowledged');
        _isConnected = true;
        _authCompleter?.complete();
        break;
      case 0x48545541: // AUTH
        debugPrint('[ADB] Auth required (device not authorized)');
        _authCompleter?.completeError(Exception('ADB auth required - enable USB debugging'));
        break;
      case 0x59414b4f: // OKAY
        // Command acknowledged
        break;
      default:
        break;
    }
  }

  Uint8List _buildAdbMessage(int command, int arg0, int arg1, String payload) {
    final payloadBytes = utf8.encode(payload);
    final header = ByteData(24);
    header.setUint32(0, command, Endian.little);
    header.setUint32(4, arg0, Endian.little);
    header.setUint32(8, arg1, Endian.little);
    header.setUint32(12, payloadBytes.length, Endian.little);
    header.setUint32(16, _crc32(payloadBytes), Endian.little);
    header.setUint32(20, command ^ 0xFFFFFFFF, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...payloadBytes]);
  }

  int _crc32(List<int> data) {
    int crc = 0;
    for (final byte in data) {
      crc += byte;
    }
    return crc & 0xFFFFFFFF;
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
    _isConnected = false;
    _ip = null;
  }

  void dispose() {
    disconnect();
  }
}
