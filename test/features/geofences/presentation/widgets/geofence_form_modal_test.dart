import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/repositories/geofences_repository.dart';
import 'package:gpsku/features/geofences/presentation/providers/geofences_provider.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_form_modal.dart';

class MockGeofencesRepository implements GeofencesRepository {
  GeofenceModel? lastCreatedGeofence;
  GeofenceModel? lastUpdatedGeofence;
  Failure? failureToReturn;

  @override
  Future<Either<Failure, List<GeofenceModel>>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    lastCreatedGeofence = geofence;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(geofence.copyWith(id: 101));
  }

  @override
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    lastUpdatedGeofence = geofence;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(geofence);
  }

  @override
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    return const Right(null);
  }
}

void main() {
  group('GeofenceFormModal Widget Tests', () {
    late MockGeofencesRepository mockRepository;
    late GeofencesProvider geofencesProvider;

    setUp(() {
      mockRepository = MockGeofencesRepository();
      geofencesProvider = GeofencesProvider(repository: mockRepository);
    });

    Widget createTestApp({GeofenceModel? geofence}) {
      return ChangeNotifierProvider<GeofencesProvider>.value(
        value: geofencesProvider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    GeofenceFormModal.show(ctx, geofence: geofence),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('TC-GFM-01: Renders form fields for new Circle geofence', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Geofence Baru'), findsOneWidget);
      expect(find.text('Tipe Geometri'), findsOneWidget);
      expect(find.text('Lingkaran'), findsOneWidget);
      expect(find.text('Poligon'), findsOneWidget);
      expect(find.text('Rute'), findsOneWidget);

      // Required text field
      expect(
        find.widgetWithText(TextFormField, 'Nama Geofence *'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Radius (meter) *'),
        findsOneWidget,
      );
      expect(find.text('Simpan Geofence'), findsOneWidget);
    });

    testWidgets(
      'TC-GFM-02: Switching to Polygon reveals WKT Polygon input field',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Poligon'));
        await tester.pumpAndSettle();

        expect(find.text('Perimeter Poligon (WKT)'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Koordinat Simpul WKT POLYGON *'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-GFM-03: Switching to Linestring reveals WKT Linestring and corridor distance fields',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rute'));
        await tester.pumpAndSettle();

        expect(find.text('Parameter Rute Koridor'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Lebar Koridor Penyangga (meter)'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, 'WKT LINESTRING *'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-GFM-04: Validates required name field and prevents submission when empty',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Clear name field
        final nameField = find.widgetWithText(TextFormField, 'Nama Geofence *');
        await tester.enterText(nameField, '');

        // Tap submit
        await tester.ensureVisible(find.text('Simpan Geofence'));
        await tester.tap(find.text('Simpan Geofence'));
        await tester.pumpAndSettle();

        expect(find.text('Nama geofence wajib diisi'), findsOneWidget);
        expect(mockRepository.lastCreatedGeofence, isNull);
      },
    );

    testWidgets('TC-GFM-05: Validates circle radius must be > 0', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, 'Nama Geofence *');
      await tester.enterText(nameField, 'Valid Area');

      final radiusField = find.widgetWithText(
        TextFormField,
        'Radius (meter) *',
      );
      await tester.enterText(radiusField, '-10');

      await tester.ensureVisible(find.text('Simpan Geofence'));
      await tester.tap(find.text('Simpan Geofence'));
      await tester.pumpAndSettle();

      expect(find.text('Radius harus > 0'), findsOneWidget);
      expect(mockRepository.lastCreatedGeofence, isNull);
    });

    testWidgets('TC-GFM-06: Pre-fills existing geofence fields when editing', (
      tester,
    ) async {
      const existingGeofence = GeofenceModel(
        id: 42,
        name: 'Zona Bongkar Muat',
        description: 'Docking bay 3',
        area: 'CIRCLE (-6.1500 106.8500, 850.0)',
        attributes: {'color': '#4CAF50', 'speedLimit': 25.0},
      );

      await tester.pumpWidget(createTestApp(geofence: existingGeofence));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Geofence'), findsOneWidget);
      expect(find.text('Zona Bongkar Muat'), findsOneWidget);
      expect(find.text('Docking bay 3'), findsOneWidget);
      expect(find.text('850'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets(
      'TC-GFM-07: Submits valid form and creates geofence via provider',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestApp());
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Fill Name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Geofence *'),
          'Pabrik Karawang',
        );

        // Fill Speed Limit
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Batas Kecepatan Maksimum (Opsional)',
          ),
          '50',
        );

        // Tap submit
        await tester.ensureVisible(find.text('Simpan Geofence'));
        await tester.tap(find.text('Simpan Geofence'));
        await tester.pumpAndSettle();

        expect(mockRepository.lastCreatedGeofence, isNotNull);
        expect(
          mockRepository.lastCreatedGeofence!.name,
          equals('Pabrik Karawang'),
        );
        expect(mockRepository.lastCreatedGeofence!.speedLimit, equals(50.0));
        expect(mockRepository.lastCreatedGeofence!.isCircle, isTrue);
      },
    );

    testWidgets(
      'TC-GFM-08: Submits valid form and updates existing geofence via provider',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const existingGeofence = GeofenceModel(
          id: 55,
          name: 'Old Name',
          area: 'CIRCLE (-6.20 106.80, 400.0)',
          attributes: {'color': '#1E88E5'},
        );

        await tester.pumpWidget(createTestApp(geofence: existingGeofence));
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Geofence *'),
          'New Updated Name',
        );

        await tester.ensureVisible(find.text('Simpan Geofence'));
        await tester.tap(find.text('Simpan Geofence'));
        await tester.pumpAndSettle();

        expect(mockRepository.lastUpdatedGeofence, isNotNull);
        expect(mockRepository.lastUpdatedGeofence!.id, equals(55));
        expect(
          mockRepository.lastUpdatedGeofence!.name,
          equals('New Updated Name'),
        );
      },
    );
  });
}
