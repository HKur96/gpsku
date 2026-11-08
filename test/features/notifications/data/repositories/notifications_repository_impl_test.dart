import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';
import 'package:gpsku/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:gpsku/features/notifications/domain/repositories/notifications_repository.dart';

class MockNotificationsRemoteDataSource
    implements NotificationsRemoteDataSource {
  List<NotificationModel> mockNotifications = [];
  NotificationModel? mockCreatedNotification;
  NotificationModel? mockUpdatedNotification;
  List<NotificationTypeModel> mockTypes = [];
  List<NotificationTypeModel> mockNotificators = [];
  UserModel? mockUpdatedUser;

  Exception? exceptionToThrow;
  int deleteCallCount = 0;
  int testChannelCallCount = 0;
  String? lastTestedChannel;
  int testAllCallCount = 0;
  UserModel? lastUserToUpdate;

  @override
  Future<List<NotificationModel>> getNotifications({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockNotifications;
  }

  @override
  Future<NotificationModel> createNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockCreatedNotification ?? notification;
  }

  @override
  Future<NotificationModel> updateNotification(
    NotificationModel notification, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockUpdatedNotification ?? notification;
  }

  @override
  Future<void> deleteNotification(int id, {CancelToken? cancelToken}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    deleteCallCount++;
  }

  @override
  Future<List<NotificationTypeModel>> getNotificationTypes({
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockTypes;
  }

  @override
  Future<List<NotificationTypeModel>> getNotificators({
    bool? announcement,
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockNotificators;
  }

  @override
  Future<void> testNotificationChannel(
    String notificator, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    testChannelCallCount++;
    lastTestedChannel = notificator;
  }

  @override
  Future<void> testAllNotificationChannels({CancelToken? cancelToken}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    testAllCallCount++;
  }

  @override
  Future<UserModel> updateUser(
    UserModel user, {
    CancelToken? cancelToken,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    lastUserToUpdate = user;
    return mockUpdatedUser ?? user;
  }
}

void main() {
  late MockNotificationsRemoteDataSource mockDataSource;
  late NotificationsRepository repository;

  setUp(() {
    mockDataSource = MockNotificationsRemoteDataSource();
    repository = NotificationsRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('NotificationsRepositoryImpl Unit Tests', () {
    test(
      'TC-NRI-01: getNotifications returns Right with unmodifiable list',
      () async {
        mockDataSource.mockNotifications = [
          const NotificationModel(
            id: 1,
            type: 'deviceOnline',
            notificators: 'web',
          ),
        ];

        final result = await repository.getNotifications();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Should succeed'), (items) {
          expect(items.length, 1);
          expect(items.first.id, 1);
          expect(
            () => items.add(const NotificationModel(id: 2, type: 'alarm')),
            throwsUnsupportedError,
          );
        });
      },
    );

    test('TC-NRI-02: createNotification returns Right on success', () async {
      final input = const NotificationModel(
        id: 0,
        type: 'alarm',
        notificators: 'web,firebase',
      );
      final created = const NotificationModel(
        id: 99,
        type: 'alarm',
        notificators: 'web,firebase',
      );
      mockDataSource.mockCreatedNotification = created;

      final result = await repository.createNotification(input);

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Should succeed'),
        (model) => expect(model.id, 99),
      );
    });

    test('TC-NRI-03: updateNotification returns Right on success', () async {
      final input = const NotificationModel(
        id: 10,
        type: 'deviceMoving',
        notificators: 'web',
      );
      mockDataSource.mockUpdatedNotification = input;

      final result = await repository.updateNotification(input);

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('Should succeed'),
        (model) => expect(model.id, 10),
      );
    });

    test(
      'TC-NRI-04: deleteNotification returns Right(null) on success',
      () async {
        final result = await repository.deleteNotification(15);

        expect(result.isRight(), isTrue);
        expect(mockDataSource.deleteCallCount, 1);
      },
    );

    test(
      'TC-NRI-05: getNotificationTypes returns Right with unmodifiable list',
      () async {
        mockDataSource.mockTypes = [
          const NotificationTypeModel(type: 'deviceOnline'),
          const NotificationTypeModel(type: 'alarm'),
        ];

        final result = await repository.getNotificationTypes();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('Should succeed'), (items) {
          expect(items.length, 2);
          expect(items.first.type, 'deviceOnline');
        });
      },
    );

    test(
      'TC-NRI-06: getNotificators returns Right with unmodifiable list',
      () async {
        mockDataSource.mockNotificators = [
          const NotificationTypeModel(type: 'web'),
          const NotificationTypeModel(type: 'firebase'),
        ];

        final result = await repository.getNotificators();

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('Should succeed'),
          (items) => expect(items.length, 2),
        );
      },
    );

    test(
      'TC-NRI-07: testNotificationChannel returns Right on success',
      () async {
        final result = await repository.testNotificationChannel('firebase');

        expect(result.isRight(), isTrue);
        expect(mockDataSource.testChannelCallCount, 1);
        expect(mockDataSource.lastTestedChannel, 'firebase');
      },
    );

    test(
      'TC-NRI-08: testAllNotificationChannels returns Right on success',
      () async {
        final result = await repository.testAllNotificationChannels();

        expect(result.isRight(), isTrue);
        expect(mockDataSource.testAllCallCount, 1);
      },
    );

    test(
      'TC-NRI-09: registerNotificationToken safely updates user attributes via PUT',
      () async {
        const user = UserModel(
          id: 7,
          name: 'Supervisor',
          email: 'supervisor@gpsku.id',
          attributes: {'speedUnit': 'km/h', 'notificationTokens': 'tokenA'},
        );

        final result = await repository.registerNotificationToken(
          currentUser: user,
          token: 'tokenB',
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.lastUserToUpdate, isNotNull);
        expect(
          mockDataSource.lastUserToUpdate!.attributes['notificationTokens'],
          'tokenA,tokenB',
        );
        expect(
          mockDataSource.lastUserToUpdate!.attributes['speedUnit'],
          'km/h',
        );
      },
    );

    test(
      'TC-NRI-10: registerNotificationToken skips PUT when token already present',
      () async {
        const user = UserModel(
          id: 7,
          name: 'Supervisor',
          email: 'supervisor@gpsku.id',
          attributes: {'notificationTokens': 'tokenA,tokenB'},
        );

        final result = await repository.registerNotificationToken(
          currentUser: user,
          token: 'tokenA',
        );

        expect(result.isRight(), isTrue);
        expect(
          mockDataSource.lastUserToUpdate,
          isNull,
        ); // Skipped network call!
      },
    );

    test(
      'TC-NRI-11: unregisterNotificationToken removes token via PUT',
      () async {
        const user = UserModel(
          id: 7,
          name: 'Supervisor',
          email: 'supervisor@gpsku.id',
          attributes: {'notificationTokens': 'tokenA,tokenB'},
        );

        final result = await repository.unregisterNotificationToken(
          currentUser: user,
          token: 'tokenA',
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.lastUserToUpdate, isNotNull);
        expect(
          mockDataSource.lastUserToUpdate!.attributes['notificationTokens'],
          'tokenB',
        );
      },
    );

    test(
      'TC-NRI-12: unregisterNotificationToken skips PUT when token is absent',
      () async {
        const user = UserModel(
          id: 7,
          name: 'Supervisor',
          email: 'supervisor@gpsku.id',
          attributes: {'notificationTokens': 'tokenA'},
        );

        final result = await repository.unregisterNotificationToken(
          currentUser: user,
          token: 'tokenX',
        );

        expect(result.isRight(), isTrue);
        expect(mockDataSource.lastUserToUpdate, isNull);
      },
    );

    test('TC-NRI-13: converts AuthException to AuthFailure', () async {
      mockDataSource.exceptionToThrow = const AuthException(
        'Session expired',
        401,
      );

      final result = await repository.getNotifications();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (data) => fail('Should fail with AuthFailure'),
      );
    });

    test(
      'TC-NRI-14: converts ForbiddenException to ForbiddenFailure',
      () async {
        mockDataSource.exceptionToThrow = const ForbiddenException(
          'Forbidden',
          403,
        );

        final result = await repository.deleteNotification(1);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<ForbiddenFailure>()),
          (data) => fail('Should fail with ForbiddenFailure'),
        );
      },
    );

    test(
      'TC-NRI-15: converts ConnectionTimeoutException to TimeoutFailure',
      () async {
        mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
          'Timed out',
          408,
        );

        final result = await repository.testNotificationChannel('web');

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<TimeoutFailure>()),
          (data) => fail('Should fail with TimeoutFailure'),
        );
      },
    );

    test('TC-NRI-16: converts NetworkException to NetworkFailure', () async {
      mockDataSource.exceptionToThrow = const NetworkException(
        'No connection',
        503,
      );

      final result = await repository.getNotificationTypes();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (data) => fail('Should fail with NetworkFailure'),
      );
    });

    test('TC-NRI-17: converts ServerException to ServerFailure', () async {
      mockDataSource.exceptionToThrow = const ServerException(
        'Internal error',
        500,
      );

      final result = await repository.createNotification(
        const NotificationModel(id: 0, type: 'alarm'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (data) => fail('Should fail with ServerFailure'),
      );
    });

    test(
      'TC-NRI-18: converts unknown Exception to UnexpectedFailure',
      () async {
        mockDataSource.exceptionToThrow = Exception('Catastrophic failure');

        final result = await repository.getNotifications();

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<UnexpectedFailure>()),
          (data) => fail('Should fail with UnexpectedFailure'),
        );
      },
    );
  });
}
