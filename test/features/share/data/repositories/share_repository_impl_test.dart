import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/share/data/datasources/share_remote_data_source.dart';
import 'package:gpsku/features/share/data/repositories/share_repository_impl.dart';

class MockShareRemoteDataSource implements ShareRemoteDataSource {
  String mockToken = 'mock_share_token_secret_123';
  Exception? exceptionToThrow;

  int? lastDeviceId;
  int? lastGroupId;
  DateTime? lastExpiration;
  CancelToken? lastCancelToken;

  @override
  Future<String> createDeviceShareToken({
    required int deviceId,
    required DateTime expiration,
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastExpiration = expiration;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockToken;
  }

  @override
  Future<String> createGroupShareToken({
    required int groupId,
    required DateTime expiration,
    CancelToken? cancelToken,
  }) async {
    lastGroupId = groupId;
    lastExpiration = expiration;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockToken;
  }

  @override
  Future<String> createUserSessionToken({
    required DateTime expiration,
    CancelToken? cancelToken,
  }) async {
    lastExpiration = expiration;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockToken;
  }
}

void main() {
  late MockShareRemoteDataSource mockRemoteDataSource;
  late AppConfig appConfig;
  late ShareRepositoryImpl repository;

  const tBaseUrl = 'http://10.0.2.2:8082';

  setUp(() {
    mockRemoteDataSource = MockShareRemoteDataSource();
    appConfig = const AppConfig(baseUrl: tBaseUrl);
    repository = ShareRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      appConfig: appConfig,
    );
  });

  group('ShareRepositoryImpl Unit Tests', () {
    test(
      'TC-SRI-01: generateShareLink returns Right(ShareLinkModel) on success',
      () async {
        final cancelToken = CancelToken();
        final result = await repository.generateShareLink(
          42,
          const Duration(days: 7),
          cancelToken: cancelToken,
        );

        expect(result.isRight(), isTrue);
        final model = result.getOrElse((_) => throw Exception());

        expect(model.deviceId, 42);
        expect(model.groupId, isNull);
        expect(model.token, 'mock_share_token_secret_123');
        expect(model.shareUrl, '$tBaseUrl/?token=mock_share_token_secret_123');
        expect(model.isExpired, isFalse);
        expect(mockRemoteDataSource.lastDeviceId, 42);
        expect(mockRemoteDataSource.lastCancelToken, cancelToken);
      },
    );

    test(
      'TC-SRI-02: Normalizes base URLs with trailing slashes in shareUrl',
      () async {
        final repoWithSlash = ShareRepositoryImpl(
          remoteDataSource: mockRemoteDataSource,
          appConfig: const AppConfig(baseUrl: 'https://gps.antigravity.id/'),
        );

        final result = await repoWithSlash.generateShareLink(
          11,
          const Duration(hours: 24),
        );

        expect(result.isRight(), isTrue);
        final model = result.getOrElse((_) => throw Exception());
        expect(
          model.shareUrl,
          'https://gps.antigravity.id/?token=mock_share_token_secret_123',
        );
      },
    );

    test(
      'TC-SRI-03: Rejects invalid or negative durations with Left(ServerFailure)',
      () async {
        final resultZero = await repository.generateShareLink(
          42,
          Duration.zero,
        );
        expect(resultZero.isLeft(), isTrue);
        resultZero.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('lebih dari 0'));
        }, (_) => fail('Must fail'));

        final resultNegative = await repository.generateShareLink(
          42,
          const Duration(hours: -1),
        );
        expect(resultNegative.isLeft(), isTrue);
      },
    );

    test(
      'TC-SRI-04: Rejects invalid device ID (<= 0) with Left(ServerFailure)',
      () async {
        final result = await repository.generateShareLink(
          0,
          const Duration(hours: 1),
        );
        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) =>
              expect(failure.message, contains('ID perangkat tidak valid')),
          (_) => fail('Must fail'),
        );
      },
    );

    test('TC-SRI-05: Maps AuthException to Left(AuthFailure)', () async {
      mockRemoteDataSource.exceptionToThrow = const AuthException(
        'Unauthorized',
        401,
      );

      final result = await repository.generateShareLink(
        42,
        const Duration(hours: 1),
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.statusCode, 401);
      }, (_) => fail('Must fail'));
    });

    test(
      'TC-SRI-06: Maps ForbiddenException to Left(ForbiddenFailure)',
      () async {
        mockRemoteDataSource.exceptionToThrow = const ForbiddenException(
          'Sharing disabled',
          403,
        );

        final result = await repository.generateShareLink(
          42,
          const Duration(hours: 1),
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ForbiddenFailure>());
          expect(failure.statusCode, 403);
        }, (_) => fail('Must fail'));
      },
    );

    test('TC-SRI-07: Maps ServerException to Left(ServerFailure)', () async {
      mockRemoteDataSource.exceptionToThrow = const ServerException(
        'Internal server error',
        500,
      );

      final result = await repository.generateShareLink(
        42,
        const Duration(hours: 1),
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.statusCode, 500);
      }, (_) => fail('Must fail'));
    });

    test(
      'TC-SRI-07B: Maps ConflictException to Left(ConflictFailure)',
      () async {
        mockRemoteDataSource.exceptionToThrow = const ConflictException(
          'Active link already exists',
          409,
        );

        final result = await repository.generateShareLink(
          42,
          const Duration(hours: 1),
        );

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ConflictFailure>());
          expect(failure.statusCode, 409);
          expect(failure.message, contains('Active link already exists'));
        }, (_) => fail('Must fail'));
      },
    );

    test(
      'TC-SRI-08: Maps ConnectionTimeoutException to Left(TimeoutFailure)',
      () async {
        mockRemoteDataSource.exceptionToThrow =
            const ConnectionTimeoutException('Timeout');

        final result = await repository.generateShareLink(
          42,
          const Duration(hours: 1),
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<TimeoutFailure>()),
          (_) => fail('Must fail'),
        );
      },
    );

    test('TC-SRI-09: Maps NetworkException to Left(NetworkFailure)', () async {
      mockRemoteDataSource.exceptionToThrow = const NetworkException(
        'Connection refused',
      );

      final result = await repository.generateShareLink(
        42,
        const Duration(hours: 1),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Must fail'),
      );
    });

    test(
      'TC-SRI-10: Maps unexpected generic exception to Left(UnexpectedFailure)',
      () async {
        mockRemoteDataSource.exceptionToThrow = Exception('Database corrupt');

        final result = await repository.generateShareLink(
          42,
          const Duration(hours: 1),
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<UnexpectedFailure>()),
          (_) => fail('Must fail'),
        );
      },
    );

    test(
      'TC-SRI-11: generateGroupShareLink returns Right(ShareLinkModel) with groupId',
      () async {
        final result = await repository.generateGroupShareLink(
          9,
          const Duration(days: 3),
        );

        expect(result.isRight(), isTrue);
        final model = result.getOrElse((_) => throw Exception());

        expect(model.deviceId, 0);
        expect(model.groupId, 9);
        expect(model.isGroupShare, isTrue);
        expect(model.token, 'mock_share_token_secret_123');
        expect(mockRemoteDataSource.lastGroupId, 9);
      },
    );

    test(
      'TC-SRI-12: generateGroupShareLink rejects invalid group ID (<= 0)',
      () async {
        final result = await repository.generateGroupShareLink(
          -1,
          const Duration(hours: 1),
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure.message, contains('ID grup tidak valid')),
          (_) => fail('Must fail'),
        );
      },
    );
  });
}
