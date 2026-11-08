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

class MockMaintenanceRepository implements MaintenanceRepository {
  MaintenanceModel? lastCreated;
  MaintenanceModel? lastUpdated;

  @override
  Future<Either<Failure, List<MaintenanceModel>>> getMaintenances({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> createMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    lastCreated = maintenance.copyWith(id: 777);
    return Right(lastCreated!);
  }

  @override
  Future<Either<Failure, MaintenanceModel>> updateMaintenance(
    MaintenanceModel maintenance, {
    CancelToken? cancelToken,
  }) async {
    lastUpdated = maintenance;
    return Right(maintenance);
  }

  @override
  Future<Either<Failure, void>> deleteMaintenance(
    int id, {
    CancelToken? cancelToken,
  }) async {
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

  setUp(() {
    mockRepo = MockMaintenanceRepository();
    provider = MaintenanceProvider(repository: mockRepo);
  });

  Widget buildTestWidget({
    MaintenanceModel? initialMaintenance,
    double? currentTelemetry,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider<MaintenanceProvider>.value(
        value: provider,
        child: Scaffold(
          body: MaintenanceFormModal(
            initialMaintenance: initialMaintenance,
            currentTelemetryValue: currentTelemetry,
          ),
        ),
      ),
    );
  }

  group('MaintenanceFormModal Widget Tests', () {
    testWidgets(
      'TC-MFM-01: Renders all form inputs with proper labels and default values',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Tambah Jadwal Pemeliharaan'), findsOneWidget);
        expect(
          find.byKey(const Key('maintenance_form_name_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('maintenance_form_type_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('maintenance_form_start_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('maintenance_form_period_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('maintenance_form_submit_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-MFM-02: Validates empty name, negative start, and non-positive period',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Clear name and enter invalid values
        await tester.enterText(
          find.byKey(const Key('maintenance_form_name_field')),
          '',
        );
        await tester.enterText(
          find.byKey(const Key('maintenance_form_start_field')),
          '-5',
        );
        await tester.enterText(
          find.byKey(const Key('maintenance_form_period_field')),
          '0',
        );

        await tester.tap(
          find.byKey(const Key('maintenance_form_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nama jadwal tidak boleh kosong'), findsOneWidget);
        expect(find.text('Nilai awal harus angka >= 0'), findsOneWidget);
        expect(find.text('Interval servis harus angka > 0'), findsOneWidget);
        expect(mockRepo.lastCreated, isNull);
      },
    );

    testWidgets(
      'TC-MFM-03: Creates distance-based maintenance with km -> meters conversion',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('maintenance_form_name_field')),
          'Ganti Oli Mesin',
        );
        await tester.enterText(
          find.byKey(const Key('maintenance_form_start_field')),
          '10000', // 10,000 km
        );
        await tester.enterText(
          find.byKey(const Key('maintenance_form_period_field')),
          '5000', // 5,000 km
        );

        await tester.tap(
          find.byKey(const Key('maintenance_form_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(mockRepo.lastCreated, isNotNull);
        expect(mockRepo.lastCreated?.name, equals('Ganti Oli Mesin'));
        expect(mockRepo.lastCreated?.type, equals('totalDistance'));
        // 10,000 km converted to 10,000,000 meters
        expect(mockRepo.lastCreated?.start, equals(10000000.0));
        // 5,000 km converted to 5,000,000 meters
        expect(mockRepo.lastCreated?.period, equals(5000000.0));
      },
    );

    testWidgets(
      'TC-MFM-04: Pre-populates fields and converts meters -> km when editing',
      (tester) async {
        const existing = MaintenanceModel(
          id: 42,
          name: 'Rotasi Ban Depan',
          type: 'totalDistance',
          start: 20000000.0, // 20,000 km in meters
          period: 10000000.0, // 10,000 km in meters
        );

        await tester.pumpWidget(buildTestWidget(initialMaintenance: existing));
        await tester.pumpAndSettle();

        expect(find.text('Ubah Jadwal Pemeliharaan'), findsOneWidget);
        expect(find.text('Rotasi Ban Depan'), findsOneWidget);
        expect(find.text('20000'), findsOneWidget); // 20000 km
        expect(find.text('10000'), findsOneWidget); // 10000 km

        // Update name and submit
        await tester.enterText(
          find.byKey(const Key('maintenance_form_name_field')),
          'Rotasi 4 Roda',
        );
        await tester.tap(
          find.byKey(const Key('maintenance_form_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(mockRepo.lastUpdated, isNotNull);
        expect(mockRepo.lastUpdated?.id, equals(42));
        expect(mockRepo.lastUpdated?.name, equals('Rotasi 4 Roda'));
        expect(mockRepo.lastUpdated?.start, equals(20000000.0));
      },
    );

    testWidgets(
      'TC-MFM-05: Quick action button sets start value to current telemetry',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(currentTelemetry: 35000.0));
        await tester.pumpAndSettle();

        // Initial text should already take current telemetry (35000)
        expect(find.text('35000'), findsOneWidget);

        // Modify it, then tap quick action button
        await tester.enterText(
          find.byKey(const Key('maintenance_form_start_field')),
          '1234',
        );
        await tester.pumpAndSettle();
        expect(find.text('1234'), findsOneWidget);

        // Tap suffix quick action button
        await tester.tap(find.byTooltip('Reset / Gunakan Nilai Saat Ini'));
        await tester.pumpAndSettle();

        expect(find.text('35000'), findsOneWidget);
      },
    );
  });
}
