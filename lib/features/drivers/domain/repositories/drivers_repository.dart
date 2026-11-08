import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/driver_model.dart';

/// Domain repository contract for managing drivers and device-driver permissions.
abstract class DriversRepository {
  /// Fetches drivers from Traccar API.
  Future<Either<Failure, List<DriverModel>>> getDrivers({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new driver.
  Future<Either<Failure, DriverModel>> createDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  });

  /// Updates an existing driver.
  Future<Either<Failure, DriverModel>> updateDriver(
    DriverModel driver, {
    CancelToken? cancelToken,
  });

  /// Deletes a driver by [id].
  Future<Either<Failure, void>> deleteDriver(
    int id, {
    CancelToken? cancelToken,
  });

  /// Links a device to a driver via permissions.
  Future<Either<Failure, void>> linkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  });

  /// Unlinks a device from a driver via permissions.
  Future<Either<Failure, void>> unlinkDeviceDriver({
    required int deviceId,
    required int driverId,
    CancelToken? cancelToken,
  });
}
