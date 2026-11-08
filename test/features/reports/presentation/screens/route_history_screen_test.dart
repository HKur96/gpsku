import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'package:gpsku/features/reports/data/models/trip_report_model.dart';
import 'package:gpsku/features/reports/domain/helpers/report_date_range_helper.dart';
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
  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<Either<Failure, List<PositionModel>>> getRouteReport({
    required int deviceId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    routeCallCount++;
    lastFrom = from;
    lastTo = to;
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
  group('RouteHistoryScreen Widget Tests', () {
    final tTime = DateTime.parse('2026-11-08T08:00:00.000Z');

    final tPositions = [
      PositionModel(
        id: 1,
        deviceId: 42,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.2088,
        longitude: 106.8456,
        speed: 25.0,
        course: 90.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 2,
        deviceId: 42,
        serverTime: tTime.add(const Duration(minutes: 5)),
        fixTime: tTime.add(const Duration(minutes: 5)),
        latitude: -6.2150,
        longitude: 106.8550,
        speed: 30.0,
        course: 110.0,
        attributes: const {'ignition': true},
      ),
      PositionModel(
        id: 3,
        deviceId: 42,
        serverTime: tTime.add(const Duration(minutes: 10)),
        fixTime: tTime.add(const Duration(minutes: 10)),
        latitude: -6.2200,
        longitude: 106.8650,
        speed: 0.0,
        course: 0.0,
        attributes: const {'ignition': false},
      ),
    ];

    final tTrips = [
      TripReportModel(
        deviceId: 42,
        deviceName: 'Toyota Avanza B 1234 CD',
        distance: 14200.0,
        averageSpeed: 21.6, // ~40 km/h
        maxSpeed: 37.8, // ~70 km/h
        startTime: tTime,
        endTime: tTime.add(const Duration(minutes: 25)),
        duration: 1500000,
        startAddress: 'Jl. Sudirman No. 1',
        endAddress: 'Jl. Thamrin No. 10',
        startLat: -6.2088,
        startLon: 106.8456,
        endLat: -6.2200,
        endLon: 106.8650,
      ),
    ];

    final tStops = [
      StopReportModel(
        deviceId: 42,
        deviceName: 'Toyota Avanza B 1234 CD',
        distance: 0.0,
        averageSpeed: 0.0,
        maxSpeed: 0.0,
        startTime: tTime.add(const Duration(minutes: 30)),
        endTime: tTime.add(const Duration(minutes: 55)),
        latitude: -6.2200,
        longitude: 106.8650,
        address: 'Parkiran Thamrin',
        duration: 1500000, // 25 mins
        engineHours: 0,
      ),
    ];

    late MockReportsRepository mockRepo;
    late TestMapRouteController mockMap;

    setUp(() {
      mockRepo = MockReportsRepository();
      mockRepo.mockPositions = tPositions;
      mockRepo.mockTrips = tTrips;
      mockRepo.mockStops = tStops;
      mockMap = TestMapRouteController();
    });

    Widget createTestApp({ReportDateRange? initialRange}) {
      return MaterialApp(
        home: RouteHistoryScreen(
          deviceId: 42,
          deviceName: 'Toyota Avanza B 1234 CD',
          reportsRepository: mockRepo,
          testMapRouteController: mockMap,
          initialDateRange: initialRange,
        ),
      );
    }

    testWidgets(
      'TC-RHS-01: Initial load renders header, preset bar and triggers fetches',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Toyota Avanza B 1234 CD'), findsOneWidget);
        expect(find.text('Riwayat: Hari Ini'), findsOneWidget);
        expect(find.text('Hari Ini'), findsOneWidget);
        expect(find.text('Kemarin'), findsOneWidget);
        expect(find.text('24 Jam Terakhir'), findsOneWidget);
        expect(find.text('Kustom'), findsOneWidget);

        expect(mockRepo.routeCallCount, 1);
        expect(mockRepo.tripCallCount, 1);
        expect(mockRepo.stopCallCount, 1);

        // Verify spatial layer rendered on test map
        expect(
          mockMap.sources.containsKey(RouteGeoJsonBuilder.defaultSourceId),
          isTrue,
        );
        expect(
          mockMap.layers.containsKey(RouteGeoJsonBuilder.defaultLayerId),
          isTrue,
        );
      },
    );

    testWidgets(
      'TC-RHS-02: Renders RouteSummaryPanel with Trip and Stop tabs',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(RouteSummaryPanel), findsOneWidget);
        expect(find.text('Perjalanan (1)'), findsOneWidget);
        expect(find.text('Pemberhentian (1)'), findsOneWidget);

        // Verify Trip card
        expect(find.text('14.2 km'), findsOneWidget);
        expect(find.text('Jl. Sudirman No. 1'), findsOneWidget);

        // Switch to Pemberhentian tab
        await tester.tap(find.text('Pemberhentian (1)'));
        await tester.pumpAndSettle();

        expect(find.text('25m'), findsOneWidget);
        expect(find.text('Parkiran Thamrin'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-RHS-03: Tapping Mulai Pemutaran switches to RoutePlaybackSheet',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(RouteSummaryPanel), findsOneWidget);
        expect(find.byType(RoutePlaybackSheet), findsNothing);

        // Tap CTA button
        await tester.tap(
          find.byKey(const Key('route_history_start_playback_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(RoutePlaybackSheet), findsOneWidget);
        expect(find.byType(RouteSummaryPanel), findsNothing);

        // Close button exits playback
        await tester.tap(
          find.byKey(const Key('route_history_close_playback_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(RouteSummaryPanel), findsOneWidget);
      },
    );

    testWidgets(
      'TC-RHS-04: PopScope handles back gesture during Playback mode',
      (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Enter playback mode
        await tester.tap(
          find.byKey(const Key('route_history_start_playback_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(RoutePlaybackSheet), findsOneWidget);

        // Simulate Android back button / PopScope invocation
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Successfully returned to summary mode without popping screen
        expect(find.byType(RoutePlaybackSheet), findsNothing);
        expect(find.byType(RouteSummaryPanel), findsOneWidget);
      },
    );

    testWidgets('TC-RHS-05: Changing preset refetches data and updates title', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockRepo.routeCallCount, 1);

      // Tap 'Kemarin'
      await tester.tap(find.byKey(const Key('date_preset_yesterday')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockRepo.routeCallCount, 2);
      expect(find.text('Riwayat: Kemarin'), findsOneWidget);
    });

    testWidgets('TC-RHS-06: Empty route renders info badge and disables CTA', (
      tester,
    ) async {
      mockRepo.mockPositions = [];
      mockRepo.mockTrips = [];
      mockRepo.mockStops = [];

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Tidak ada riwayat rute pada periode ini.'),
        findsOneWidget,
      );
      expect(find.text('Tidak Ada Jejak Rute'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('route_history_start_playback_button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('TC-RHS-07: Error response renders error banner', (
      tester,
    ) async {
      mockRepo.failureToReturn = const ServerFailure(
        'Database error on reports',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Database error on reports'), findsOneWidget);
    });
  });
}
