import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_device.dart';
import 'android_tv_service.dart';
import 'cast_service.dart';
import 'adb_service.dart';
import 'certificate_manager.dart';
import 'protobuf_codec.dart';

/// Active connection strategy.
enum ConnectionMethod {
  androidTv,  // Primary: TLS protocol v2
  cast,       // Fallback 1: Google Cast HTTP
  adb,        // Fallback 2: ADB shell commands
  none,       // No connection
}

/// Orchestrates the multi-strategy connection system.
///
/// Tries strategies in order: Android TV Protocol → Google Cast → ADB.
/// Maintains a single persistent connection and delegates commands 
/// to the active service.
class ConnectionManager {
  final CertificateManager _certManager;
  final AndroidTvService _atvService;
  final CastService _castService;
  final AdbService _adbService;

  ConnectionMethod _activeMethod = ConnectionMethod.none;
  String? _connectedIp;

  ConnectionMethod get activeMethod => _activeMethod;
  bool get isConnected => _activeMethod != ConnectionMethod.none;
  String? get connectedIp => _connectedIp;

  // Expose ATV state
  AndroidTvService get atvService => _atvService;
  CastService get castService => _castService;
  AdbService get adbService => _adbService;

  // Auto-reconnect
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _connectionController = StreamController<ConnectionMethod>.broadcast();
  Stream<ConnectionMethod> get onMethodChanged => _connectionController.stream;

  ConnectionManager(this._certManager)
      : _atvService = AndroidTvService(_certManager),
        _castService = CastService(),
        _adbService = AdbService() {
    // Listen for ATV disconnection to trigger reconnect
    _atvService.onConnectionChanged.listen((connected) {
      if (!connected && _activeMethod == ConnectionMethod.androidTv) {
        debugPrint('[ConnMgr] Android TV disconnected, scheduling reconnect...');
        _scheduleReconnect();
      }
    });
  }

  /// Initialize the certificate manager.
  Future<void> initialize() async {
    await _certManager.initialize();
  }

  // ==========================================================================
  //  CONNECTION WITH FALLBACK
  // ==========================================================================

  /// Connect to the device using the fallback chain.
  /// Returns the method that succeeded.
  Future<ConnectionMethod> connect(String ip, {String? deviceType}) async {
    _connectedIp = ip;
    _reconnectAttempts = 0;

    debugPrint('[ConnMgr] Attempting connection to $ip (type: $deviceType)...');

    // Strategy 1: Android TV Remote Protocol v2
    if (deviceType == null || 
        deviceType == 'android_tv' || 
        deviceType == 'chromecast' ||
        deviceType == 'google_tv') {
      debugPrint('[ConnMgr] Trying Android TV Protocol...');
      try {
        final success = await _atvService.connectRemote(ip);
        if (success) {
          _activeMethod = ConnectionMethod.androidTv;
          _connectionController.add(_activeMethod);
          debugPrint('[ConnMgr] ✓ Connected via Android TV Protocol');
          _saveLastDevice(ip);
          return _activeMethod;
        }
      } catch (e) {
        debugPrint('[ConnMgr] Android TV Protocol failed: $e');
      }
    }

    // Strategy 2: Google Cast
    debugPrint('[ConnMgr] Trying Google Cast...');
    try {
      final success = await _castService.connect(ip);
      if (success) {
        _activeMethod = ConnectionMethod.cast;
        _connectionController.add(_activeMethod);
        debugPrint('[ConnMgr] ✓ Connected via Google Cast');
        _saveLastDevice(ip);
        return _activeMethod;
      }
    } catch (e) {
      debugPrint('[ConnMgr] Google Cast failed: $e');
    }

    // Strategy 3: ADB
    debugPrint('[ConnMgr] Trying ADB...');
    try {
      final success = await _adbService.connect(ip);
      if (success) {
        _activeMethod = ConnectionMethod.adb;
        _connectionController.add(_activeMethod);
        debugPrint('[ConnMgr] ✓ Connected via ADB');
        _saveLastDevice(ip);
        return _activeMethod;
      }
    } catch (e) {
      debugPrint('[ConnMgr] ADB failed: $e');
    }

    // All strategies failed
    _activeMethod = ConnectionMethod.none;
    _connectionController.add(_activeMethod);
    debugPrint('[ConnMgr] ✗ All connection strategies failed');
    return _activeMethod;
  }

  // ==========================================================================
  //  PAIRING (delegates to ATV)
  // ==========================================================================

  /// Start Android TV pairing. The TV will show a 6-digit code on screen.
  Future<void> startPairing(String ip) async {
    await _atvService.startPairing(ip);
  }

  /// Submit the pairing code. Returns true if successful.
  Future<bool> submitPairingCode(String ip, String code) async {
    return _atvService.submitPairingCode(ip, code);
  }

  /// Check if we have a stored pairing for this device.
  Future<bool> isPaired(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('atv_paired_$ip') ?? false;
  }

  // ==========================================================================
  //  COMMAND DISPATCH
  //  Routes commands to whichever service is currently active.
  // ==========================================================================

