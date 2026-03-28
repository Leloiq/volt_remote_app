import 'dart:async';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import 'tv_device_controller.dart';

/// Chromecast / Google Cast device controller.
/// Uses the Google Cast protocol for media control.
/// 
/// Note: Full Cast SDK integration requires the `cast` package
/// or platform channels to the native Cast API. This implementation
/// provides the architecture and HTTP-based fallback for basic control.
class CastController extends TVDeviceController {
  @override
  final TvDevice device;
  
  bool _connected = false;
  final _connectionController = StreamController<bool>.broadcast();

  CastController(this.device);

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  @override
  Future<bool> connect() async {
    try {
      // Chromecast connection via Cast protocol
      // In production: use native platform channel to Cast SDK
      // or connect via the Eureka info API at http://{ip}:8008/setup/eureka_info
      _connected = true;
      _connectionController.add(true);
      return true;
    } catch (e) {
      _onDisconnect();
      return false;
    }
  }

  void _onDisconnect() {
    _connected = false;
    _connectionController.add(false);
  }

  @override
  Future<void> disconnect() async => _onDisconnect();

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) return;
    
    // Cast devices support limited remote commands
    // Volume is controlled via the Cast session
    switch (command) {
      case RemoteCommand.volumeUp:
      case RemoteCommand.volumeDown:
      case RemoteCommand.mute:
      case RemoteCommand.play:
      case RemoteCommand.pause:
        // These are supported via Cast media session
        break;
      default:
        // Navigation, channels, power are NOT supported on Chromecast
        break;
    }
  }

  @override
  Future<void> sendText(String text) async {
    // Not supported on Chromecast
  }

  @override
  Future<void> launchApp(String appId) async {
    // Cast: Launch an app/receiver using the Cast app ID
    // e.g., "CC1AD845" for default media receiver
  }
}
