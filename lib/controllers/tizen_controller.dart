import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import 'tv_device_controller.dart';

/// Samsung Tizen TV controller via WebSocket API (port 8002).
/// 
/// Performance optimizations:
/// - Pre-cached SharedPreferences (no async on hot path)
/// - Pre-encoded JSON payloads per command (zero allocation on send)
/// - Synchronous sink.add (WebSocket is already buffered)
class TizenController extends TVDeviceController {
  @override
  final TvDevice device;
  
  WebSocketChannel? _channel;
  String? _pairedToken;
  bool _connected = false;
  
  final _connectionController = StreamController<bool>.broadcast();

  // Pre-computed JSON payloads — allocated once, reused on every send.
  // This eliminates jsonEncode + Map allocation from the hot path.
  late final Map<RemoteCommand, String> _payloadCache = {
    for (final cmd in RemoteCommand.values)
      cmd: jsonEncode({
        'method': 'ms.remote.control',
        'params': {
          'Cmd': 'Click',
          'DataOfCmd': cmd.samsungKey,
          'Option': 'false',
          'TypeOfRemote': 'SendRemoteKey',
        },
      }),
  };

  TizenController(this.device);

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  @override
  Future<bool> connect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pairedToken = prefs.getString('samsung_token_${device.ip}');
      
      final appName = base64Encode(utf8.encode('VoltRemote'));
      String url = 'wss://${device.ip}:8002/api/v2/channels/samsung.remote.control?name=$appName';
      
      if (_pairedToken != null) {
        url += '&token=$_pairedToken';
      }

      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        (message) => _handleMessage(message, prefs),
        onDone: () => _onDisconnect(),
        onError: (_) => _onDisconnect(),
      );
      
      return true;
    } catch (e) {
      _onDisconnect();
      return false;
    }
  }

  void _handleMessage(dynamic message, SharedPreferences prefs) {
    if (message is String) {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['event'] == 'ms.channel.connect') {
        final token = data['data']?['token'];
        if (token != null) {
          _pairedToken = token;
          prefs.setString('samsung_token_${device.ip}', token);
        }
      }
    }
  }

  void _onDisconnect() {
    _connected = false;
    _connectionController.add(false);
    _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> disconnect() async => _onDisconnect();

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    if (_channel == null || !_connected) return;
    // Zero-allocation send: use pre-computed payload string
    _channel!.sink.add(_payloadCache[command]!);
  }

  @override
  Future<void> sendText(String text) async {
    if (_channel == null || !_connected) return;
    final encoded = base64Encode(utf8.encode(text));
    _channel!.sink.add(jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': encoded,
        'DataOfCmd': 'base64',
        'TypeOfRemote': 'SendInputString',
      },
    }));
  }

  @override
  Future<void> launchApp(String appId) async {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({
      'method': 'ms.channel.emit',
      'params': {
        'event': 'ed.apps.launch',
        'to': 'host',
        'data': {'appId': appId, 'action_type': 'DEEP_LINK'},
      },
    }));
  }
}
