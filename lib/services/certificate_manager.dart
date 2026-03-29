import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:asn1lib/asn1lib.dart';

/// Manages self-signed RSA certificates for Android TV TLS pairing.
/// 
/// The Android TV Remote Protocol v2 requires mutual TLS authentication.
/// We generate a self-signed RSA 2048-bit certificate on first launch,
/// then reuse it for all future connections. The cert is stored in the
/// platform's secure keychain via flutter_secure_storage.
class CertificateManager {
  static const _certKey = 'volt_atv_cert_pem';
  static const _keyKey = 'volt_atv_key_pem';
  static const _storage = FlutterSecureStorage();

  String? _certPem;
  String? _keyPem;

  String? get certPem => _certPem;
  String? get keyPem => _keyPem;

  /// Initialize: load existing certs or generate new ones.
  Future<void> initialize() async {
    _certPem = await _storage.read(key: _certKey);
    _keyPem = await _storage.read(key: _keyKey);

    if (_certPem == null || _keyPem == null) {
      debugPrint('[CertManager] Generating new RSA 2048 certificate...');
      await _generateAndStore();
      debugPrint('[CertManager] Certificate generated and stored.');
    } else {
      debugPrint('[CertManager] Loaded existing certificate from secure storage.');
    }
  }

  Future<void> _generateAndStore() async {
    final keyPair = _generateRSAKeyPair();
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    // Build self-signed X.509 certificate
    final certDer = _buildSelfSignedCert(publicKey, privateKey);
    final keyDer = _encodePrivateKeyPkcs8(privateKey);

    _certPem = _derToPem(certDer, 'CERTIFICATE');
    _keyPem = _derToPem(keyDer, 'PRIVATE KEY');

    await _storage.write(key: _certKey, value: _certPem);
    await _storage.write(key: _keyKey, value: _keyPem);
  }

