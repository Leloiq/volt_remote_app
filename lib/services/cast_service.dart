import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Fallback 1: Google Cast HTTP-based control.
///
/// Works with Chromecast-enabled devices. Limited to volume and basic playback.
/// No D-PAD navigation — Cast doesn't support it.
class CastService {
  String? _ip;
  bool _isConnected = false;
  Map<String, dynamic>? _deviceInfo;

  bool get isConnected => _isConnected;
  Map<String, dynamic>? get deviceInfo => _deviceInfo;

  /// Attempt to connect to a Cast device via its HTTP info endpoint.
  Future<bool> connect(String ip) async {
    _ip = ip;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(
        Uri.parse('http://$ip:8008/setup/eureka_info?params=version,name,build_info'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        _deviceInfo = json.decode(body) as Map<String, dynamic>;
        _isConnected = true;
        debugPrint('[Cast] Connected: ${_deviceInfo?['name']}');
        client.close();
        return true;
      }

      client.close();
      return false;
    } catch (e) {
      debugPrint('[Cast] Connection failed: $e');
      return false;
    }
  }

  /// Send a volume change via Cast REST API.
  Future<bool> setVolume(double level) async {
    if (!_isConnected || _ip == null) return false;
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://$_ip:8008/setup/assistant/set_volume'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode({'volume': (level * 100).round()}));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Cast] Volume command failed: $e');
      return false;
    }
  }

  /// Send volume up/down commands.
  Future<bool> volumeUp() async => _postCommand('volume_up');
  Future<bool> volumeDown() async => _postCommand('volume_down');
  Future<bool> mute() async => _postCommand('mute');

  Future<bool> _postCommand(String command) async {
    if (!_isConnected || _ip == null) return false;
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://$_ip:8008/setup/assistant/$command'),
      );
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Cast] Command $command failed: $e');
      return false;
    }
  }

  void disconnect() {
    _isConnected = false;
    _deviceInfo = null;
    _ip = null;
  }

  void dispose() {
    disconnect();
  }
}
