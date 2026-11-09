import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_test_result_model.dart';
import 'package:gpsku/features/attributes/presentation/providers/computed_attributes_provider.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attribute_form_modal.dart';
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

  const tDevice = DeviceModel(
    id: 101,
    name: 'Truk Box Alpha',
    uniqueId: 'BOX-01',
    status: 'online',
  );

  const tAttr = ComputedAttributeModel(
    id: 1,
    description: 'Baterai Rendah',
    attribute: 'batteryLow',
    expression: 'battery < 3.5 ? true : false',
    type: 'boolean',
  );

  setUp(() {
    mockRepo = MockComputedAttributesRepository();
    provider = ComputedAttributesProvider(repository: mockRepo);
    liveFleetProvider = LiveFleetProvider(
      webSocketService: FakeWebSocketService(),
    );
    liveFleetProvider.setInitialFleetData(
      initialDevices: [tDevice],
      initialPositions: const [],
    );
  });

  Widget buildTestWidget({
    ComputedAttributeModel? initialAttribute,
    int? initialDeviceId,
  }) {
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
        child: Scaffold(
          body: ComputedAttributeFormModal(
            initialAttribute: initialAttribute,
            initialDeviceId: initialDeviceId,
          ),
        ),
      ),
    );
  }

  group('ComputedAttributeFormModal Widget Tests', () {
    testWidgets(
      'TC-CFM-01: Renders form fields, dropdowns, syntax chips, and runner',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Tambah Atribut Terhitung'), findsOneWidget);
        expect(
          find.byKey(const Key('attribute_description_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('attribute_target_key_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('attribute_type_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('attribute_expression_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('computed_attribute_save_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('attribute_test_formula_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('TC-CFM-02: Pre-fills existing attribute data in edit mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialAttribute: tAttr));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Atribut Terhitung'), findsOneWidget);
      expect(find.text('Baterai Rendah'), findsOneWidget);
      expect(find.text('batteryLow'), findsOneWidget);
      expect(find.text('battery < 3.5 ? true : false'), findsOneWidget);
    });

    testWidgets(
      'TC-CFM-03: Tapping syntax helper chip inserts token into expression field',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap syntax chip for 'speed'
        await tester.tap(find.byKey(const Key('syntax_chip_speed')));
        await tester.pumpAndSettle();

        final fieldFinder = find.byKey(const Key('attribute_expression_field'));
        final TextFormField field = tester.widget(fieldFinder);
        expect(field.controller?.text, 'speed');

        // Tap operator chip for ' > '
        await tester.tap(find.byKey(const Key('syntax_chip_>')));
        await tester.pumpAndSettle();

        expect(field.controller?.text, 'speed > ');
      },
    );

    testWidgets(
      'TC-CFM-04: Shows validation errors when saving with empty inputs',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('computed_attribute_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Deskripsi wajib diisi'), findsOneWidget);
        expect(find.text('Nama atribut wajib diisi'), findsOneWidget);
        expect(find.text('Ekspresi JEXL wajib diisi'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CFM-05: Live test runner executes expression and displays success card',
      (tester) async {
        mockRepo.testResultToReturn = ComputedAttributeTestResultModel.success(
          value: true,
          type: 'boolean',
        );

        await tester.pumpWidget(
          buildTestWidget(initialAttribute: tAttr, initialDeviceId: 101),
        );
        await tester.pumpAndSettle();

        // Scroll to test button and tap
        await tester.ensureVisible(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('test_result_success_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('test_result_success_card')),
          findsOneWidget,
        );
        expect(find.text('Evaluasi Berhasil'), findsOneWidget);
        expect(find.text('true'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CFM-06: Live test runner displays 204 No Content card when result is null',
      (tester) async {
        mockRepo.testResultToReturn =
            ComputedAttributeTestResultModel.noContent();

        await tester.pumpWidget(
          buildTestWidget(initialAttribute: tAttr, initialDeviceId: 101),
        );
        await tester.pumpAndSettle();

        // Scroll to test button and tap
        await tester.ensureVisible(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('test_result_no_content_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('test_result_no_content_card')),
          findsOneWidget,
        );
        expect(find.textContaining('204 No Content'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CFM-07: Live test runner displays failure error card on JEXL syntax exception',
      (tester) async {
        mockRepo.testResultToReturn = ComputedAttributeTestResultModel.failure(
          error: 'JexlException: variable not found in position',
        );

        await tester.pumpWidget(
          buildTestWidget(initialAttribute: tAttr, initialDeviceId: 101),
        );
        await tester.pumpAndSettle();

        // Scroll to test button and tap
        await tester.ensureVisible(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('attribute_test_formula_button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('test_result_failure_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('test_result_failure_card')),
          findsOneWidget,
        );
        expect(
          find.textContaining('JexlException: variable not found'),
          findsOneWidget,
        );
      },
    );

    testWidgets('TC-CFM-08: Submitting form saves attribute successfully', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('attribute_description_field')),
        'Overspeed Alert',
      );
      await tester.enterText(
        find.byKey(const Key('attribute_target_key_field')),
        'isOverspeed',
      );
      await tester.enterText(
        find.byKey(const Key('attribute_expression_field')),
        'speed > 80 ? true : false',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('computed_attribute_save_button')));
      await tester.pumpAndSettle();

      expect(
        mockRepo.mockAttributes.any((a) => a.attribute == 'isOverspeed'),
        isTrue,
      );
    });
  });
}
