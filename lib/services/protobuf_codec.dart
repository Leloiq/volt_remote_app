import 'dart:typed_data';

// ============================================================================
//  VARINT ENCODING / DECODING
//  Protobuf uses LEB128-style variable-length integers.
// ============================================================================

/// Encode an integer as a protobuf varint.
Uint8List encodeVarint(int value) {
  if (value < 0) throw ArgumentError('Varint must be non-negative');
  final bytes = <int>[];
  while (value > 0x7F) {
    bytes.add((value & 0x7F) | 0x80);
    value >>= 7;
  }
  bytes.add(value & 0x7F);
  return Uint8List.fromList(bytes);
}

/// Decode a varint from bytes starting at [offset].
/// Returns (value, bytesConsumed).
(int, int) decodeVarint(Uint8List data, int offset) {
  int result = 0;
  int shift = 0;
  int pos = offset;
  while (pos < data.length) {
    final byte = data[pos];
    result |= (byte & 0x7F) << shift;
    pos++;
    if ((byte & 0x80) == 0) break;
    shift += 7;
  }
  return (result, pos - offset);
}

// ============================================================================
//  PROTOBUF FIELD ENCODING
//  Wire types: 0=varint, 2=length-delimited, 5=32-bit fixed
// ============================================================================

/// Encode a varint field: tag + varint value.
Uint8List encodeVarintField(int fieldNumber, int value) {
  final tag = encodeVarint((fieldNumber << 3) | 0); // wire type 0
  final val = encodeVarint(value);
  return Uint8List.fromList([...tag, ...val]);
}

/// Encode a length-delimited field: tag + length + bytes.
Uint8List encodeLengthDelimited(int fieldNumber, Uint8List data) {
  final tag = encodeVarint((fieldNumber << 3) | 2); // wire type 2
  final len = encodeVarint(data.length);
  return Uint8List.fromList([...tag, ...len, ...data]);
}

/// Encode a string field.
Uint8List encodeStringField(int fieldNumber, String value) {
  return encodeLengthDelimited(fieldNumber, Uint8List.fromList(value.codeUnits));
}

/// Encode an embedded message field.
Uint8List encodeMessageField(int fieldNumber, Uint8List messageBytes) {
  return encodeLengthDelimited(fieldNumber, messageBytes);
}

/// Encode a bytes field.
Uint8List encodeBytesField(int fieldNumber, Uint8List value) {
  return encodeLengthDelimited(fieldNumber, value);
}

// ============================================================================
//  PROTOBUF FIELD DECODING
// ============================================================================

/// A decoded protobuf field.
class ProtoField {
  final int fieldNumber;
  final int wireType;
  final dynamic value; // int for varint, Uint8List for length-delimited

  ProtoField(this.fieldNumber, this.wireType, this.value);
}

/// Parse all fields from a protobuf message.
List<ProtoField> parseProtoFields(Uint8List data) {
  final fields = <ProtoField>[];
  int pos = 0;
  while (pos < data.length) {
    final (tag, tagLen) = decodeVarint(data, pos);
    pos += tagLen;
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x07;

    switch (wireType) {
      case 0: // Varint
        final (value, valLen) = decodeVarint(data, pos);
        pos += valLen;
        fields.add(ProtoField(fieldNumber, wireType, value));
        break;
      case 2: // Length-delimited
        final (len, lenBytes) = decodeVarint(data, pos);
        pos += lenBytes;
        if (pos + len > data.length) return fields;
        final value = Uint8List.sublistView(data, pos, pos + len);
        pos += len;
        fields.add(ProtoField(fieldNumber, wireType, value));
        break;
      case 5: // 32-bit fixed
        if (pos + 4 > data.length) return fields;
        final value = ByteData.sublistView(data, pos, pos + 4).getUint32(0, Endian.little);
        pos += 4;
        fields.add(ProtoField(fieldNumber, wireType, value));
        break;
      default:
        // Unknown wire type — skip
        return fields;
    }
  }
  return fields;
}

/// Get a field by number from a parsed list.
ProtoField? getField(List<ProtoField> fields, int fieldNumber) {
  for (final f in fields) {
    if (f.fieldNumber == fieldNumber) return f;
  }
  return null;
}

