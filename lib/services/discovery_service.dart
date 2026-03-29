import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/tv_device.dart';

/// Unified device discovery service.
/// Scans the local network using multiple protocols simultaneously:
/// - SSDP (UPnP) for Samsung, LG, DLNA, and generic Smart TVs
/// - mDNS/Bonjour for Chromecast and Android TV devices
/// - Direct IP probe for fallback discovery
class DiscoveryService {
  // --- SSDP Config ---
  static const _ssdpAddress = '239.255.255.250';
  static const _ssdpPort = 1900;

  // DIAL discovery (Samsung, LG, many Smart TVs)
  static const String _dialSearch =
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 3\r\n'
      'ST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n';

  // UPnP media renderer discovery (DLNA)
  static const String _upnpSearch =
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 3\r\n'
      'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';

  // General UPnP root device discovery
  static const String _rootSearch =
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 3\r\n'
      'ST: upnp:rootdevice\r\n\r\n';

  // All SSDP discovery (catches everything)
  static const String _allSearch =
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 5\r\n'
      'ST: ssdp:all\r\n\r\n';

  final _devicesController = StreamController<TvDevice>.broadcast();
  Stream<TvDevice> get onDeviceFound => _devicesController.stream;

  final Set<String> _seenIds = {};
  RawDatagramSocket? _ssdpSocket;
  RawDatagramSocket? _mdnsSocket;
  bool _scanning = false;

