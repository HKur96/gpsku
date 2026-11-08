import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/commands/data/models/command_payload_model.dart';
import 'package:gpsku/features/commands/data/models/command_type_model.dart';
import 'package:gpsku/features/commands/domain/repositories/commands_repository.dart';
import 'package:gpsku/features/commands/presentation/widgets/command_bottom_sheet.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';

class MockCommandsRepository implements CommandsRepository {
  List<CommandTypeModel> mockTypes = [];
  CommandPayloadModel? mockSendResult;
  Failure? getTypesFailure;
  Failure? sendFailure;
  CommandPayloadModel? lastSentPayload;

  @override
  Future<Either<Failure, List<CommandTypeModel>>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  }) async {
    if (getTypesFailure != null) return Left(getTypesFailure!);
    return Right(mockTypes);
  }

  @override
  Future<Either<Failure, CommandPayloadModel>> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  }) async {
    lastSentPayload = payload;
    if (sendFailure != null) return Left(sendFailure!);
    return Right(mockSendResult ?? payload);
  }
}

void main() {
  group('CommandBottomSheet Widget Tests', () {
    late MockCommandsRepository mockRepo;

    final sampleDevice = DeviceModel(
      id: 42,
      name: 'Avanza Operasional',
      uniqueId: 'B 1234 CD',
      status: 'online',
      model: 'Toyota Avanza 1.5',
    );

    final movingPosition = PositionModel(
      id: 1,
      deviceId: 42,
      serverTime: DateTime.utc(2026, 11, 8, 10, 0, 0),
      deviceTime: DateTime.utc(2026, 11, 8, 10, 0, 0),
      fixTime: DateTime.utc(2026, 11, 8, 10, 0, 0),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 15.0, // 15 knots * 1.852 = 27.78 km/h (> 20 km/h)
      attributes: const {'ignition': true},
    );

    final stationaryPosition = PositionModel(
      id: 2,
      deviceId: 42,
      serverTime: DateTime.utc(2026, 11, 8, 10, 0, 0),
      deviceTime: DateTime.utc(2026, 11, 8, 10, 0, 0),
      fixTime: DateTime.utc(2026, 11, 8, 10, 0, 0),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 5.0, // 5 knots * 1.852 = 9.26 km/h (<= 20 km/h)
      attributes: const {'ignition': true},
    );

    setUp(() {
      mockRepo = MockCommandsRepository();
      mockRepo.mockTypes = [
        const CommandTypeModel(type: 'engineStop'),
        const CommandTypeModel(type: 'engineResume'),
        const CommandTypeModel(type: 'custom'),
        const CommandTypeModel(type: 'positionPeriodic'),
      ];
    });

    Widget buildSheet({PositionModel? position}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_sheet_button'),
                onPressed: () {
                  CommandBottomSheet.show(
                    context,
                    device: sampleDevice,
                    position: position,
                    commandsRepository: mockRepo,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
    }

    testWidgets(
      'TC-CBS-01: Opens sheet, displays device header, and loads supported commands',
      (tester) async {
        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(find.text('Avanza Operasional'), findsOneWidget);
        expect(find.text('B 1234 CD • Toyota Avanza 1.5'), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);
        expect(find.byKey(const Key('command_type_dropdown')), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CBS-02: Selecting engineStop displays warning and slide-to-confirm',
      (tester) async {
        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Mematikan mesin akan memutus aliran bahan bakar',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('command_slide_to_confirm')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-CBS-03: Speed interlock activates when speed > 20 km/h and unlocks only after checkbox is checked',
      (tester) async {
        await tester.pumpWidget(buildSheet(position: movingPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        // Warning banner and checkbox must be visible
        expect(
          find.byKey(const Key('speed_interlock_warning')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Kendaraan Melaju: 27.8 km/h'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('speed_interlock_checkbox')),
          findsOneWidget,
        );

        // Slide-to-confirm should be disabled initially
        expect(find.text('Terkunci / Nonaktif'), findsOneWidget);

        // Check the safety acknowledgement checkbox
        await tester.tap(find.byKey(const Key('speed_interlock_checkbox')));
        await tester.pumpAndSettle();

        // Slide-to-confirm should now be enabled
        expect(find.text('Geser untuk Matikan Mesin'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CBS-04: Speed interlock does NOT activate when speed <= 20 km/h',
      (tester) async {
        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('speed_interlock_warning')), findsNothing);
        expect(find.byKey(const Key('speed_interlock_checkbox')), findsNothing);
        expect(find.text('Geser untuk Matikan Mesin'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CBS-05: Slide-to-confirm on engineStop triggers sendCommand and displays success snackbar',
      (tester) async {
        mockRepo.mockSendResult = CommandPayloadModel(
          deviceId: 42,
          type: 'engineStop',
          isQueued: false,
        );

        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(500, 0));
        await tester.pumpAndSettle();

        expect(mockRepo.lastSentPayload?.deviceId, equals(42));
        expect(mockRepo.lastSentPayload?.type, equals('engineStop'));
        expect(
          find.byKey(const Key('command_success_snackbar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-CBS-06: Displays queued snackbar when response returns isQueued=true',
      (tester) async {
        mockRepo.mockSendResult = CommandPayloadModel(
          deviceId: 42,
          type: 'engineStop',
          isQueued: true,
        );

        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(500, 0));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('command_queued_snackbar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-CBS-07: Displays error banner inside sheet on ForbiddenFailure',
      (tester) async {
        mockRepo.sendFailure = const ForbiddenFailure(
          'Akses ditolak',
          statusCode: 403,
        );

        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(500, 0));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('command_error_banner')), findsOneWidget);
        expect(find.textContaining('Akses ditolak'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CBS-08: Custom command input validates empty payload and dispatches with data attribute',
      (tester) async {
        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        // Switch dropdown to custom
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Perintah Kustom (Protokol)').last);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('custom_command_input')), findsOneWidget);
        expect(find.byKey(const Key('command_send_button')), findsOneWidget);

        // Submit without typing -> validation error
        await tester.tap(find.byKey(const Key('command_send_button')));
        await tester.pumpAndSettle();
        expect(
          find.text('Payload perintah kustom tidak boleh kosong'),
          findsOneWidget,
        );

        // Type command payload
        await tester.enterText(
          find.byKey(const Key('custom_command_input')),
          'RELAY,1#',
        );
        await tester.tap(find.byKey(const Key('command_send_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.lastSentPayload?.type, equals('custom'));
        expect(
          mockRepo.lastSentPayload?.attributes['data'],
          equals('RELAY,1#'),
        );
      },
    );

    testWidgets(
      'TC-CBS-09: Periodic position reporting sends frequency parameter',
      (tester) async {
        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        // Switch to positionPeriodic
        await tester.tap(find.byKey(const Key('command_type_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set Periode Pelaporan').last);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('frequency_command_input')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('frequency_command_input')),
          '30',
        );
        await tester.tap(find.byKey(const Key('command_send_button')));
        await tester.pumpAndSettle();

        expect(mockRepo.lastSentPayload?.type, equals('positionPeriodic'));
        expect(mockRepo.lastSentPayload?.attributes['frequency'], equals(30));
      },
    );

    testWidgets(
      'TC-CBS-10: Shows error state and retry button when loading command types fails',
      (tester) async {
        mockRepo.getTypesFailure = const ServerFailure('Gagal memuat tipe');

        await tester.pumpWidget(buildSheet(position: stationaryPosition));

        await tester.tap(find.byKey(const Key('open_sheet_button')));
        await tester.pumpAndSettle();

        expect(find.text('Gagal memuat tipe'), findsOneWidget);
        expect(
          find.byKey(const Key('command_sheet_retry_button')),
          findsOneWidget,
        );

        // Retry succeeds
        mockRepo.getTypesFailure = null;
        mockRepo.mockTypes = [const CommandTypeModel(type: 'engineStop')];
        await tester.tap(find.byKey(const Key('command_sheet_retry_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('command_type_dropdown')), findsOneWidget);
      },
    );
  });
}
