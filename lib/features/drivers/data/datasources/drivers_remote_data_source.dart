import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/driver_model.dart';

/// Contract for managing Traccar Drivers via REST API (`/api/drivers` and `/api/permissions`).
abstract class DriversRemoteDataSource {
  /// Fetches drivers from Traccar REST API.
  /// Endpoint: GET `/api/drivers`
  /// Query parameters: optional [all], [userId], [deviceId], [groupId].
  Future<List<DriverModel>> getDrivers({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new driver.
  /// Endpoint: POST `/api/drivers`
  Future<DriverModel> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  });

  /// Updates an existing driver.
  /// Endpoint: PUT `/api/drivers/{id}`
  Future<DriverModel> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  });

  /// Deletes a driver by [id].
  /// Endpoint: DELETE `/api/drivers/{id}`
  Future<void> deleteDriver(int id, {CancelToken? cancelToken});

  /// Links a device to a driver via Traccar permissions API.
  /// Endpoint: POST `/api/permissions` with body `{"deviceId": X, "driverId": Y}`.
  Future<void> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  });

  /// Unlinks a device from a driver via Traccar permissions API.
  /// Endpoint: DELETE `/api/permissions` with body `{"deviceId": X, "driverId": Y}`.
  Future<void> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [DriversRemoteDataSource] using [DioClient].
/// Automatically inherits RFC 6265 session cookies, re-auth interceptor, and request sanitization.
class DriversRemoteDataSourceImpl implements DriversRemoteDataSource {
  final DioClient dioClient;

  DriversRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<DriverModel>> getDrivers({
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
        ApiEndpoints.drivers,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map(
              (item) =>
                  DriverModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioException(e, 'drivers/get');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<DriverModel> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    try {
      final payload = driver.toJson();
      if (driver.id == 0) {
        payload.remove('id');
      }

      final response = await dioClient.post<dynamic>(
        ApiEndpoints.drivers,
        data: payload,
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      return DriverModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      _handleDioException(e, 'drivers/create');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<DriverModel> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.put<dynamic>(
        '${ApiEndpoints.drivers}/${driver.id}',
        data: driver.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      return DriverModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      _handleDioException(e, 'drivers/update');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteDriver(int id, {CancelToken? cancelToken}) async {
    try {
      await dioClient.delete<dynamic>(
        '${ApiEndpoints.drivers}/$id',
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'drivers/delete');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.post<dynamic>(
        ApiEndpoints.permissions,
        data: {'deviceId': deviceId, 'driverId': driverId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/linkDriver');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.delete<dynamic>(
        ApiEndpoints.permissions,
        data: {'deviceId': deviceId, 'driverId': driverId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/unlinkDriver');
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
        'Forbidden: Access denied to driver resource ($resourceName)',
        403,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Bad request: Invalid driver parameters ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Driver request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Driver request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on driver resource ($resourceName)',
        statusCode,
      );
    }
  }
}
