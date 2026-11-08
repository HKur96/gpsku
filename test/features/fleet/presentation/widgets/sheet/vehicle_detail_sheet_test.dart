import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/camera_calculation_helper.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/fleet_marker_manager.dart';
import 'package:gpsku/features/fleet/presentation/widgets/sheet/vehicle_detail_sheet.dart';

class FakeWebSocketService extends TraccarWebSocketService {
  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _msgController = StreamController<Map<String, dynamic>>.broadcast();
  final WebSocketConnectionState _state = WebSocketConnectionState.connected;

  FakeWebSocketService()
    : super(appConfig: const AppConfig(), cookieJar: SessionCookieJar());

  @override
  WebSocketConnectionState get state => _state;

  @override
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgController.stream;

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

class FakeMapSymbolController implements MapSymbolController {
  final List<Symbol> addedSymbols = [];
  final List<Map<String, dynamic>> updateCalls = [];
  final List<Symbol> removedSymbols = [];
  final List<void Function(Symbol)> tappedListeners = [];
  int _nextSymbolId = 1;

  @override
  bool get isDisposed => false;

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
  Future<void> removeSymbols(Iterable<Symbol> symbols) async {}

  @override
  Future<void> clearSymbols() async {}

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

void main() {
  group('VehicleDetailSheet - Widget & Interaction Tests', () {
    final sampleDevice = const DeviceModel(
      id: 10,
      name: 'Toyota Avanza B 1234 CD',
      uniqueId: 'AVANZA-01',
      category: 'car',
      status: 'online',
      model: '1.5 G MT',
    );

    final samplePosition = PositionModel(
      id: 100,
      deviceId: 10,
      serverTime: DateTime.parse('2026-11-08T08:30:00.000Z'),
      fixTime: DateTime.parse('2026-11-08T08:30:00.000Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 32.4, // knots -> ~60.0 km/h
      course: 90.0,
      address: 'Jl. Sudirman Kav. 1, Jakarta Pusat',
      attributes: {'ignition': true, 'batteryLevel': 92},
    );

    testWidgets(
      'TC-VDS-01: Displays complete device and position telemetry metrics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VehicleDetailSheet(
                device: sampleDevice,
                position: samplePosition,
              ),
            ),
          ),
        );

        // Verify Header
        expect(find.text('Toyota Avanza B 1234 CD'), findsOneWidget);
        expect(find.text('AVANZA-01 • 1.5 G MT'), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);

        // Verify Metrics
        expect(
          find.text('60.0 km/h'),
          findsOneWidget,
        ); // 32.4 knots * 1.852 = 60.0048
        expect(find.text('ON'), findsOneWidget); // ignition: true
        expect(find.text('90° (T)'), findsOneWidget); // 90° East / Timur
        expect(find.text('92%'), findsOneWidget); // batteryLevel
        expect(find.text('Jl. Sudirman Kav. 1, Jakarta Pusat'), findsOneWidget);
        expect(find.byKey(const Key('metric_fix_time')), findsOneWidget);
      },
    );

