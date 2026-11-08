import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../fleet/data/models/position_model.dart';
import '../models/stop_report_model.dart';
import '../models/trip_report_model.dart';

/// Contract for querying historical reports (route points, trips, stops) from Traccar REST API.
abstract class ReportsRemoteDataSource {
  /// Fetches raw historical route GPS positions for [deviceId] between [from] and [to].
  /// Endpoint: GET `/api/reports/route`
  Future<List<PositionModel>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });

  /// Fetches aggregated historical trips for [deviceId] between [from] and [to].
  /// Endpoint: GET `/api/reports/trips`
  Future<List<TripReportModel>> getTripReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });

  /// Fetches aggregated historical stops for [deviceId] between [from] and [to].
  /// Endpoint: GET `/api/reports/stops`
  Future<List<StopReportModel>> getStopReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [ReportsRemoteDataSource] using [DioClient].
/// Automatically inherits RFC 6265 cookie handling, re-auth interceptor, and request sanitization.
class ReportsRemoteDataSourceImpl implements ReportsRemoteDataSource {
  final DioClient dioClient;

  ReportsRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _reportHeaders = {
    'Accept': 'application/json',
  };

  @override
  Future<List<PositionModel>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.reportsRoute,
        queryParameters: {
          'deviceId': deviceId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
        options: Options(headers: _reportHeaders),
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
            'Invalid position item in route response array',
          );
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/reports/route: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'route');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TripReportModel>> getTripReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.reportsTrips,
        queryParameters: {
          'deviceId': deviceId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
        options: Options(headers: _reportHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return TripReportModel.fromJson(item);
          } else if (item is Map) {
            return TripReportModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException(
            'Invalid trip item in trips response array',
          );
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/reports/trips: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'trips');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<StopReportModel>> getStopReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.get<dynamic>(
        ApiEndpoints.reportsStops,
        queryParameters: {
          'deviceId': deviceId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
        options: Options(headers: _reportHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        return const [];
      }

      if (data is List) {
        return data.map((item) {
          if (item is Map<String, dynamic>) {
            return StopReportModel.fromJson(item);
          } else if (item is Map) {
            return StopReportModel.fromJson(Map<String, dynamic>.from(item));
          }
          throw const ServerException(
            'Invalid stop item in stops response array',
          );
        }).toList();
      }

      throw const ServerException(
        'Unexpected response format from /api/reports/stops: expected List',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'stops');
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
        'Forbidden: Access denied to reports resources',
        403,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Reports request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Reports request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on reports $resourceName',
        statusCode,
      );
    }
  }
}
