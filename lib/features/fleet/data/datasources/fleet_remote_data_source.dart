import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/device_model.dart';
import '../models/group_model.dart';
import '../models/position_model.dart';

/// Contract for fetching fleet devices, groups, and positions from the Traccar REST API.
abstract class FleetRemoteDataSource {
  /// Fetches all devices accessible by the currently authenticated session.
  /// Endpoint: GET `/api/devices`
  Future<List<DeviceModel>> getDevices({CancelToken? cancelToken});

  /// Fetches the latest positions for all devices accessible by the authenticated session.
  /// Endpoint: GET `/api/positions`
  Future<List<PositionModel>> getPositions({CancelToken? cancelToken});

  /// Fetches all vehicle operational groups accessible by the authenticated session.
  /// Endpoint: GET `/api/groups`
  Future<List<GroupModel>> getGroups({CancelToken? cancelToken});
}

/// Production implementation of [FleetRemoteDataSource] utilizing the configured [DioClient].
/// Reuses existing authentication, RFC 6265 session cookies, and security interceptors.
class FleetRemoteDataSourceImpl implements FleetRemoteDataSource {
  final DioClient dioClient;

  FleetRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<DeviceModel>> getDevices({CancelToken? cancelToken}) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.devices,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return DeviceModel.fromJson(item);
          } else if (item is Map) {
            return DeviceModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException('Invalid device item in response array');
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/devices: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'devices');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PositionModel>> getPositions({CancelToken? cancelToken}) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.positions,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return PositionModel.fromJson(item);
          } else if (item is Map) {
            return PositionModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException(
            'Invalid position item in response array',
          );
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/positions: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'positions');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<GroupModel>> getGroups({CancelToken? cancelToken}) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.groups,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return GroupModel.fromJson(item);
          } else if (item is Map) {
            return GroupModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException('Invalid group item in response array');
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/groups: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'groups');
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
      throw const ServerException(
        'Forbidden: Access denied to fleet resources',
        403,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Fleet request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Fleet request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on $resourceName',
        statusCode,
      );
    }
  }
}
