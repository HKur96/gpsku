import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/security/secure_storage_service.dart';
import 'package:gpsku/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gpsku/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gpsku/features/fleet/data/datasources/fleet_remote_data_source.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';
import 'package:gpsku/features/fleet/data/repositories/fleet_repository_impl.dart';
import 'package:gpsku/features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'package:gpsku/features/fleet/presentation/providers/live_fleet_provider.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();
  FlutterSecureStorage.setMockInitialValues({});

  group('Traccar Backend Live Integration Tests (Fleet API & Dual-Fetch Sync)', () {
    const backendBaseUrl = 'http://localhost:8082';
    const validEmail = 'admin@gps.local';
    const validPassword = 'Password123!';

    late SessionCookieJar cookieJar;
    late AppConfig appConfig;
    late DioClient dioClient;
    late AuthRepositoryImpl authRepository;
    late FleetRemoteDataSourceImpl fleetRemoteDataSource;
    late FleetRepositoryImpl fleetRepository;
    late TraccarWebSocketService webSocketService;
    late LiveFleetProvider liveFleetProvider;
    late InitialFleetSyncCoordinator coordinator;

    setUp(() async {
      HttpOverrides.global = RealHttpOverrides();
      cookieJar = SessionCookieJar();
      appConfig = const AppConfig(baseUrl: backendBaseUrl);
      dioClient = DioClient(appConfig: appConfig, cookieJar: cookieJar);
      authRepository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSourceImpl(dioClient: dioClient),
        secureStorage: SecureStorageService(),
        cookieJar: cookieJar,
      );
      fleetRemoteDataSource = FleetRemoteDataSourceImpl(dioClient: dioClient);
      fleetRepository = FleetRepositoryImpl(
        remoteDataSource: fleetRemoteDataSource,
      );
      webSocketService = TraccarWebSocketService(
        appConfig: appConfig,
        cookieJar: cookieJar,
      );
      liveFleetProvider = LiveFleetProvider(
        webSocketService: webSocketService,
        coalescingWindow: const Duration(milliseconds: 50),
      );
      coordinator = InitialFleetSyncCoordinator(
        fleetRepository: fleetRepository,
        liveFleetProvider: liveFleetProvider,
        webSocketService: webSocketService,
      );
    });

    tearDown(() {
      coordinator.dispose();
      liveFleetProvider.dispose();
      webSocketService.dispose();
    });

    test(
      'INT-FLEET-01: Authenticated GET /api/devices returns real devices from local Traccar',
      () async {
        // 1. Authenticate session
        final loginResult = await authRepository.login(
          email: validEmail,
          password: validPassword,
        );
        expect(loginResult.isRight(), isTrue);

        // 2. Fetch fleet devices
        final devicesResult = await fleetRepository.getDevices();
        expect(devicesResult.isRight(), isTrue);
        devicesResult.fold(
          (f) => fail('Failed to fetch devices: ${f.message}'),
          (devices) {
            expect(
              devices.isNotEmpty,
              isTrue,
              reason: 'Expected at least 1 seed device in Traccar DB',
            );
            final firstDev = devices.first;
            expect(firstDev.id, greaterThan(0));
            expect(firstDev.name.isNotEmpty, isTrue);
            expect(firstDev.uniqueId.isNotEmpty, isTrue);
          },
        );
      },
    );

    test(
      'INT-FLEET-02: Authenticated GET /api/positions returns real position list from local Traccar',
      () async {
        // 1. Authenticate session
        final loginResult = await authRepository.login(
          email: validEmail,
          password: validPassword,
        );
        expect(loginResult.isRight(), isTrue);

        // 2. Fetch latest positions
        final positionsResult = await fleetRepository.getPositions();
        expect(positionsResult.isRight(), isTrue);
        positionsResult.fold(
          (f) => fail('Failed to fetch positions: ${f.message}'),
          (positions) {
            // Positions array may be empty if no tracker has reported yet, but call must succeed
            expect(positions, isA<List>());
          },
        );
      },
    );

    test(
      'INT-FLEET-03: Unauthenticated GET /api/devices returns HTTP 401 AuthFailure',
      () async {
        // Ensure cookie jar is empty
        cookieJar.clear();

        final result = await fleetRepository.getDevices();
        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.statusCode, equals(401));
        }, (_) => fail('Unauthenticated request must not return devices'));
      },
    );

    test(
      'INT-FLEET-04: Dual-fetch synchronization end-to-end against live backend succeeds and seeds provider',
      () async {
        // 1. Authenticate
        final loginResult = await authRepository.login(
          email: validEmail,
          password: validPassword,
        );
        expect(loginResult.isRight(), isTrue);

        // 2. Execute full synchronization via InitialFleetSyncCoordinator
        final syncResult = await coordinator.synchronizeFleet();

        expect(syncResult.isSuccess, isTrue);
        expect(coordinator.isReady, isTrue);
        expect(liveFleetProvider.devices.isNotEmpty, isTrue);

        // Wait for WebSocket handshake
        await Future.delayed(const Duration(milliseconds: 300));
        expect(
          webSocketService.state,
          equals(WebSocketConnectionState.connected),
        );
      },
    );
  });
}
