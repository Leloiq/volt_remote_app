import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_device.dart';
import '../models/remote_command.dart';

class CommandService {
  WebSocketChannel? _channel;
  String? _pairedToken;
  bool _isConnected = false;
  
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionStateController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect(TvDevice device) async {
    // If device has a pairing token, we use the new authenticated HTTP protocol
    if (device.pairingToken != null) {
      _isConnected = true;
      _connectionStateController.add(true);
      return;
    }

    if (device.brand != TvBrand.samsung) {
      throw Exception('This device requires pairing or is not yet supported.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _pairedToken = prefs.getString('samsung_token_${device.ip}');
      
      final appName = base64Encode(utf8.encode('Volt App'));
      String url = 'wss://${device.ip}:8002/api/v2/channels/samsung.remote.control?name=$appName';
      
      if (_pairedToken != null) {
        url += '&token=$_pairedToken';
      }

      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      
      _isConnected = true;
      _connectionStateController.add(true);

      _channel!.stream.listen((message) {
        _handleIncomingMessage(message, device.ip, prefs);
      }, onDone: () {
        _handleDisconnect();
      }, onError: (error) {
        print('WebSocket Error: $error');
        _handleDisconnect();
      });
    } catch (e) {
      _handleDisconnect();
      rethrow;
    }
  }

  void _handleIncomingMessage(dynamic message, String ip, SharedPreferences prefs) {
    if (message is String) {
      final Map<String, dynamic> data = jsonDecode(message);
      
      // Handle Token Event (Pairing Success)
      if (data['event'] == 'ms.channel.connect') {
        final token = data['data']?['token'];
        if (token != null) {
          _pairedToken = token;
          prefs.setString('samsung_token_$ip', token);
        }
      }
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStateController.add(false);
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> sendCommand(RemoteCommand command, {TvDevice? device}) async {
    // High-priority: New Pairing Protocol (HTTP)
    if (device?.pairingToken != null) {
      final url = Uri.parse('http://${device!.ip}:8080/command');
      try {
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${device.pairingToken}',
          },
          body: jsonEncode({
            'action': command.label.toUpperCase().replaceAll(' ', '_'),
          }),
        ).timeout(const Duration(milliseconds: 500));
      } catch (e) {
        print('HTTP Command Error: $e');
      }
      return;
    }

    // Classic Protocol (Samsung WebSocket)
    if (_channel == null || !_isConnected) return;
    
    final payload = jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': command.samsungKey,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });
    
    _channel!.sink.add(payload);
  }

  void disconnect() {
    _handleDisconnect();
  }
}
