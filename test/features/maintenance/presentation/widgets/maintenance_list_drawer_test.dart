import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/maintenance/data/models/maintenance_model.dart';
import 'package:gpsku/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:gpsku/features/maintenance/presentation/providers/maintenance_provider.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_form_modal.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_list_drawer.dart';
import 'package:gpsku/features/maintenance/presentation/widgets/maintenance_list_item.dart';

class MockMaintenanceRepository implements MaintenanceRepository {
  List<MaintenanceModel> mockMaintenances = [];
  Failure? failureToReturn;
  int? lastDeletedId;

  @override
  Future<Either<Failure, List<MaintenanceModel>>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockMaintenances);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    final created = maintenance.copyWith(id: 99);
    mockMaintenances.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(maintenance);
  }

  @override
  Future<Either<Failure, void>> deleteMaintenance(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    mockMaintenances.removeWhere((m) => m.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceMaintenance({
    required int deviceId,
    required int maintenanceId,
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }
}

void main() {
  late MockMaintenanceRepository mockRepo;
  late MaintenanceProvider provider;

  const tItem1 = MaintenanceModel(
    id: 1,
    name: 'Ganti Oli Mesin',
    type: 'totalDistance',
    start: 10000000.0,
    period: 5000000.0,
  );

  const tItem2 = MaintenanceModel(
    id: 2,
    name: 'Servis Berkala 250 Jam',
    type: 'hours',
    start: 360000000.0,
    period: 180000000.0,
  );

  setUp(() {
    mockRepo = MockMaintenanceRepository();
    mockRepo.mockMaintenances = [tItem1, tItem2];
    provider = MaintenanceProvider(repository: mockRepo);
  });

  Widget buildTestWidget({
    void Function(MaintenanceModel)? onSelected,
    VoidCallback? onClose,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider<MaintenanceProvider>.value(
        value: provider,
        child: Scaffold(
          body: MaintenanceListDrawer(
            onMaintenanceSelected: onSelected,
            onClosePressed: onClose,
          ),
        ),
      ),
    );
  }

  group('MaintenanceListDrawer Widget Tests', () {
    testWidgets(
      'TC-MLD-01: Renders drawer with header, search bar, filter chips, and add button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Jadwal Pemeliharaan'), findsOneWidget);
        expect(
          find.byKey(const Key('maintenance_drawer_search_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('maintenance_drawer_add_button')),
          findsOneWidget,
        );

        // Filter chips
        expect(find.widgetWithText(FilterChip, 'Semua'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Jatuh Tempo'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Mendekati'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Normal'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MLD-02: Displays maintenance items with info sisa and type icon',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Ganti Oli Mesin'), findsOneWidget);
        expect(find.text('Jarak Tempuh'), findsOneWidget);
        expect(find.text('Servis Berkala 250 Jam'), findsOneWidget);
        expect(find.text('Jam Mesin'), findsOneWidget);

        // Progress info
        expect(find.text('Sisa 5000 km'), findsOneWidget);
        expect(find.text('Sisa 50 jam'), findsOneWidget);
        expect(find.byType(MaintenanceListItem), findsNWidgets(2));
      },
    );

    testWidgets('TC-MLD-03: Debounced search bar filters the items by name', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('maintenance_drawer_search_field')),
        'oli',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Ganti Oli Mesin'), findsOneWidget);
      expect(find.text('Servis Berkala 250 Jam'), findsNothing);

      // Clear query
      await tester.enterText(
        find.byKey(const Key('maintenance_drawer_search_field')),
        '',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Ganti Oli Mesin'), findsOneWidget);
      expect(find.text('Servis Berkala 250 Jam'), findsOneWidget);
    });

    testWidgets(
      'TC-MLD-04: Tapping item triggers onMaintenanceSelected callback',
      (tester) async {
        MaintenanceModel? selected;
        await tester.pumpWidget(
          buildTestWidget(
            onSelected: (m) {
              selected = m;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ganti Oli Mesin'));
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected?.id, equals(1));
      },
    );

    testWidgets('TC-MLD-05: Tapping Add button opens MaintenanceFormModal', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('maintenance_drawer_add_button')));
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceFormModal), findsOneWidget);
      expect(find.text('Tambah Jadwal Pemeliharaan'), findsOneWidget);
    });

    testWidgets(
      'TC-MLD-06: Deleting item displays confirmation dialog and deletes on confirm',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap more options menu on item 1
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();

        // Tap 'Hapus'
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Alert dialog appears
        expect(find.text('Hapus Jadwal Pemeliharaan'), findsOneWidget);

        // Tap 'Hapus' inside AlertDialog
        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(mockRepo.lastDeletedId, equals(1));
        expect(find.text('Ganti Oli Mesin'), findsNothing);
      },
    );

    testWidgets('TC-MLD-07: Displays empty state message when list is empty', (
      tester,
    ) async {
      mockRepo.mockMaintenances = [];
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada jadwal pemeliharaan'), findsOneWidget);
    });

    testWidgets(
      'TC-MLD-08: Displays error message and retry button when fetch fails',
      (tester) async {
        mockRepo.mockMaintenances = [];
        mockRepo.failureToReturn = const ServerFailure('Server error 500');

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Server error 500'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Coba Lagi'), findsOneWidget);

        // Recovery
        mockRepo.failureToReturn = null;
        mockRepo.mockMaintenances = [tItem1];
        await tester.tap(find.widgetWithText(FilledButton, 'Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.text('Ganti Oli Mesin'), findsOneWidget);
      },
    );
  });
}
