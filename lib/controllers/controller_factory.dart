import '../models/tv_device.dart';
import 'tv_device_controller.dart';
import 'tizen_controller.dart';
import 'webos_controller.dart';
import 'android_tv_controller.dart';
import 'cast_controller.dart';
import 'dlna_controller.dart';

/// Factory class that creates the correct controller for a given TV device.
/// This is the single entry point for instantiating platform-specific controllers.
class ControllerFactory {
  /// Create the appropriate controller based on device brand.
  static TVDeviceController create(TvDevice device) {
    switch (device.brand) {
      case TvBrand.samsung:
        return TizenController(device);
      case TvBrand.lg:
        return WebOSController(device);
      case TvBrand.androidTv:
        return AndroidTVController(device);
      case TvBrand.chromecast:
        return CastController(device);
      case TvBrand.roku:
      case TvBrand.unknown:
        return DLNAController(device);
    }
  }
}
