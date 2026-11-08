import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/geofence_model.dart';

/// Contract for managing Traccar Geofences via REST API (`/api/geofences`).
abstract class GeofencesRemoteDataSource {
  /// Fetches geofences from Traccar REST API.
  /// Endpoint: GET `/api/geofences`
  /// Query parameters: optional [all], [userId], [deviceId], [groupId].
  Future<List<GeofenceModel>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new geofence.
  /// Endpoint: POST `/api/geofences`
  Future<GeofenceModel> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  });

  /// Updates an existing geofence.
  /// Endpoint: PUT `/api/geofences/{id}`
  Future<GeofenceModel> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  });

  /// Deletes a geofence by [id].
  /// Endpoint: DELETE `/api/geofences/{id}`
  Future<void> deleteGeofence(int id, {CancelToken? cancelToken});
}

/// Production implementation of [GeofencesRemoteDataSource] using [DioClient].
/// Automatically inherits RFC 6265 cookie handling, re-auth interceptor, and request sanitization.
class GeofencesRemoteDataSourceImpl implements GeofencesRemoteDataSource {
  final DioClient dioClient;

  GeofencesRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<GeofenceModel>> getGeofences({
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
        ApiEndpoints.geofences,
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
            return GeofenceModel.fromJson(item);
          } else if (item is Map) {
            return GeofenceModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException(
            'Invalid geofence item in response array',
          );
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/geofences: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'geofences/get');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<GeofenceModel> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.post<dynamic>(
        ApiEndpoints.geofences,
        data: geofence.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return GeofenceModel.fromJson(data);
      } else if (data is Map) {
        return GeofenceModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw const ServerException(
        'Unexpected response format from POST /api/geofences: expected Map',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'geofences/create');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<GeofenceModel> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.put<dynamic>(
        '${ApiEndpoints.geofences}/${geofence.id}',
        data: geofence.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return GeofenceModel.fromJson(data);
      } else if (data is Map) {
        return GeofenceModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw const ServerException(
        'Unexpected response format from PUT /api/geofences/{id}: expected Map',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'geofences/update');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteGeofence(int id, {CancelToken? cancelToken}) async {
    try {
      await dioClient.delete<dynamic>(
        '${ApiEndpoints.geofences}/$id',
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'geofences/delete');
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
        'Forbidden: Access denied to geofence resource ($resourceName)',
        403,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Bad request: Invalid geofence parameters ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Geofence request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Geofence request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on geofence resource ($resourceName)',
        statusCode,
      );
    }
  }
}
