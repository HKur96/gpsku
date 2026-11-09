import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/computed_attribute_model.dart';
import '../models/computed_attribute_test_result_model.dart';

/// Contract for managing Computed Attributes (JEXL Formulas) via Traccar REST API.
abstract class ComputedAttributesRemoteDataSource {
  /// Fetches computed attributes from Traccar REST API.
  /// Endpoint: GET `/api/attributes/computed`
  /// Query parameters: optional [all], [userId], [deviceId], [groupId].
  Future<List<ComputedAttributeModel>> getComputedAttributes({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new computed attribute formula.
  /// Endpoint: POST `/api/attributes/computed`
  Future<ComputedAttributeModel> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  });

  /// Updates an existing computed attribute formula.
  /// Endpoint: PUT `/api/attributes/computed/{id}`
  Future<ComputedAttributeModel> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  });

  /// Deletes a computed attribute formula by [id].
  /// Endpoint: DELETE `/api/attributes/computed/{id}`
  Future<void> deleteComputedAttribute(int id, {CancelToken? cancelToken});

  /// Evaluates a formula against the latest position of [deviceId].
  /// Endpoint: POST `/api/attributes/computed/test?deviceId={deviceId}`
  Future<ComputedAttributeTestResultModel> testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  });

  /// Links a device to a computed attribute via `/api/permissions`.
  /// Endpoint: POST `/api/permissions` with body `{"deviceId": X, "attributeId": Y}`.
  Future<void> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  });

  /// Unlinks a device from a computed attribute via `/api/permissions`.
  /// Endpoint: DELETE `/api/permissions` with body `{"deviceId": X, "attributeId": Y}`.
  Future<void> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  });

  /// Links a fleet group to a computed attribute via `/api/permissions`.
  /// Endpoint: POST `/api/permissions` with body `{"groupId": X, "attributeId": Y}`.
  Future<void> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  });

  /// Unlinks a fleet group from a computed attribute via `/api/permissions`.
  /// Endpoint: DELETE `/api/permissions` with body `{"groupId": X, "attributeId": Y}`.
  Future<void> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  });
}

/// Production implementation of [ComputedAttributesRemoteDataSource] using [DioClient].
class ComputedAttributesRemoteDataSourceImpl
    implements ComputedAttributesRemoteDataSource {
  final DioClient dioClient;

  ComputedAttributesRemoteDataSourceImpl({required this.dioClient});

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<ComputedAttributeModel>> getComputedAttributes({
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
        ApiEndpoints.attributesComputed,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: {'Accept': 'application/json'}),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map(
              (item) =>
                  ComputedAttributeModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return <ComputedAttributeModel>[];
    } on DioException catch (e) {
      _handleDioException(e, 'attributes/computed/get');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ComputedAttributeModel> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.post<dynamic>(
        ApiEndpoints.attributesComputed,
        data: attribute.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ComputedAttributeModel.fromJson(data);
      }
      throw const ServerException(
        'Unexpected empty response from create computed attribute',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'attributes/computed/create');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ComputedAttributeModel> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.put<dynamic>(
        ApiEndpoints.attributesComputedById(attribute.id),
        data: attribute.toJson(),
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ComputedAttributeModel.fromJson(data);
      }
      throw const ServerException(
        'Unexpected empty response from update computed attribute',
      );
    } on DioException catch (e) {
      _handleDioException(e, 'attributes/computed/update');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteComputedAttribute(
    int id, {
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.delete<dynamic>(
        ApiEndpoints.attributesComputedById(id),
        options: Options(headers: {'Accept': 'application/json'}),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'attributes/computed/delete');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ComputedAttributeTestResultModel> testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dioClient.post<dynamic>(
        ApiEndpoints.attributesComputedTest,
        queryParameters: {'deviceId': deviceId},
        data: attribute.toJson(),
        options: Options(
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
          },
        ),
        cancelToken: cancelToken,
      );

      // Backend returns 204 No Content if expression evaluates to null
      if (response.statusCode == 204 || response.data == null) {
        return ComputedAttributeTestResultModel.empty(type: attribute.type);
      }

      return ComputedAttributeTestResultModel.fromResponse(
        response.data,
        type: attribute.type,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'attributes/computed/test');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.post<dynamic>(
        ApiEndpoints.permissions,
        data: {'deviceId': deviceId, 'attributeId': attributeId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/linkDeviceAttribute');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.delete<dynamic>(
        ApiEndpoints.permissions,
        data: {'deviceId': deviceId, 'attributeId': attributeId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/unlinkDeviceAttribute');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.post<dynamic>(
        ApiEndpoints.permissions,
        data: {'groupId': groupId, 'attributeId': attributeId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/linkGroupAttribute');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  }) async {
    try {
      await dioClient.delete<dynamic>(
        ApiEndpoints.permissions,
        data: {'groupId': groupId, 'attributeId': attributeId},
        options: Options(headers: _defaultHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleDioException(e, 'permissions/unlinkGroupAttribute');
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
        'Forbidden: Access denied to computed attribute resource ($resourceName)',
        403,
      );
    } else if (statusCode == 409) {
      throw ConflictException(
        'Conflict: Computed attribute relation already exists ($resourceName)',
        409,
      );
    } else if (statusCode == 400) {
      throw ServerException(
        e.response?.data?.toString() ??
            'Bad request: Invalid computed attribute parameters ($resourceName)',
        400,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw ConnectionTimeoutException(
        e.message ?? 'Computed attribute request timed out ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.connectionError) {
      throw NetworkException(
        e.message ?? 'Failed to connect to Traccar server ($resourceName)',
        statusCode,
      );
    } else if (e.type == DioExceptionType.cancel) {
      throw NetworkException(
        'Computed attribute request cancelled by caller ($resourceName)',
        statusCode,
      );
    } else {
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Server error on computed attribute resource ($resourceName)',
        statusCode,
      );
    }
  }
}
