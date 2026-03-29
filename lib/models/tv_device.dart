/// Represents the capabilities a TV device supports.
/// Used by the UI to show/hide controls dynamically.
class DeviceCapabilities {
  final bool canPower;
  final bool canVolume;
  final bool canChannel;
  final bool canNavigate;
  final bool canLaunchApps;
  final bool canCastMedia;
  final bool canMirror;
  final bool canTextInput;
  final bool canVoiceSearch;

  const DeviceCapabilities({
    this.canPower = false,
    this.canVolume = false,
    this.canChannel = false,
    this.canNavigate = false,
    this.canLaunchApps = false,
    this.canCastMedia = false,
    this.canMirror = false,
    this.canTextInput = false,
    this.canVoiceSearch = false,
  });

  /// Full-featured remote (Samsung, LG, Android TV)
  const DeviceCapabilities.fullRemote()
      : canPower = true,
        canVolume = true,
        canChannel = true,
        canNavigate = true,
        canLaunchApps = true,
        canCastMedia = true,
        canMirror = false,
        canTextInput = true,
        canVoiceSearch = true;

  /// Cast-only device (Chromecast)
  const DeviceCapabilities.castOnly()
      : canPower = false,
        canVolume = true,
        canChannel = false,
        canNavigate = false,
        canLaunchApps = true,
        canCastMedia = true,
        canMirror = false,
        canTextInput = false,
        canVoiceSearch = false;

  /// DLNA renderer (basic media control)
  const DeviceCapabilities.dlnaRenderer()
      : canPower = false,
        canVolume = true,
        canChannel = false,
        canNavigate = false,
        canLaunchApps = false,
        canCastMedia = true,
        canMirror = false,
        canTextInput = false,
        canVoiceSearch = false;

  Map<String, bool> toMap() => {
        'power': canPower,
        'volume': canVolume,
        'channel': canChannel,
        'navigate': canNavigate,
        'apps': canLaunchApps,
        'cast': canCastMedia,
        'mirror': canMirror,
        'text': canTextInput,
        'voice': canVoiceSearch,
      };
}

class TvDevice {
  final String id;
  final String name;
  final String ip;
  final int? port;
  final String? macAddress;
  final String? descriptionUrl;
  final String? modelName;
  final String? pairingToken;
  final TvBrand brand;
  final DeviceCapabilities capabilities;

  const TvDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.port,
    this.macAddress,
    this.descriptionUrl,
    this.modelName,
    this.pairingToken,
    this.brand = TvBrand.unknown,
    this.capabilities = const DeviceCapabilities(),
  });

  TvDevice copyWith({
    String? name,
    String? modelName,
    TvBrand? brand,
    DeviceCapabilities? capabilities,
    int? port,
    String? pairingToken,
  }) {
    return TvDevice(
      id: id,
      name: name ?? this.name,
      ip: ip,
      port: port ?? this.port,
      macAddress: macAddress,
      descriptionUrl: descriptionUrl,
      modelName: modelName ?? this.modelName,
      pairingToken: pairingToken ?? this.pairingToken,
      brand: brand ?? this.brand,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'macAddress': macAddress,
      'descriptionUrl': descriptionUrl,
      'modelName': modelName,
      'pairingToken': pairingToken,
      'brand': brand.name,
    };
  }

  factory TvDevice.fromJson(Map<String, dynamic> json) {
    final brand = TvBrand.values.firstWhere(
      (e) => e.name == json['brand'],
      orElse: () => TvBrand.unknown,
    );
    return TvDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int?,
      macAddress: json['macAddress'] as String?,
      descriptionUrl: json['descriptionUrl'] as String?,
      modelName: json['modelName'] as String?,
      pairingToken: json['pairingToken'] as String?,
      brand: brand,
      capabilities: _defaultCapabilities(brand),
    );
  }

  static DeviceCapabilities _defaultCapabilities(TvBrand brand) {
    switch (brand) {
      case TvBrand.samsung:
      case TvBrand.lg:
      case TvBrand.androidTv:
        return const DeviceCapabilities.fullRemote();
      case TvBrand.chromecast:
        return const DeviceCapabilities.castOnly();
      case TvBrand.roku:
        return const DeviceCapabilities(
          canPower: true,
          canVolume: true,
          canChannel: true,
          canNavigate: true,
          canLaunchApps: true,
          canCastMedia: false,
          canTextInput: true,
        );
      case TvBrand.unknown:
        return const DeviceCapabilities.dlnaRenderer();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum TvBrand {
  samsung,
  lg,
  androidTv,
  chromecast,
  roku,
  unknown,
}