/// Check if a field exists.
bool hasField(List<ProtoField> fields, int fieldNumber) {
  return getField(fields, fieldNumber) != null;
}

// ============================================================================
//  POLO.PROTO — OuterMessage (Pairing)
//
//  message OuterMessage {
//    required uint32 protocol_version = 1;
//    required Status status = 2; // 200=OK
//    optional PairingRequest pairing_request = 10;
//    optional PairingRequestAck pairing_request_ack = 11;
//    optional Options options = 20;
//    optional Configuration configuration = 30;
//    optional ConfigurationAck configuration_ack = 31;
//    optional Secret secret = 40;
//    optional SecretAck secret_ack = 41;
//  }
// ============================================================================

class PairingCodec {
  // Status values
  static const int statusOk = 200;
  static const int statusError = 400;
  static const int statusBadSecret = 402;

  // Encoding types
  static const int encodingHexadecimal = 3;

  // Role types
  static const int roleInput = 1;

  /// Build PairingRequest message.
  static Uint8List buildPairingRequest(String clientName, String serviceName) {
    // PairingRequest: service_name=1, client_name=2
    final inner = Uint8List.fromList([
      ...encodeStringField(1, serviceName),
      ...encodeStringField(2, clientName),
    ]);
    return _wrapOuterMessage(pairingRequestField: inner);
  }

  /// Build Options message (client wants to INPUT hex code of length 6).
  static Uint8List buildOptions() {
    // Encoding: type=1 (varint), symbol_length=2 (varint)
    final encoding = Uint8List.fromList([
      ...encodeVarintField(1, encodingHexadecimal),
      ...encodeVarintField(2, 6),
    ]);
    // Options: input_encodings=1 (repeated), preferred_role=3
    final options = Uint8List.fromList([
      ...encodeMessageField(1, encoding),
      ...encodeVarintField(3, roleInput),
    ]);
    return _wrapOuterMessage(optionsField: options);
  }

  /// Build Configuration message.
  static Uint8List buildConfiguration() {
    // Encoding sub-message
    final encoding = Uint8List.fromList([
      ...encodeVarintField(1, encodingHexadecimal),
      ...encodeVarintField(2, 6),
    ]);
    // Configuration: encoding=1, client_role=2
    final config = Uint8List.fromList([
      ...encodeMessageField(1, encoding),
      ...encodeVarintField(2, roleInput),
    ]);
    return _wrapOuterMessage(configurationField: config);
  }

  /// Build Secret message.
  static Uint8List buildSecret(Uint8List secretHash) {
    // Secret: secret=1 (bytes)
    final secret = encodeBytesField(1, secretHash);
    return _wrapOuterMessage(secretField: secret);
  }

  /// Wrap inner payload into an OuterMessage with protocol_version=2, status=OK.
  static Uint8List _wrapOuterMessage({
    Uint8List? pairingRequestField,    // field 10
    Uint8List? optionsField,           // field 20
    Uint8List? configurationField,     // field 30
    Uint8List? secretField,            // field 40
  }) {
    final parts = <int>[
      ...encodeVarintField(1, 2),        // protocol_version = 2
      ...encodeVarintField(2, statusOk), // status = 200
    ];
    if (pairingRequestField != null) {
      parts.addAll(encodeMessageField(10, pairingRequestField));
    }
    if (optionsField != null) {
      parts.addAll(encodeMessageField(20, optionsField));
    }
    if (configurationField != null) {
      parts.addAll(encodeMessageField(30, configurationField));
    }
    if (secretField != null) {
      parts.addAll(encodeMessageField(40, secretField));
    }
    return Uint8List.fromList(parts);
  }

  /// Parse an OuterMessage and determine which phase it belongs to.
  static PairingResponse parseOuterMessage(Uint8List data) {
    final fields = parseProtoFields(data);
    final statusField = getField(fields, 2);
    final status = statusField?.value as int? ?? 0;

    if (hasField(fields, 11)) return PairingResponse(PairingPhase.pairingRequestAck, status);
    if (hasField(fields, 20)) return PairingResponse(PairingPhase.options, status);
    if (hasField(fields, 31)) return PairingResponse(PairingPhase.configurationAck, status);
    if (hasField(fields, 41)) return PairingResponse(PairingPhase.secretAck, status);

    return PairingResponse(PairingPhase.unknown, status);
  }
}

