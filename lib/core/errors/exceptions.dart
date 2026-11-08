// Core exception classes for data sources

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? debugDetails;

  const AppException([
    this.message = 'Application error',
    this.statusCode,
    this.debugDetails,
  ]);

  @override
  String toString() =>
      'AppException: $message (code: $statusCode, details: $debugDetails)';
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Server error',
    super.statusCode,
    super.debugDetails,
  ]);
}

class AuthException extends AppException {
  const AuthException([
    super.message = 'Authentication error',
    super.statusCode,
    super.debugDetails,
  ]);
}

class ForbiddenException extends AppException {
  const ForbiddenException([
    super.message = 'Forbidden access',
    super.statusCode = 403,
    super.debugDetails,
  ]);
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connection failed',
    super.statusCode,
    super.debugDetails,
  ]);
}

class ConnectionTimeoutException extends AppException {
  const ConnectionTimeoutException([
    super.message = 'Connection timed out',
    super.statusCode,
    super.debugDetails,
  ]);
}

class StorageException extends AppException {
  const StorageException([
    super.message = 'Storage error',
    super.statusCode,
    super.debugDetails,
  ]);
}
