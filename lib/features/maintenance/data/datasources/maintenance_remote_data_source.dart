import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/maintenance_model.dart';

/// Contract for managing Traccar Maintenance schedules via REST API (`/api/maintenance`).
abstract class MaintenanceRemoteDataSource {
  /// Fetches maintenance schedules from Traccar REST API.
  /// Endpoint: GET `/api/maintenance`
  /// Query parameters: optional [all], [userId], [deviceId], [groupId].
  Future<List<MaintenanceModel>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new maintenance schedule.
  /// Endpoint: POST `/api/maintenance`
  Future<MaintenanceModel> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  });

  /// Updates an existing maintenance schedule.
  /// Endpoint: PUT `/api/maintenance/{id}`
  Future<MaintenanceModel> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  });

  /// Deletes a maintenance schedule by [id].
  /// Endpoint: DELETE `/api/maintenance/{id}`
  Future<void> deleteMaintenance(int id, {CancelToken? cancelToken});

  /// Links a device to a maintenance schedule via Traccar permissions API.
  /// Endpoint: POST `/api/permissions`
  Future<void> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  });

  /// Unlinks a device from a maintenance schedule via Traccar permissions API.
  /// Endpoint: DELETE `/api/permissions`
  Future<void> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [MaintenanceRemoteDataSource] using [DioClient].
/// Automatically inherits RFC 6265 session cookies, re-auth interceptor, and request sanitization.
class MaintenanceRemoteDataSourceImpl implements MaintenanceRemoteDataSource {
  final DioClient dioClient;

  MaintenanceRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<MaintenanceModel>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (all != null) queryParams['all'] = all;
      if (userId != null) queryParams['userId'] = userId;
      if (deviceId != null) queryParams['deviceId'] = deviceId;
      if (groupId != null) queryParams['groupId'] = groupId;

      final response = await dioClient.get<dynamic>(
        ApiEndpoints.maintenance,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map(
              (item) => MaintenanceModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e, 'maintenance/get');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<MaintenanceModel> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    try {
      final payload = maintenance.toJson();
      if (maintenance.id == 0) {
        payload.remove('id');
      }

      final response = await dioClient.post<dynamic>(
        ApiEndpoints.maintenance,
        data: payload,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      return MaintenanceModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      _handleDioException(e, 'maintenance/create');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<MaintenanceModel> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.put<dynamic>(
        '${ApiEndpoints.maintenance}/${maintenance.id}',
        data: maintenance.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      return MaintenanceModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      _handleDioException(e, 'maintenance/update');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteMaintenance(int id, {CancelToken? cancelToken}) async {
    try {
      await dioClient.delete<dynamic>(
        '${ApiEndpoints.maintenance}/$id',
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'maintenance/delete');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.post<dynamic>(
        ApiEndpoints.permissions,
        data: {'deviceId': deviceId, 'maintenanceId': maintenanceId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/linkMaintenance');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.delete<dynamic>(
        ApiEndpoints.permissions,
        data: {'deviceId': deviceId, 'maintenanceId': maintenanceId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/unlinkMaintenance');
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
        'Forbidden: Access denied to maintenance resource ($resourceName)',
        403,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Bad request: Invalid maintenance parameters ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Maintenance request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Maintenance request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on maintenance resource ($resourceName)',
        statusCode,
      );
    }
  }
}
