import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({
    required String email,
    required String password,
    String? code,
  });

  Future<UserModel> getCurrentSession();

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<UserModel> login({
    required String email,
    required String password,
    String? code,
  }) async {
    try {
      final formData = {
        'email': email,
        'password': password,
        if (code != null && code.isNotEmpty) 'code': code,
      };

      final response = await dioClient.post<dynamic>(
        ApiEndpoints.session,
        data: formData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.data is Map<String, dynamic>) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      } else if (response.data is Map) {
        return UserModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } else {
        throw const ServerException('Unexpected response format from server');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final authHeader = e.response?.headers.value('WWW-Authenticate');
        if (authHeader == 'TOTP') {
          throw const AuthException('TOTP_REQUIRED');
        }
        throw const AuthException('Invalid credentials');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ConnectionTimeoutException(e.message ?? 'Connection timed out');
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(
          e.message ?? 'Failed to connect to Traccar server',
        );
      } else {
        throw ServerException(
          e.response?.data?.toString() ?? e.message ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel> getCurrentSession() async {
    try {
      final response = await dioClient.get<dynamic>(ApiEndpoints.session);

      if (response.data is Map<String, dynamic>) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      } else if (response.data is Map) {
        return UserModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } else {
        throw const ServerException('Invalid session response data');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        throw const AuthException('No active session or session expired');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ConnectionTimeoutException(
          e.message ?? 'Session validation timed out',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(
          e.message ?? 'Cannot reach server to validate session',
        );
      } else {
        throw ServerException(
          e.response?.data?.toString() ?? e.message ?? 'Server error',
          e.response?.statusCode,
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dioClient.delete<dynamic>(ApiEndpoints.session);
    } on DioException catch (e) {
      // 401 on logout still counts as session ended
      if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
        return;
      }
      throw ServerException(
        e.response?.data?.toString() ?? e.message ?? 'Logout error',
        e.response?.statusCode,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
