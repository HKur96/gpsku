import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/repositories/geofences_repository.dart';
import 'package:gpsku/features/geofences/presentation/providers/geofences_provider.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_list_drawer.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_list_item.dart';

class MockGeofencesRepository implements GeofencesRepository {
  List<GeofenceModel> mockGeofences = [];
  int? lastDeletedId;
  Failure? failureToReturn;

  @override
  Future<Either<Failure, List<GeofenceModel>>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(mockGeofences);
  }

  @override
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(geofence.copyWith(id: 99));
  }

  @override
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(geofence);
  }

  @override
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  }) async {
    lastDeletedId = id;
    if (failureToReturn != null) return Left(failureToReturn!);
    mockGeofences.removeWhere((g) => g.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return const Right(null);
  }
}

void main() {
  group('GeofenceListDrawer Widget Tests', () {
    late MockGeofencesRepository mockRepository;
    late GeofencesProvider geofencesProvider;

    final testGeofences = [
      const GeofenceModel(
        id: 1,
        name: 'Gudang Pusat Cakung',
        description: 'Logistics hub perimeter',
        area: 'CIRCLE (-6.2088 106.8456, 1200.0)',
        attributes: {'color': '#1E88E5', 'speedLimit': 30.0},
      ),
      const GeofenceModel(
        id: 2,
        name: 'Pelabuhan Tanjung Priok',
        description: 'Restricted customs zone',
        area:
            'POLYGON ((-6.10 106.88, -6.11 106.89, -6.12 106.87, -6.10 106.88))',
        attributes: {'color': '#4CAF50'},
      ),
      const GeofenceModel(
        id: 3,
        name: 'Tol Jakarta Cikampek',
        area: 'LINESTRING (-6.20 106.81, -6.21 106.82, -6.22 106.83)',
        attributes: {'color': '#E53935', 'polylineDistance': 50.0},
      ),
    ];

    setUp(() {
      mockRepository = MockGeofencesRepository();
      mockRepository.mockGeofences = List.from(testGeofences);
      geofencesProvider = GeofencesProvider(repository: mockRepository);
    });

    Widget createTestApp({
      void Function(GeofenceModel)? onGeofenceSelected,
      VoidCallback? onClosePressed,
    }) {
      return ChangeNotifierProvider<GeofencesProvider>.value(
        value: geofencesProvider,
        child: MaterialApp(
          home: Scaffold(
            body: GeofenceListDrawer(
              onGeofenceSelected: onGeofenceSelected,
              onClosePressed: onClosePressed,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'TC-GLD-01: Renders header, counter badge, search field, add button, and filter chips',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Daftar Geofence'), findsOneWidget);
        expect(find.text('3 / 3'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);

        expect(find.widgetWithText(FilterChip, 'Semua'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Poligon'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Lingkaran'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Rute'), findsOneWidget);
      },
    );

    testWidgets('TC-GLD-02: Displays geofence items with metadata and badges', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(GeofenceListItem), findsNWidgets(3));
      expect(find.text('Gudang Pusat Cakung'), findsOneWidget);
      expect(find.text('Pelabuhan Tanjung Priok'), findsOneWidget);
      expect(find.text('Tol Jakarta Cikampek'), findsOneWidget);

      // Verify speed limit badge
      expect(find.text('30 km/j'), findsOneWidget);

      // Verify radius badge
      expect(find.text('r = 1200 m'), findsOneWidget);
    });

    testWidgets('TC-GLD-03: Filters geofence list by geometry filter chip', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap "Lingkaran" filter chip
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Lingkaran'));
      await tester.tap(find.widgetWithText(FilterChip, 'Lingkaran'));
      await tester.pumpAndSettle();

      expect(find.byType(GeofenceListItem), findsOneWidget);
      expect(find.text('Gudang Pusat Cakung'), findsOneWidget);
      expect(find.text('Pelabuhan Tanjung Priok'), findsNothing);

      // Tap "Poligon" filter chip
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Poligon'));
      await tester.tap(find.widgetWithText(FilterChip, 'Poligon'));
      await tester.pumpAndSettle();

      expect(find.byType(GeofenceListItem), findsOneWidget);
      expect(find.text('Pelabuhan Tanjung Priok'), findsOneWidget);
      expect(find.text('Gudang Pusat Cakung'), findsNothing);

      // Tap "Semua" to restore
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Semua'));
      await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
      await tester.pumpAndSettle();

      expect(find.byType(GeofenceListItem), findsNWidgets(3));
    });

    testWidgets(
      'TC-GLD-04: Filters geofence list by search query with 200ms debouncing',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'priok');
        // Before 200ms debounce fires:
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(GeofenceListItem), findsNWidgets(3));

        // After 200ms debounce completes:
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.byType(GeofenceListItem), findsOneWidget);
        expect(find.text('Pelabuhan Tanjung Priok'), findsOneWidget);
        expect(find.text('Gudang Pusat Cakung'), findsNothing);
      },
    );

    testWidgets(
      'TC-GLD-05: Tapping item triggers onGeofenceSelected callback',
      (tester) async {
        GeofenceModel? selected;
        await tester.pumpWidget(
          createTestApp(onGeofenceSelected: (g) => selected = g),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Gudang Pusat Cakung'));
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected!.id, equals(1));
        expect(geofencesProvider.selectedGeofence?.id, equals(1));
      },
    );

    testWidgets(
      'TC-GLD-06: Delete action shows confirmation dialog and removes geofence on confirm',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Tap more options on first item
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();

        // Tap 'Hapus'
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Dialog should be displayed
        expect(find.text('Hapus Geofence'), findsOneWidget);

        // Tap 'Hapus' inside AlertDialog
        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(mockRepository.lastDeletedId, equals(1));
        expect(find.text('Gudang Pusat Cakung'), findsNothing);
        expect(find.byType(GeofenceListItem), findsNWidgets(2));
      },
    );

    testWidgets(
      'TC-GLD-07: Shows empty state when no geofences match search filter',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'non_existent_area');
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.byType(GeofenceListItem), findsNothing);
        expect(
          find.text('Tidak ada geofence sesuai pencarian'),
          findsOneWidget,
        );
      },
    );
  });
}
