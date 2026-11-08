import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/device_model.dart';
import '../../data/models/group_model.dart';
import '../../data/models/position_model.dart';

/// Domain contract for fleet operations, exposing immutable entity collections
/// encapsulated within functional [Either] results.
abstract class FleetRepository {
  /// Retrieves all devices accessible by the authenticated user.
  Future<Either<Failure, List<DeviceModel>>> getDevices({
    CancelToken? cancelToken,
  });

  /// Retrieves the latest positions for all accessible devices.
  Future<Either<Failure, List<PositionModel>>> getPositions({
    CancelToken? cancelToken,
  });

  /// Retrieves all operational vehicle groups accessible by the authenticated user.
  Future<Either<Failure, List<GroupModel>>> getGroups({
    CancelToken? cancelToken,
  });
}
