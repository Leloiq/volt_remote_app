import '../models/tv_device.dart';
import 'tv_device_controller.dart';
import 'tizen_controller.dart';
import 'webos_controller.dart';
import 'android_tv_controller.dart';
import 'cast_controller.dart';
import 'dlna_controller.dart';

/// Factory class that creates the correct controller for a given TV device.
/// 
/// For Android TV and Chromecast, the RemoteProvider handles connection
/// directly via the ConnectionManager (TLS protocol + fallbacks).
/// This factory is used for non-Android TV brands (Samsung, LG, etc).
class ControllerFactory {
  /// Create the appropriate controller based on device brand.
  static TVDeviceController create(TvDevice device) {
    switch (device.brand) {
      case TvBrand.samsung:
        return TizenController(device);
      case TvBrand.lg:
        return WebOSController(device);
      case TvBrand.androidTv:
        // The real connection is handled by RemoteProvider + ConnectionManager.
        // This creates a standalone controller for fallback scenarios.
        return AndroidTVController(device);
      case TvBrand.chromecast:
        return CastController(device);
      case TvBrand.roku:
        return DLNAController(device);
      case TvBrand.unknown:
        return DLNAController(device);
    }
  }
}
