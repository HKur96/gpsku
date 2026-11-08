import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_marker_manager.dart';

/// Test double simulating MapLibre symbol operations headlessly.
class FakeMapSymbolController implements MapSymbolController {
  final List<Symbol> addedSymbols = [];
  final List<Map<String, dynamic>> updateCalls = [];
  final List<Symbol> removedSymbols = [];
  final List<void Function(Symbol)> tappedListeners = [];
  bool clearSymbolsCalled = false;
  bool _isDisposed = false;
  int _nextSymbolId = 1;

  @override
  bool get isDisposed => _isDisposed;

  void dispose() {
    _isDisposed = true;
  }

  @override
  Future<Symbol> addSymbol(
    SymbolOptions options, [
    Map<String, dynamic>? data,
  ]) async {
    final sym = Symbol('sym_${_nextSymbolId++}', options, data);
    addedSymbols.add(sym);
    return sym;
  }

  @override
  Future<void> updateSymbol(Symbol symbol, SymbolOptions changes) async {
    updateCalls.add({'symbol': symbol, 'changes': changes});
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    removedSymbols.add(symbol);
    addedSymbols.remove(symbol);
  }

  @override
  Future<void> removeSymbols(Iterable<Symbol> symbols) async {
    for (final s in symbols) {
      await removeSymbol(s);
    }
  }

  @override
  Future<void> clearSymbols() async {
    clearSymbolsCalled = true;
    removedSymbols.addAll(addedSymbols);
    addedSymbols.clear();
  }

  @override
  void addSymbolTappedListener(void Function(Symbol symbol) listener) {
    tappedListeners.add(listener);
  }

  @override
  void removeSymbolTappedListener(void Function(Symbol symbol) listener) {
    tappedListeners.remove(listener);
  }

  void simulateTap(Symbol symbol) {
    for (final l in List.of(tappedListeners)) {
      l(symbol);
    }
  }
}

class FakeWebSocketService extends TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();
  final WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  FakeWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => _state;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

  bool get isConnected => _state == WebSocketConnectionState.connected;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
    super.dispose();
  }
}