enum PairingPhase {
  pairingRequestAck,
  options,
  configurationAck,
  secretAck,
  unknown,
}

class PairingResponse {
  final PairingPhase phase;
  final int status;
  PairingResponse(this.phase, this.status);
}

// ============================================================================
//  REMOTEMESSAGE.PROTO — RemoteMessage (Commands)
//
//  message RemoteMessage {
//    RemoteConfigure remote_configure = 1;
//    RemoteSetActive remote_set_active = 2;
//    RemoteError remote_error = 3;
//    RemotePingRequest remote_ping_request = 8;
//    RemotePingResponse remote_ping_response = 9;
//    RemoteKeyInject remote_key_inject = 10;
//    RemoteStart remote_start = 40;
//    RemoteSetVolumeLevel remote_set_volume_level = 50;
//    RemoteAppLinkLaunchRequest remote_app_link_launch_request = 90;
//  }
//
//  RemoteKeyInject { key_code=1, direction=2 }
//  RemoteDirection: SHORT=3, START_LONG=1, END_LONG=2
//  RemotePingResponse { val1=1 }
//  RemoteConfigure { code1=1, device_info=2 }
//  RemoteDeviceInfo { model=1, vendor=2, unknown1=3, unknown2=4,
//                     package_name=5, app_version=6 }
//  RemoteSetActive { active=1 }
//  RemoteStart { started=1 }
//  RemoteSetVolumeLevel { ... volume_max=6, volume_level=7, volume_muted=8 }
//  RemoteAppLinkLaunchRequest { app_link=1 }
// ============================================================================

class RemoteCodec {
  // RemoteDirection enum values
  static const int directionShort = 3;
  static const int directionStartLong = 1;
  static const int directionEndLong = 2;

  // Feature bitmask
  static const int featurePing = 1;
  static const int featureKey = 2;
  static const int featureIme = 4;
  static const int featurePower = 32;
  static const int featureVolume = 64;
  static const int featureAppLink = 512;

  static int get defaultFeatures =>
      featurePing | featureKey | featurePower | featureVolume | featureAppLink;

  /// Build a RemoteKeyInject command.
  static Uint8List buildKeyInject(int keyCode, {int direction = directionShort}) {
    // RemoteKeyInject: key_code=1, direction=2
    final keyInject = Uint8List.fromList([
      ...encodeVarintField(1, keyCode),
      ...encodeVarintField(2, direction),
    ]);
    // RemoteMessage: remote_key_inject=10
    return encodeMessageField(10, keyInject);
  }

  /// Build a RemotePingResponse.
  static Uint8List buildPingResponse(int val1) {
    final ping = encodeVarintField(1, val1);
    return encodeMessageField(9, ping);
  }

  /// Build RemoteConfigure response (our capabilities).
  static Uint8List buildConfigureResponse(int features) {
    // RemoteDeviceInfo
    final deviceInfo = Uint8List.fromList([
      ...encodeVarintField(3, 1),                   // unknown1 = 1
      ...encodeStringField(4, '1'),                  // unknown2 = "1"
      ...encodeStringField(5, 'com.volt.remote'),    // package_name
      ...encodeStringField(6, '1.0.0'),              // app_version
    ]);
    // RemoteConfigure: code1=1, device_info=2
    final configure = Uint8List.fromList([
      ...encodeVarintField(1, features),
      ...encodeMessageField(2, deviceInfo),
    ]);
    return encodeMessageField(1, configure);
  }

  /// Build RemoteSetActive response.
  static Uint8List buildSetActiveResponse(int features) {
    final setActive = encodeVarintField(1, features);
    return encodeMessageField(2, setActive);
  }

  /// Build RemoteAppLinkLaunchRequest.
  static Uint8List buildAppLinkLaunch(String appLink) {
    final inner = encodeStringField(1, appLink);
    return encodeMessageField(90, inner);
  }

