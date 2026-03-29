import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import '../services/discovery_service.dart';
import '../services/connection_manager.dart';
import '../services/certificate_manager.dart';
import '../controllers/tv_device_controller.dart';
import '../controllers/controller_factory.dart';
import '../controllers/android_tv_controller.dart';

/// Central state manager for the entire remote control system.
/// Optimized for ultra-low latency command delivery.
///
/// Integrates the multi-strategy ConnectionManager for Android TV devices:
///   1. Android TV Remote Protocol v2 (TLS + protobuf)
///   2. Google Cast HTTP fallback
///   3. ADB over WiFi fallback
class RemoteProvider extends ChangeNotifier with WidgetsBindingObserver {
  final DiscoveryService _discoveryService = DiscoveryService();

  // --- Certificate and Connection Manager (shared across Android TV connections) ---
  final CertificateManager _certManager = CertificateManager();
  late final ConnectionManager _connectionManager;
  bool _certInitialized = false;

  // --- Pre-cached instances (avoid async on hot path) ---
  SharedPreferences? _prefs;

  // --- Discovery State ---
  List<TvDevice> _discoveredDevices = [];
  List<TvDevice> get discoveredDevices => _discoveredDevices;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // --- Connection State ---
  TVDeviceController? _controller;
  TVDeviceController? get controller => _controller;
  TvDevice? get activeDevice => _controller?.device;
  bool get isConnected => _controller?.isConnected ?? false;
  DeviceCapabilities get capabilities =>
      activeDevice?.capabilities ?? const DeviceCapabilities();

  /// The active connection method (for Android TV devices).
  ConnectionMethod get connectionMethod {
    if (_controller is AndroidTVController) {
      return (_controller as AndroidTVController).connectionMethod;
    }
    return ConnectionMethod.none;
  }

  // --- Pairing State ---
  bool _isPairing = false;
  bool get isPairing => _isPairing;
  bool _pairingStarted = false;
  bool get pairingStarted => _pairingStarted;
  TvDevice? _tempDevice; // Device we are currently trying to pair with
  TvDevice? get tempDevice => _tempDevice;

  // --- Reconnection ---
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;
  TvDevice? _lastDevice;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;

  // --- Repeat Key (long-press) ---
  Timer? _repeatTimer;

  // --- Error Handling ---
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;

  RemoteProvider() {
    _connectionManager = ConnectionManager(_certManager);

    WidgetsBinding.instance.addObserver(this);
    // Pre-cache SharedPreferences on construction — never block the hot path
    SharedPreferences.getInstance().then((p) => _prefs = p);

    _discoveryService.onDeviceFound.listen((device) {
      if (!_discoveredDevices.any((d) => d.id == device.id)) {
        _discoveredDevices.add(device);
        notifyListeners();
      }
    });

    // Start background discovery immediately on app launch
    _backgroundDiscovery();
  }

  /// Ensure certificates are ready (lazy init).
  Future<void> _ensureCertInitialized() async {
    if (!_certInitialized) {
      await _certManager.initialize();
      _certInitialized = true;
    }
  }

  // ============================================
  //  BACKGROUND DISCOVERY (runs on app start)
  // ============================================

  void _backgroundDiscovery() {
    // Fire a silent scan so devices are pre-populated
    Future.delayed(const Duration(seconds: 1), () {
      startScan(silent: true);
    });
  }

  Future<void> startScan({bool silent = false}) async {
    _isScanning = true;
    if (!silent) {
      _discoveredDevices.clear();
    }
    notifyListeners();
    await _discoveryService.scan();
    _isScanning = false;
    notifyListeners();

    // Auto-reconnect to last known device if found
    if (_controller == null || !isConnected) {
      final lastIp = _prefs?.getString('last_device_ip');
      if (lastIp != null) {
        var match = _discoveredDevices.where((d) => d.ip == lastIp).firstOrNull;
        if (match != null) {
          await connectToDevice(match);
        }
      }
    }
  }

  Future<void> addManualDevice(String ip) async {
    _isScanning = true;
    notifyListeners();
    final device = await _discoveryService.addManualDevice(ip);
    _isScanning = false;
    notifyListeners();

    if (device != null) {
      await connectToDevice(device);
    }
  }

