import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/reports/data/models/stop_report_model.dart';
import 'package:gpsku/features/reports/presentation/map/map_route_controller.dart';
import 'package:gpsku/features/reports/presentation/map/route_geojson_builder.dart';
import 'package:gpsku/features/reports/presentation/map/route_map_renderer.dart';
import 'package:gpsku/features/reports/presentation/map/route_map_style_config.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MockMapRouteController implements MapRouteController {
  final List<String> operationLog = [];
  final Map<String, Map<String, dynamic>> sources = {};
  final Map<String, LineLayerProperties> layers = {};
  final List<Symbol> symbols = [];
  final Map<String, Map<String, dynamic>> symbolData = {};
  final List<void Function(Symbol)> tapListeners = [];

  CameraUpdate? lastCameraUpdate;
  Duration? lastCameraDuration;
  bool isDisposedValue = false;
  int _symbolCounter = 1;

  @override
  bool get isDisposed => isDisposedValue;

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
  Future<Symbol> addSymbol(
    SymbolOptions options, [
    Map<String, dynamic>? data,
  ]) async {
    final symbol = Symbol('sym_${_symbolCounter++}', options, data);
    symbols.add(symbol);
    if (data != null) {
      symbolData[symbol.id] = data;
    }
    operationLog.add('addSymbol:${symbol.id}');
    return symbol;
  }

  @override
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) async {
    operationLog.add('updateSymbol:${symbol.id}');
    final idx = symbols.indexWhere((s) => s.id == symbol.id);
    if (idx >= 0) {
      symbols[idx] = Symbol(
        symbol.id,
        symbol.options.copyWith(changes),
        symbol.data,
      );
    }
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    operationLog.add('removeSymbol:${symbol.id}');
    symbols.removeWhere((s) => s.id == symbol.id);
  }

  @override
  Future<void> removeSymbols(Iterable<Symbol> syms) async {
    final ids = syms.map((s) => s.id).toSet();
    operationLog.add('removeSymbols:${ids.length}');
    symbols.removeWhere((s) => ids.contains(s.id));
  }

  @override
  Future<void> clearSymbols() async {
    operationLog.add('clearSymbols');
    symbols.clear();
  }

  @override
  void addSymbolTappedListener(void Function(Symbol symbol) listener) {
    tapListeners.add(listener);
  }

  @override
  void removeSymbolTappedListener(void Function(Symbol symbol) listener) {
    tapListeners.remove(listener);
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    lastCameraUpdate = cameraUpdate;
    lastCameraDuration = duration;
    operationLog.add('animateCamera');
    return true;
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool defer = false,
    double pixelRatio = 1.0,
  ]) async {}

  void simulateSymbolTap(Symbol symbol) {
    for (final listener in tapListeners) {
      listener(symbol);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteMapRenderer Lifecycle, LineLayer & Marker Tests', () {
    late MockMapRouteController mockController;
    late RouteMapRenderer renderer;

    final tTime = DateTime.parse('2026-11-08T08:00:00.000Z');

    final tPositions = [
      PositionModel(
        id: 1,
        deviceId: 42,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.2088,
        longitude: 106.8456,
      ),
      PositionModel(
        id: 2,
        deviceId: 42,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.2500,
        longitude: 106.8700,
      ),
      PositionModel(
        id: 3,
        deviceId: 42,
        serverTime: tTime,
        fixTime: tTime,
        latitude: -6.3000,
        longitude: 106.9000,
      ),
    ];

    final tStops = [
      StopReportModel(
        deviceId: 42,
        distance: 0.0,
        averageSpeed: 0.0,
        maxSpeed: 0.0,
        startTime: tTime,
        endTime: tTime.add(const Duration(minutes: 45)),
        positionId: 101,
        latitude: -6.2500,
        longitude: 106.8700,
        address: 'Rest Area KM 14',
        duration: 2700000, // 45m
        engineHours: 0,
      ),
    ];

    setUp(() {
      mockController = MockMapRouteController();
      renderer = RouteMapRenderer(controller: mockController);
      renderer.attach(mockController);
    });

    test(
      'TC-RMR-01: First renderRoute adds GeoJSON source and LineLayer',
      () async {
        final success = await renderer.renderRoute(positions: tPositions);

        expect(success, isTrue);
        expect(
          mockController.sources.containsKey(
            RouteGeoJsonBuilder.defaultSourceId,
          ),
          isTrue,
        );
        expect(
          mockController.layers.containsKey(RouteGeoJsonBuilder.defaultLayerId),
          isTrue,
        );

        final lineProps =
            mockController.layers[RouteGeoJsonBuilder.defaultLayerId]!;
        expect(lineProps.lineColor, '#1E88E5');
        expect(lineProps.lineWidth, 4.5);
        expect(lineProps.lineOpacity, 0.9);
        expect(lineProps.lineCap, 'round');
        expect(lineProps.lineJoin, 'round');
      },
    );

    test(
      'TC-RMR-02: Subsequent renderRoute calls use setGeoJsonSource without recreating layer',
      () async {
        await renderer.renderRoute(positions: tPositions);
        mockController.operationLog.clear();

        final updatedPositions = [
          ...tPositions,
          PositionModel(
            id: 4,
            deviceId: 42,
            serverTime: tTime,
            fixTime: tTime,
            latitude: -6.3500,
            longitude: 106.9500,
          ),
        ];

        final success = await renderer.renderRoute(positions: updatedPositions);

        expect(success, isTrue);
        // Verify setGeoJsonSource was called, and addLineLayer was NOT called again
        expect(
          mockController.operationLog,
          contains('setGeoJsonSource:${RouteGeoJsonBuilder.defaultSourceId}'),
        );
        expect(
          mockController.operationLog.where(
            (op) => op.startsWith('addLineLayer'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'TC-RMR-03: Places Start (Green) and End (Red) waypoint symbols',
      () async {
        await renderer.renderRoute(positions: tPositions);

        expect(mockController.symbols.length, 2);
        final startSymbol = mockController.symbols[0];
        final endSymbol = mockController.symbols[1];

        expect(startSymbol.options.iconImage, 'route-start-pin');
        expect(startSymbol.options.geometry, const LatLng(-6.2088, 106.8456));

        expect(endSymbol.options.iconImage, 'route-end-pin');
        expect(endSymbol.options.geometry, const LatLng(-6.3000, 106.9000));
      },
    );

    test('TC-RMR-04: Places Stop markers with duration text label', () async {
      await renderer.renderRoute(positions: tPositions, stops: tStops);

      // 2 terminus (Start, End) + 1 Stop = 3 symbols
      expect(mockController.symbols.length, 3);
      final stopSymbol = mockController.symbols[2];

      expect(stopSymbol.options.iconImage, 'route-stop-pin');
      expect(stopSymbol.options.geometry, const LatLng(-6.2500, 106.8700));
      expect(stopSymbol.options.textField, '45m');
      expect(stopSymbol.options.textColor, '#FFFFFF');
      expect(stopSymbol.options.textHaloColor, '#000000');
    });

    test(
      'TC-RMR-05: Animates camera to LatLngBounds with style padding when >= 2 points exist',
      () async {
        await renderer.renderRoute(positions: tPositions);

        expect(mockController.lastCameraUpdate, isNotNull);
        expect(mockController.operationLog, contains('animateCamera'));
      },
    );

    test(
      'TC-RMR-06: Handles single-point route: places Start pin and animates camera with zoom',
      () async {
        final singlePoint = [tPositions.first];
        final success = await renderer.renderRoute(positions: singlePoint);

        expect(success, isTrue);
        // Start pin placed, no End pin
        expect(mockController.symbols.length, 1);
        expect(
          mockController.symbols.first.options.iconImage,
          'route-start-pin',
        );
        expect(mockController.lastCameraUpdate, isNotNull);
      },
    );

    test(
      'TC-RMR-07: Handles empty positions list: clears route and returns false',
      () async {
        final success = await renderer.renderRoute(positions: []);

        expect(success, isFalse);
        expect(mockController.symbols, isEmpty);
      },
    );

    test(
      'TC-RMR-08: Dispatches onStopTapped callback when stop marker is tapped',
      () async {
        StopReportModel? tappedStop;
        renderer.onStopTapped = (stop) {
          tappedStop = stop;
        };

        await renderer.renderRoute(positions: tPositions, stops: tStops);
        final stopSymbol = mockController.symbols[2];

        mockController.simulateSymbolTap(stopSymbol);

        expect(tappedStop, isNotNull);
        expect(tappedStop!.positionId, 101);
        expect(tappedStop!.address, 'Rest Area KM 14');
      },
    );

    test(
      'TC-RMR-09: Dispatches onStartTapped and onEndTapped callbacks',
      () async {
        PositionModel? tappedStart;
        PositionModel? tappedEnd;

        renderer.onStartTapped = (p) => tappedStart = p;
        renderer.onEndTapped = (p) => tappedEnd = p;

        await renderer.renderRoute(positions: tPositions);

        mockController.simulateSymbolTap(mockController.symbols[0]);
        expect(tappedStart, isNotNull);
        expect(tappedStart!.id, 1);

        mockController.simulateSymbolTap(mockController.symbols[1]);
        expect(tappedEnd, isNotNull);
        expect(tappedEnd!.id, 3);
      },
    );

    test(
      'TC-RMR-10: Teardown order: Removes LineLayer FIRST, removes GeoJSON source SECOND',
      () async {
        await renderer.renderRoute(positions: tPositions);
        mockController.operationLog.clear();

        await renderer.clearRoute();

        final removeLayerIndex = mockController.operationLog.indexOf(
          'removeLayer:${RouteGeoJsonBuilder.defaultLayerId}',
        );
        final removeSourceIndex = mockController.operationLog.indexOf(
          'removeSource:${RouteGeoJsonBuilder.defaultSourceId}',
        );

        expect(removeLayerIndex, isNot(-1));
        expect(removeSourceIndex, isNot(-1));
        // Strict MapLibre C++ requirement: Layer must be removed BEFORE Source
        expect(removeLayerIndex, lessThan(removeSourceIndex));
      },
    );

    test(
      'TC-RMR-11: formatDurationLabel outputs compact Indonesian duration',
      () {
        expect(
          RouteMapRenderer.formatDurationLabel(const Duration(seconds: 45)),
          '45d',
        );
        expect(
          RouteMapRenderer.formatDurationLabel(const Duration(minutes: 25)),
          '25m',
        );
        expect(
          RouteMapRenderer.formatDurationLabel(const Duration(hours: 2)),
          '2j',
        );
        expect(
          RouteMapRenderer.formatDurationLabel(
            const Duration(hours: 1, minutes: 30),
          ),
          '1j 30m',
        );
      },
    );

    test(
      'TC-RMR-12: Full dispose cleans up native resources and detaches',
      () async {
        await renderer.renderRoute(positions: tPositions);
        await renderer.dispose();

        expect(mockController.tapListeners, isEmpty);
        expect(renderer.isReady, isFalse);
      },
    );

    test('TC-RMR-13: Updates custom RouteMapStyleConfig properly', () {
      const customConfig = RouteMapStyleConfig(
        lineColor: '#FF5722',
        lineWidth: 6.0,
      );
      renderer.updateStyleConfig(customConfig);
    });

    test(
      'TC-RMR-14: Updates and removes moving playback vehicle symbol',
      () async {
        await renderer.renderRoute(positions: tPositions);

        // Create playback marker
        await renderer.updatePlaybackMarker(
          coordinate: const LatLng(-6.2088, 106.8456),
          bearing: 90.0,
        );

        expect(mockController.symbols.length, 3);
        expect(
          mockController.symbols.last.options.geometry,
          const LatLng(-6.2088, 106.8456),
        );
        expect(mockController.symbols.last.options.iconRotate, 90.0);

        // Update position and heading
        await renderer.updatePlaybackMarker(
          coordinate: const LatLng(-6.2100, 106.8500),
          bearing: 110.0,
        );

        // Remove playback marker
        await renderer.removePlaybackMarker();
        expect(mockController.symbols.length, 2);
      },
    );
  });
}
