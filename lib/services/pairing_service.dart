import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tv_device.dart';

class PairingResult {
  final bool success;
  final String? token;
  final String? error;

  PairingResult({required this.success, this.token, this.error});
}

class PairingService {
  /// Port used by the VOLT TV Simulator and modern pairing servers.
  static const int _pairingPort = 8080;

  /// Sends a pairing request to the TV with the 6-digit code.
  Future<PairingResult> verifyCode(String ip, String code) async {
    final url = Uri.parse('http://$ip:$_pairingPort/pair');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'deviceId': 'volt_mobile_app', // Unique ID for this phone
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PairingResult(
          success: true,
          token: data['token'],
        );
      } else {
        final data = jsonDecode(response.body);
        return PairingResult(
          success: false,
          error: data['error'] ?? 'Incorrect code. Please try again.',
        );
      }
    } catch (e) {
      return PairingResult(
        success: false,
        error: 'Connection failed. Make sure your TV and phone are on the same WiFi.',
      );
    }
  }

  /// Pings the TV to ensure the pairing server is reachable.
  Future<bool> isPairingServerAvailable(String ip) async {
    try {
      // Just a simple probe - we expect a 404 or specific response if the server is there
      final response = await http.get(Uri.parse('http://$ip:$_pairingPort/')).timeout(const Duration(seconds: 2));
      return response.statusCode != 0;
    } catch (_) {
      return false;
    }
  }
}
