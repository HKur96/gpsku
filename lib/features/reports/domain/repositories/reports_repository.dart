import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../fleet/data/models/position_model.dart';
import '../../data/models/stop_report_model.dart';
import '../../data/models/trip_report_model.dart';

/// Repository domain contract for historical route and reports.
abstract class ReportsRepository {
  /// Fetches raw route positions for [deviceId] between [from] and [to].
  Future<Either<Failure, List<PositionModel>>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });

  /// Fetches trips report for [deviceId] between [from] and [to].
  Future<Either<Failure, List<TripReportModel>>> getTripReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });

  /// Fetches stops report for [deviceId] between [from] and [to].
  Future<Either<Failure, List<StopReportModel>>> getStopReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });
}
