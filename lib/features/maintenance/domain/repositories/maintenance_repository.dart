import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/maintenance_model.dart';

/// Domain interface for managing Traccar Maintenance schedules and permissions.
abstract class MaintenanceRepository {
  /// Fetches maintenance schedules with optional filters.
  /// Enforces unmodifiable collection on success.
  Future<Either<Failure, List<MaintenanceModel>>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new maintenance schedule.
  Future<Either<Failure, MaintenanceModel>> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  });

  /// Updates an existing maintenance schedule.
  Future<Either<Failure, MaintenanceModel>> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  });

  /// Deletes a maintenance schedule by [id].
  Future<Either<Failure, void>> deleteMaintenance(
    int id, {
    CancelToken? cancelToken,
  });

  /// Associates a vehicle [deviceId] with a [maintenanceId].
  Future<Either<Failure, void>> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  });

  /// Dissociates a vehicle [deviceId] from a [maintenanceId].
  Future<Either<Failure, void>> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  });
}
