import 'package:flutter/foundation.dart';

/// Strongly-typed, immutable representation of a public tracking share link.
///
/// Implements Traccar's device and group temporary share mechanism (Feature F-37).
/// Allows external third parties (clients, logistics recipients, emergency responders)
/// to track vehicles in real time without login credentials until [expiration].
@immutable
class ShareLinkModel {
  /// The Traccar device ID associated with this share link (0 if group share).
  final int deviceId;

  /// Optional Traccar group ID if this share link covers an entire fleet group.
  final int? groupId;

  /// Temporary signed security token returned by `/api/share/{type}` or `/api/session/token`.
  final String token;

  /// Timestamp when this share link becomes invalid on the server.
  final DateTime expiration;

  /// Fully formatted web URL with token parameter (e.g., `https://gpsku.app/?token=...`).
  final String shareUrl;

  /// Unmodifiable metadata attributes associated with the share link.
  final Map<String, dynamic> attributes;

  ShareLinkModel({
    required this.deviceId,
    this.groupId,
    required this.token,
    required this.expiration,
    required this.shareUrl,
    Map<String, dynamic> attributes = const {},
  }) : attributes = Map.unmodifiable(Map<String, dynamic>.from(attributes));

  /// Helper utility to construct a standard Traccar Web / GPSku share URL.
  ///
  /// Cleans and sanitizes baseUrl by stripping trailing slashes and any trailing `/api` path segment
  /// (e.g. `https://demo.traccar.org/api` or `https://demo.traccar.org/api/` -> `https://demo.traccar.org/?token={token}`).
  static String buildShareUrl(String baseUrl, String token) {
    var cleanBase = baseUrl.trim();
    if (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    if (cleanBase.endsWith('/api')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 4);
    }
    if (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    return '$cleanBase/?token=$token';
  }

  /// Whether the share link's expiration timestamp has passed.
  bool get isExpired => DateTime.now().isAfter(expiration);

  /// Remaining duration until the share link expires.
  /// Returns [Duration.zero] if already expired.
  Duration get remainingDuration {
    final diff = expiration.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// True if this link shares a single specific device.
  bool get isDeviceShare => deviceId > 0;

  /// True if this link shares an entire fleet group.
  bool get isGroupShare => groupId != null && groupId! > 0;

  /// Creates a copy of this [ShareLinkModel] with optional updated fields.
  ShareLinkModel copyWith({
    int? deviceId,
    int? groupId,
    String? token,
    DateTime? expiration,
    String? shareUrl,
    Map<String, dynamic>? attributes,
  }) {
    return ShareLinkModel(
      deviceId: deviceId ?? this.deviceId,
      groupId: groupId ?? this.groupId,
      token: token ?? this.token,
      expiration: expiration ?? this.expiration,
      shareUrl: shareUrl ?? this.shareUrl,
      attributes: attributes ?? this.attributes,
    );
  }

  /// Deserializes a [ShareLinkModel] from JSON.
  factory ShareLinkModel.fromJson(Map<String, dynamic> json) {
    return ShareLinkModel(
      deviceId: (json['deviceId'] as num?)?.toInt() ?? 0,
      groupId: (json['groupId'] as num?)?.toInt(),
      token: (json['token'] as String?) ?? '',
      expiration: json['expiration'] != null
          ? (json['expiration'] is String
                ? DateTime.parse(json['expiration'] as String)
                : DateTime.fromMillisecondsSinceEpoch(
                    (json['expiration'] as num).toInt(),
                  ))
          : DateTime.now(),
      shareUrl: (json['shareUrl'] as String?) ?? '',
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : const {},
    );
  }

  /// Serializes this [ShareLinkModel] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      if (groupId != null) 'groupId': groupId,
      'token': token,
      'expiration': expiration.toIso8601String(),
      'shareUrl': shareUrl,
      'attributes': attributes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareLinkModel &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          groupId == other.groupId &&
          token == other.token &&
          expiration.isAtSameMomentAs(other.expiration) &&
          shareUrl == other.shareUrl &&
          mapEquals(attributes, other.attributes);

  @override
  int get hashCode =>
      deviceId.hashCode ^
      groupId.hashCode ^
      token.hashCode ^
      expiration.millisecondsSinceEpoch.hashCode ^
      shareUrl.hashCode;

  @override
  String toString() =>
      'ShareLinkModel(deviceId: $deviceId, groupId: $groupId, token: ${token.length > 10 ? "${token.substring(0, 10)}..." : token}, expiration: $expiration, shareUrl: $shareUrl)';
}
