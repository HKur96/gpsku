import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/geofences/data/models/geofence_model.dart';
import 'package:gpsku/features/geofences/domain/repositories/geofences_repository.dart';
import 'package:gpsku/features/geofences/presentation/providers/geofences_provider.dart';
import 'package:gpsku/features/geofences/presentation/widgets/geofence_map_layer_toggle_button.dart';

class MockGeofencesRepository implements GeofencesRepository {
  @override
  Future<Either<Failure, List<GeofenceModel>>> getGeofences({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  }) async => const Right([]);

  @override
  Future<Either<Failure, GeofenceModel>> createGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async => Right(geofence);

  @override
  Future<Either<Failure, GeofenceModel>> updateGeofence(
    GeofenceModel geofence, {
    CancelToken? cancelToken,
  }) async => Right(geofence);

  @override
  Future<Either<Failure, void>> deleteGeofence(
    int id, {
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> linkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> unlinkDeviceGeofence({
    required int deviceId,
    required int geofenceId,
    CancelToken? cancelToken,
  }) async => const Right(null);
}

void main() {
  group('GeofenceMapLayerToggleButton Widget Tests', () {
    late GeofencesProvider provider;

    setUp(() {
      provider = GeofencesProvider(repository: MockGeofencesRepository());
    });

    Widget createTestApp({ValueChanged<bool>? onToggle}) {
      return ChangeNotifierProvider<GeofencesProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: GeofenceMapLayerToggleButton(onToggle: onToggle),
          ),
        ),
      );
    }

    testWidgets(
      'TC-GLT-01: Displays visible layer state initially and toggles on tap',
      (tester) async {
        bool? lastToggled;
        await tester.pumpWidget(
          createTestApp(onToggle: (v) => lastToggled = v),
        );

        expect(provider.isLayersVisible, isTrue);
        expect(find.byIcon(Icons.layers), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(provider.isLayersVisible, isFalse);
        expect(lastToggled, isFalse);
        expect(find.byIcon(Icons.layers_clear), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(provider.isLayersVisible, isTrue);
        expect(lastToggled, isTrue);
        expect(find.byIcon(Icons.layers), findsOneWidget);
      },
    );
  });
}