  /// Build RemoteImeBatchEdit for text input.
  static Uint8List buildTextInput(String text, int imeCounter, int fieldCounter) {
    // RemoteImeObject: start=1, end=2, value=3
    final imeObject = Uint8List.fromList([
      ...encodeVarintField(1, text.length - 1),
      ...encodeVarintField(2, text.length - 1),
      ...encodeStringField(3, text),
    ]);
    // RemoteEditInfo: insert=1, text_field_status=2
    final editInfo = Uint8List.fromList([
      ...encodeVarintField(1, 1),
      ...encodeMessageField(2, imeObject),
    ]);
    // RemoteImeBatchEdit: ime_counter=1, field_counter=2, edit_info=3
    final batchEdit = Uint8List.fromList([
      ...encodeVarintField(1, imeCounter),
      ...encodeVarintField(2, fieldCounter),
      ...encodeMessageField(3, editInfo),
    ]);
    // RemoteMessage field 21
    return encodeMessageField(21, batchEdit);
  }

  /// Parse a RemoteMessage and return a structured result.
  static RemoteResponse parseRemoteMessage(Uint8List data) {
    final fields = parseProtoFields(data);

    // remote_configure = 1
    if (hasField(fields, 1)) {
      final configData = getField(fields, 1)!.value as Uint8List;
      final configFields = parseProtoFields(configData);
      final code1 = getField(configFields, 1)?.value as int? ?? 0;

      String model = '';
      String vendor = '';
      final deviceInfoField = getField(configFields, 2);
      if (deviceInfoField != null) {
        final diFields = parseProtoFields(deviceInfoField.value as Uint8List);
        model = _fieldToString(getField(diFields, 1));
        vendor = _fieldToString(getField(diFields, 2));
      }
      return RemoteResponse(
        type: RemoteMessageType.configure,
        features: code1,
        deviceModel: model,
        deviceVendor: vendor,
      );
    }

    // remote_set_active = 2
    if (hasField(fields, 2)) {
      return RemoteResponse(type: RemoteMessageType.setActive);
    }

    // remote_ping_request = 8
    if (hasField(fields, 8)) {
      final pingData = getField(fields, 8)!.value as Uint8List;
      final pingFields = parseProtoFields(pingData);
      final val1 = getField(pingFields, 1)?.value as int? ?? 0;
      return RemoteResponse(type: RemoteMessageType.pingRequest, pingVal: val1);
    }

    // remote_key_inject = 10 (from server, rare)
    if (hasField(fields, 10)) {
      return RemoteResponse(type: RemoteMessageType.keyInject);
    }

    // remote_ime_key_inject = 20
    if (hasField(fields, 20)) {
      final imeData = getField(fields, 20)!.value as Uint8List;
      final imeFields = parseProtoFields(imeData);
      // app_info = 1 → app_package = 12
      final appInfoField = getField(imeFields, 1);
      String currentApp = '';
      if (appInfoField != null) {
        final aiFields = parseProtoFields(appInfoField.value as Uint8List);
        currentApp = _fieldToString(getField(aiFields, 12));
      }
      return RemoteResponse(type: RemoteMessageType.imeKeyInject, currentApp: currentApp);
    }

    // remote_ime_batch_edit = 21
    if (hasField(fields, 21)) {
      final batchData = getField(fields, 21)!.value as Uint8List;
      final batchFields = parseProtoFields(batchData);
      final imeCounter = getField(batchFields, 1)?.value as int? ?? 0;
      final fieldCounter = getField(batchFields, 2)?.value as int? ?? 0;
      return RemoteResponse(
        type: RemoteMessageType.imeBatchEdit,
        imeCounter: imeCounter,
        imeFieldCounter: fieldCounter,
      );
    }

    // remote_start = 40
    if (hasField(fields, 40)) {
      final startData = getField(fields, 40)!.value as Uint8List;
      final startFields = parseProtoFields(startData);
      final started = (getField(startFields, 1)?.value as int? ?? 0) != 0;
      return RemoteResponse(type: RemoteMessageType.start, isOn: started);
    }

    // remote_set_volume_level = 50
    if (hasField(fields, 50)) {
      final volData = getField(fields, 50)!.value as Uint8List;
      final volFields = parseProtoFields(volData);
      return RemoteResponse(
        type: RemoteMessageType.volumeLevel,
        volumeMax: getField(volFields, 6)?.value as int? ?? 100,
        volumeLevel: getField(volFields, 7)?.value as int? ?? 0,
        volumeMuted: (getField(volFields, 8)?.value as int? ?? 0) != 0,
      );
    }

    // remote_error = 3
    if (hasField(fields, 3)) {
      return RemoteResponse(type: RemoteMessageType.error);
    }

    return RemoteResponse(type: RemoteMessageType.unknown);
  }

