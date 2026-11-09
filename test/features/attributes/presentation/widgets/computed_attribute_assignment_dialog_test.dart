import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/presentation/providers/computed_attributes_provider.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attribute_assignment_dialog.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import '../providers/computed_attributes_provider_test.dart';

class FakeWebSocketService extends Fake implements TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  WebSocketConnectionState get state => WebSocketConnectionState.connected;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
  }
}

void main() {
  late MockComputedAttributesRepository mockRepo;
  late ComputedAttributesProvider provider;
  late LiveFleetProvider liveFleetProvider;

  const tAttr = ComputedAttributeModel(
    id: 1,
    description: 'Baterai Rendah',
    attribute: 'batteryLow',
    expression: 'battery < 3.5',
    type: 'boolean',
  );

  const tDevice1 = DeviceModel(
    id: 101,
    name: 'Truk Tronton 01',
    uniqueId: 'TRK-001',
    status: 'online',
  );

  const tDevice2 = DeviceModel(
    id: 102,
    name: 'Truk Box 02',
    uniqueId: 'TRK-002',
    status: 'offline',
  );

  const tDevice3 = DeviceModel(
    id: 103,
    name: 'Mobil Operasional 03',
    uniqueId: 'OPS-003',
    status: 'online',
  );

  setUp(() {
    mockRepo = MockComputedAttributesRepository();
    // Device 101 initially has attribute 1 assigned
    mockRepo.mockDeviceAttributes = {
      101: [tAttr],
      102: [],
      103: [],
    };
    provider = ComputedAttributesProvider(repository: mockRepo);
    liveFleetProvider = LiveFleetProvider(
      webSocketService: FakeWebSocketService(),
    );
    liveFleetProvider.setInitialFleetData(
      initialDevices: [tDevice1, tDevice2, tDevice3],
      initialPositions: const [],
    );
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ComputedAttributesProvider>.value(
            value: provider,
          ),
          ChangeNotifierProvider<LiveFleetProvider>.value(
            value: liveFleetProvider,
          ),
        ],
        child: const Scaffold(
          body: ComputedAttributeAssignmentDialog(attribute: tAttr),
        ),
      ),
    );
  }

  group('ComputedAttributeAssignmentDialog Widget Tests', () {
    testWidgets(
      'TC-CAA-01: Renders device list and checks initially assigned device',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Tautkan Armada'), findsOneWidget);
        expect(find.text('Baterai Rendah'), findsOneWidget);
        expect(find.text('Truk Tronton 01'), findsOneWidget);
        expect(find.text('Truk Box 02'), findsOneWidget);
        expect(find.text('Mobil Operasional 03'), findsOneWidget);
        expect(find.text('1 dipilih'), findsOneWidget);
      },
    );

    testWidgets('TC-CAA-02: Searching filters visible devices in dialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Operasional');
      await tester.pumpAndSettle();

      expect(find.text('Mobil Operasional 03'), findsOneWidget);
      expect(find.text('Truk Tronton 01'), findsNothing);
      expect(find.text('Truk Box 02'), findsNothing);
    });

    testWidgets(
      'TC-CAA-03: Select all and clear all buttons update checked items',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap 'Pilih Semua'
        await tester.tap(find.byKey(const Key('select_all_devices_button')));
        await tester.pumpAndSettle();

        expect(find.text('3 dipilih'), findsOneWidget);

        // Tap 'Batal Semua'
        await tester.tap(find.byKey(const Key('clear_all_devices_button')));
        await tester.pumpAndSettle();

        expect(find.text('0 dipilih'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CAA-04: Saving diff calls link and unlink and dismisses dialog',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Initially 101 is selected. Uncheck 101 and check 102.
        await tester.tap(find.byKey(const Key('device_checkbox_101')));
        await tester.tap(find.byKey(const Key('device_checkbox_102')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('save_device_assignment_button')),
        );
        await tester.pumpAndSettle();

        // Verify unlinked 101 and linked 102
        expect(
          mockRepo.unlinkedHistory.any(
            (h) => h.deviceId == 101 && h.attributeId == 1,
          ),
          isTrue,
        );
        expect(
          mockRepo.linkedHistory.any(
            (h) => h.deviceId == 102 && h.attributeId == 1,
          ),
          isTrue,
        );
      },
    );

    testWidgets('TC-CAA-05: Cancelling dismisses dialog without changes', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('cancel_device_assignment_button')),
      );
      await tester.pumpAndSettle();

      expect(mockRepo.linkedHistory, isEmpty);
      expect(mockRepo.unlinkedHistory, isEmpty);
    });
  });
}
