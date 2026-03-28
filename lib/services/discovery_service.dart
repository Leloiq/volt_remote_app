import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/tv_device.dart';

/// Unified device discovery service.
/// Scans the local network using multiple protocols simultaneously:
/// - SSDP (UPnP) for Samsung, LG, DLNA, and generic Smart TVs
/// - mDNS/Bonjour for Chromecast and Android TV devices
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

  final _devicesController = StreamController<TvDevice>.broadcast();
  Stream<TvDevice> get onDeviceFound => _devicesController.stream;

  final Set<String> _seenIds = {};
  RawDatagramSocket? _socket;

  /// Start scanning with all protocols in parallel.
  Future<void> scan() async {
    if (kIsWeb) return;
    
    _seenIds.clear();
    
    await Future.wait([
      _scanSSDP(),
      _scanMDNS(),
    ]);
  }

  /// SSDP/UPnP scan: sends multiple M-SEARCH queries.
  Future<void> _scanSSDP() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _socket!.multicastHops = 4;

      // Send all three search types
      for (final query in [_dialSearch, _upnpSearch, _rootSearch]) {
        _socket!.send(query.codeUnits, InternetAddress(_ssdpAddress), _ssdpPort);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            final response = String.fromCharCodes(datagram.data);
            final device = _parseSSDPResponse(response, datagram.address);
            if (device != null) _emit(device);
          }
        }
      });

      await Future.delayed(const Duration(seconds: 5));
      _socket?.close();
      _socket = null;
    } catch (e) {
      _socket?.close();
      _socket = null;
    }
  }

  /// mDNS/Bonjour scan: discovers Chromecast and Android TV devices.
  Future<void> _scanMDNS() async {
    try {
      // Scan for Google Cast devices (_googlecast._tcp.local)
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      
      // mDNS query for _googlecast._tcp.local
      // This is a simplified query — full implementation uses the multicast_dns package
      final mdnsAddress = InternetAddress('224.0.0.251');
      final mdnsPort = 5353;
      
      // Construct a minimal mDNS query for _googlecast._tcp.local
      final query = _buildMDNSQuery('_googlecast._tcp.local');
      socket.send(query, mdnsAddress, mdnsPort);
      
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final device = _parseMDNSResponse(datagram.data, datagram.address);
            if (device != null) _emit(device);
          }
        }
      });

      await Future.delayed(const Duration(seconds: 4));
      socket.close();
    } catch (e) {
      // mDNS may fail on web platform — this is expected
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
        name: 'Chromecast',
        ip: address.address,
        brand: TvBrand.chromecast,
        capabilities: const DeviceCapabilities.castOnly(),
      );
    }
    
    return null;
  }

  void _emit(TvDevice device) {
    if (!_seenIds.contains(device.id)) {
      _seenIds.add(device.id);
      _devicesController.add(device);
    }
  }

  void stopScan() {
    _socket?.close();
    _socket = null;
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
    }

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
