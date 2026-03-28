import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import 'tv_device_controller.dart';

/// Generic DLNA / UPnP device controller.
/// Uses HTTP SOAP actions to control UPnP AVTransport and RenderingControl.
class DLNAController extends TVDeviceController {
  @override
  final TvDevice device;
  
  bool _connected = false;
  final _connectionController = StreamController<bool>.broadcast();
  
  String? _avTransportUrl;
  String? _renderingControlUrl;

  DLNAController(this.device);

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  @override
  Future<bool> connect() async {
    try {
      // Fetch the device description XML to find service control URLs
      if (device.descriptionUrl != null) {
        final response = await http.get(Uri.parse(device.descriptionUrl!))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _parseDeviceDescription(response.body);
        }
      }
      _connected = true;
      _connectionController.add(true);
      return true;
    } catch (e) {
      _onDisconnect();
      return false;
    }
  }

  void _parseDeviceDescription(String xml) {
    // Parse UPnP device description XML to extract:
    // - AVTransport control URL
    // - RenderingControl control URL
    final avMatch = RegExp(r'<controlURL>(.*/AVTransport.*?)</controlURL>').firstMatch(xml);
    final rcMatch = RegExp(r'<controlURL>(.*/RenderingControl.*?)</controlURL>').firstMatch(xml);
    
    _avTransportUrl = avMatch?.group(1);
    _renderingControlUrl = rcMatch?.group(1);
  }

  void _onDisconnect() {
    _connected = false;
    _connectionController.add(false);
  }

  @override
  Future<void> disconnect() async => _onDisconnect();

  Future<void> _sendSoapAction(String controlUrl, String serviceType, String action, String body) async {
    final url = 'http://${device.ip}$controlUrl';
    await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPAction': '"$serviceType#$action"',
      },
      body: '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:$action xmlns:u="$serviceType">
      $body
    </u:$action>
  </s:Body>
</s:Envelope>''',
    ).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (!_connected) return;
    
    switch (command) {
      case RemoteCommand.volumeUp:
        if (_renderingControlUrl != null) {
          // Get current volume, increment, set
          await _sendSoapAction(
            _renderingControlUrl!,
            'urn:schemas-upnp-org:service:RenderingControl:1',
            'SetVolume',
            '<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>50</DesiredVolume>',
          );
        }
        break;
      case RemoteCommand.play:
        if (_avTransportUrl != null) {
          await _sendSoapAction(
            _avTransportUrl!,
            'urn:schemas-upnp-org:service:AVTransport:1',
            'Play',
            '<InstanceID>0</InstanceID><Speed>1</Speed>',
          );
        }
        break;
      case RemoteCommand.pause:
        if (_avTransportUrl != null) {
          await _sendSoapAction(
            _avTransportUrl!,
            'urn:schemas-upnp-org:service:AVTransport:1',
            'Pause',
            '<InstanceID>0</InstanceID>',
          );
        }
        break;
      default:
        // DLNA renderers don't support navigation/power/channels
        break;
    }
  }

  @override
  Future<void> sendText(String text) async {
    // Not supported on DLNA
  }

  @override
  Future<void> launchApp(String appId) async {
    // Not supported on DLNA
  }
}
