import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A simple Smart TV Pairing Simulator for the VOLT Remote App.
/// 
/// This script creates an HTTP server on port 8080 that:
/// - Generates a 6-digit code for 2 minutes.
/// - Validates pairing requests via POST /pair.
/// - Receives remote commands via POST /command.
void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('=========================================');
  print('📺 VOLT TV SIMULATOR RUNNING ON PORT 8080');
  print('=========================================');

  String? currentCode;
  Timer? expiryTimer;
  Map<String, String> activeSessions = {}; // deviceId -> token

  void generateNewCode() {
    currentCode = (Random().nextInt(899999) + 100000).toString();
    print('\n[SYSTEM] New Pairing Code generated: \x1B[32m$currentCode\x1B[0m');
    print('[SYSTEM] Valid for 2 minutes.');
    
    expiryTimer?.cancel();
    expiryTimer = Timer(const Duration(minutes: 2), () {
      print('\n[SYSTEM] Code \x1B[31m$currentCode\x1B[0m EXPIRED.');
      currentCode = null;
    });
  }

  // Generate initial code
  generateNewCode();

  await for (HttpRequest request in server) {
    print('--> ${request.method} ${request.uri.path}');

    if (request.method == 'POST' && request.uri.path == '/pair') {
      final body = await utf8.decodeStream(request.body);
      final json = jsonDecode(body);
      final code = json['code'];
      final deviceId = json['deviceId'] ?? 'unknown_phone';

      if (currentCode != null && code == currentCode) {
        final token = 'volt_token_${Random().nextInt(999999)}';
        activeSessions[deviceId] = token;
        
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'success': true,
            'token': token,
            'tvName': 'Volt Simulator TV',
            'deviceId': deviceId
          }));
        
        print('\n[AUTH] ✅ Pairing SUCCESS for user: $deviceId');
        print('[AUTH] Session token issued: $token');
        
        // Generate a new code after successful pairing
        generateNewCode();
      } else {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'success': false, 'error': 'Invalid or expired code'}));
        
        print('\n[AUTH] ❌ Pairing FAILED: Invalid code $code');
      }
    } 
    else if (request.method == 'POST' && request.uri.path == '/command') {
      final authHeader = request.headers.value('Authorization');
      final body = await utf8.decodeStream(request.body);
      final json = jsonDecode(body);
      final action = json['action'];

      // Basic token validation
      if (authHeader != null && activeSessions.containsValue(authHeader.replaceFirst('Bearer ', ''))) {
        print('\n[REMOTE] 📡 COMMAND RECEIVED: \x1B[35m$action\x1B[0m');
        request.response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': true}));
      } else {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write(jsonEncode({'error': 'Unauthorized - Please pair first'}));
        print('\n[REMOTE] 🚫 BLOCKED: Unauthorized command attempt');
      }
    } 
    else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
    }

    await request.response.close();
  }
}
