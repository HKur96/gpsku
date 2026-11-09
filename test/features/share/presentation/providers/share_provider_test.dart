import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/share/data/models/share_link_model.dart';
import 'package:gpsku/features/share/domain/repositories/share_repository.dart';
import 'package:gpsku/features/share/presentation/providers/share_provider.dart';

class MockShareRepository implements ShareRepository {
  ShareLinkModel? mockLinkToReturn;
  Failure? failureToReturn;

  int? lastDeviceId;
  int? lastGroupId;
  Duration? lastDuration;
  CancelToken? lastCancelToken;

  @override
  Future<Either<Failure, ShareLinkModel>> generateShareLink(
    int deviceId,
    Duration duration, {
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastDuration = duration;
    lastCancelToken = cancelToken;

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(
      mockLinkToReturn ??
          ShareLinkModel(
            deviceId: deviceId,
            token: 'mock_token_123',
            expiration: DateTime.now().add(duration),
            shareUrl: 'https://gpsku.app/?token=mock_token_123',
          ),
    );
  }

  @override
  Future<Either<Failure, ShareLinkModel>> generateGroupShareLink(
    int groupId,
    Duration duration, {
    CancelToken? cancelToken,
  }) async {
    lastGroupId = groupId;
    lastDuration = duration;
    lastCancelToken = cancelToken;

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(
      mockLinkToReturn ??
          ShareLinkModel(
            deviceId: 0,
            groupId: groupId,
            token: 'mock_group_token_456',
            expiration: DateTime.now().add(duration),
            shareUrl: 'https://gpsku.app/?token=mock_group_token_456',
          ),
    );
  }
}

void main() {
  late MockShareRepository mockRepository;
  late ShareProvider provider;

  setUp(() {
    mockRepository = MockShareRepository();
    provider = ShareProvider(repository: mockRepository);
  });

  group('ShareProvider Unit Tests', () {
    test(
      'TC-SP-01: Initial state has no link, not loading, no failure, and default 24h duration',
      () {
        expect(provider.shareLink, isNull);
        expect(provider.isLoading, isFalse);
        expect(provider.failure, isNull);
        expect(provider.errorMessage, isNull);
        expect(provider.isConflict, isFalse);
        expect(provider.hasLink, isFalse);
        expect(provider.selectedDuration, const Duration(hours: 24));
      },
    );

    test(
      'TC-SP-02: setDuration updates selectedDuration and notifies listeners',
      () {
        var notified = false;
        provider.addListener(() => notified = true);

        provider.setDuration(const Duration(hours: 6));

        expect(provider.selectedDuration, const Duration(hours: 6));
        expect(notified, isTrue);
      },
    );

    test(
      'TC-SP-03: generateLink manages loading and sets shareLink on repository success',
      () async {
        final cancelToken = CancelToken();
        final success = await provider.generateLink(
          42,
          duration: const Duration(days: 7),
          cancelToken: cancelToken,
        );

        expect(success, isTrue);
        expect(provider.isLoading, isFalse);
        expect(provider.shareLink, isNotNull);
        expect(provider.shareLink!.deviceId, 42);
        expect(provider.hasLink, isTrue);
        expect(provider.failure, isNull);
        expect(mockRepository.lastDeviceId, 42);
        expect(mockRepository.lastDuration, const Duration(days: 7));
        expect(mockRepository.lastCancelToken, cancelToken);
      },
    );

    test(
      'TC-SP-04: generateLink captures failure and sets errorMessage on error',
      () async {
        mockRepository.failureToReturn = const ServerFailure(
          'Internal server error',
          statusCode: 500,
        );

        final success = await provider.generateLink(42);

        expect(success, isFalse);
        expect(provider.isLoading, isFalse);
        expect(provider.shareLink, isNull);
        expect(provider.failure, isA<ServerFailure>());
        expect(provider.errorMessage, contains('Internal server error'));
        expect(provider.isConflict, isFalse);
      },
    );

    test(
      'TC-SP-05: isConflict evaluates true when failure is ConflictFailure or 409',
      () async {
        mockRepository.failureToReturn = const ConflictFailure(
          'Tautan aktif sudah terdaftar di server',
          statusCode: 409,
        );

        final success = await provider.generateLink(42);

        expect(success, isFalse);
        expect(provider.isConflict, isTrue);
        expect(provider.errorMessage, contains('Tautan aktif sudah terdaftar'));
      },
    );

    test('TC-SP-06: generateGroupLink generates group share link', () async {
      final success = await provider.generateGroupLink(
        15,
        duration: const Duration(hours: 1),
      );

      expect(success, isTrue);
      expect(provider.shareLink, isNotNull);
      expect(provider.shareLink!.groupId, 15);
      expect(provider.shareLink!.isGroupShare, isTrue);
      expect(mockRepository.lastGroupId, 15);
    });

    test(
      'TC-SP-07: clearState resets shareLink, failure, and loading flags',
      () async {
        await provider.generateLink(42);
        expect(provider.shareLink, isNotNull);

        provider.clearState();

        expect(provider.shareLink, isNull);
        expect(provider.failure, isNull);
        expect(provider.isLoading, isFalse);
        expect(provider.hasLink, isFalse);
      },
    );

    test(
      'TC-SP-08: formatDurationPreset formats presets into Indonesian text',
      () {
        expect(
          ShareProvider.formatDurationPreset(const Duration(hours: 1)),
          '1 Jam',
        );
        expect(
          ShareProvider.formatDurationPreset(const Duration(hours: 6)),
          '6 Jam',
        );
        expect(
          ShareProvider.formatDurationPreset(const Duration(hours: 24)),
          '24 Jam',
        );
        expect(
          ShareProvider.formatDurationPreset(const Duration(days: 7)),
          '7 Hari',
        );
      },
    );
  });
}