  /// Ensure we have location permission (required for network discovery on Android 10+).
  Future<bool> _ensurePermissions() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      // Android 10+ requires location permission for multicast/network discovery
      var locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.locationWhenInUse.request();
        if (!locationStatus.isGranted) {
          debugPrint('[Discovery] Location permission denied — cannot scan network');
          return false;
        }
      }

      // Android 13+ also needs NEARBY_WIFI_DEVICES
      if (Platform.version.isNotEmpty) {
        var nearbyStatus = await Permission.nearbyWifiDevices.status;
        if (!nearbyStatus.isGranted) {
          nearbyStatus = await Permission.nearbyWifiDevices.request();
          // Not fatal if denied — SSDP still works with location perm
        }
      }
    }
    return true;
  }

  /// Start scanning with all protocols in parallel.
  Future<void> scan() async {
    if (kIsWeb || _scanning) return;
    _scanning = true;

    _seenIds.clear();

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) {
      debugPrint('[Discovery] Skipping scan — no permission');
      _scanning = false;
      return;
    }

    debugPrint('[Discovery] Starting scan...');

    await Future.wait([
      _scanSSDP(),
      _scanMDNS(),
      _scanCommonPorts(),
    ]);

    debugPrint('[Discovery] Scan complete. Found ${_seenIds.length} devices.');
    _scanning = false;
  }

  /// SSDP/UPnP scan: sends multiple M-SEARCH queries with retries.
  Future<void> _scanSSDP() async {
    try {
      _ssdpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: false,
      );
      _ssdpSocket!.broadcastEnabled = true;
      _ssdpSocket!.multicastHops = 4;
      _ssdpSocket!.readEventsEnabled = true;

      // Try to join the SSDP multicast group to receive announcements
      try {
        _ssdpSocket!.joinMulticast(InternetAddress(_ssdpAddress));
        debugPrint('[SSDP] Joined multicast group $_ssdpAddress');
      } catch (e) {
        debugPrint('[SSDP] Could not join multicast group (non-fatal): $e');
      }

      // Listen for responses BEFORE sending queries
      _ssdpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _ssdpSocket?.receive();
          if (datagram != null) {
            final response = String.fromCharCodes(datagram.data);
            debugPrint('[SSDP] Got response from ${datagram.address.address}');
            final device = _parseSSDPResponse(response, datagram.address);
            if (device != null) _emit(device);
          }
        }
      });
      
      // Send queries multiple times with delays (WiFi is lossy)
      final queries = [_dialSearch, _upnpSearch, _rootSearch, _allSearch];
      for (int round = 0; round < 3; round++) {
        for (final query in queries) {
          try {
            _ssdpSocket?.send(
              query.codeUnits,
              InternetAddress(_ssdpAddress),
              _ssdpPort,
            );
          } catch (e) {
            debugPrint('[SSDP] Send error: $e');
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }
        // Wait between rounds
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // Wait for late responses
      await Future.delayed(const Duration(seconds: 4));
      
      try {
        _ssdpSocket?.leaveMulticast(InternetAddress(_ssdpAddress));
      } catch (_) {}
      _ssdpSocket?.close();
      _ssdpSocket = null;
    } catch (e) {
      debugPrint('[SSDP] Scan error: $e');
      _ssdpSocket?.close();
      _ssdpSocket = null;
    }
  }

  /// mDNS/Bonjour scan: discovers Chromecast and Android TV devices.
  Future<void> _scanMDNS() async {
    try {
      _mdnsSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final mdnsAddress = InternetAddress('224.0.0.251');
      const mdnsPort = 5353;

      // Join multicast group to receive mDNS responses
      try {
        _mdnsSocket!.joinMulticast(mdnsAddress);
        debugPrint('[mDNS] Joined multicast group 224.0.0.251');
      } catch (e) {
        debugPrint('[mDNS] Could not join multicast group: $e');
      }

      _mdnsSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _mdnsSocket?.receive();
          if (datagram != null) {
            final device = _parseMDNSResponse(datagram.data, datagram.address);
            if (device != null) _emit(device);
          }
        }
      });

      // Send query for Chromecast devices
      final castQuery = _buildMDNSQuery('_googlecast._tcp.local');
      // Send query for Android TV
      final atvQuery = _buildMDNSQuery('_androidtvremote2._tcp.local');

      // Send multiple times for reliability
      for (int i = 0; i < 3; i++) {
        try {
          _mdnsSocket?.send(castQuery, mdnsAddress, mdnsPort);
          await Future.delayed(const Duration(milliseconds: 200));
          _mdnsSocket?.send(atvQuery, mdnsAddress, mdnsPort);
        } catch (e) {
          debugPrint('[mDNS] Send error: $e');
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      await Future.delayed(const Duration(seconds: 3));
      
      try {
        _mdnsSocket?.leaveMulticast(mdnsAddress);
      } catch (_) {}
      _mdnsSocket?.close();
      _mdnsSocket = null;
    } catch (e) {
      debugPrint('[mDNS] Scan error: $e');
      _mdnsSocket?.close();
      _mdnsSocket = null;
    }
  }

  /// Fallback: probe common TV ports on the local subnet.
  /// If SSDP/mDNS don't work, try direct HTTP connections to known ports.
  Future<void> _scanCommonPorts() async {
    try {
      // Get local IP to determine subnet
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? subnet;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            // Use the first 3 octets as subnet
            subnet = ip.substring(0, ip.lastIndexOf('.'));
            debugPrint('[Probe] Local IP: $ip, scanning subnet: $subnet.*');
            break;
          }
        }
        if (subnet != null) break;
      }

      if (subnet == null) {
        debugPrint('[Probe] Could not determine local subnet');
        return;
      }

      // Known TV ports to probe
      final tvPorts = {
        8001: TvBrand.samsung,   // Samsung HTTP
        8002: TvBrand.samsung,   // Samsung WSS
        3000: TvBrand.lg,        // LG WebOS
        3001: TvBrand.lg,        // LG WebOS SSL
        8008: TvBrand.chromecast, // Chromecast
        8443: TvBrand.chromecast, // Chromecast SSL
        8060: TvBrand.roku,      // Roku
        6466: TvBrand.androidTv, // Android TV
      };

      // Scan common IPs (1-30 range covers most routers' DHCP pools)
      // We scan in batches to avoid overwhelming the network
      final futures = <Future>[];
      
      for (int i = 1; i <= 30; i++) {
        final ip = '$subnet.$i';
        futures.add(_probeIP(ip, tvPorts));
      }

      // Also try higher ranges (many routers assign 100+)
      for (int i = 100; i <= 120; i++) {
        final ip = '$subnet.$i';
        futures.add(_probeIP(ip, tvPorts));
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint('[Probe] Subnet scan error: $e');
    }
  }

  Future<void> _probeIP(String ip, Map<int, TvBrand> tvPorts) async {
    for (final entry in tvPorts.entries) {
      try {
        final socket = await Socket.connect(
          ip,
          entry.key,
          timeout: const Duration(milliseconds: 800),
        );
        socket.destroy();

        // Port is open — this is likely a TV!
        debugPrint('[Probe] Found open port ${entry.key} on $ip');
        
        final brand = entry.value;
        String name;
        DeviceCapabilities caps;
        int port = entry.key;

        switch (brand) {
          case TvBrand.samsung:
            name = 'Samsung TV';
            caps = const DeviceCapabilities.fullRemote();
            port = 8002;
            break;
          case TvBrand.lg:
            name = 'LG TV';
            caps = const DeviceCapabilities.fullRemote();
            port = 3000;
            break;
          case TvBrand.androidTv:
            name = 'Android TV';
            caps = const DeviceCapabilities.fullRemote();
            break;
          case TvBrand.chromecast:
            name = 'Chromecast';
            caps = const DeviceCapabilities.castOnly();
            break;
          case TvBrand.roku:
            name = 'Roku';
            caps = const DeviceCapabilities(
              canPower: true, canVolume: true, canChannel: true,
              canNavigate: true, canLaunchApps: true,
            );
            break;
          default:
            name = 'Smart TV';
            caps = const DeviceCapabilities.dlnaRenderer();
        }

        _emit(TvDevice(
          id: 'probe_${ip}_${entry.key}',
          name: '$name ($ip)',
          ip: ip,
          port: port,
          brand: brand,
          capabilities: caps,
        ));

        // Found a TV on this IP, skip other ports for this IP
        break;
      } on SocketException {
        // Port closed — expected
      } on TimeoutException {
        // Timeout — expected
      } catch (_) {
        // Any other error — skip
      }
    }
  }

  List<int> _buildMDNSQuery(String name) {
    // Build a minimal DNS query packet
    final bytes = <int>[];
    // Transaction ID
    bytes.addAll([0x00, 0x00]);
    // Flags (standard query)
    bytes.addAll([0x00, 0x00]);
    // Questions: 1
    bytes.addAll([0x00, 0x01]);
    // Answer/Authority/Additional: 0
    bytes.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    // Query name
    for (final part in name.split('.')) {
      bytes.add(part.length);
      bytes.addAll(part.codeUnits);
    }
    bytes.add(0x00); // Null terminator
    // Type: PTR (12)
    bytes.addAll([0x00, 0x0C]);
    // Class: IN (1) with unicast response bit
    bytes.addAll([0x00, 0x01]);
    return bytes;
  }

  TvDevice? _parseMDNSResponse(List<int> data, InternetAddress address) {
    // Simplified: any response from an mDNS cast query implies a Chromecast-compatible device
    final response = String.fromCharCodes(data, 0, data.length.clamp(0, 500));
    
    if (response.contains('_googlecast') || response.contains('Chromecast')) {
      return TvDevice(
        id: 'cast_${address.address}',
        name: 'Chromecast (${address.address})',
        ip: address.address,
        brand: TvBrand.chromecast,
        capabilities: const DeviceCapabilities.castOnly(),
      );
    }

    if (response.contains('_androidtvremote') || response.contains('Android')) {
      return TvDevice(
        id: 'atv_${address.address}',
        name: 'Android TV (${address.address})',
        ip: address.address,
        port: 6466,
        brand: TvBrand.androidTv,
        capabilities: const DeviceCapabilities.fullRemote(),
      );
    }
    
    return null;
  }

  void _emit(TvDevice device) {
    if (!_seenIds.contains(device.id)) {
      _seenIds.add(device.id);
      debugPrint('[Discovery] ✓ Found device: ${device.name} at ${device.ip}');
      _devicesController.add(device);
    }
  }

  void stopScan() {
    _scanning = false;
    try { _ssdpSocket?.leaveMulticast(InternetAddress(_ssdpAddress)); } catch (_) {}
    _ssdpSocket?.close();
    _ssdpSocket = null;
    try { _mdnsSocket?.leaveMulticast(InternetAddress('224.0.0.251')); } catch (_) {}
    _mdnsSocket?.close();
    _mdnsSocket = null;
  }

  /// Add a device manually by IP address (fallback for network issues).
  Future<TvDevice?> addManualDevice(String ip) async {
    // Try to identify the device type by probing known ports
    final tvPorts = {
      8002: TvBrand.samsung,
      8001: TvBrand.samsung,
      3000: TvBrand.lg,
      3001: TvBrand.lg,
      8008: TvBrand.chromecast,
      8060: TvBrand.roku,
      6466: TvBrand.androidTv,
    };

    for (final entry in tvPorts.entries) {
      try {
        final socket = await Socket.connect(
          ip,
          entry.key,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();

        final brand = entry.value;
        String name;
        DeviceCapabilities caps;
        int port = entry.key;

        switch (brand) {
          case TvBrand.samsung:
            name = 'Samsung TV (Manual)';
            caps = const DeviceCapabilities.fullRemote();
            port = 8002;
            break;
          case TvBrand.lg:
            name = 'LG TV (Manual)';
            caps = const DeviceCapabilities.fullRemote();
            port = 3000;
            break;
          case TvBrand.androidTv:
            name = 'Android TV (Manual)';
            caps = const DeviceCapabilities.fullRemote();
            break;
          case TvBrand.chromecast:
            name = 'Chromecast (Manual)';
            caps = const DeviceCapabilities.castOnly();
            break;
          case TvBrand.roku:
            name = 'Roku (Manual)';
            caps = const DeviceCapabilities(
              canPower: true, canVolume: true, canChannel: true,
              canNavigate: true, canLaunchApps: true,
            );
            break;
          default:
            name = 'Smart TV (Manual)';
            caps = const DeviceCapabilities.dlnaRenderer();
        }

        final device = TvDevice(
          id: 'manual_${ip}_$port',
          name: name,
          ip: ip,
          port: port,
          brand: brand,
          capabilities: caps,
        );

        _emit(device);
        return device;
      } catch (_) {
        // Port not open, try next
      }
    }

    // No known ports found — add as unknown device anyway
    final device = TvDevice(
      id: 'manual_$ip',
      name: 'TV ($ip)',
      ip: ip,
      brand: TvBrand.unknown,
      capabilities: const DeviceCapabilities.dlnaRenderer(),
    );
    _emit(device);
    return device;
  }

  TvDevice? _parseSSDPResponse(String response, InternetAddress address) {
    if (!response.contains('200 OK')) return null;

    final locationMatch = RegExp(r'LOCATION:\s*(.+)', caseSensitive: false).firstMatch(response);
    final usnMatch = RegExp(r'USN:\s*(.+)', caseSensitive: false).firstMatch(response);
    final serverMatch = RegExp(r'SERVER:\s*(.+)', caseSensitive: false).firstMatch(response);
    final stMatch = RegExp(r'ST:\s*(.+)', caseSensitive: false).firstMatch(response);

    final location = locationMatch?.group(1)?.trim();
    final usn = usnMatch?.group(1)?.trim() ?? address.address;
    final server = (serverMatch?.group(1)?.trim() ?? '').toLowerCase();
    final st = (stMatch?.group(1)?.trim() ?? '').toLowerCase();

    TvBrand brand = TvBrand.unknown;
    String name = 'Smart TV';
    DeviceCapabilities caps = const DeviceCapabilities();
    int? port;

    if (server.contains('samsung') || server.contains('tizen')) {
      brand = TvBrand.samsung;
      name = 'Samsung TV';
      port = 8002;
      caps = const DeviceCapabilities.fullRemote();
    } else if (server.contains('webos') || server.contains('lg')) {
      brand = TvBrand.lg;
      name = 'LG TV';
      port = 3000;
      caps = const DeviceCapabilities.fullRemote();
    } else if (server.contains('android') || server.contains('google')) {
      brand = TvBrand.androidTv;
      name = 'Android TV';
      port = 6466;
      caps = const DeviceCapabilities.fullRemote();
    } else if (server.contains('roku')) {
      brand = TvBrand.roku;
      name = 'Roku';
      port = 8060;
    } else if (st.contains('mediarenderer')) {
      name = 'DLNA Renderer';
      caps = const DeviceCapabilities.dlnaRenderer();
    } else if (st.contains('dial')) {
      name = 'Smart TV (DIAL)';
      caps = const DeviceCapabilities(
        canLaunchApps: true,
        canCastMedia: true,
      );
    }

    // Add IP to name for clarity
    name = '$name (${address.address})';

    return TvDevice(
      id: usn,
      name: name,
      ip: address.address,
      port: port,
      descriptionUrl: location,
      brand: brand,
      capabilities: caps,
    );
  }
}
