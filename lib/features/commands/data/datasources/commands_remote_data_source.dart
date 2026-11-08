import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/command_payload_model.dart';
import '../models/command_type_model.dart';

/// Contract for querying supported device commands and executing remote commands
/// via Traccar REST API (`/api/commands/types` and `/api/commands/send`).
abstract class CommandsRemoteDataSource {
  /// Fetches supported command types for [deviceId] from Traccar REST API.
  /// Endpoint: GET `/api/commands/types`
  /// Query parameters: `deviceId`, optional [protocol], optional [textChannel].
  Future<List<CommandTypeModel>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  });

  /// Executes or queues a remote command for a device.
  /// Endpoint: POST `/api/commands/send`
  /// Status 200 OK: Command dispatched immediately (`isQueued = false`).
  /// Status 202 Accepted: Command queued on server (`isQueued = true`).
  Future<CommandPayloadModel> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  });
}

/// Production implementation of [CommandsRemoteDataSource] using [DioClient].
/// Automatically inherits RFC 6265 cookie handling, re-auth interceptor, and request sanitization.
class CommandsRemoteDataSourceImpl implements CommandsRemoteDataSource {
  final DioClient dioClient;

  CommandsRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<CommandTypeModel>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{'deviceId': deviceId};
      if (protocol != null && protocol.isNotEmpty) {
        queryParams['protocol'] = protocol;
      }
      if (textChannel != null) {
        queryParams['textChannel'] = textChannel;
      }

      final response = await dioClient.get<dynamic>(
        ApiEndpoints.commandsTypes,
        queryParameters: queryParams,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return CommandTypeModel.fromJson(item);
          } else if (item is Map) {
            return CommandTypeModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException(
            'Invalid command type item in response array',
          );
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/commands/types: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'commands/types');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<CommandPayloadModel> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.post<dynamic>(
        ApiEndpoints.commandsSend,
        data: payload.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final isQueued = response.statusCode == 202;
      final data = response.data;

      if (data is Map<String, dynamic>) {
        return CommandPayloadModel.fromJson(data, isQueued: isQueued);
      } else if (data is Map) {
        return CommandPayloadModel.fromJson(
          Map<String, dynamic>.from(data),
          isQueued: isQueued,
        );
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        return CommandPayloadModel.fromJson(
          Map<String, dynamic>.from(data.first as Map),
          isQueued: isQueued,
        );
      }

      return payload.copyWith(isQueued: isQueued);
    } on DioException catch (e) {
      _handleDioException(e, 'commands/send');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Never _handleDioException(DioException e, String resourceName) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      throw const AuthException('Session expired or unauthorized', 401);
    } else if (statusCode == 403) {
      throw ForbiddenException(
        'Forbidden: Access denied to remote command ($resourceName)',
        403,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Bad request: Invalid command parameters ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Command request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Command request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on command resource ($resourceName)',
        statusCode,
      );
    }
  }
}