    testWidgets(
      'TC-VDS-02: Displays No-Fix banner when position is null or (0, 0)',
      (tester) async {
        // 1. Position is null
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VehicleDetailSheet(device: sampleDevice, position: null),
            ),
          ),
        );

        expect(find.text('Toyota Avanza B 1234 CD'), findsOneWidget);
        expect(find.text('Menunggu Sinyal GPS'), findsOneWidget);
        expect(find.byKey(const Key('metric_speed')), findsNothing);

        // 2. Position is Null Island (0.0, 0.0)
        final nullIslandPosition = PositionModel(
          id: 101,
          deviceId: 10,
          serverTime: DateTime.now(),
          fixTime: DateTime.now(),
          latitude: 0.0,
          longitude: 0.0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VehicleDetailSheet(
                device: sampleDevice,
                position: nullIslandPosition,
              ),
            ),
          ),
        );

        expect(find.text('Menunggu Sinyal GPS'), findsOneWidget);
        expect(find.byKey(const Key('metric_speed')), findsNothing);
      },
    );

    testWidgets('TC-VDS-03: Tapping close button fires onDismiss callback', (
      tester,
    ) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleDetailSheet(
              device: sampleDevice,
              position: samplePosition,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      final closeButton = find.byKey(const Key('vehicle_sheet_dismiss_button'));
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets(
      'TC-VDS-04: Tapping Pusatkan fires onCenterToVehicle callback',
      (tester) async {
        bool centered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VehicleDetailSheet(
                device: sampleDevice,
                position: samplePosition,
                onCenterToVehicle: () => centered = true,
              ),
            ),
          ),
        );

        final centerButton = find.byKey(
          const Key('vehicle_sheet_center_button'),
        );
        expect(centerButton, findsOneWidget);

        await tester.tap(centerButton);
        await tester.pump();

        expect(centered, isTrue);
      },
    );

    testWidgets('TC-VDS-04B: Tapping Riwayat fires onHistoryPressed callback', (
      tester,
    ) async {
      bool historyTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleDetailSheet(
              device: sampleDevice,
              position: samplePosition,
              onHistoryPressed: () => historyTapped = true,
            ),
          ),
        ),
      );

      final historyButton = find.byKey(
        const Key('vehicle_sheet_history_button'),
      );
      expect(historyButton, findsOneWidget);

      await tester.tap(historyButton);
      await tester.pump();

      expect(historyTapped, isTrue);
    });

    testWidgets(
      'TC-VDS-05: Real-time update updates metrics without widget recreation',
      (tester) async {
        var currentPosition = samplePosition;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      VehicleDetailSheet(
                        device: sampleDevice,
                        position: currentPosition,
                      ),
                      ElevatedButton(
                        key: const Key('update_position_btn'),
                        onPressed: () {
                          setState(() {
                            currentPosition = samplePosition.copyWith(
                              speed: 43.2, // ~80.0 km/h
                              attributes: {
                                'ignition': false,
                                'batteryLevel': 75,
                              },
                            );
                          });
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        // Initial state
        expect(find.text('60.0 km/h'), findsOneWidget);
        expect(find.text('ON'), findsOneWidget);
        expect(find.text('92%'), findsOneWidget);

        // Trigger update
        await tester.tap(find.byKey(const Key('update_position_btn')));
        await tester.pump();

        // Updated state
        expect(find.text('80.0 km/h'), findsOneWidget);
        expect(find.text('OFF'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
      },
    );

    test(
      'TC-VDS-06: Compass direction mapping converts all 8 cardinal quadrants',
      () {
        expect(VehicleDetailSheet.compassDirection(0.0), equals('U'));
        expect(VehicleDetailSheet.compassDirection(45.0), equals('TL'));
        expect(VehicleDetailSheet.compassDirection(90.0), equals('T'));
        expect(VehicleDetailSheet.compassDirection(135.0), equals('TG'));
        expect(VehicleDetailSheet.compassDirection(180.0), equals('S'));
        expect(VehicleDetailSheet.compassDirection(225.0), equals('BD'));
        expect(VehicleDetailSheet.compassDirection(270.0), equals('B'));
        expect(VehicleDetailSheet.compassDirection(315.0), equals('BL'));
        expect(VehicleDetailSheet.compassDirection(360.0), equals('U'));
        expect(VehicleDetailSheet.compassDirection(-90.0), equals('B'));
      },
    );

    test('TC-VDS-07: Speed conversion accurately formats knots to km/h', () {
      final pos0 = samplePosition.copyWith(speed: 0.0);
      expect(pos0.speedKmh, equals(0.0));

      final pos10 = samplePosition.copyWith(speed: 10.0);
      expect(pos10.speedKmh, closeTo(18.52, 0.01));
    });

    test(
      'TC-VDS-08: Camera offset calculation accounts for bottom sheet height',
      () {
        const originalTarget = LatLng(-6.2088, 106.8456);
        const zoom = 14.0;
        const sheetHeight = VehicleDetailSheet.estimatedSheetHeight;

        final offsetTarget = CameraCalculationHelper.calculateOffsetCenter(
          target: originalTarget,
          zoom: zoom,
          verticalOffsetPixels: sheetHeight,
        );

        // Shifting camera target southward means offset latitude is LOWER (more negative in Southern Hemisphere)
        expect(offsetTarget.latitude, lessThan(originalTarget.latitude));
        expect(offsetTarget.longitude, equals(originalTarget.longitude));
      },
    );

    testWidgets(
      'TC-VDS-09: Fallback address to coordinates when address is null or empty',
      (tester) async {
        final posWithoutAddress = samplePosition.copyWith(address: '');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VehicleDetailSheet(
                device: sampleDevice,
                position: posWithoutAddress,
              ),
            ),
          ),
        );

        // Coordinates displayed instead of address string
        expect(find.text('-6.20880, 106.84560'), findsOneWidget);
      },
    );

    test(
      'TC-VDS-10: Two-way selection synchronization with LiveFleetProvider & MarkerManager',
      () async {
        final fakeWs = FakeWebSocketService();
        final liveFleet = LiveFleetProvider(
          webSocketService: fakeWs,
          coalescingWindow: const Duration(milliseconds: 10),
        );
        final fakeMapController = FakeMapSymbolController();
        final markerManager = FleetMarkerManager();
        markerManager.attachController(
          fakeMapController,
          fleetProvider: liveFleet,
        );

        liveFleet.setInitialFleetData(
          initialDevices: [sampleDevice],
          initialPositions: [samplePosition],
        );
        await Future.delayed(const Duration(milliseconds: 20));

        // 1. Initial unselected state
        expect(liveFleet.selectedDeviceId, isNull);
        expect(markerManager.getRenderedIconId(10), equals('car-success'));

        // 2. Select device
        liveFleet.selectDevice(10);
        await Future.delayed(const Duration(milliseconds: 20));

        expect(liveFleet.selectedDeviceId, equals(10));
        expect(markerManager.getRenderedIconId(10), equals('car-info'));

        // 3. Dismiss selection (as done by VehicleDetailSheet onDismiss)
        liveFleet.selectDevice(null);
        await Future.delayed(const Duration(milliseconds: 20));

        expect(liveFleet.selectedDeviceId, isNull);
        expect(markerManager.getRenderedIconId(10), equals('car-success'));

        markerManager.dispose();
        liveFleet.dispose();
        fakeWs.dispose();
      },
    );
  });
}
