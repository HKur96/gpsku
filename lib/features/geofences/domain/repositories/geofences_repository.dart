import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/geofence_model.dart';

/// Domain repository contract for managing Traccar Geofences.
///
/// Returns typed [Either<Failure, T>] for functional error handling.
abstract class GeofencesRepository {
  /// Retrieves geofences matching optional filtering criteria.
  Future<Either<Failure, List<GeofenceModel>>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new geofence perimeter.
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  });

  /// Updates an existing geofence perimeter.
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  });

  /// Deletes a geofence by its [id].
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  });
}