  static String _fieldToString(ProtoField? field) {
    if (field == null) return '';
    if (field.value is Uint8List) {
      return String.fromCharCodes(field.value as Uint8List);
    }
    return '';
  }
}

// RemoteKeyCode constants (matching remotemessage.proto)
class AndroidKeyCode {
  static const int home = 3;
  static const int back = 4;
  static const int dpadUp = 19;
  static const int dpadDown = 20;
  static const int dpadLeft = 21;
  static const int dpadRight = 22;
  static const int dpadCenter = 23;
  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int power = 26;
  static const int enter = 66;
  static const int mediaPlayPause = 85;
  static const int mediaStop = 86;
  static const int mediaNext = 87;
  static const int mediaPrevious = 88;
  static const int mediaRewind = 89;
  static const int mediaFastForward = 90;
  static const int mute = 91;
  static const int channelUp = 166;
  static const int channelDown = 167;
  static const int settings = 176;
  static const int tvPower = 177;
  static const int tvInput = 178;
  static const int search = 84;
  static const int mediaPlay = 126;
  static const int mediaPause = 127;
  static const int volumeMute = 164;
  static const int guide = 172;
  static const int menu = 82;
  static const int appSwitch = 187;
}

enum RemoteMessageType {
  configure,
  setActive,
  error,
  pingRequest,
  keyInject,
  imeKeyInject,
  imeBatchEdit,
  start,
  volumeLevel,
  appLinkLaunch,
  unknown,
}

class RemoteResponse {
  final RemoteMessageType type;
  final int features;
  final String deviceModel;
  final String deviceVendor;
  final int pingVal;
  final bool isOn;
  final int volumeMax;
  final int volumeLevel;
  final bool volumeMuted;
  final String currentApp;
  final int imeCounter;
  final int imeFieldCounter;

  RemoteResponse({
    required this.type,
    this.features = 0,
    this.deviceModel = '',
    this.deviceVendor = '',
    this.pingVal = 0,
    this.isOn = false,
    this.volumeMax = 100,
    this.volumeLevel = 0,
    this.volumeMuted = false,
    this.currentApp = '',
    this.imeCounter = 0,
    this.imeFieldCounter = 0,
  });
}

// ============================================================================
//  FRAMING: varint(length) + protobuf bytes
//  Used for both pairing and remote protocols.
// ============================================================================

/// Frame a protobuf message with a varint length prefix.
Uint8List frameMessage(Uint8List message) {
  final lenPrefix = encodeVarint(message.length);
  return Uint8List.fromList([...lenPrefix, ...message]);
}

/// Extract complete framed messages from a byte buffer.
/// Returns (messages, remainingBytes).
(List<Uint8List>, Uint8List) extractFramedMessages(Uint8List buffer) {
  final messages = <Uint8List>[];
  int pos = 0;
  while (pos < buffer.length) {
    final (msgLen, varLen) = decodeVarint(buffer, pos);
    if (msgLen == 0 && varLen == 0) break;
    final totalLen = varLen + msgLen;
    if (pos + totalLen > buffer.length) break; // Incomplete message
    messages.add(Uint8List.sublistView(buffer, pos + varLen, pos + totalLen));
    pos += totalLen;
  }
  final remaining = pos < buffer.length
      ? Uint8List.sublistView(buffer, pos)
      : Uint8List(0);
  return (messages, remaining);
}
