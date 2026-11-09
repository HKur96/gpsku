// Core error models for GPSku architecture
// Separates user-facing clean messages from diagnostic technical debug details.

abstract class Failure {
  final String message;
  final int? statusCode;
  final String? debugDetails;

  const Failure(this.message, {this.statusCode, this.debugDetails});

  @override
  String toString() =>
      'Failure(message: $message, statusCode: $statusCode, debugDetails: $debugDetails)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode &&
          debugDetails == other.debugDetails;

  @override
  int get hashCode =>
      message.hashCode ^ statusCode.hashCode ^ debugDetails.hashCode;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode, super.debugDetails});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.statusCode, super.debugDetails});
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message, {super.statusCode, super.debugDetails});
}

class ConflictFailure extends Failure {
  const ConflictFailure(
    super.message, {
    super.statusCode = 409,
    super.debugDetails,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.statusCode, super.debugDetails});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message, {super.statusCode, super.debugDetails});
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.statusCode, super.debugDetails});
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(
    super.message, {
    super.statusCode,
    super.debugDetails,
  });
}
