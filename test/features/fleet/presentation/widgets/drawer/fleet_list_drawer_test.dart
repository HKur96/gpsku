import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';
import 'package:gpsku/features/fleet/data/models/position_model.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';
import 'package:gpsku/features/fleet/presentation/widgets/drawer/fleet_list_drawer.dart';

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

  void emitMessage(Map<String, dynamic> msg) => _msgController.add(msg);

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void dispose() {
    _stateController.close();
    _msgController.close();
  }
}

void main() {
  group('FleetListDrawer - Widget & Integration Tests', () {
    late FakeWebSocketService fakeWs;
    late LiveFleetProvider liveFleet;

    final dev1 = const DeviceModel(
      id: 101,
      name: 'Armada Alpha B 1111 AA',
      uniqueId: 'ALPHA-01',
      category: 'truck',
      status: 'online',
      model: 'Hino Dutro',
    );

    final dev2 = const DeviceModel(
      id: 102,
      name: 'Armada Bravo B 2222 BB',
      uniqueId: 'BRAVO-02',
      category: 'car',
      status: 'online',
      model: 'Toyota Innova',
    );

    final dev3 = const DeviceModel(
      id: 103,
      name: 'Armada Charlie B 3333 CC',
      uniqueId: 'CHARLIE-03',
      category: 'motorcycle',
      status: 'offline',
      model: 'Honda Vario',
    );

    // dev1 moving (speed: 40 knots = ~74 km/h)
    final pos1 = PositionModel(
      id: 1001,
      deviceId: 101,
      serverTime: DateTime.parse('2026-11-08T09:00:00Z'),
      fixTime: DateTime.parse('2026-11-08T09:00:00Z'),
      latitude: -6.2088,
      longitude: 106.8456,
      speed: 40.0,
      attributes: {'ignition': true},
    );

    // dev2 idle (speed: 0)
    final pos2 = PositionModel(
      id: 1002,
      deviceId: 102,
      serverTime: DateTime.parse('2026-11-08T09:00:00Z'),
      fixTime: DateTime.parse('2026-11-08T09:00:00Z'),
      latitude: -6.2000,
      longitude: 106.8400,
      speed: 0.0,
      attributes: {'ignition': false},
    );

    setUp(() {
      fakeWs = FakeWebSocketService();
      liveFleet = LiveFleetProvider(
        webSocketService: fakeWs,
        coalescingWindow: const Duration(milliseconds: 10),
      );
    });

    tearDown(() {
      liveFleet.dispose();
      fakeWs.dispose();
    });

    Widget createTestWidget({
      void Function(DeviceModel, PositionModel?)? onDeviceSelected,
      VoidCallback? onClosePressed,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LiveFleetProvider>.value(value: liveFleet),
        ],
        child: MaterialApp(
          home: Scaffold(
            drawer: FleetListDrawer(
              onDeviceSelected: onDeviceSelected,
              onClosePressed: onClosePressed,
            ),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Buka Drawer'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'TC-FLD-01: Displays empty fleet placeholder when no devices exist',
      (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Open drawer
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        expect(find.text('Daftar Armada'), findsOneWidget);
        expect(find.text('0 Unit'), findsOneWidget);
        expect(find.text('Belum Ada Armada Terdaftar'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLD-02: Renders populated fleet with title, counts, and items',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2, dev3],
          initialPositions: [pos1, pos2],
        );

        await tester.pumpWidget(createTestWidget());

        // Open drawer
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        expect(find.text('Daftar Armada'), findsOneWidget);
        expect(find.text('3 Unit'), findsOneWidget);

        // Verify Chips count
        expect(find.text('Semua (3)'), findsOneWidget);
        expect(find.text('Bergerak (1)'), findsOneWidget);
        expect(find.text('Diam (1)'), findsOneWidget);
        expect(find.text('Offline (1)'), findsOneWidget);

        // Verify list items present
        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
        expect(find.text('Armada Charlie B 3333 CC'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLD-03: Instant search text filtering updates displayed items',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2, dev3],
          initialPositions: [pos1, pos2],
        );

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Enter search query 'Bravo'
        await tester.enterText(find.byType(TextField), 'Bravo');
        await tester.pumpAndSettle();

        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
        expect(find.text('Armada Alpha B 1111 AA'), findsNothing);
        expect(find.text('Armada Charlie B 3333 CC'), findsNothing);

        // Clear search via clear icon button
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();

        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
        expect(find.text('Armada Charlie B 3333 CC'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLD-04: No search results state renders reset button that restores list',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2],
          initialPositions: [pos1, pos2],
        );

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Enter query matching nothing
        await tester.enterText(find.byType(TextField), 'NonExistent');
        await tester.pumpAndSettle();

        expect(find.text('Tidak Ada Armada yang Sesuai'), findsOneWidget);

        // Tap Reset Filter
        await tester.tap(find.text('Reset Filter'));
        await tester.pumpAndSettle();

        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLD-05: Status filter chip switching filters displayed items',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2, dev3],
          initialPositions: [pos1, pos2],
        );

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Tap 'Bergerak (1)' chip
        await tester.tap(find.text('Bergerak (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsNothing);
        expect(find.text('Armada Charlie B 3333 CC'), findsNothing);

        // Tap 'Offline (1)' chip after ensuring it is visible in the scrollable row
        await tester.ensureVisible(find.text('Offline (1)'));
        await tester.tap(find.text('Offline (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Armada Charlie B 3333 CC'), findsOneWidget);
        expect(find.text('Armada Alpha B 1111 AA'), findsNothing);
      },
    );

    testWidgets(
      'TC-FLD-06: WebSocket speed update updates list item speed reactively',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1],
          initialPositions: [pos1],
        );

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Initial speed: 40 knots * 1.852 = 74.08 -> 74.1 km/h
        expect(find.text('74.1 km/h'), findsOneWidget);

        // Speed increases to 50 knots (~92.6 km/h) via WebSocket with newer fixTime (09:05:00Z)
        fakeWs.emitMessage({
          'positions': [
            {
              'id': 1005,
              'deviceId': 101,
              'serverTime': '2026-11-08T09:05:00.000Z',
              'fixTime': '2026-11-08T09:05:00.000Z',
              'latitude': -6.2088,
              'longitude': 106.8456,
              'speed': 50.0,
              'attributes': {'ignition': true},
            },
          ],
        });

        // Advance fake async to ingest stream event and flush coalescing buffer
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        liveFleet.flushImmediately();
        await tester.pump();

        // Speed badge updated in-place to 92.6 km/h!
        expect(find.text('92.6 km/h'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLD-07: Tapping item selects device, fires callback, and closes drawer',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2],
          initialPositions: [pos1, pos2],
        );

        DeviceModel? selectedDevice;
        PositionModel? selectedPosition;

        await tester.pumpWidget(
          createTestWidget(
            onDeviceSelected: (device, pos) {
              selectedDevice = device;
              selectedPosition = pos;
            },
          ),
        );

        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Tap Armada Alpha
        await tester.tap(find.text('Armada Alpha B 1111 AA'));
        await tester.pumpAndSettle();

        // LiveFleetProvider selectedDeviceId is updated
        expect(liveFleet.selectedDeviceId, equals(101));
        expect(selectedDevice?.id, equals(101));
        expect(selectedPosition?.id, equals(1001));

        // Drawer was closed
        expect(find.byType(FleetListDrawer), findsNothing);
      },
    );

    testWidgets(
      'TC-FLD-08: Close button invokes onClosePressed or dismisses drawer',
      (tester) async {
        bool closed = false;

        await tester.pumpWidget(
          createTestWidget(
            onClosePressed: () {
              closed = true;
            },
          ),
        );

        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        expect(find.byType(FleetListDrawer), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(closed, isTrue);
      },
    );

    testWidgets(
      'TC-FLD-09: 200ms debounce prevents premature filtering during rapid typing',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2, dev3],
          initialPositions: [pos1, pos2],
        );

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Enter search text 'Alpha'
        await tester.enterText(find.byType(TextField), 'Alpha');

        // Advance by 50ms (before 200ms debounce threshold)
        await tester.pump(const Duration(milliseconds: 50));

        // Query has not yet taken effect — all items still visible
        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);

        // Advance past 200ms debounce threshold
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();

        // Now query is applied — only Alpha is visible
        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsNothing);
      },
    );

    testWidgets(
      'TC-FLD-10: Category filter chip selection filters displayed fleet items',
      (tester) async {
        liveFleet.setInitialFleetData(
          initialDevices: [dev1, dev2, dev3],
          initialPositions: [pos1, pos2],
        );

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Find 'Mobil' category chip
        final mobilChip = find.text('Mobil');
        expect(mobilChip, findsOneWidget);

        // Ensure 'Mobil' chip is fully scrolled into view in the horizontal category bar
        await tester.ensureVisible(mobilChip);
        await tester.tap(mobilChip, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Only dev2 (car / Mobil) is visible
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
        expect(find.text('Armada Alpha B 1111 AA'), findsNothing);
        expect(find.text('Armada Charlie B 3333 CC'), findsNothing);

        // Tap 'Mobil' again to toggle it off (unselect)
        await tester.ensureVisible(mobilChip);
        await tester.tap(mobilChip, warnIfMissed: false);
        await tester.pumpAndSettle();

        // All items restored
        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
        expect(find.text('Armada Charlie B 3333 CC'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-FLD-11: Expandable/collapsible group headers toggle visibility of vehicles',
      (tester) async {
        final groupedDev1 = dev1.copyWith(groupId: 1);
        final groupedDev2 = dev2.copyWith(groupId: 1);
        final unassignedDev3 = dev3.copyWith(groupId: null);

        liveFleet.setInitialFleetData(
          initialDevices: [groupedDev1, groupedDev2, unassignedDev3],
          initialPositions: [pos1, pos2],
        );
        liveFleet.updateGroups([
          const GroupModel(id: 1, name: 'Divisi Logistik', groupId: null),
        ]);

        await tester.pumpWidget(createTestWidget());
        await tester.tap(find.text('Buka Drawer'));
        await tester.pumpAndSettle();

        // Group headers rendered
        expect(find.text('Divisi Logistik'), findsOneWidget);
        expect(find.text('Tanpa Grup'), findsOneWidget);

        // Initially all groups expanded
        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
        expect(find.text('Armada Charlie B 3333 CC'), findsOneWidget);

        // Tap 'Divisi Logistik' group header to collapse it
        await tester.tap(find.text('Divisi Logistik'));
        await tester.pumpAndSettle();

        // Group devices collapsed (hidden)
        expect(find.text('Armada Alpha B 1111 AA'), findsNothing);
        expect(find.text('Armada Bravo B 2222 BB'), findsNothing);
        // Unassigned group still expanded
        expect(find.text('Armada Charlie B 3333 CC'), findsOneWidget);

        // Tap 'Divisi Logistik' again to expand it
        await tester.tap(find.text('Divisi Logistik'));
        await tester.pumpAndSettle();

        // Vehicles visible again
        expect(find.text('Armada Alpha B 1111 AA'), findsOneWidget);
        expect(find.text('Armada Bravo B 2222 BB'), findsOneWidget);
      },
    );
  });
}
