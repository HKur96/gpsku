import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/geofences/data/datasources/geofences_remote_data_source.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/data/repositories/geofences_repository_impl.dart';

class MockGeofencesRemoteDataSource implements GeofencesRemoteDataSource {
  List<GeofenceModel> mockGeofences = [];
  GeofenceModel? mockCreatedGeofence;
  GeofenceModel? mockUpdatedGeofence;
  Exception? exceptionToThrow;

  bool? lastAll;
  int? lastUserId;
  int? lastDeviceId;
  int? lastGroupId;
  CancelToken? lastCancelToken;
  GeofenceModel? lastCreatedInput;
  GeofenceModel? lastUpdatedInput;
  int? lastDeletedId;

  @override
  Future<List<GeofenceModel>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    lastAll = all;
    lastUserId = userId;
    lastDeviceId = deviceId;
    lastGroupId = groupId;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockGeofences;
  }

  @override
  Future<GeofenceModel> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    lastCreatedInput = geofence;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockCreatedGeofence ?? geofence.copyWith(id: 101);
  }

  @override
  Future<GeofenceModel> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    lastUpdatedInput = geofence;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockUpdatedGeofence ?? geofence;
  }

  @override
  Future<void> deleteGeofence(int id, {CancelToken? cancelToken}) async {
    lastDeletedId = id;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  int? lastLinkedDeviceId;
  int? lastLinkedGeofenceId;
  int? lastUnlinkedDeviceId;
  int? lastUnlinkedGeofenceId;

  @override
  Future<void> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    lastLinkedDeviceId = deviceId;
    lastLinkedGeofenceId = geofenceId;
    lastCancelToken = cancelToken;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    lastUnlinkedDeviceId = deviceId;
    lastUnlinkedGeofenceId = geofenceId;
    lastCancelToken = cancelToken;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }
}

