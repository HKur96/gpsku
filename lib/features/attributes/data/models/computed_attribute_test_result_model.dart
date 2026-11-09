import 'package:flutter/foundation.dart';

/// Immutable model representing the result of testing a JEXL formula expression (Feature F-38).
/// Returns evaluation output from Traccar `POST /api/attributes/computed/test`.
@immutable
class ComputedAttributeTestResultModel {
  final dynamic rawValue;
  final String stringValue;
  final String type;
  final bool success;
  final String? error;

  const ComputedAttributeTestResultModel({
    this.rawValue,
    required this.stringValue,
    required this.type,
    this.success = true,
    this.error,
  });

  /// Factory for a successful evaluation with a non-null return value.
  factory ComputedAttributeTestResultModel.success({
    required dynamic value,
    String type = 'number',
  }) {
    return ComputedAttributeTestResultModel(
      rawValue: value,
      stringValue: value?.toString() ?? '',
      type: type,
      success: true,
      error: null,
    );
  }

  /// Factory for an empty evaluation (e.g. HTTP 204 No Content or null result).
  factory ComputedAttributeTestResultModel.empty({String type = 'number'}) {
    return ComputedAttributeTestResultModel(
      rawValue: null,
      stringValue: '',
      type: type,
      success: true,
      error: null,
    );
  }

  /// Factory alias for 204 No Content.
  factory ComputedAttributeTestResultModel.noContent({String type = 'number'}) {
    return ComputedAttributeTestResultModel.empty(type: type);
  }

  /// Factory for a failed evaluation (e.g. syntax error in formula or server error).
  factory ComputedAttributeTestResultModel.failure({
    required String error,
    String type = 'string',
  }) {
    return ComputedAttributeTestResultModel(
      rawValue: null,
      stringValue: '',
      type: type,
      success: false,
      error: error,
    );
  }

  /// Creates a [ComputedAttributeTestResultModel] from raw response data and expected type.
  /// Detects error stack traces or exception strings (such as 'JexlException')
  /// and marks the evaluation as failed.
  factory ComputedAttributeTestResultModel.fromResponse(
    dynamic data, {
    required String type,
  }) {
    if (data == null) {
      return ComputedAttributeTestResultModel.empty(type: type);
    }

    final str = data.toString();
    final lowerStr = str.toLowerCase();
    final isErrorString =
        str.contains('JexlException') ||
        lowerStr.contains('exception') ||
        lowerStr.contains('failed to evaluate') ||
        lowerStr.contains('syntax error') ||
        lowerStr.contains('evaluation error') ||
        (lowerStr.startsWith('error:') || lowerStr.startsWith('error '));

    if (isErrorString) {
      return ComputedAttributeTestResultModel.failure(error: str, type: type);
    }

    return ComputedAttributeTestResultModel(
      rawValue: data,
      stringValue: str,
      type: type,
      success: true,
      error: null,
    );
  }

  /// Getter alias for evaluated value.
  dynamic get value => rawValue;

  /// Getter alias for result data type.
  String get resultType => type;

  /// Whether the test resulted in a non-null evaluated value.
  bool get hasValue => rawValue != null;

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'rawValue': rawValue,
      'stringValue': stringValue,
      'type': type,
      'success': success,
      if (error != null) 'error': error,
    };
  }

  /// Deserializes from a JSON map.
  factory ComputedAttributeTestResultModel.fromJson(Map<String, dynamic> json) {
    return ComputedAttributeTestResultModel(
      rawValue: json['rawValue'],
      stringValue: (json['stringValue'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'number',
      success: (json['success'] as bool?) ?? true,
      error: json['error'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComputedAttributeTestResultModel &&
        other.rawValue == rawValue &&
        other.stringValue == stringValue &&
        other.type == type &&
        other.success == success &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(rawValue, stringValue, type, success, error);

  @override
  String toString() {
    return 'ComputedAttributeTestResultModel(value: $rawValue, type: "$type", success: $success, error: $error)';
  }
}
