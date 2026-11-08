import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';
import 'package:gpsku/features/reports/domain/repositories/reports_repository.dart';
import 'package:gpsku/features/reports/presentation/map/map_route_controller.dart';
import 'package:gpsku/features/reports/presentation/map/route_geojson_builder.dart';
import 'package:gpsku/features/reports/presentation/screens/route_history_screen.dart';
import 'package:gpsku/features/reports/presentation/widgets/playback/route_playback_sheet.dart';
import 'package:gpsku/features/reports/presentation/widgets/sheet/route_summary_panel.dart';

class MockReportsRepository implements ReportsRepository {
  List<PositionModel> mockPositions = [];
  List<TripReportModel> mockTrips = [];
  List<StopReportModel> mockStops = [];
  Failure? failureToReturn;

  int routeCallCount = 0;
  int tripCallCount = 0;
  int stopCallCount = 0;

  @override
  Future<Either<Failure, List<PositionModel>>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    routeCallCount++;
    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(mockPositions);
  }

  @override
  Future<Either<Failure, List<TripReportModel>>> getTripReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    tripCallCount++;
    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(mockTrips);
  }

  @override
  Future<Either<Failure, List<StopReportModel>>> getStopReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    stopCallCount++;
    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }
    return Right(mockStops);
  }
}

class TestMapRouteController implements MapRouteController {
  final List<String> operationLog = [];
  final Map<String, dynamic> sources = {};
  final Map<String, LineLayerProperties> layers = {};
  final List<Symbol> symbols = [];
  final List<void Function(Symbol)> tapListeners = [];
  CameraUpdate? lastCameraUpdate;
  int _counter = 1;

  @override
  bool isDisposed = false;

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    operationLog.add('addGeoJsonSource:$sourceId');
    sources[sourceId] = geojson;
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    operationLog.add('setGeoJsonSource:$sourceId');
    sources[sourceId] = geojson;
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = true,
  }) async {
    operationLog.add('addLineLayer:$layerId');
    layers[layerId] = properties;
  }

  @override
  Future<void> removeLayer(String layerId) async {
    operationLog.add('removeLayer:$layerId');
    layers.remove(layerId);
  }

  @override
  Future<void> removeSource(String sourceId) async {
    operationLog.add('removeSource:$sourceId');
    sources.remove(sourceId);
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool defer = false,
    double pixelRatio = 1.0,
  ]) async {
    operationLog.add('addImage:$name');
  }

  @override
  Future<Symbol> addSymbol(
    SymbolOptions options, [
    Map<String, dynamic>? data,
  ]) async {
    final sym = Symbol('sym_${_counter++}', options, data);
    symbols.add(sym);
    operationLog.add('addSymbol:${options.iconImage}');
    return sym;
  }

  @override
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) async {
    operationLog.add('updateSymbol:${symbol.id}');
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    symbols.remove(symbol);
    operationLog.add('removeSymbol:${symbol.id}');
  }

  @override
  Future<void> removeSymbols(Iterable<Symbol> syms) async {
    final ids = syms.map((s) => s.id).toSet();
    symbols.removeWhere((s) => ids.contains(s.id));
    operationLog.add('removeSymbols:${ids.length}');
  }

  @override
  Future<void> clearSymbols() async {
    symbols.clear();
    operationLog.add('clearSymbols');
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    lastCameraUpdate = cameraUpdate;
    operationLog.add('animateCamera');
    return true;
  }

  @override
  void addSymbolTappedListener(void Function(Symbol symbol) listener) {
    tapListeners.add(listener);
  }

  @override
  void removeSymbolTappedListener(void Function(Symbol symbol) listener) {
    tapListeners.remove(listener);
  }
}

