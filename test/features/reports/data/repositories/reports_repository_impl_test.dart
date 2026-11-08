import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';
import 'package:gpsku/features/reports/data/repositories/reports_repository_impl.dart';

class MockReportsRemoteDataSource implements ReportsRemoteDataSource {
  List<PositionModel> mockPositions = [];
  List<TripReportModel> mockTrips = [];
  List<StopReportModel> mockStops = [];
  Exception? exceptionToThrow;
  CancelToken? lastCancelToken;
  int? lastDeviceId;
  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<List<PositionModel>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastFrom = from;
    lastTo = to;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockPositions;
  }

  @override
  Future<List<TripReportModel>> getTripReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastFrom = from;
    lastTo = to;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockTrips;
  }

  @override
  Future<List<StopReportModel>> getStopReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastFrom = from;
    lastTo = to;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockStops;
  }
}

void main() {
  group('ReportsRepositoryImpl Unit Tests', () {
    late MockReportsRemoteDataSource mockDataSource;
    late ReportsRepositoryImpl repository;

    final tFrom = DateTime.utc(2026, 11, 8, 8, 0, 0);
    final tTo = DateTime.utc(2026, 11, 8, 17, 0, 0);

    setUp(() {
      mockDataSource = MockReportsRemoteDataSource();
      repository = ReportsRepositoryImpl(remoteDataSource: mockDataSource);
    });

    test(
      'TC-REPO-01: getRouteReport returns Right(unmodifiableList) on success',
      () async {
        mockDataSource.mockPositions = [
          PositionModel(
            id: 10,
            deviceId: 42,
            serverTime: tFrom,
            fixTime: tFrom,
            latitude: -6.2,
            longitude: 106.8,
          ),
        ];

        final result = await repository.getRouteReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          positions,
        ) {
          expect(positions.length, 1);
          expect(positions.first.id, 10);
          expect(() => positions.add(positions.first), throwsUnsupportedError);
        });
      },
    );

    test(
      'TC-REPO-02: getTripReport returns Right(unmodifiableList) on success',
      () async {
        mockDataSource.mockTrips = [
          TripReportModel(
            deviceId: 42,
            distance: 5000.0,
            averageSpeed: 20.0,
            maxSpeed: 35.0,
            startTime: tFrom,
            endTime: tTo,
            duration: 3600000,
          ),
        ];

        final result = await repository.getTripReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          trips,
        ) {
          expect(trips.length, 1);
          expect(trips.first.distance, 5000.0);
          expect(() => trips.add(trips.first), throwsUnsupportedError);
        });
      },
    );

    test(
      'TC-REPO-03: getStopReport returns Right(unmodifiableList) on success',
      () async {
        mockDataSource.mockStops = [
          StopReportModel(
            deviceId: 42,
            distance: 0.0,
            averageSpeed: 0.0,
            maxSpeed: 0.0,
            startTime: tFrom,
            endTime: tTo,
            latitude: -6.2,
            longitude: 106.8,
            duration: 1800000,
            engineHours: 0,
          ),
        ];

        final result = await repository.getStopReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          stops,
        ) {
          expect(stops.length, 1);
          expect(stops.first.duration, 1800000);
          expect(() => stops.add(stops.first), throwsUnsupportedError);
        });
      },
    );

    test('TC-REPO-04: Maps AuthException to Left(AuthFailure)', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Unauthorized',
        401,
      );

      final result = await repository.getRouteReport(
        deviceId: 42,
        from: tFrom,
        to: tTo,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<AuthFailure>().having((f) => f.statusCode, 'statusCode', 401),
        ),
        (positions) => fail('Expected Left, got Right'),
      );
    });

    test('TC-REPO-05: Maps NetworkException to Left(NetworkFailure)', () async {
      mockDataSource.exceptionToThrow = const NetworkException(
        'No connection',
        503,
      );

      final result = await repository.getTripReport(
        deviceId: 42,
        from: tFrom,
        to: tTo,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<NetworkFailure>().having((f) => f.statusCode, 'statusCode', 503),
        ),
        (trips) => fail('Expected Left, got Right'),
      );
    });

    test(
      'TC-REPO-06: Maps ConnectionTimeoutException to Left(TimeoutFailure)',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Timed out',
          408,
        );

        final result = await repository.getStopReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(
            failure,
            isA<TimeoutFailure>().having(
              (f) => f.statusCode,
              'statusCode',
              408,
            ),
          ),
          (stops) => fail('Expected Left, got Right'),
        );
      },
    );

    test('TC-REPO-07: Maps ServerException to Left(ServerFailure)', () async {
      mockDataSource.exceptionToThrow = const ServerException(
        'Internal Error',
        500,
      );

      final result = await repository.getRouteReport(
        deviceId: 42,
        from: tFrom,
        to: tTo,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(
          failure,
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 500),
        ),
        (positions) => fail('Expected Left, got Right'),
      );
    });

    test(
      'TC-REPO-08: Maps unexpected exception to Left(UnexpectedFailure)',
      () async {
        mockDataSource.exceptionToThrow = Exception('Unexpected disk error');

        final result = await repository.getRouteReport(
          deviceId: 42,
          from: tFrom,
          to: tTo,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<UnexpectedFailure>()),
          (positions) => fail('Expected Left, got Right'),
        );
      },
    );

    test('TC-REPO-09: Propagates CancelToken to datasource', () async {
      final token = CancelToken();

      await repository.getRouteReport(
        deviceId: 42,
        from: tFrom,
        to: tTo,
        cancelToken: token,
      );

      expect(mockDataSource.lastCancelToken, same(token));
      expect(mockDataSource.lastDeviceId, 42);
      expect(mockDataSource.lastFrom, tFrom);
      expect(mockDataSource.lastTo, tTo);
    });
  });
}
