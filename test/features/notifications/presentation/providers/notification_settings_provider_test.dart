import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';
import 'package:gpsku/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:gpsku/features/notifications/presentation/providers/notification_settings_provider.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<NotificationModel> mockNotifications = [];
  List<NotificationTypeModel> mockTypes = [];
  List<NotificationTypeModel> mockNotificators = [];
  NotificationModel? mockCreatedNotification;
  NotificationModel? mockUpdatedNotification;
  Failure? failureToReturn;

  int getNotificationsCount = 0;
  int createCount = 0;
  int updateCount = 0;
  int deleteCount = 0;
  int testChannelCount = 0;
  String? lastTestedChannel;
  int? lastDeletedId;
  Completer<void>? pendingGetNotificationsCompleter;

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    CancelToken? cancelToken,
  }) async {
    getNotificationsCount++;
    if (pendingGetNotificationsCompleter != null) {
      await pendingGetNotificationsCompleter!.future;
    }
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockNotifications);
  }

  @override
  Future<Either<Failure, NotificationModel>> createNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async {
    createCount++;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockCreatedNotification ?? notification);
  }

  @override
  Future<Either<Failure, NotificationModel>> updateNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async {
    updateCount++;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockUpdatedNotification ?? notification);
  }

  @override
  Future<Either<Failure, void>> deleteNotification(
    int id, {
    CancelToken? cancelToken,
  }) async {
    deleteCount++;
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<NotificationTypeModel>>> getNotificationTypes({
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockTypes);
  }

  @override
  Future<Either<Failure, List<NotificationTypeModel>>> getNotificators({
    bool? announcement,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockNotificators);
  }

  @override
  Future<Either<Failure, void>> testNotificationChannel(
    String notificator, {
    CancelToken? cancelToken,
  }) async {
    testChannelCount++;
    lastTestedChannel = notificator;
    if (failureToReturn != null) return Left(failureToReturn!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> testAllNotificationChannels({
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserModel>> registerNotificationToken({
    required UserModel currentUser,
    required String token,
    CancelToken? cancelToken,
  }) async {
    return Right(currentUser);
  }

  @override
  Future<Either<Failure, UserModel>> unregisterNotificationToken({
    required UserModel currentUser,
    required String token,
    CancelToken? cancelToken,
  }) async {
    return Right(currentUser);
  }
}

void main() {
  late MockNotificationsRepository repository;
  late NotificationSettingsProvider provider;

  setUp(() {
    repository = MockNotificationsRepository();
    provider = NotificationSettingsProvider(repository: repository);
  });

  group('NotificationSettingsProvider Unit Tests', () {
    test(
      'TC-NSP-01: fetchSettings loads notifications, types, and notificators',
      () async {
        repository.mockNotifications = [
          const NotificationModel(
            id: 1,
            type: 'alarm',
            always: true,
            notificators: 'web,firebase',
          ),
        ];
        repository.mockTypes = [
          const NotificationTypeModel(type: 'alarm', name: 'Alarm SOS'),
        ];
        repository.mockNotificators = [
          const NotificationTypeModel(type: 'web', name: 'Web'),
          const NotificationTypeModel(type: 'firebase', name: 'Firebase'),
        ];

        await provider.fetchSettings();

        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);
        expect(provider.notifications.length, 1);
        expect(provider.notifications.first.id, 1);
        expect(provider.types.length, 1);
        expect(provider.notificators.length, 2);
      },
    );

    test(
      'TC-NSP-02: fetchSettings captures error when repository fails',
      () async {
        repository.failureToReturn = const ServerFailure(
          'Server internal error 500',
        );

        await provider.fetchSettings();

        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, contains('Server internal error 500'));
        expect(provider.notifications, isEmpty);
        // Fallback types and notificators should be preserved
        expect(provider.types, isNotEmpty);
        expect(provider.notificators, isNotEmpty);
      },
    );

    test(
      'TC-NSP-03: createNotification adds newly created rule to list',
      () async {
        repository.mockCreatedNotification = const NotificationModel(
          id: 10,
          type: 'deviceOnline',
          notificators: 'web',
        );

        final success = await provider.createNotification(
          const NotificationModel(
            id: 0,
            type: 'deviceOnline',
            notificators: 'web',
          ),
        );

        expect(success, isTrue);
        expect(provider.notifications.length, 1);
        expect(provider.notifications.first.id, 10);
        expect(provider.isSaving, isFalse);
        expect(provider.errorMessage, isNull);
      },
    );

    test(
      'TC-NSP-04: createNotification failure preserves existing list and sets error',
      () async {
        repository.failureToReturn = const NetworkFailure('Koneksi timeout');

        final success = await provider.createNotification(
          const NotificationModel(id: 0, type: 'alarm', notificators: 'web'),
        );

        expect(success, isFalse);
        expect(provider.notifications, isEmpty);
        expect(provider.errorMessage, contains('Koneksi timeout'));
        expect(provider.isSaving, isFalse);
      },
    );

    test(
      'TC-NSP-05: updateNotification replaces matching rule in list',
      () async {
        repository.mockNotifications = [
          const NotificationModel(
            id: 5,
            type: 'alarm',
            always: false,
            notificators: 'web',
          ),
        ];
        await provider.fetchSettings();

        const updated = NotificationModel(
          id: 5,
          type: 'alarm',
          always: true,
          notificators: 'web,firebase',
        );
        repository.mockUpdatedNotification = updated;

        final success = await provider.updateNotification(updated);

        expect(success, isTrue);
        expect(provider.notifications.length, 1);
        expect(provider.notifications.first.always, isTrue);
        expect(provider.notifications.first.notificators, 'web,firebase');
      },
    );

    test('TC-NSP-06: updateNotification failure sets errorMessage', () async {
      repository.failureToReturn = const ForbiddenFailure('Akses ditolak 403');

      final success = await provider.updateNotification(
        const NotificationModel(id: 5, type: 'alarm'),
      );

      expect(success, isFalse);
      expect(provider.errorMessage, contains('Akses ditolak 403'));
      expect(provider.isSaving, isFalse);
    });

    test(
      'TC-NSP-07: deleteNotification removes matching rule from list',
      () async {
        repository.mockNotifications = [
          const NotificationModel(id: 1, type: 'alarm'),
          const NotificationModel(id: 2, type: 'deviceOnline'),
        ];
        await provider.fetchSettings();

        final success = await provider.deleteNotification(1);

        expect(success, isTrue);
        expect(provider.notifications.length, 1);
        expect(provider.notifications.first.id, 2);
        expect(repository.lastDeletedId, 1);
      },
    );

    test('TC-NSP-08: deleteNotification failure sets errorMessage', () async {
      repository.failureToReturn = const ServerFailure('Cannot delete rule');

      final success = await provider.deleteNotification(1);

      expect(success, isFalse);
      expect(provider.errorMessage, contains('Cannot delete rule'));
      expect(provider.isSaving, isFalse);
    });

    test(
      'TC-NSP-09: testNotificator returns true on success and manages testing state',
      () async {
        final future = provider.testNotificator('telegram');
        final success = await future;

        expect(success, isTrue);
        expect(repository.lastTestedChannel, 'telegram');
        expect(provider.testingNotificator, isNull);
        expect(provider.errorMessage, isNull);
      },
    );

    test(
      'TC-NSP-10: testNotificator returns false on failure and captures error',
      () async {
        repository.failureToReturn = const NetworkFailure(
          'Telegram API timeout',
        );

        final success = await provider.testNotificator('telegram');

        expect(success, isFalse);
        expect(provider.errorMessage, contains('Telegram API timeout'));
        expect(provider.testingNotificator, isNull);
      },
    );

    test('TC-NSP-11: clearSettings resets all state to empty', () async {
      repository.mockNotifications = [
        const NotificationModel(id: 1, type: 'alarm'),
      ];
      await provider.fetchSettings();
      expect(provider.notifications, isNotEmpty);

      provider.clearSettings();

      expect(provider.notifications, isEmpty);
      expect(provider.types, isEmpty);
      expect(provider.notificators, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });
  });
}
