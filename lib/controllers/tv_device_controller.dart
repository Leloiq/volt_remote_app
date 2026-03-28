import 'dart:async';
import '../models/tv_device.dart';
import '../models/remote_command.dart';

/// Abstract base class for all TV platform controllers.
/// Each platform (Samsung, LG, Android TV, Chromecast, DLNA)
/// must implement this interface to provide unified remote control.
abstract class TVDeviceController {
  TvDevice get device;
  bool get isConnected;
  
  Stream<bool> get onConnectionChanged;

  /// Connect to the TV device. Returns true on success.
  Future<bool> connect();

  /// Disconnect from the TV device.
  Future<void> disconnect();

  /// Send a unified remote command.
  Future<void> sendCommand(RemoteCommand command);

  /// Send raw text input (for keyboard/search).
  Future<void> sendText(String text);

  /// Launch an app by its platform-specific ID.
  Future<void> launchApp(String appId);

  /// Get the list of installed apps (if supported).
  Future<List<Map<String, String>>> getInstalledApps() async => [];

  /// Get current volume level (if supported). Returns 0-100 or -1 if unknown.
  Future<int> getVolume() async => -1;

  /// Check if the TV is currently powered on.
  Future<bool> isPoweredOn() async => isConnected;

  /// Factory method to create the correct controller for a device.
  static TVDeviceController create(TvDevice device) {
    // Import controllers lazily to avoid circular dependencies
    switch (device.brand) {
      case TvBrand.samsung:
        return _createTizen(device);
      case TvBrand.lg:
        return _createWebOS(device);
      case TvBrand.androidTv:
        return _createAndroidTV(device);
      case TvBrand.chromecast:
        return _createCast(device);
      case TvBrand.roku:
      case TvBrand.unknown:
        return _createDLNA(device);
    }
  }

  // These are forwarded methods — actual instantiation happens in the factory file
  static TVDeviceController _createTizen(TvDevice d) => throw UnimplementedError('Use ControllerFactory');
  static TVDeviceController _createWebOS(TvDevice d) => throw UnimplementedError('Use ControllerFactory');
  static TVDeviceController _createAndroidTV(TvDevice d) => throw UnimplementedError('Use ControllerFactory');
  static TVDeviceController _createCast(TvDevice d) => throw UnimplementedError('Use ControllerFactory');
  static TVDeviceController _createDLNA(TvDevice d) => throw UnimplementedError('Use ControllerFactory');
}
