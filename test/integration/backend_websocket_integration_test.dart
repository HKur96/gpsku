import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/config/app_config.dart';
import 'package:gpsku/core/network/dio_client.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/security/secure_storage_service.dart';
import 'package:gpsku/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gpsku/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gpsku/features/fleet/data/datasources/traccar_websocket_service.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();
  FlutterSecureStorage.setMockInitialValues({});

  group('Traccar Backend Live Integration Tests (WebSocket /api/socket)', () {
    const backendBaseUrl = 'http://localhost:8082';
    const validEmail = 'admin@gps.local';
    const validPassword = 'Password123!';

    late SessionCookieJar cookieJar;
    late AppConfig appConfig;
    late DioClient dioClient;
    late AuthRemoteDataSource remoteDataSource;
    late SecureStorageService secureStorage;
    late AuthRepositoryImpl authRepository;

    setUp(() async {
      HttpOverrides.global = RealHttpOverrides();
      cookieJar = SessionCookieJar();
      appConfig = const AppConfig(baseUrl: backendBaseUrl);
      dioClient = DioClient(appConfig: appConfig, cookieJar: cookieJar);
      remoteDataSource = AuthRemoteDataSourceImpl(dioClient: dioClient);
      secureStorage = SecureStorageService();
      authRepository = AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        secureStorage: secureStorage,
        cookieJar: cookieJar,
      );

      // Perform real login to obtain valid JSESSIONID cookie
      final loginResult = await authRepository.login(
        email: validEmail,
        password: validPassword,
      );
      expect(loginResult.isRight(), isTrue, reason: 'Setup login must succeed');
      expect(cookieJar.hasValidSession, isTrue);
    });

    test(
      'INT-WS-01 & 02: Authenticated WebSocket handshake and initial packet reception',
      () async {
        final wsService = TraccarWebSocketService(
          appConfig: appConfig,
          cookieJar: cookieJar,
        );

        final messageCompleter = Completer<Map<String, dynamic>>();
        final states = <WebSocketConnectionState>[];

        final stateSub = wsService.stateStream.listen((state) {
          states.add(state);
        });

        final msgSub = wsService.messageStream.listen((msg) {
          if (!messageCompleter.isCompleted) {
            messageCompleter.complete(msg);
          }
        });

        await wsService.connect();

        // Verify connection state transition
        expect(wsService.state, equals(WebSocketConnectionState.connected));

        // Wait for the initial positions synchronization payload
        final receivedMsg = await messageCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Timed out waiting for initial WebSocket packet',
          ),
        );

        expect(receivedMsg, isNotNull);
        // Traccar AsyncSocket sends {"positions": [...]} on handshake completion
        expect(receivedMsg.containsKey('positions'), isTrue);
        expect(receivedMsg['positions'], isA<List>());

        await stateSub.cancel();
        await msgSub.cancel();
        wsService.dispose();
      },
    );

    test(
      'INT-WS-03: Invalid / expired session cookie is rejected by backend',
      () async {
        final invalidCookieJar = SessionCookieJar();
        // Inject dummy expired/invalid session cookie
        invalidCookieJar.saveFromSetCookieHeaders([
          'JSESSIONID=invalid_session_deadbeef_0000; Path=/; HttpOnly',
        ]);
        expect(invalidCookieJar.hasValidSession, isTrue);

        final wsService = TraccarWebSocketService(
          appConfig: appConfig,
          cookieJar: invalidCookieJar,
        );

        final states = <WebSocketConnectionState>[];
        final stateSub = wsService.stateStream.listen((state) {
          states.add(state);
        });

        await wsService.connect();

        // Allow handshake negotiation to fail on backend
        await Future<void>.delayed(const Duration(milliseconds: 1500));

        // Because server rejects with 403 or closes socket, service should transition away from connected
        expect(wsService.state != WebSocketConnectionState.connected, isTrue);

        await stateSub.cancel();
        wsService.dispose();
      },
    );

    test('INT-WS-04: Manual disconnect halts reconnection cycle', () async {
      final wsService = TraccarWebSocketService(
        appConfig: appConfig,
        cookieJar: cookieJar,
      );

      await wsService.connect();
      expect(wsService.state, equals(WebSocketConnectionState.connected));

      wsService.disconnect();
      expect(wsService.state, equals(WebSocketConnectionState.disconnected));

      // Wait to ensure no reconnect timer triggers
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(wsService.state, equals(WebSocketConnectionState.disconnected));

      wsService.dispose();
    });

    test(
      'INT-WS-05: Missing cookie prevents connection attempt gracefully',
      () async {
        final emptyCookieJar = SessionCookieJar();
        final wsService = TraccarWebSocketService(
          appConfig: appConfig,
          cookieJar: emptyCookieJar,
        );

        await wsService.connect();
        expect(wsService.state, equals(WebSocketConnectionState.disconnected));
        wsService.dispose();
      },
    );
  });
}
