import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/presentation/providers/computed_attributes_provider.dart';
import 'package:gpsku/features/attributes/presentation/widgets/computed_attributes_drawer.dart';
import '../providers/computed_attributes_provider_test.dart';

void main() {
  late MockComputedAttributesRepository mockRepo;
  late ComputedAttributesProvider provider;

  const tAttr1 = ComputedAttributeModel(
    id: 1,
    description: 'Baterai Rendah',
    attribute: 'batteryLow',
    expression: 'battery < 3.5 ? true : false',
    type: 'boolean',
  );

  const tAttr2 = ComputedAttributeModel(
    id: 2,
    description: 'Konsumsi Bahan Bakar',
    attribute: 'fuelRate',
    expression: 'speed > 60 ? (speed * 0.1) : 0',
    type: 'number',
  );

  setUp(() {
    mockRepo = MockComputedAttributesRepository();
    provider = ComputedAttributesProvider(repository: mockRepo);
  });

  Widget buildTestWidget({void Function(ComputedAttributeModel)? onSelect}) {
    return MaterialApp(
      home: ChangeNotifierProvider<ComputedAttributesProvider>.value(
        value: provider,
        child: Scaffold(
          body: ComputedAttributesDrawer(onAttributeSelected: onSelect),
        ),
      ),
    );
  }

  group('ComputedAttributesDrawer Widget Tests', () {
    testWidgets(
      'TC-CAD-01: Renders header, formula count, search field, and type filter chips',
      (tester) async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Atribut Sensor Terhitung'), findsOneWidget);
        expect(find.text('2 formula JEXL terdaftar'), findsOneWidget);
        expect(
          find.byKey(const Key('computed_attributes_search_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('computed_attributes_add_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('type_filter_chip_all')), findsOneWidget);
        expect(
          find.byKey(const Key('type_filter_chip_number')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('type_filter_chip_string')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('type_filter_chip_boolean')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-CAD-02: Displays computed attribute cards with description and target keys',
      (tester) async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Baterai Rendah'), findsOneWidget);
        expect(find.text('batteryLow'), findsOneWidget);
        expect(find.text('BOOLEAN'), findsOneWidget);

        expect(find.text('Konsumsi Bahan Bakar'), findsOneWidget);
        expect(find.text('fuelRate'), findsOneWidget);
        expect(find.text('NUMBER'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CAD-03: Searching text filters attribute list dynamically',
      (tester) async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('computed_attributes_search_field')),
          'bahan bakar',
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.text('Konsumsi Bahan Bakar'), findsOneWidget);
        expect(find.text('Baterai Rendah'), findsNothing);
      },
    );

    testWidgets(
      'TC-CAD-04: Tapping type filter chip updates list according to return type',
      (tester) async {
        mockRepo.mockAttributes = [tAttr1, tAttr2];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap 'Boolean (boolean)'
        await tester.tap(find.byKey(const Key('type_filter_chip_boolean')));
        await tester.pumpAndSettle();

        expect(find.text('Baterai Rendah'), findsOneWidget);
        expect(find.text('Konsumsi Bahan Bakar'), findsNothing);

        // Tap 'Angka (number)'
        await tester.tap(find.byKey(const Key('type_filter_chip_number')));
        await tester.pumpAndSettle();

        expect(find.text('Konsumsi Bahan Bakar'), findsOneWidget);
        expect(find.text('Baterai Rendah'), findsNothing);
      },
    );

    testWidgets(
      'TC-CAD-05: Tapping item triggers onAttributeSelected callback',
      (tester) async {
        mockRepo.mockAttributes = [tAttr1];
        ComputedAttributeModel? selected;

        await tester.pumpWidget(
          buildTestWidget(onSelect: (attr) => selected = attr),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Baterai Rendah'));
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected?.id, 1);
        expect(provider.selectedAttribute?.id, 1);
      },
    );

    testWidgets('TC-CAD-06: Delete confirmation dialog cancels on Batal', (
      tester,
    ) async {
      mockRepo.mockAttributes = [tAttr1];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open action menu
      await tester.tap(find.byKey(const Key('attribute_action_menu_1')));
      await tester.pumpAndSettle();

      // Tap 'Hapus'
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Atribut Terhitung'), findsOneWidget);

      // Tap 'Batal'
      await tester.tap(find.byKey(const Key('attribute_delete_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Atribut Terhitung'), findsNothing);
      expect(provider.attributes.length, 1);
    });

    testWidgets(
      'TC-CAD-07: Delete confirmation dialog confirms and deletes attribute',
      (tester) async {
        mockRepo.mockAttributes = [tAttr1];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Open action menu
        await tester.tap(find.byKey(const Key('attribute_action_menu_1')));
        await tester.pumpAndSettle();

        // Tap 'Hapus'
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Confirm delete
        await tester.tap(
          find.byKey(const Key('attribute_delete_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(mockRepo.lastDeletedId, 1);
        expect(provider.attributes, isEmpty);
      },
    );

    testWidgets(
      'TC-CAD-08: Empty state renders clean message when no attributes exist',
      (tester) async {
        mockRepo.mockAttributes = [];

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.text('Belum ada atribut sensor terhitung.'),
          findsOneWidget,
        );
      },
    );
  });
}
