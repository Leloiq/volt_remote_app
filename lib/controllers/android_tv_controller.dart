import 'dart:async';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import '../services/connection_manager.dart';
import '../services/certificate_manager.dart';
import '../services/protobuf_codec.dart';
import 'tv_device_controller.dart';

/// Android TV / Google TV controller.
///
/// Uses the multi-strategy ConnectionManager:
///   1. Android TV Remote Protocol v2 (TLS + protobuf)
///   2. Google Cast HTTP fallback
///   3. ADB over WiFi fallback
///
/// Once paired via the TLS handshake (port 6467), subsequent connections
/// are instant — no re-pairing needed. Commands are sent over a persistent
/// socket (port 6466) with near-zero latency.
class AndroidTVController extends TVDeviceController {
  @override
  final TvDevice device;

  late final ConnectionManager _connectionManager;
  final _connectionController = StreamController<bool>.broadcast();
  bool _initialized = false;

  AndroidTVController(this.device) {
    final certManager = CertificateManager();
    _connectionManager = ConnectionManager(certManager);

    // Forward connection events
    _connectionManager.onMethodChanged.listen((method) {
      _connectionController.add(method != ConnectionMethod.none);
    });
  }

  /// Provide a constructor that accepts an existing ConnectionManager.
  /// Used when the provider already has one initialized.
  AndroidTVController.withManager(this.device, this._connectionManager) {
    _initialized = true;
    _connectionManager.onMethodChanged.listen((method) {
      _connectionController.add(method != ConnectionMethod.none);
    });
  }

  @override
  bool get isConnected => _connectionManager.isConnected;

  @override
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  /// The active connection method.
  ConnectionMethod get connectionMethod => _connectionManager.activeMethod;

  /// Device info from the TV (after connection).
  String get deviceModel => _connectionManager.atvService.deviceModel;
  String get deviceVendor => _connectionManager.atvService.deviceVendor;

  /// Volume info stream.
  Stream<dynamic> get onVolumeChanged => _connectionManager.atvService.onVolumeChanged;

  /// Power state stream.
  Stream<bool> get onPowerChanged => _connectionManager.atvService.onPowerChanged;

  @override
  Future<bool> connect() async {
    if (!_initialized) {
      await _connectionManager.initialize();
      _initialized = true;
    }

    // Check if already paired
    final paired = await _connectionManager.isPaired(device.ip);
    if (!paired) {
      // Need to pair first
      return false;
    }

    final method = await _connectionManager.connect(device.ip, deviceType: device.brand.name);
    return method != ConnectionMethod.none;
  }

  /// Start pairing process. TV will show a 6-digit code.
  Future<void> startPairing() async {
    if (!_initialized) {
      await _connectionManager.initialize();
      _initialized = true;
    }
    await _connectionManager.startPairing(device.ip);
  }

  /// Submit pairing code. Returns true on success.
  Future<bool> submitPairingCode(String code) async {
    final success = await _connectionManager.submitPairingCode(device.ip, code);
    if (success) {
      // Now connect the remote control channel
      final method = await _connectionManager.connect(device.ip, deviceType: device.brand.name);
      return method != ConnectionMethod.none;
    }
    return false;
  }

  @override
  Future<void> disconnect() async {
    _connectionManager.disconnect();
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!isConnected) return;

    final keyCode = _remoteCommandToKeyCode(command);
    if (keyCode != null) {
      _connectionManager.sendKeyCode(keyCode);
    }
  }

  /// Send a key code with a long-press start.
  void startLongPress(RemoteCommand command) {
    final keyCode = _remoteCommandToKeyCode(command);
    if (keyCode != null) {
      _connectionManager.startLongPress(keyCode);
    }
  }

  /// End a long press.
  void endLongPress(RemoteCommand command) {
    final keyCode = _remoteCommandToKeyCode(command);
    if (keyCode != null) {
      _connectionManager.endLongPress(keyCode);
    }
  }

  /// Send a named command directly.
  void sendNamedCommand(String command) {
    _connectionManager.sendCommand(command);
  }

  @override
  Future<void> sendText(String text) async {
    _connectionManager.sendText(text);
  }

  @override
  Future<void> launchApp(String appId) async {
    _connectionManager.launchApp(appId);
  }

  @override
  Future<int> getVolume() async {
    final vol = _connectionManager.atvService.volumeInfo;
    if (vol != null && vol.max > 0) {
      return ((vol.level / vol.max) * 100).round();
    }
    return -1;
  }

  @override
  Future<bool> isPoweredOn() async {
    return _connectionManager.atvService.isOn;
  }

  int? _remoteCommandToKeyCode(RemoteCommand command) {
    switch (command) {
      case RemoteCommand.power:
        return AndroidKeyCode.power;
      case RemoteCommand.volumeUp:
        return AndroidKeyCode.volumeUp;
      case RemoteCommand.volumeDown:
        return AndroidKeyCode.volumeDown;
      case RemoteCommand.mute:
        return AndroidKeyCode.volumeMute;
      case RemoteCommand.channelUp:
        return AndroidKeyCode.channelUp;
      case RemoteCommand.channelDown:
        return AndroidKeyCode.channelDown;
      case RemoteCommand.up:
        return AndroidKeyCode.dpadUp;
      case RemoteCommand.down:
        return AndroidKeyCode.dpadDown;
      case RemoteCommand.left:
        return AndroidKeyCode.dpadLeft;
      case RemoteCommand.right:
        return AndroidKeyCode.dpadRight;
      case RemoteCommand.enter:
        return AndroidKeyCode.dpadCenter;
      case RemoteCommand.back:
        return AndroidKeyCode.back;
      case RemoteCommand.home:
        return AndroidKeyCode.home;
      case RemoteCommand.play:
        return AndroidKeyCode.mediaPlay;
      case RemoteCommand.pause:
        return AndroidKeyCode.mediaPause;
      case RemoteCommand.fastForward:
        return AndroidKeyCode.mediaFastForward;
      case RemoteCommand.rewind:
        return AndroidKeyCode.mediaRewind;
    }
  }

  /// Access the connection manager for advanced operations.
  ConnectionManager get connectionManager => _connectionManager;
}
