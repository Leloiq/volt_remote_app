import 'dart:async';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import '../services/command_service.dart';
import 'tv_device_controller.dart';

/// Controller for devices using the modern 6-digit PIN pairing system (HTTP).
class PairingController extends TVDeviceController {
  @override
  final TvDevice device;
  
  final CommandService _commandService = CommandService();
  bool _isConnected = false;
  final _connectionController = StreamController<bool>.broadcast();

  PairingController(this.device);

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  @override
  Future<bool> connect() async {
    try {
      await _commandService.connect(device);
      _isConnected = true;
      _connectionController.add(true);
      return true;
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _commandService.disconnect();
    _isConnected = false;
    _connectionController.add(false);
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    await _commandService.sendCommand(command, device: device);
  }

  @override
  Future<void> sendText(String text) async {
    // Basic text support via custom HTTP endpoint if available
    // For now, we'll just log it or use the generic command logic
    print('Sending text: $text');
  }

  @override
  Future<void> launchApp(String appId) async {
    // Basic app launch via custom HTTP endpoint
    print('Launching app: $appId');
  }
}