  /// Send a remote command. Maps RemoteCommand names to protocol-specific actions.
  void sendCommand(String command) {
    switch (_activeMethod) {
      case ConnectionMethod.androidTv:
        _sendAtvCommand(command);
        break;
      case ConnectionMethod.cast:
        _sendCastCommand(command);
        break;
      case ConnectionMethod.adb:
        _sendAdbCommand(command);
        break;
      case ConnectionMethod.none:
        debugPrint('[ConnMgr] Cannot send command — not connected');
        break;
    }
  }

  /// Send a key code directly (Android TV protocol).
  void sendKeyCode(int keyCode, {int direction = RemoteCodec.directionShort}) {
    if (_activeMethod == ConnectionMethod.androidTv) {
      _atvService.sendKeyCode(keyCode, direction: direction);
    } else if (_activeMethod == ConnectionMethod.adb) {
      _adbService.sendKeyCodeRaw(keyCode);
    }
  }

  /// Start a long press.
  void startLongPress(int keyCode) {
    if (_activeMethod == ConnectionMethod.androidTv) {
      _atvService.sendKeyCode(keyCode, direction: RemoteCodec.directionStartLong);
    }
  }

  /// End a long press.
  void endLongPress(int keyCode) {
    if (_activeMethod == ConnectionMethod.androidTv) {
      _atvService.sendKeyCode(keyCode, direction: RemoteCodec.directionEndLong);
    }
  }

  /// Send text input.
  void sendText(String text) {
    if (_activeMethod == ConnectionMethod.androidTv) {
      _atvService.sendText(text);
    }
  }

  /// Launch an app by deep link.
  void launchApp(String appLink) {
    if (_activeMethod == ConnectionMethod.androidTv) {
      _atvService.launchApp(appLink);
    }
  }

  void _sendAtvCommand(String command) {
    final keyCode = _commandToKeyCode(command);
    if (keyCode != null) {
      _atvService.sendKeyCode(keyCode);
    }
  }

  void _sendCastCommand(String command) {
    switch (command) {
      case 'volume_up':
        _castService.volumeUp();
        break;
      case 'volume_down':
        _castService.volumeDown();
        break;
      case 'mute':
        _castService.mute();
        break;
      default:
        debugPrint('[ConnMgr] Cast does not support command: $command');
        break;
    }
  }

  void _sendAdbCommand(String command) {
    _adbService.sendKeyEvent(command);
  }

  /// Map command names to Android key codes.
  int? _commandToKeyCode(String command) {
    const map = {
      'up': AndroidKeyCode.dpadUp,
      'down': AndroidKeyCode.dpadDown,
      'left': AndroidKeyCode.dpadLeft,
      'right': AndroidKeyCode.dpadRight,
      'center': AndroidKeyCode.dpadCenter,
      'select': AndroidKeyCode.dpadCenter,
      'ok': AndroidKeyCode.dpadCenter,
      'back': AndroidKeyCode.back,
      'home': AndroidKeyCode.home,
      'menu': AndroidKeyCode.menu,
      'power': AndroidKeyCode.power,
      'tv_power': AndroidKeyCode.tvPower,
      'volume_up': AndroidKeyCode.volumeUp,
      'volume_down': AndroidKeyCode.volumeDown,
      'mute': AndroidKeyCode.volumeMute,
      'play_pause': AndroidKeyCode.mediaPlayPause,
      'play': AndroidKeyCode.mediaPlay,
      'pause': AndroidKeyCode.mediaPause,
      'stop': AndroidKeyCode.mediaStop,
      'next': AndroidKeyCode.mediaNext,
      'previous': AndroidKeyCode.mediaPrevious,
      'rewind': AndroidKeyCode.mediaRewind,
      'fast_forward': AndroidKeyCode.mediaFastForward,
      'enter': AndroidKeyCode.enter,
      'search': AndroidKeyCode.search,
      'settings': AndroidKeyCode.settings,
      'channel_up': AndroidKeyCode.channelUp,
      'channel_down': AndroidKeyCode.channelDown,
      'guide': AndroidKeyCode.guide,
      'tv_input': AndroidKeyCode.tvInput,
      'app_switch': AndroidKeyCode.appSwitch,
    };
    return map[command];
  }

  // ==========================================================================
  //  AUTO-RECONNECT
  // ==========================================================================

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[ConnMgr] Max reconnect attempts reached.');
      _activeMethod = ConnectionMethod.none;
      _connectionController.add(_activeMethod);
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // Exponential backoff
    debugPrint('[ConnMgr] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_connectedIp != null) {
        await connect(_connectedIp!);
      }
    });
  }

  Future<void> _saveLastDevice(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_device_ip', ip);
  }

  Future<String?> getLastDeviceIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_device_ip');
  }

  // ==========================================================================
  //  LIFECYCLE
  // ==========================================================================

  void disconnect() {
    _reconnectTimer?.cancel();
    _atvService.disconnect();
    _castService.disconnect();
    _adbService.disconnect();
    _activeMethod = ConnectionMethod.none;
    _connectedIp = null;
    _connectionController.add(_activeMethod);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _atvService.dispose();
    _castService.dispose();
    _adbService.dispose();
    _connectionController.close();
  }
}
