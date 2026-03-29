import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volt_remote_app/services/certificate_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage method channel
  const MethodChannel channel = MethodChannel('plugins.it_nomad.com/flutter_secure_storage');
  
  final Map<String, String> mockStorage = {};

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'read':
          final key = methodCall.arguments['key'];
          return mockStorage[key];
        case 'write':
          final key = methodCall.arguments['key'];
          final value = methodCall.arguments['value'];
          mockStorage[key] = value;
          return null;
        case 'delete':
          final key = methodCall.arguments['key'];
          mockStorage.remove(key);
          return null;
        case 'deleteAll':
          mockStorage.clear();
          return null;
        case 'containsKey':
          final key = methodCall.arguments['key'];
          return mockStorage.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    mockStorage.clear();
  });

  group('CertificateManager', () {
    test('Generates new RSA Key Pair and X509 Cert if not present', () async {
      final certManager = CertificateManager();
      
      expect(certManager.certPem, isNull);
      expect(certManager.keyPem, isNull);

      await certManager.initialize();

      // Ensure they exist now
      expect(certManager.certPem, isNotNull);
      expect(certManager.keyPem, isNotNull);
      
      expect(certManager.certPem!.startsWith('-----BEGIN CERTIFICATE-----'), isTrue);
      expect(certManager.keyPem!.startsWith('-----BEGIN PRIVATE KEY-----'), isTrue);

      // Verify it was saved to our mock storage
      expect(mockStorage['volt_atv_cert_pem'], isNotNull);
      expect(mockStorage['volt_atv_key_pem'], isNotNull);
    });

    test('Loads existing certs from storage if present', () async {
      mockStorage['volt_atv_cert_pem'] = '-----BEGIN CERTIFICATE-----\nMOCK_CERT\n-----END CERTIFICATE-----';
      mockStorage['volt_atv_key_pem'] = '-----BEGIN PRIVATE KEY-----\nMOCK_KEY\n-----END PRIVATE KEY-----';

      final certManager = CertificateManager();
      
      await certManager.initialize();

      expect(certManager.certPem, contains('MOCK_CERT'));
      expect(certManager.keyPem, contains('MOCK_KEY'));
    });

    test('getPublicKeyComponents extracts modulus and exponent from generated PEM', () async {
      final certManager = CertificateManager();
      await certManager.initialize();

      // This requires ASN.1 parsing of our generated X.509 cert.
      final (modulus, exponent) = certManager.getPublicKeyComponents();

      // Expected RSA public exponent is usually 65537 (0x10001)
      expect(exponent, equals(BigInt.from(65537)));
      
      // Modulus for 2048-bit key should be large
      expect(modulus.bitLength, greaterThan(2040));
    });

    test('deleteCertificates removes them from storage and memory', () async {
      final certManager = CertificateManager();
      await certManager.initialize();

      expect(certManager.certPem, isNotNull);
      expect(mockStorage.isNotEmpty, isTrue);

      await certManager.deleteCertificates();

      expect(certManager.certPem, isNull);
      expect(certManager.keyPem, isNull);
      expect(mockStorage.isEmpty, isTrue);
    });
  });
}