void main() {
  group('GeofencesRepositoryImpl Unit Tests', () {
    late MockGeofencesRemoteDataSource mockDataSource;
    late GeofencesRepositoryImpl repository;

    const samplePolygonWkt =
        'POLYGON ((-6.20 106.81, -6.21 106.82, -6.22 106.80, -6.20 106.81))';
    const sampleCircleWkt = 'CIRCLE (-6.2088 106.8456, 500)';

    setUp(() {
      mockDataSource = MockGeofencesRemoteDataSource();
      repository = GeofencesRepositoryImpl(remoteDataSource: mockDataSource);
    });

    group('getGeofences', () {
      test(
        'TC-GRI-01: Returns Right(unmodifiable list) on successful remote fetch',
        () async {
          mockDataSource.mockGeofences = [
            const GeofenceModel(
              id: 1,
              name: 'Gudang #1',
              area: samplePolygonWkt,
            ),
            const GeofenceModel(id: 2, name: 'Depot #2', area: sampleCircleWkt),
          ];

          final result = await repository.getGeofences(all: true, deviceId: 42);

          expect(result.isRight(), isTrue);
          result.fold((failure) => fail('Should be Right'), (geofences) {
            expect(geofences.length, equals(2));
            expect(geofences[0].id, equals(1));
            expect(geofences[1].id, equals(2));

            // Verify unmodifiable
            expect(
              () => (geofences as dynamic).add(
                const GeofenceModel(id: 3, name: 'X', area: sampleCircleWkt),
              ),
              throwsUnsupportedError,
            );
          });
          expect(mockDataSource.lastAll, isTrue);
          expect(mockDataSource.lastDeviceId, equals(42));
        },
      );
    });

    group('createGeofence', () {
      test('TC-GRI-02: Returns Right(GeofenceModel) on success', () async {
        const input = GeofenceModel(
          id: 0,
          name: 'Zona Baru',
          area: sampleCircleWkt,
        );
        mockDataSource.mockCreatedGeofence = const GeofenceModel(
          id: 77,
          name: 'Zona Baru',
          area: sampleCircleWkt,
        );

        final result = await repository.createGeofence(input);

        expect(result.isRight(), isTrue);
        expect(result.getOrElse((_) => throw 'fail').id, equals(77));
        expect(mockDataSource.lastCreatedInput?.name, equals('Zona Baru'));
      });
    });

    group('updateGeofence', () {
      test('TC-GRI-03: Returns Right(GeofenceModel) on success', () async {
        const input = GeofenceModel(
          id: 77,
          name: 'Zona Update',
          area: sampleCircleWkt,
        );
        mockDataSource.mockUpdatedGeofence = input;

        final result = await repository.updateGeofence(input);

        expect(result.isRight(), isTrue);
        expect(
          result.getOrElse((_) => throw 'fail').name,
          equals('Zona Update'),
        );
      });
    });

    group('deleteGeofence', () {
      test('TC-GRI-04: Returns Right(null) on success', () async {
        final result = await repository.deleteGeofence(77);

        expect(result.isRight(), isTrue);
        expect(mockDataSource.lastDeletedId, equals(77));
      });
    });

    group('Failure Mappings', () {
      test('TC-GRI-05: Maps AuthException to Left(AuthFailure)', () async {
        mockDataSource.exceptionToThrow = const AuthException(
          'Unauthorized session',
          401,
        );

        final result = await repository.getGeofences();

        expect(result.isLeft(), isTrue);
        expect(
          result.swap().getOrElse((_) => throw 'fail'),
          isA<AuthFailure>()
              .having((f) => f.statusCode, 'statusCode', 401)
              .having((f) => f.message, 'message', 'Unauthorized session'),
        );
      });

      test(
        'TC-GRI-06: Maps ForbiddenException to Left(ForbiddenFailure)',
        () async {
          mockDataSource.exceptionToThrow = const ForbiddenException(
            'Akses geofence ditolak',
            403,
          );

          final result = await repository.deleteGeofence(12);

          expect(result.isLeft(), isTrue);
          expect(
            result.swap().getOrElse((_) => throw 'fail'),
            isA<ForbiddenFailure>()
                .having((f) => f.statusCode, 'statusCode', 403)
                .having((f) => f.message, 'message', 'Akses geofence ditolak'),
          );
        },
      );

      test(
        'TC-GRI-07: Maps ConnectionTimeoutException to Left(TimeoutFailure)',
        () async {
          mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
            'Request timed out',
          );

          final result = await repository.getGeofences();

          expect(result.isLeft(), isTrue);
          expect(
            result.swap().getOrElse((_) => throw 'fail'),
            isA<TimeoutFailure>(),
          );
        },
      );

      test(
        'TC-GRI-08: Maps NetworkException to Left(NetworkFailure)',
        () async {
          mockDataSource.exceptionToThrow = const NetworkException(
            'No internet connection',
          );

          final result = await repository.getGeofences();

          expect(result.isLeft(), isTrue);
          expect(
            result.swap().getOrElse((_) => throw 'fail'),
            isA<NetworkFailure>(),
          );
        },
      );

      test('TC-GRI-09: Maps ServerException to Left(ServerFailure)', () async {
        mockDataSource.exceptionToThrow = const ServerException(
          'Internal server error',
          500,
        );

        final result = await repository.createGeofence(
          const GeofenceModel(id: 0, name: 'X', area: sampleCircleWkt),
        );

        expect(result.isLeft(), isTrue);
        expect(
          result.swap().getOrElse((_) => throw 'fail'),
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 500),
        );
      });

      test(
        'TC-GRI-10: Maps unexpected Exception to Left(UnexpectedFailure)',
        () async {
          mockDataSource.exceptionToThrow = Exception('Catastrophic failure');

          final result = await repository.getGeofences();

          expect(result.isLeft(), isTrue);
          expect(
            result.swap().getOrElse((_) => throw 'fail'),
            isA<UnexpectedFailure>(),
          );
        },
      );

      test(
        'TC-GRI-11: linkDeviceGeofence delegates to remoteDataSource and returns Right(null)',
        () async {
          final result = await repository.linkDeviceGeofence(
            deviceId: 10,
            geofenceId: 25,
          );

          expect(result.isRight(), isTrue);
          expect(mockDataSource.lastLinkedDeviceId, equals(10));
          expect(mockDataSource.lastLinkedGeofenceId, equals(25));
        },
      );

      test(
        'TC-GRI-12: unlinkDeviceGeofence delegates to remoteDataSource and returns Right(null)',
        () async {
          final result = await repository.unlinkDeviceGeofence(
            deviceId: 10,
            geofenceId: 25,
          );

          expect(result.isRight(), isTrue);
          expect(mockDataSource.lastUnlinkedDeviceId, equals(10));
          expect(mockDataSource.lastUnlinkedGeofenceId, equals(25));
        },
      );

      test(
        'TC-GRI-13: linkDeviceGeofence maps AuthException to Left(AuthFailure)',
        () async {
          mockDataSource.exceptionToThrow = const AuthException(
            'Unauthorized',
            401,
          );

          final result = await repository.linkDeviceGeofence(
            deviceId: 10,
            geofenceId: 25,
          );

          expect(result.isLeft(), isTrue);
          expect(
            result.swap().getOrElse((_) => throw 'fail'),
            isA<AuthFailure>().having((f) => f.statusCode, 'statusCode', 401),
          );
        },
      );
    });
  });
}