  /// Generate RSA 2048-bit key pair.
  AsymmetricKeyPair<PublicKey, PrivateKey> _generateRSAKeyPair() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        secureRandom,
      ));

    return keyGen.generateKeyPair();
  }

  /// Build a self-signed X.509 v3 certificate in DER format.
  Uint8List _buildSelfSignedCert(RSAPublicKey publicKey, RSAPrivateKey privateKey) {
    final now = DateTime.now().toUtc();
    final notBefore = now.subtract(const Duration(days: 1));
    final notAfter = now.add(const Duration(days: 3650)); // 10 years

    // TBSCertificate
    final tbs = ASN1Sequence();

    // Version: v3 (2)
    final versionTag = ASN1Object.fromBytes(
      Uint8List.fromList([0xA0, 0x03, 0x02, 0x01, 0x02]),
    );
    tbs.add(versionTag);

    // Serial Number
    tbs.add(ASN1Integer(BigInt.from(1000)));

    // Signature Algorithm: SHA256withRSA (OID 1.2.840.113549.1.1.11)
    final sigAlg = ASN1Sequence();
    sigAlg.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.11'));
    sigAlg.add(ASN1Null());
    tbs.add(sigAlg);

    // Issuer: CN=volt-remote
    final issuer = _buildDN('volt-remote');
    tbs.add(issuer);

    // Validity
    final validity = ASN1Sequence();
    validity.add(ASN1UtcTime(notBefore));
    validity.add(ASN1UtcTime(notAfter));
    tbs.add(validity);

    // Subject: CN=volt-remote
    tbs.add(_buildDN('volt-remote'));

    // Subject Public Key Info
    tbs.add(_encodePublicKeyInfo(publicKey));

    // Encode TBSCertificate
    final tbsBytes = tbs.encode();

    // Sign the TBSCertificate
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(tbsBytes) as RSASignature;

    // Full Certificate
    final cert = ASN1Sequence();
    cert.add(tbs);
    cert.add(sigAlg); // Same algorithm as above

    // Signature value (BIT STRING)
    final sigBits = ASN1BitString(
      Uint8List.fromList([0x00, ...signature.bytes]),
    );
    cert.add(sigBits);

    return cert.encode();
  }

  ASN1Sequence _buildDN(String cn) {
    final dn = ASN1Sequence();
    final rdn = ASN1Set();
    final atv = ASN1Sequence();
    // OID for CN: 2.5.4.3
    atv.add(ASN1ObjectIdentifier.fromComponentString('2.5.4.3'));
    atv.add(ASN1UTF8String(cn));
    rdn.add(atv);
    dn.add(rdn);
    return dn;
  }

  ASN1Sequence _encodePublicKeyInfo(RSAPublicKey key) {
    final algSeq = ASN1Sequence();
    algSeq.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1')); // rsaEncryption
    algSeq.add(ASN1Null());

    final pubKeySeq = ASN1Sequence();
    pubKeySeq.add(ASN1Integer(key.modulus!));
    pubKeySeq.add(ASN1Integer(key.exponent!));

    final pubKeyBitString = ASN1BitString(Uint8List.fromList([0x00, ...pubKeySeq.encode()]));

    final spki = ASN1Sequence();
    spki.add(algSeq);
    spki.add(pubKeyBitString);
    return spki;
  }

  /// Encode RSA private key in PKCS#8 DER format.
  Uint8List _encodePrivateKeyPkcs8(RSAPrivateKey key) {
    // RSAPrivateKey sequence
    final rsaKey = ASN1Sequence();
    rsaKey.add(ASN1Integer(BigInt.zero)); // version
    rsaKey.add(ASN1Integer(key.modulus!));
    rsaKey.add(ASN1Integer(key.publicExponent!));
    rsaKey.add(ASN1Integer(key.privateExponent!));
    rsaKey.add(ASN1Integer(key.p!));
    rsaKey.add(ASN1Integer(key.q!));
    // d mod (p-1)
    rsaKey.add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.one)));
    // d mod (q-1)
    rsaKey.add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.one)));
    // q^(-1) mod p
    rsaKey.add(ASN1Integer(key.q!.modInverse(key.p!)));

    final rsaKeyBytes = rsaKey.encode();

    // PKCS#8 wrapper
    final algSeq = ASN1Sequence();
    algSeq.add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'));
    algSeq.add(ASN1Null());

    final pkcs8 = ASN1Sequence();
    pkcs8.add(ASN1Integer(BigInt.zero)); // version
    pkcs8.add(algSeq);
    pkcs8.add(ASN1OctetString(octets: rsaKeyBytes));

    return pkcs8.encode();
  }

  /// Convert DER bytes to PEM string.
  String _derToPem(Uint8List der, String label) {
    final b64 = _base64Encode(der);
    final lines = <String>['-----BEGIN $label-----'];
    for (int i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    lines.add('-----END $label-----');
    return lines.join('\n');
  }

  String _base64Encode(Uint8List data) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buf = StringBuffer();
    int i = 0;
    while (i < data.length) {
      final b0 = data[i++];
      final b1 = i < data.length ? data[i++] : -1;
      final b2 = i < data.length ? data[i++] : -1;
      buf.write(chars[(b0 >> 2) & 0x3F]);
      buf.write(chars[((b0 << 4) | (b1 >= 0 ? (b1 >> 4) : 0)) & 0x3F]);
      buf.write(b1 >= 0 ? chars[((b1 << 2) | (b2 >= 0 ? (b2 >> 6) : 0)) & 0x3F] : '=');
      buf.write(b2 >= 0 ? chars[b2 & 0x3F] : '=');
    }
    return buf.toString();
  }

  /// Extract the modulus and public exponent from the stored PEM certificate.
  /// Returns (modulus, exponent) as BigInt.
  (BigInt, BigInt) getPublicKeyComponents() {
    if (_certPem == null) throw StateError('Certificate not initialized');
    final der = _pemToDer(_certPem!);
    // Parse X.509 cert → TBSCertificate → SubjectPublicKeyInfo → RSA params
    final certSeq = ASN1Parser(der).nextObject() as ASN1Sequence;
    final tbsSeq = certSeq.elements![0] as ASN1Sequence;
    // SubjectPublicKeyInfo is at index 6 (after version, serial, alg, issuer, validity, subject)
    final spki = tbsSeq.elements![6] as ASN1Sequence;
    final pubKeyBits = spki.elements![1] as ASN1BitString;
    // Strip the leading 0x00 byte from the BIT STRING
    final pubKeyBytes = Uint8List.sublistView(pubKeyBits.encode(),
        pubKeyBits.encode().length - pubKeyBits.numberOfUnusedBits - pubKeyBits.contentBytes()!.length + 1);
    // Actually, let's parse it properly
    final pubKeyDer = pubKeyBits.contentBytes()!;
    // Skip leading 0x00 unused-bits byte
    final pubKeySeqBytes = pubKeyDer.sublist(1);
    final pubKeySeq = ASN1Parser(Uint8List.fromList(pubKeySeqBytes)).nextObject() as ASN1Sequence;
    final modulus = (pubKeySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (pubKeySeq.elements![1] as ASN1Integer).integer!;
    return (modulus, exponent);
  }

  Uint8List _pemToDer(String pem) {
    final lines = pem.split('\n')
        .where((l) => !l.startsWith('-----'))
        .join();
    return _base64Decode(lines);
  }

  Uint8List _base64Decode(String input) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = <int>[];
    int buffer = 0;
    int bitsCollected = 0;
    for (int i = 0; i < input.length; i++) {
      final c = input[i];
      if (c == '=') break;
      final value = chars.indexOf(c);
      if (value < 0) continue;
      buffer = (buffer << 6) | value;
      bitsCollected += 6;
      if (bitsCollected >= 8) {
        bitsCollected -= 8;
        bytes.add((buffer >> bitsCollected) & 0xFF);
      }
    }
    return Uint8List.fromList(bytes);
  }

  /// Delete stored certificates (for re-pairing).
  Future<void> deleteCertificates() async {
    await _storage.delete(key: _certKey);
    await _storage.delete(key: _keyKey);
    _certPem = null;
    _keyPem = null;
  }
}