void main() {
  group('Phase 7.5 Route History Consolidation End-to-End Regression Tests', () {
    final tTime = DateTime.parse('2026-11-08T08:00:00.000Z');

    final tDevice = const DeviceModel(
      id: 77,
      name: 'Isuzu Giga Heavy Truck B 9999 XYZ',
      uniqueId: 'IMEI-99998888',
      status: 'online',
      lastUpdate: null,
      positionId: 101,
      groupId: null,
      phone: null,
      model: 'Giga FVR',
      contact: null,
      category: 'truck',
      disabled: false,
    );

    final tPosition = PositionModel(
      id: 101,
      deviceId: 77,
      serverTime: tTime,
      fixTime: tTime,
      latitude: -6.1754,
      longitude: 106.8272,
      speed: 15.0,
      course: 180.0,
      attributes: const {'ignition': true, 'batteryLevel': 95},
    );

    final tRoutePositions = [
      PositionModel(
        id: 101,
        deviceId: 77,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.1754,
        longitude: 106.8272,
        speed: 15.0,
        course: 180.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 102,
        deviceId: 77,
        serverTime: tTime.add(const Duration(minutes: 10)),
        fixTime: tTime.add(const Duration(minutes: 10)),
        latitude: -6.1900,
        longitude: 106.8350,
        speed: 25.0,
        course: 160.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 103,
        deviceId: 77,
        serverTime: tTime.add(const Duration(minutes: 20)),
        fixTime: tTime.add(const Duration(minutes: 20)),
        latitude: -6.2088,
        longitude: 106.8456,
        speed: 0.0,
        course: 0.0,
        attributes: const {'ignition': false},
      ),
    ];

    final tTrips = [
      TripReportModel(
        deviceId: 77,
        deviceName: 'Isuzu Giga Heavy Truck B 9999 XYZ',
        distance: 18500.0,
        averageSpeed: 24.3,
        maxSpeed: 43.2,
        startTime: tTime,
        endTime: tTime.add(const Duration(minutes: 20)),
        duration: 1200000,
        startAddress: 'Tanjung Priok Logistics Hub',
        endAddress: 'Cikarang Dry Port Depot',
        startLat: -6.1754,
        startLon: 106.8272,
        endLat: -6.2088,
        endLon: 106.8456,
      ),
    ];

    final tStops = [
      StopReportModel(
        deviceId: 77,
        deviceName: 'Isuzu Giga Heavy Truck B 9999 XYZ',
        distance: 0.0,
        averageSpeed: 0.0,
        maxSpeed: 0.0,
        startTime: tTime.add(const Duration(minutes: 20)),
        endTime: tTime.add(const Duration(minutes: 50)),
        latitude: -6.2088,
        longitude: 106.8456,
        address: 'Rest Area KM 19',
        duration: 1800000,
        engineHours: 0,
      ),
    ];

    late MockReportsRepository mockRepo;
    late TestMapRouteController mockMap;

    setUp(() {
      mockRepo = MockReportsRepository();
      mockRepo.mockPositions = tRoutePositions;
      mockRepo.mockTrips = tTrips;
      mockRepo.mockStops = tStops;
      mockMap = TestMapRouteController();
    });

    testWidgets(
      'REG-P75-01: Full End-to-End Cycle: Vehicle Sheet -> Tap History -> Route History Screen -> Fetch Data -> Render Polyline & Stops -> Start Playback -> Scrub -> Change Preset -> Back Pop',
      (tester) async {
        // Step 1: Render Host with VehicleDetailSheet
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return VehicleDetailSheet(
                    device: tDevice,
                    position: tPosition,
                    onHistoryPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RouteHistoryScreen(
                            deviceId: tDevice.id,
                            deviceName: tDevice.name,
                            reportsRepository: mockRepo,
                            testMapRouteController: mockMap,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VehicleDetailSheet), findsOneWidget);
        expect(find.text('Isuzu Giga Heavy Truck B 9999 XYZ'), findsOneWidget);

        // Step 2: Tap "Riwayat" button on VehicleDetailSheet
        final historyBtn = find.byKey(
          const Key('vehicle_sheet_history_button'),
        );
        expect(historyBtn, findsOneWidget);
        await tester.tap(historyBtn);
        await tester.pumpAndSettle();

        // Step 3: Verified navigation to RouteHistoryScreen
        expect(find.byType(RouteHistoryScreen), findsOneWidget);
        expect(find.text('Riwayat: Hari Ini'), findsOneWidget);
        expect(mockRepo.routeCallCount, 1);
        expect(mockRepo.tripCallCount, 1);
        expect(mockRepo.stopCallCount, 1);

        // Step 4: Verify Map rendering of GeoJSON polyline and Waypoints
        expect(
          mockMap.sources.containsKey(RouteGeoJsonBuilder.defaultSourceId),
          isTrue,
        );
        expect(
          mockMap.layers.containsKey(RouteGeoJsonBuilder.defaultLayerId),
          isTrue,
        );
        expect(mockMap.symbols.isNotEmpty, isTrue);

        // Step 5: Verify Summary Mode with Trips & Stops tabs
        expect(find.byType(RouteSummaryPanel), findsOneWidget);
        expect(find.text('Perjalanan (1)'), findsOneWidget);
        expect(find.text('18.5 km'), findsOneWidget);
        expect(find.text('Tanjung Priok Logistics Hub'), findsOneWidget);

        // Step 6: Start Playback Mode
        final startPlaybackBtn = find.byKey(
          const Key('route_history_start_playback_button'),
        );
        expect(startPlaybackBtn, findsOneWidget);
        await tester.tap(startPlaybackBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify RoutePlaybackSheet is visible with telemetry
        expect(find.byType(RoutePlaybackSheet), findsOneWidget);
        expect(find.byType(RouteSummaryPanel), findsNothing);

        // Step 7: Timeline Scrubbing Interaction
        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);

        // Scrub slider to midpoint
        await tester.drag(sliderFinder, const Offset(50.0, 0.0));
        await tester.pump();

        // Step 8: Change Date Preset to '24 Jam Terakhir'
        // Exit playback mode first
        final closePlaybackBtn = find.byKey(
          const Key('route_history_close_playback_button'),
        );
        await tester.tap(closePlaybackBtn);
        await tester.pumpAndSettle();

        expect(find.byType(RouteSummaryPanel), findsOneWidget);

        // Tap preset '24 Jam Terakhir'
        final preset24h = find.byKey(const Key('date_preset_last24Hours'));
        expect(preset24h, findsOneWidget);
        await tester.tap(preset24h);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(mockRepo.routeCallCount, 2);
        expect(find.text('Riwayat: 24 Jam Terakhir'), findsOneWidget);

        // Step 9: Pop back gracefully to VehicleDetailSheet
        final backButton = find.byType(BackButton);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Screen popped back cleanly, no errors or leaks
        expect(find.byType(RouteHistoryScreen), findsNothing);
        expect(find.byType(VehicleDetailSheet), findsOneWidget);
      },
    );
  });
}
