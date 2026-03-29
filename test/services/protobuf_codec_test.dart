import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:volt_remote_app/services/protobuf_codec.dart';

void main() {
  group('Varint Encoding / Decoding', () {
    test('Encodes and decodes simple small values', () {
      final bytes = encodeVarint(5);
      expect(bytes, [0x05]);

      final (decoded, len) = decodeVarint(bytes, 0);
      expect(decoded, 5);
      expect(len, 1);
    });

    test('Encodes and decodes multi-byte varints', () {
      final bytes = encodeVarint(300);
      // 300 = 0000 0001 0010 1100
      // 7 bits chunk 1: 010 1100 -> 0x2C | 0x80 -> 0xAC
      // 7 bits chunk 2: 000 0010 -> 0x02
      expect(bytes, [0xAC, 0x02]);

      final (decoded, len) = decodeVarint(bytes, 0);
      expect(decoded, 300);
      expect(len, 2);
    });

    test('Fails on negative values', () {
      expect(() => encodeVarint(-1), throwsArgumentError);
    });
  });

  group('Protobuf Field Encoding', () {
    test('encodeVarintField formats tag correctly', () {
      final field = encodeVarintField(1, 150);
      // Tag for field 1, wireType 0: 1 << 3 | 0 = 8
      // Value 150: 1001 0110 -> 0x96, 0000 0001 -> 0x01
      expect(field, [0x08, 0x96, 0x01]);
    });

    test('encodeStringField encodes length delimited string', () {
      final field = encodeStringField(2, 'test');
      // Tag for field 2, wireType 2: 2 << 3 | 2 = 18 (0x12)
      // Length: 4
      // string: 't', 'e', 's', 't'
      expect(field, [0x12, 0x04, 116, 101, 115, 116]);
    });
  });

  group('Protobuf Parsing', () {
    test('Parses multiple fields', () {
      // Create a dummy message
      final data = Uint8List.fromList([
        ...encodeVarintField(1, 42),
        ...encodeStringField(2, 'hello'),
      ]);

      final fields = parseProtoFields(data);
      expect(fields.length, 2);

      final f1 = getField(fields, 1);
      expect(f1?.wireType, 0);
      expect(f1?.value, 42);

      final f2 = getField(fields, 2);
      expect(f2?.wireType, 2);
      expect(String.fromCharCodes(f2?.value as Uint8List), 'hello');
    });
  });

  group('PairingCodec', () {
    test('buildPairingRequest creates correct OuterMessage', () {
      final request = PairingCodec.buildPairingRequest('TestClient', 'TestService');
      final response = PairingCodec.parseOuterMessage(request);
      
      // We don't have a parse builder for sending, but we can parse it as OuterMessage
      // and check the status field manually.
      final fields = parseProtoFields(request);
      expect(getField(fields, 1)?.value, 2); // protocol_version = 2
      expect(getField(fields, 2)?.value, 200); // status = 200
      expect(hasField(fields, 10), isTrue); // pairing_request is field 10
    });

    test('parseOuterMessage identifies SecretAck phase', () {
      // Hand-craft a SecretAck OuterMessage
      final parts = <int>[
        ...encodeVarintField(1, 2),        // protocol_version = 2
        ...encodeVarintField(2, 200),      // status = 200
        ...encodeMessageField(41, Uint8List(0)), // secret_ack is field 41
      ];

      final response = PairingCodec.parseOuterMessage(Uint8List.fromList(parts));
      expect(response.phase, PairingPhase.secretAck);
      expect(response.status, 200);
    });
  });

  group('RemoteCodec', () {
    test('buildKeyInject returns properly structured field', () {
      final btn = RemoteCodec.buildKeyInject(AndroidKeyCode.home);
      
      // Should be field 10 (RemoteKeyInject)
      final fields = parseProtoFields(Uint8List.fromList(btn));
      final innerData = getField(fields, 10)?.value as Uint8List;
      final innerFields = parseProtoFields(innerData);

      expect(getField(innerFields, 1)?.value, AndroidKeyCode.home);
      expect(getField(innerFields, 2)?.value, RemoteCodec.directionShort);
    });

    test('parseRemoteMessage handles VolumeLevel', () {
      // Construct a RemoteSetVolumeLevel
      final volMsg = Uint8List.fromList([
        ...encodeVarintField(6, 100), // max
        ...encodeVarintField(7, 25),  // level
        ...encodeVarintField(8, 0),   // muted (false)
      ]);

      // Wrap in RemoteMessage (field 50)
      final outer = encodeMessageField(50, volMsg);

      final response = RemoteCodec.parseRemoteMessage(Uint8List.fromList(outer));
      expect(response.type, RemoteMessageType.volumeLevel);
      expect(response.volumeMax, 100);
      expect(response.volumeLevel, 25);
      expect(response.volumeMuted, isFalse);
    });
  });

  group('Framing', () {
    test('Frames and extracts messages correctly', () {
      final msg1 = Uint8List.fromList([1, 2, 3]);
      final msg2 = Uint8List.fromList([4, 5, 6, 7]);

      final buffer = Uint8List.fromList([
        ...frameMessage(msg1),
        ...frameMessage(msg2)
      ]);

      final (messages, remaining) = extractFramedMessages(buffer);
      expect(messages.length, 2);
      expect(messages[0], [1, 2, 3]);
      expect(messages[1], [4, 5, 6, 7]);
      expect(remaining.length, 0);
    });

    test('Partial messages remain in buffer', () {
      final msg = Uint8List.fromList([1, 2, 3, 4, 5]);
      final framed = frameMessage(msg);

      // Cut off the last 2 bytes
      final partialBuffer = Uint8List.sublistView(framed, 0, framed.length - 2);

      final (messages, remaining) = extractFramedMessages(partialBuffer);
      
      // Should extract nothing and leave everything in remaining
      expect(messages.length, 0);
      expect(remaining.length, partialBuffer.length);
      expect(remaining, partialBuffer);
    });
  });
}
