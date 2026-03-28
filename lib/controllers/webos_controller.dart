import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_device.dart';
import '../models/remote_command.dart';
import 'tv_device_controller.dart';

/// LG webOS TV controller via SSAP WebSocket API (port 3000).
/// Uses the luna://com.webos.service API surface.
class WebOSController extends TVDeviceController {
  @override
  final TvDevice device;
  
  WebSocketChannel? _channel;
  String? _clientKey;
  bool _connected = false;
  bool _paired = false;
  int _commandId = 0;
  
  final _connectionController = StreamController<bool>.broadcast();

  WebOSController(this.device);

  @override
  bool get isConnected => _connected && _paired;

  @override
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  @override
  Future<bool> connect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _clientKey = prefs.getString('lg_client_key_${device.ip}');
      
      final port = device.port ?? 3000;
      _channel = WebSocketChannel.connect(Uri.parse('ws://${device.ip}:$port'));
      _connected = true;

      _channel!.stream.listen(
        (message) => _handleMessage(message, prefs),
        onDone: () => _onDisconnect(),
        onError: (_) => _onDisconnect(),
      );
      
      // Send registration/pairing request
      _sendRegistration();
      
      // Wait briefly for pairing confirmation
      await Future.delayed(const Duration(seconds: 2));
      _connectionController.add(_paired);
      return _paired || _connected; // Return connected even if pairing is pending (TV shows prompt)
    } catch (e) {
      _onDisconnect();
      return false;
    }
  }

  void _sendRegistration() {
    final payload = {
      'type': 'register',
      'id': 'register_0',
      'payload': {
        'pairingType': 'PROMPT',
        'manifest': {
          'appVersion': '1.0',
          'signed': {
            'appId': 'com.volt.remote',
            'vendorId': 'com.volt',
          },
          'permissions': [
            'LAUNCH', 'LAUNCH_WEBAPP',
            'CONTROL_AUDIO', 'CONTROL_DISPLAY',
            'CONTROL_INPUT_JOYSTICK', 'CONTROL_INPUT_MEDIA_RECORDING',
            'CONTROL_INPUT_MEDIA_PLAYBACK', 'CONTROL_INPUT_TV',
            'CONTROL_POWER', 'READ_APP_STATUS',
            'READ_CURRENT_CHANNEL', 'READ_INPUT_DEVICE_LIST',
            'READ_NETWORK_STATE', 'READ_TV_CHANNEL_LIST',
            'WRITE_NOTIFICATION',
          ],
        },
        if (_clientKey != null) 'client-key': _clientKey,
      },
    };
    _channel?.sink.add(jsonEncode(payload));
  }

  void _handleMessage(dynamic message, SharedPreferences prefs) {
    if (message is! String) return;
    final data = jsonDecode(message) as Map<String, dynamic>;
    
    // Handle registration response with client-key
    if (data['id'] == 'register_0' && data['type'] == 'registered') {
      _clientKey = data['payload']?['client-key'];
      if (_clientKey != null) {
        prefs.setString('lg_client_key_${device.ip}', _clientKey!);
        _paired = true;
        _connectionController.add(true);
      }
    }
  }

  void _onDisconnect() {
    _connected = false;
    _paired = false;
    _connectionController.add(false);
    _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> disconnect() async => _onDisconnect();

  String _nextId() => 'cmd_${++_commandId}';

  void _sendRequest(String uri, {Map<String, dynamic>? payload}) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'request',
      'id': _nextId(),
      'uri': uri,
      if (payload != null) 'payload': payload,
    }));
  }

  void _sendButton(String name) {
    // webOS uses a special input socket for button presses
    // For the main WebSocket, we use the remote input API
    _sendRequest('ssap://com.webos.service.networkinput/getPointerInputSocket');
    // Note: Full implementation requires connecting to the pointer input socket
    // and sending button events there. For now, we use URI-based commands.
  }

  @override
  Future<void> sendCommand(RemoteCommand command) async {
    switch (command) {
      case RemoteCommand.power:
        _sendRequest('ssap://system/turnOff');
        break;
      case RemoteCommand.volumeUp:
        _sendRequest('ssap://audio/volumeUp');
        break;
      case RemoteCommand.volumeDown:
        _sendRequest('ssap://audio/volumeDown');
        break;
      case RemoteCommand.mute:
        _sendRequest('ssap://audio/setMute', payload: {'mute': true});
        break;
      case RemoteCommand.channelUp:
        _sendRequest('ssap://tv/channelUp');
        break;
      case RemoteCommand.channelDown:
        _sendRequest('ssap://tv/channelDown');
        break;
      case RemoteCommand.home:
        _sendRequest('ssap://system/launcher/launch', payload: {
          'id': 'com.webos.app.home',
        });
        break;
      case RemoteCommand.back:
        // Handled via pointer input socket in full implementation
        break;
      case RemoteCommand.play:
        _sendRequest('ssap://media.controls/play');
        break;
      case RemoteCommand.pause:
        _sendRequest('ssap://media.controls/pause');
        break;
      case RemoteCommand.fastForward:
        _sendRequest('ssap://media.controls/fastForward');
        break;
      case RemoteCommand.rewind:
        _sendRequest('ssap://media.controls/rewind');
        break;
      case RemoteCommand.up:
      case RemoteCommand.down:
      case RemoteCommand.left:
      case RemoteCommand.right:
      case RemoteCommand.enter:
        // D-pad requires pointer input socket connection
        break;
    }
  }

  @override
  Future<void> sendText(String text) async {
    // Text input requires pointer input socket
    // Full implementation would connect to the input socket URI
  }

  @override
  Future<void> launchApp(String appId) async {
    _sendRequest('ssap://system/launcher/launch', payload: {'id': appId});
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    _sendRequest('ssap://com.webos.applicationManager/listLaunchPoints');
    // In production, you'd await the response and parse it
    return [];
  }

  @override
  Future<int> getVolume() async {
    _sendRequest('ssap://audio/getVolume');
    // In production, you'd await the response and parse the volume value
    return -1;
  }
}
