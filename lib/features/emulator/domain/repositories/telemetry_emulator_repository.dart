import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/telemetry_packet_model.dart';

/// Domain contract for testing and transmitting simulated telemetry packets
/// to Traccar's OsmAnd protocol decoder.
abstract class TelemetryEmulatorRepository {
  /// Transmits simulated telemetry to Traccar's OsmAnd protocol port (port 5055).
  ///
  /// Returns [Right(true)] when the server acknowledges receipt (HTTP 200 OK).
  /// Returns [Left(Failure)] with domain-typed error when transmission fails.
  Future<Either<Failure, bool>> sendTelemetry({
    required TelemetryPacketModel packet,
    String? customHost,
    int? customPort,
    bool usePost = true,
    CancelToken? cancelToken,
  });

  /// Probes reachability of the OsmAnd protocol listener on port 5055.
  ///
  /// Returns [Right(true)] if port 5055 is reachable.
  /// Returns [Left(Failure)] if connection is refused or timed out.
  Future<Either<Failure, bool>> probePort({
    String? customHost,
    int? customPort,
    CancelToken? cancelToken,
  });
}