  void stopScan() {
    _discoveryService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ============================================
  //  PAIRING — Android TV Protocol v2
  // ============================================

  /// Start pairing with an Android TV device.
  /// The TV will display a 6-digit code on screen.
  Future<bool> startPairing(TvDevice device) async {
    await _ensureCertInitialized();

    _tempDevice = device;
    _isPairing = true;
    _pairingStarted = false;
    notifyListeners();

    try {
      await _connectionManager.startPairing(device.ip);
      _pairingStarted = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isPairing = false;
      _pairingStarted = false;
      _errorController.add('Pairing failed: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  /// Submit the 6-digit code shown on the TV screen.
  Future<bool> submitPairingCode(String code) async {
    if (_tempDevice == null) return false;

    try {
      final success = await _connectionManager.submitPairingCode(
          _tempDevice!.ip, code);

      if (success) {
        // Pairing succeeded — now connect the remote control channel
        _isPairing = false;
        _pairingStarted = false;
        notifyListeners();

        // Connect using the full fallback chain
        return await connectToDevice(_tempDevice!);
      } else {
        _errorController.add('Invalid pairing code. Please try again.');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isPairing = false;
      _errorController.add('Pairing verification failed: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  /// Check if a device needs pairing.
  Future<bool> needsPairing(TvDevice device) async {
    if (device.brand == TvBrand.androidTv ||
        device.brand == TvBrand.chromecast) {
      return !(await _connectionManager.isPaired(device.ip));
    }
    return false;
  }

  // ============================================
  //  CONNECTION (with auto-reconnect)
  // ============================================

  Future<bool> connectToDevice(TvDevice device) async {
    // For Android TV / Chromecast: check if pairing is needed
    if (device.brand == TvBrand.androidTv || device.brand == TvBrand.chromecast) {
      final needsPair = await needsPairing(device);
      if (needsPair) {
        _tempDevice = device;
        notifyListeners();
        return false; // UI should navigate to pairing screen
      }

      // Use the new multi-strategy connection
      await disconnect(clearLast: false);
      await _ensureCertInitialized();

      try {
        _controller = AndroidTVController.withManager(device, _connectionManager);
        _lastDevice = device;

        _controller!.onConnectionChanged.listen((connected) {
          if (!connected && _lastDevice != null) {
            _scheduleReconnect();
          }
          notifyListeners();
        });

        final success = await _controller!.connect();

        if (success) {
          _reconnectAttempts = 0;
          _prefs?.setString('last_device_ip', device.ip);
          _startKeepAlive();
        } else {
          _errorController.add('Connection failed. The TV may need re-pairing.');
        }

        notifyListeners();
        return success;
      } catch (e) {
        _controller = null;
        _errorController.add('Connection error: ${e.toString()}');
        notifyListeners();
        return false;
      }
    }

    // For non-Android TV devices: use the old controller factory
    await disconnect(clearLast: false);

    try {
      _controller = ControllerFactory.create(device);
      _lastDevice = device;

      _controller!.onConnectionChanged.listen((connected) {
        if (!connected && _lastDevice != null) {
          _scheduleReconnect();
        }
        notifyListeners();
      });

      final success = await _controller!.connect();

      if (success) {
        _reconnectAttempts = 0;
        _prefs?.setString('last_device_ip', device.ip);
        _startKeepAlive();
      } else {
        _errorController.add('Connection failed or refused by TV.');
      }

      notifyListeners();
      return success;
    } catch (e) {
      _controller = null;
      _errorController.add('Connection error: ${e.toString()}');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect({bool clearLast = true}) async {
    _keepAliveTimer?.cancel();
    _reconnectTimer?.cancel();
    await _controller?.disconnect();
    _controller = null;
    if (clearLast) {
      _lastDevice = null;
      _prefs?.remove('last_device_ip');
    }
    notifyListeners();
  }

  /// Keepalive: periodically check connection health.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_controller != null && !_controller!.isConnected) {
        _scheduleReconnect();
      }
    });
  }

  /// Exponential backoff reconnect.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts || _lastDevice == null) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_lastDevice != null) connectToDevice(_lastDevice!);
    });
  }

  // ============================================
  //  COMMANDS — FIRE-AND-FORGET (zero-await)
  // ============================================

  /// Send a single command. Synchronous call, no Future awaited.
  /// Triggers haptic feedback for tactile response.
  void sendCommand(RemoteCommand command) {
    if (_controller == null) return;
    // Haptic feedback — instant tactile response even before the TV reacts
    HapticFeedback.lightImpact();
    // Fire-and-forget: no await, no blocking
    _controller!.sendCommand(command);
  }

  /// Start repeating a command on long-press (e.g., volume hold).
  /// For Android TV: uses START_LONG protocol direction for true long-press.
  void startRepeat(RemoteCommand command) {
    stopRepeat();

    if (_controller is AndroidTVController) {
      // Use native long-press support from the Android TV protocol
      (_controller as AndroidTVController).startLongPress(command);
    } else {
      sendCommand(command); // Fire first one immediately
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _controller?.sendCommand(command);
      });
    }
  }

  /// Stop repeating commands (on long-press release).
  void stopRepeat({RemoteCommand? command}) {
    if (_controller is AndroidTVController && command != null) {
      (_controller as AndroidTVController).endLongPress(command);
    }
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  /// Send text input to the TV.
  void sendText(String text) {
    _controller?.sendText(text);
  }

  /// Launch an app on the connected TV.
  void launchApp(String appId) {
    _controller?.launchApp(appId);
  }

  /// Get installed apps (if the platform supports it).
  Future<List<Map<String, String>>> getInstalledApps() async {
    return await _controller?.getInstalledApps() ?? [];
  }

  /// Send a named command directly (for Android TV key names).
  void sendNamedCommand(String command) {
    if (_controller is AndroidTVController) {
      (_controller as AndroidTVController).sendNamedCommand(command);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — aggressively wake up connections
      if (_controller != null && !_controller!.isConnected) {
        _scheduleReconnect();
      }
      startScan(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _repeatTimer?.cancel();
    _errorController.close();
    _controller?.disconnect();
    _connectionManager.dispose();
    super.dispose();
  }
}

// Dart doesn't have Kotlin's .let — tiny extension for null-safe chaining
extension _Let<T> on T? {
  R? let<R>(R Function(T) fn) => this != null ? fn(this as T) : null;
}
