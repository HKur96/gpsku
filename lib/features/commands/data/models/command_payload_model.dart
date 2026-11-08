/// Encapsulates a remote command execution request and response payload
/// for Traccar REST API `/api/commands/send`.
class CommandPayloadModel {
  final int id;
  final int deviceId;
  final String type;
  final String? description;
  final bool textChannel;
  final Map<String, dynamic> attributes;
  final bool isQueued;

  CommandPayloadModel({
    this.id = 0,
    required this.deviceId,
    required this.type,
    this.description,
    this.textChannel = false,
    Map<String, dynamic>? attributes,
    this.isQueued = false,
  }) : attributes = attributes != null
           ? Map.unmodifiable(attributes)
           : const {};

  factory CommandPayloadModel.fromJson(
    Map<String, dynamic> json, {
    bool isQueued = false,
  }) {
    final rawAttributes = json['attributes'];
    Map<String, dynamic> parsedAttributes = const {};
    if (rawAttributes is Map) {
      parsedAttributes = Map<String, dynamic>.from(rawAttributes);
    }

    return CommandPayloadModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceId: (json['deviceId'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      description: json['description'] as String?,
      textChannel: json['textChannel'] as bool? ?? false,
      attributes: parsedAttributes,
      isQueued: isQueued,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'deviceId': deviceId,
      'type': type,
      'textChannel': textChannel,
      'attributes': attributes,
    };
    if (id > 0) {
      map['id'] = id;
    }
    if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    return map;
  }

  CommandPayloadModel copyWith({
    int? id,
    int? deviceId,
    String? type,
    String? description,
    bool? textChannel,
    Map<String, dynamic>? attributes,
    bool? isQueued,
  }) {
    return CommandPayloadModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      description: description ?? this.description,
      textChannel: textChannel ?? this.textChannel,
      attributes: attributes ?? this.attributes,
      isQueued: isQueued ?? this.isQueued,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandPayloadModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          deviceId == other.deviceId &&
          type == other.type &&
          description == other.description &&
          textChannel == other.textChannel &&
          isQueued == other.isQueued &&
          _mapEquals(attributes, other.attributes);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      deviceId.hashCode ^
      type.hashCode ^
      description.hashCode ^
      textChannel.hashCode ^
      isQueued.hashCode ^
      attributes.length.hashCode;

  @override
  String toString() =>
      'CommandPayloadModel(id: $id, deviceId: $deviceId, type: $type, '
      'description: $description, textChannel: $textChannel, '
      'attributes: $attributes, isQueued: $isQueued)';
}