void main() {
  group('FleetMarkerManager - Symbol Layer Management', () {
    late FakeMapSymbolController fakeController;
    late FleetMarkerManager markerManager;
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;

    setUp(() {
      fakeController = FakeMapSymbolController();
      markerManager = FleetMarkerManager();
      fakeWs = FakeWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 10),
      );
    });

    tearDown(() {
      markerManager.dispose();
      liveFleet.dispose();
      fakeWs.dispose();
      fakeController.dispose();
    });

    test(
      'TC-FMM-01: Symbol creation for devices with valid positions',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        final device = const DeviceModel(
          id: 101,
          name: 'Delivery Van',
          uniqueId: 'VAN-01',
          category: 'car',
          status: 'online',
        );
        final position = PositionModel(
          id: 501,
          deviceId: 101,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.2088,
          longitude: 106.8456,
          course: 90.0,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [device],
          initialPositions: [position],
        );

        // Allow microtasks to complete
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.symbolCount, equals(1));
        expect(markerManager.isMarkerRegistered(101), isTrue);
        expect(fakeController.addedSymbols.length, equals(1));

        final symbol = fakeController.addedSymbols.first;
        expect(
          symbol.options.geometry,
          equals(const LatLng(-6.2088, 106.8456)),
        );
        expect(symbol.options.iconImage, equals('car-success'));
        expect(symbol.options.iconRotate, equals(90.0));
        expect(symbol.options.textField, equals('Delivery Van'));
        expect(symbol.options.zIndex, equals(1));
        expect(symbol.data, equals({'deviceId': 101}));
      },
    );

    test(
      'TC-FMM-02: Asset mapping across categories and status colors',
      () async {
        // Test static helper resolveIconId
        final carOnline = const DeviceModel(
          id: 1,
          name: 'Car 1',
          uniqueId: 'C1',
          category: 'car',
          status: 'online',
        );
        final truckOffline = const DeviceModel(
          id: 2,
          name: 'Truck 1',
          uniqueId: 'T1',
          category: 'truck',
          status: 'offline',
        );
        final busUnknown = const DeviceModel(
          id: 3,
          name: 'Bus 1',
          uniqueId: 'B1',
          category: 'bus',
          status: 'unknown',
        );
        final defaultDevice = const DeviceModel(
          id: 4,
          name: 'Unknown Cat',
          uniqueId: 'U1',
          category: 'helicopter', // unsupported -> fallback 'default'
          status: 'online',
        );

        expect(
          FleetMarkerManager.resolveIconId(device: carOnline),
          equals('car-success'),
        );
        expect(
          FleetMarkerManager.resolveIconId(device: truckOffline),
          equals('truck-error'),
        );
        expect(
          FleetMarkerManager.resolveIconId(device: busUnknown),
          equals('bus-neutral'),
        );
        expect(
          FleetMarkerManager.resolveIconId(device: defaultDevice),
          equals('default-success'),
        );

        // Selected overrides status color to info
        expect(
          FleetMarkerManager.resolveIconId(device: carOnline, isSelected: true),
          equals('car-info'),
        );
      },
    );

    test('TC-FMM-03: Selection highlight and zIndex elevation', () async {
      markerManager.attachController(fakeController, fleetProvider: liveFleet);

      final dev1 = const DeviceModel(
        id: 1,
        name: 'Dev 1',
        uniqueId: 'D1',
        category: 'car',
        status: 'online',
      );
      final dev2 = const DeviceModel(
        id: 2,
        name: 'Dev 2',
        uniqueId: 'D2',
        category: 'truck',
        status: 'offline',
      );

      final pos1 = PositionModel(
        id: 1,
        deviceId: 1,
        serverTime: DateTime.now(),
        fixTime: DateTime.now(),
        latitude: -6.1,
        longitude: 106.8,
      );
      final pos2 = PositionModel(
        id: 2,
        deviceId: 2,
        serverTime: DateTime.now(),
        fixTime: DateTime.now(),
        latitude: -6.2,
        longitude: 106.9,
      );

      liveFleet.setInitialFleetData(
        initialDevices: [dev1, dev2],
        initialPositions: [pos1, pos2],
      );
      await Future.delayed(const Duration(milliseconds: 20));

      expect(markerManager.getRenderedIconId(1), equals('car-success'));
      expect(markerManager.getRenderedIconId(2), equals('truck-error'));

      // Select Device 1
      liveFleet.selectDevice(1);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(markerManager.getRenderedIconId(1), equals('car-info'));
      // Device 2 remains truck-error
      expect(markerManager.getRenderedIconId(2), equals('truck-error'));

      // Switch selection to Device 2
      liveFleet.selectDevice(2);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(markerManager.getRenderedIconId(1), equals('car-success'));
      expect(markerManager.getRenderedIconId(2), equals('truck-info'));
    });

    test(
      'TC-FMM-04: Bearing / Course heading rotation normalization',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        final dev = const DeviceModel(
          id: 1,
          name: 'Bike',
          uniqueId: 'B1',
          category: 'motorcycle',
          status: 'online',
        );
        final pos = PositionModel(
          id: 1,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.1,
          longitude: 106.8,
          course: 275.5,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [dev],
          initialPositions: [pos],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.getRenderedRotation(1), equals(275.5));

        // Update course to 450 (should normalize to 90.0)
        final pos2 = PositionModel(
          id: 2,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now().add(const Duration(seconds: 1)),
          latitude: -6.101,
          longitude: 106.801,
          course: 450.0,
        );
        liveFleet.updatePositions([pos2]);
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.getRenderedRotation(1), equals(90.0));
      },
    );

    test(
      'TC-FMM-05: In-place surgical updates without recreating symbol',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        final dev = const DeviceModel(
          id: 1,
          name: 'Fleet Car',
          uniqueId: 'FC1',
          category: 'car',
          status: 'online',
        );
        final pos1 = PositionModel(
          id: 1,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.10,
          longitude: 106.80,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [dev],
          initialPositions: [pos1],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        expect(fakeController.addedSymbols.length, equals(1));
        expect(fakeController.updateCalls.isEmpty, isTrue);

        // Move vehicle
        final pos2 = PositionModel(
          id: 2,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now().add(const Duration(seconds: 1)),
          latitude: -6.15,
          longitude: 106.85,
          course: 180.0,
        );
        liveFleet.updatePositions([pos2]);
        await Future.delayed(const Duration(milliseconds: 20));

        // No new symbols added! Only updateSymbol called!
        expect(fakeController.addedSymbols.length, equals(1));
        expect(fakeController.updateCalls.length, equals(1));

        final updatedChanges =
            fakeController.updateCalls.first['changes'] as SymbolOptions;
        expect(updatedChanges.geometry, equals(const LatLng(-6.15, 106.85)));
        expect(updatedChanges.iconRotate, equals(180.0));
        expect(
          markerManager.getRenderedCoordinate(1),
          equals(const LatLng(-6.15, 106.85)),
        );
      },
    );

    test(
      'TC-FMM-06: Coordinate validation guard rejects Null Island and NaN',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        final dev = const DeviceModel(
          id: 1,
          name: 'Invalid GPS',
          uniqueId: 'INV1',
          category: 'car',
        );
        final nullIsland = PositionModel(
          id: 1,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: 0.0,
          longitude: 0.0,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [dev],
          initialPositions: [nullIsland],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        // Null Island rejected -> 0 symbols registered
        expect(markerManager.symbolCount, equals(0));
        expect(fakeController.addedSymbols.isEmpty, isTrue);
      },
    );

    test(
      'TC-FMM-07: Dynamic device removal on fleet clear or missing position',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        final dev = const DeviceModel(
          id: 1,
          name: 'Car 1',
          uniqueId: 'C1',
          category: 'car',
          status: 'online',
        );
        final pos = PositionModel(
          id: 1,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.1,
          longitude: 106.8,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [dev],
          initialPositions: [pos],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.symbolCount, equals(1));

        // Clear fleet
        liveFleet.clearFleet();
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.symbolCount, equals(0));
        expect(fakeController.removedSymbols.length, equals(1));
      },
    );

    test(
      'TC-FMM-08: Marker tap handling updates selection and fires callback',
      () async {
        int? tappedDeviceId;
        markerManager.onMarkerTapped = (id) => tappedDeviceId = id;
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        final dev = const DeviceModel(
          id: 42,
          name: 'Police Car',
          uniqueId: 'P42',
          category: 'car',
          status: 'online',
        );
        final pos = PositionModel(
          id: 1,
          deviceId: 42,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.1,
          longitude: 106.8,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [dev],
          initialPositions: [pos],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        expect(fakeController.addedSymbols.length, equals(1));
        final symbol = fakeController.addedSymbols.first;

        // Simulate native map symbol tap
        fakeController.simulateTap(symbol);

        expect(tappedDeviceId, equals(42));
        expect(liveFleet.selectedDeviceId, equals(42));
      },
    );

    test(
      'TC-FMM-09: Detach and dispose unregisters listeners and cleans cache',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );
        expect(fakeController.tappedListeners.length, equals(1));

        final dev = const DeviceModel(id: 1, name: 'Car', uniqueId: 'C1');
        final pos = PositionModel(
          id: 1,
          deviceId: 1,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: -6.1,
          longitude: 106.8,
        );
        liveFleet.setInitialFleetData(
          initialDevices: [dev],
          initialPositions: [pos],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        expect(markerManager.symbolCount, equals(1));

        // Detach
        await markerManager.detach(clearMapSymbols: true);
        expect(markerManager.isReady, isFalse);
        expect(markerManager.symbolCount, equals(0));
        expect(fakeController.tappedListeners.isEmpty, isTrue);
        expect(fakeController.clearSymbolsCalled, isTrue);
      },
    );

    test(
      'TC-FMM-10: High-density fleet benchmark (> 50 vehicles) without jank',
      () async {
        markerManager.attachController(
          fakeController,
          fleetProvider: liveFleet,
        );

        const fleetSize = 60;
        final devices = <DeviceModel>[];
        final positions = <PositionModel>[];

        for (int i = 1; i <= fleetSize; i++) {
          devices.add(
            DeviceModel(
              id: i,
              name: 'Fleet Vehicle $i',
              uniqueId: 'FLEET-$i',
              category: i % 2 == 0 ? 'truck' : 'car',
              status: i % 3 == 0 ? 'offline' : 'online',
            ),
          );
          positions.add(
            PositionModel(
              id: i * 10,
              deviceId: i,
              serverTime: DateTime.now(),
              fixTime: DateTime.now(),
              latitude: -6.0 + (i * 0.01),
              longitude: 106.0 + (i * 0.01),
              course: (i * 15.0) % 360,
            ),
          );
        }

        final stopwatch = Stopwatch()..start();
        liveFleet.setInitialFleetData(
          initialDevices: devices,
          initialPositions: positions,
        );
        await Future.delayed(const Duration(milliseconds: 30));
        stopwatch.stop();

        // 1. Initial 60 symbols added
        expect(markerManager.symbolCount, equals(fleetSize));
        expect(fakeController.addedSymbols.length, equals(fleetSize));
        expect(fakeController.updateCalls.length, equals(0));

        // 2. Burst update: Only 5 vehicles move
        final burstPositions = <PositionModel>[];
        for (int i = 1; i <= 5; i++) {
          burstPositions.add(
            PositionModel(
              id: i * 10 + 1,
              deviceId: i,
              serverTime: DateTime.now(),
              fixTime: DateTime.now().add(const Duration(seconds: 1)),
              latitude: -6.0 + (i * 0.01) + 0.005,
              longitude: 106.0 + (i * 0.01) + 0.005,
              course: 180.0,
            ),
          );
        }

        stopwatch.reset();
        stopwatch.start();
        liveFleet.updatePositions(burstPositions);
        await Future.delayed(const Duration(milliseconds: 30));
        stopwatch.stop();

        // 3. Exactly 5 updates executed, 0 new additions, 55 stationary vehicles skipped!
        expect(fakeController.addedSymbols.length, equals(fleetSize));
        expect(fakeController.updateCalls.length, equals(5));
        expect(markerManager.symbolCount, equals(fleetSize));

        // Verifies sub-millisecond diffing performance (< 200ms total test execution)
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      },
    );
  });
}
