import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/exceptions.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/commands/data/datasources/commands_remote_data_source.dart';
import 'package:gpsku/features/commands/data/models/command_payload_model.dart';
import 'package:gpsku/features/commands/data/models/command_type_model.dart';
import 'package:gpsku/features/commands/data/repositories/commands_repository_impl.dart';

class MockCommandsRemoteDataSource implements CommandsRemoteDataSource {
  List<CommandTypeModel> mockCommands = [];
  CommandPayloadModel? mockSendResult;
  Exception? exceptionToThrow;
  CancelToken? lastCancelToken;
  int? lastDeviceId;
  String? lastProtocol;
  bool? lastTextChannel;
  CommandPayloadModel? lastSentPayload;

  @override
  Future<List<CommandTypeModel>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  }) async {
    lastDeviceId = deviceId;
    lastProtocol = protocol;
    lastTextChannel = textChannel;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockCommands;
  }

  @override
  Future<CommandPayloadModel> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  }) async {
    lastSentPayload = payload;
    lastCancelToken = cancelToken;

    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSendResult ?? payload;
  }
}

void main() {
  group('CommandsRepositoryImpl Unit Tests', () {
    late MockCommandsRemoteDataSource mockDataSource;
    late CommandsRepositoryImpl repository;

    final tPayload = CommandPayloadModel(
      deviceId: 42,
      type: 'engineStop',
      attributes: const {},
    );

    setUp(() {
      mockDataSource = MockCommandsRemoteDataSource();
      repository = CommandsRepositoryImpl(remoteDataSource: mockDataSource);
    });

    group('getSupportedCommands', () {
      test(
        'TC-CRI-01: Returns Right with unmodifiable list of CommandTypeModel upon success',
        () async {
          mockDataSource.mockCommands = [
            const CommandTypeModel(type: 'engineStop'),
            const CommandTypeModel(type: 'engineResume'),
          ];

          final result = await repository.getSupportedCommands(deviceId: 42);

          expect(result.isRight(), isTrue);
          result.fold((failure) => fail('Expected Right, got $failure'), (
            commands,
          ) {
            expect(commands.length, equals(2));
            expect(commands[0].type, equals('engineStop'));
            expect(commands[1].type, equals('engineResume'));
            expect(
              () => commands.add(const CommandTypeModel(type: 'custom')),
              throwsA(isA<UnsupportedError>()),
            );
          });
        },
      );

      test('TC-CRI-02: Maps AuthException to AuthFailure', () async {
        mockDataSource.exceptionToThrow = const AuthException(
          'Session expired',
          401,
        );

        final result = await repository.getSupportedCommands(deviceId: 42);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.statusCode, equals(401));
        }, (_) => fail('Expected Left'));
      });

      test('TC-CRI-03: Maps ForbiddenException to ForbiddenFailure', () async {
        mockDataSource.exceptionToThrow = const ForbiddenException(
          'No permission on device',
          403,
        );

        final result = await repository.getSupportedCommands(deviceId: 42);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ForbiddenFailure>());
          expect(failure.statusCode, equals(403));
        }, (_) => fail('Expected Left'));
      });

      test(
        'TC-CRI-04: Maps ConnectionTimeoutException to TimeoutFailure',
        () async {
          mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
            'Timeout',
            504,
          );

          final result = await repository.getSupportedCommands(deviceId: 42);

          expect(result.isLeft(), isTrue);
          result.fold(
            (failure) => expect(failure, isA<TimeoutFailure>()),
            (_) => fail('Expected Left'),
          );
        },
      );

      test('TC-CRI-05: Maps NetworkException to NetworkFailure', () async {
        mockDataSource.exceptionToThrow = const NetworkException(
          'Offline network',
        );

        final result = await repository.getSupportedCommands(deviceId: 42);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('TC-CRI-06: Maps ServerException to ServerFailure', () async {
        mockDataSource.exceptionToThrow = const ServerException(
          'Server fault',
          500,
        );

        final result = await repository.getSupportedCommands(deviceId: 42);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.statusCode, equals(500));
        }, (_) => fail('Expected Left'));
      });

      test(
        'TC-CRI-07: Maps unexpected exception to UnexpectedFailure',
        () async {
          mockDataSource.exceptionToThrow = Exception('General crash');

          final result = await repository.getSupportedCommands(deviceId: 42);

          expect(result.isLeft(), isTrue);
          result.fold(
            (failure) => expect(failure, isA<UnexpectedFailure>()),
            (_) => fail('Expected Left'),
          );
        },
      );
    });

    group('sendCommand', () {
      test(
        'TC-CRI-08: Returns Right with CommandPayloadModel upon successful immediate dispatch',
        () async {
          mockDataSource.mockSendResult = CommandPayloadModel(
            id: 10,
            deviceId: 42,
            type: 'engineStop',
            isQueued: false,
          );

          final result = await repository.sendCommand(tPayload);

          expect(result.isRight(), isTrue);
          result.fold((failure) => fail('Expected Right, got $failure'), (
            payload,
          ) {
            expect(payload.id, equals(10));
            expect(payload.deviceId, equals(42));
            expect(payload.type, equals('engineStop'));
            expect(payload.isQueued, isFalse);
          });
        },
      );

      test(
        'TC-CRI-09: Preserves isQueued=true status when command is queued on server',
        () async {
          mockDataSource.mockSendResult = CommandPayloadModel(
            id: 11,
            deviceId: 42,
            type: 'engineStop',
            isQueued: true,
          );

          final result = await repository.sendCommand(tPayload);

          expect(result.isRight(), isTrue);
          result.fold((failure) => fail('Expected Right, got $failure'), (
            payload,
          ) {
            expect(payload.isQueued, isTrue);
          });
        },
      );

      test('TC-CRI-10: Maps AuthException to AuthFailure', () async {
        mockDataSource.exceptionToThrow = const AuthException(
          'Unauthorized',
          401,
        );

        final result = await repository.sendCommand(tPayload);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<AuthFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('TC-CRI-11: Maps ForbiddenException to ForbiddenFailure', () async {
        mockDataSource.exceptionToThrow = const ForbiddenException(
          'User restricted',
          403,
        );

        final result = await repository.sendCommand(tPayload);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<ForbiddenFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test(
        'TC-CRI-12: Maps ServerException (e.g. 400 Bad Request) to ServerFailure',
        () async {
          mockDataSource.exceptionToThrow = const ServerException(
            'Unsupported command type',
            400,
          );

          final result = await repository.sendCommand(tPayload);

          expect(result.isLeft(), isTrue);
          result.fold((failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.statusCode, equals(400));
          }, (_) => fail('Expected Left'));
        },
      );

      test(
        'TC-CRI-13: Maps ConnectionTimeoutException to TimeoutFailure',
        () async {
          mockDataSource.exceptionToThrow = const ConnectionTimeoutException(
            'Timeout',
          );

          final result = await repository.sendCommand(tPayload);

          expect(result.isLeft(), isTrue);
          result.fold(
            (failure) => expect(failure, isA<TimeoutFailure>()),
            (_) => fail('Expected Left'),
          );
        },
      );

      test('TC-CRI-14: Maps NetworkException to NetworkFailure', () async {
        mockDataSource.exceptionToThrow = const NetworkException(
          'Network error',
        );

        final result = await repository.sendCommand(tPayload);

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test(
        'TC-CRI-15: Maps unexpected exception to UnexpectedFailure',
        () async {
          mockDataSource.exceptionToThrow = Exception('Unexpected failure');

          final result = await repository.sendCommand(tPayload);

          expect(result.isLeft(), isTrue);
          result.fold(
            (failure) => expect(failure, isA<UnexpectedFailure>()),
            (_) => fail('Expected Left'),
          );
        },
      );
    });
  });
}
