import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import '../services/discovery_service.dart';
import '../controllers/tv_device_controller.dart';
import '../controllers/controller_factory.dart';

/// Central state manager for the entire remote control system.
/// Optimized for ultra-low latency command delivery.
class RemoteProvider extends ChangeNotifier with WidgetsBindingObserver {
  final DiscoveryService _discoveryService = DiscoveryService();

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

  // ============================================
  //  BACKGROUND DISCOVERY (runs on app start)
  // ============================================

  void _backgroundDiscovery() {
    // Try to auto-reconnect to the last known device
    _prefs?.getString('last_device_ip')?.let((ip) {
      // We'll discover it via the normal scan
    });
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
        final match = _discoveredDevices.where((d) => d.ip == lastIp).firstOrNull;
        if (match != null) {
          await connectToDevice(match);
        }
      }
    }
  }

  void stopScan() {
    _discoveryService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ============================================
  //  CONNECTION (with auto-reconnect)
  // ============================================

  Future<bool> connectToDevice(TvDevice device) async {
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
        _errorController.add('Pairing failed or connection refused by TV.');
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
  /// Fires immediately, then repeats at 100ms intervals.
  void startRepeat(RemoteCommand command) {
    stopRepeat();
    sendCommand(command); // Fire first one immediately
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _controller?.sendCommand(command);
    });
  }

  /// Stop repeating commands (on long-press release).
  void stopRepeat() {
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
    super.dispose();
  }
}

// Dart doesn't have Kotlin's .let — tiny extension for null-safe chaining
extension _Let<T> on T? {
  R? let<R>(R Function(T) fn) => this != null ? fn(this as T) : null;
}
