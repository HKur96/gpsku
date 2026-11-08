import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/datasources/fleet_remote_data_source.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/data/repositories/fleet_repository_impl.dart';

class MockFleetRemoteDataSource implements FleetRemoteDataSource {
  List<DeviceModel> mockDevices = [];
  List<PositionModel> mockPositions = [];
  List<GroupModel> mockGroups = [];
  Exception? exceptionToThrow;
  CancelToken? lastCancelToken;

  @override
  Future<List<DeviceModel>> getDevices({CancelToken? cancelToken}) async {
    lastCancelToken = cancelToken;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockDevices;
  }

  @override
  Future<List<PositionModel>> getPositions({CancelToken? cancelToken}) async {
    lastCancelToken = cancelToken;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockPositions;
  }

  @override
  Future<List<GroupModel>> getGroups({CancelToken? cancelToken}) async {
    lastCancelToken = cancelToken;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockGroups;
  }
}

void main() {
  group('FleetRepository - Domain Mapping & Error Encapsulation Tests', () {
    late MockFleetRemoteDataSource mockDataSource;
    late FleetRepositoryImpl repository;

    setUp(() {
      mockDataSource = MockFleetRemoteDataSource();
      repository = FleetRepositoryImpl(remoteDataSource: mockDataSource);
    });

    test(
      'TC-FR-01: Successful getDevices() returns Right(List<DeviceModel>)',
      () async {
        mockDataSource.mockDevices = [
          const DeviceModel(
            id: 1,
            name: 'Device A',
            uniqueId: 'DEV-001',
            status: 'online',
          ),
        ];

        final result = await repository.getDevices();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          devices,
        ) {
          expect(devices.length, equals(1));
          expect(devices.first.name, equals('Device A'));
        });
      },
    );

    test(
      'TC-FR-02: Successful getPositions() returns Right(List<PositionModel>)',
      () async {
        mockDataSource.mockPositions = [
          PositionModel(
            id: 50,
            deviceId: 1,
            serverTime: DateTime.parse('2026-11-08T08:00:00Z'),
            fixTime: DateTime.parse('2026-11-08T08:00:00Z'),
            latitude: -6.2000,
            longitude: 106.8166,
          ),
        ];

        final result = await repository.getPositions();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          positions,
        ) {
          expect(positions.length, equals(1));
          expect(positions.first.id, equals(50));
        });
      },
    );

    test(
      'TC-FR-03: Safely handles empty collections and null optional model fields',
      () async {
        mockDataSource.mockDevices = [
          const DeviceModel(
            id: 99,
            name: '',
            uniqueId: 'UNQ-99',
            contact: null,
            phone: null,
            model: null,
            lastUpdate: null,
          ),
        ];

        final result = await repository.getDevices();
        expect(result.isRight(), isTrue);
        result.fold((f) => fail(f.message), (devices) {
          expect(devices.first.id, equals(99));
          expect(devices.first.contact, isNull);
        });
      },
    );

    test('TC-FR-04: Maps AuthException to Left(AuthFailure)', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Session expired',
        401,
      );

      final result = await repository.getDevices();

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.message, equals('Session expired'));
        expect(failure.statusCode, equals(401));
      }, (_) => fail('Expected Left'));
    });

    test('TC-FR-05: Maps NetworkException to Left(NetworkFailure)', () async {
      mockDataSource.exceptionToThrow = const NetworkException(
        'Connection refused',
      );

      final result = await repository.getPositions();

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<NetworkFailure>());
        expect(failure.message, equals('Connection refused'));
      }, (_) => fail('Expected Left'));
    });

    test(
      'TC-FR-06: Maps ConnectionTimeoutException to Left(TimeoutFailure)',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Timed out',
        );

        final result = await repository.getDevices();

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<TimeoutFailure>());
          expect(failure.message, equals('Timed out'));
        }, (_) => fail('Expected Left'));
      },
    );

    test('TC-FR-07: Maps ServerException to Left(ServerFailure)', () async {
      mockDataSource.exceptionToThrow = const ServerException(
        'Server error',
        500,
      );

      final result = await repository.getPositions();

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.message, equals('Server error'));
        expect(failure.statusCode, equals(500));
      }, (_) => fail('Expected Left'));
    });

    test(
      'TC-FR-08: Preserves immutable output collections (List.unmodifiable)',
      () async {
        mockDataSource.mockDevices = [
          const DeviceModel(id: 1, name: 'D1', uniqueId: 'U1'),
        ];

        final result = await repository.getDevices();
        result.fold((f) => fail(f.message), (devices) {
          expect(
            () => devices.add(
              const DeviceModel(id: 2, name: 'D2', uniqueId: 'U2'),
            ),
            throwsUnsupportedError,
            reason:
                'Returned list must be unmodifiable to protect domain immutability',
          );
        });
      },
    );

    test(
      'TC-FR-09: Successful getGroups() returns Right(List<GroupModel>)',
      () async {
        mockDataSource.mockGroups = [
          const GroupModel(id: 1, name: 'Group Alpha', groupId: null),
          const GroupModel(id: 2, name: 'Sub-group Beta', groupId: 1),
        ];

        final result = await repository.getGroups();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Expected Right, got Left($failure)'), (
          groups,
        ) {
          expect(groups.length, equals(2));
          expect(groups[0].name, equals('Group Alpha'));
          expect(groups[1].groupId, equals(1));
        });
      },
    );

    test('TC-FR-10: Maps exceptions to Failures for getGroups()', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Unauthorized',
        401,
      );
      final authResult = await repository.getGroups();
      expect(authResult.isLeft(), isTrue);
      authResult.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('Expected Left'),
      );

      mockDataSource.exceptionToThrow = const ServerException(
        'Server error',
        500,
      );
      final serverResult = await repository.getGroups();
      expect(serverResult.isLeft(), isTrue);
      serverResult.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test(
      'TC-FR-11: Preserves immutable output collections for groups (List.unmodifiable)',
      () async {
        mockDataSource.mockGroups = [const GroupModel(id: 1, name: 'G1')];

        final result = await repository.getGroups();
        result.fold((f) => fail(f.message), (groups) {
          expect(
            () => groups.add(const GroupModel(id: 2, name: 'G2')),
            throwsUnsupportedError,
          );
        });
      },
    );
  });
}
