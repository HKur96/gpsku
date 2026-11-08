import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:requests_inspector/requests_inspector.dart';

import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'core/network/session_cookie_jar.dart';
import 'core/routing/app_router.dart';
import 'core/security/secure_storage_service.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/fleet/data/datasources/fleet_remote_data_source.dart';
import 'features/fleet/data/datasources/traccar_websocket_service.dart';
import 'features/fleet/data/repositories/fleet_repository_impl.dart';
import 'features/fleet/domain/repositories/fleet_repository.dart';
import 'features/fleet/presentation/coordinators/initial_fleet_sync_coordinator.dart';
import 'features/fleet/presentation/providers/live_fleet_provider.dart';
import 'features/reports/data/datasources/reports_remote_data_source.dart';
import 'features/reports/data/repositories/reports_repository_impl.dart';
import 'features/reports/domain/repositories/reports_repository.dart';
import 'features/commands/data/datasources/commands_remote_data_source.dart';
import 'features/commands/data/repositories/commands_repository_impl.dart';
import 'features/commands/domain/repositories/commands_repository.dart';
import 'features/geofences/data/datasources/geofences_remote_data_source.dart';
import 'features/geofences/data/repositories/geofences_repository_impl.dart';
import 'features/geofences/domain/repositories/geofences_repository.dart';
import 'features/geofences/presentation/providers/geofences_provider.dart';
import 'features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'features/maintenance/domain/repositories/maintenance_repository.dart';
import 'features/maintenance/presentation/providers/maintenance_provider.dart';
import 'features/drivers/data/datasources/drivers_remote_data_source.dart';
import 'features/drivers/data/repositories/drivers_repository_impl.dart';
import 'features/drivers/domain/repositories/drivers_repository.dart';
import 'features/drivers/presentation/providers/drivers_provider.dart';
import 'features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'features/notifications/data/repositories/notifications_repository_impl.dart';
import 'features/notifications/domain/repositories/notifications_repository.dart';
import 'features/notifications/domain/services/event_stream_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Core configurations & persistent infrastructure
  const appConfig = AppConfig();
  final cookieJar = SessionCookieJar();
  final secureStorage = SecureStorageService();

  // Late reference for resolving circular re-auth interceptor dependency
  late final AuthProvider authProvider;

  final dioClient = DioClient(
    appConfig: appConfig,
    cookieJar: cookieJar,
    onReAuth: () => authProvider.transparentReAuth(),
    onSessionExpired: () => authProvider.handleSessionExpired(),
  );

  final authRemoteDataSource = AuthRemoteDataSourceImpl(dioClient: dioClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    secureStorage: secureStorage,
    cookieJar: cookieJar,
  );

  authProvider = AuthProvider(
    authRepository: authRepository,
    onCancelReAuth: () => dioClient.reAuthInterceptor?.cancelActiveReAuth(),
  );

  final webSocketService = TraccarWebSocketService(
    appConfig: appConfig,
    cookieJar: cookieJar,
  );

  final liveFleetProvider = LiveFleetProvider(
    webSocketService: webSocketService,
  );

  final fleetRemoteDataSource = FleetRemoteDataSourceImpl(dioClient: dioClient);
  final fleetRepository = FleetRepositoryImpl(
    remoteDataSource: fleetRemoteDataSource,
  );
  final fleetSyncCoordinator = InitialFleetSyncCoordinator(
    fleetRepository: fleetRepository,
    liveFleetProvider: liveFleetProvider,
    webSocketService: webSocketService,
  );

  final reportsRemoteDataSource = ReportsRemoteDataSourceImpl(
    dioClient: dioClient,
  );
  final reportsRepository = ReportsRepositoryImpl(
    remoteDataSource: reportsRemoteDataSource,
  );

  final commandsRemoteDataSource = CommandsRemoteDataSourceImpl(
    dioClient: dioClient,
  );
  final commandsRepository = CommandsRepositoryImpl(
    remoteDataSource: commandsRemoteDataSource,
  );

  final geofencesRemoteDataSource = GeofencesRemoteDataSourceImpl(
    dioClient: dioClient,
  );
  final geofencesRepository = GeofencesRepositoryImpl(
    remoteDataSource: geofencesRemoteDataSource,
  );
  final geofencesProvider = GeofencesProvider(repository: geofencesRepository);

  final maintenanceRemoteDataSource = MaintenanceRemoteDataSourceImpl(
    dioClient: dioClient,
  );
  final maintenanceRepository = MaintenanceRepositoryImpl(
    remoteDataSource: maintenanceRemoteDataSource,
  );
  final maintenanceProvider = MaintenanceProvider(
    repository: maintenanceRepository,
  );

  final driversRemoteDataSource = DriversRemoteDataSourceImpl(
    dioClient: dioClient,
  );
  final driversRepository = DriversRepositoryImpl(
    remoteDataSource: driversRemoteDataSource,
  );
  final driversProvider = DriversProvider(repository: driversRepository);

  final notificationsRemoteDataSource = NotificationsRemoteDataSourceImpl(
    dioClient: dioClient,
  );
  final notificationsRepository = NotificationsRepositoryImpl(
    remoteDataSource: notificationsRemoteDataSource,
  );
  final eventStreamService = EventStreamService(
    webSocketService: webSocketService,
  );

  final appRouter = AppRouter(authProvider: authProvider);

  // Validate initial authentication status in background
  authProvider.checkInitialAuth();

  runApp(
    RequestsInspector(
      enabled: !kReleaseMode,
      child: MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: appConfig),
          Provider<SessionCookieJar>.value(value: cookieJar),
          Provider<SecureStorageService>.value(value: secureStorage),
          Provider<DioClient>.value(value: dioClient),
          Provider<AuthRepository>.value(value: authRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          Provider<TraccarWebSocketService>.value(value: webSocketService),
          ChangeNotifierProvider<LiveFleetProvider>.value(
            value: liveFleetProvider,
          ),
          Provider<FleetRemoteDataSource>.value(value: fleetRemoteDataSource),
          Provider<FleetRepository>.value(value: fleetRepository),
          Provider<ReportsRemoteDataSource>.value(
            value: reportsRemoteDataSource,
          ),
          Provider<ReportsRepository>.value(value: reportsRepository),
          Provider<CommandsRemoteDataSource>.value(
            value: commandsRemoteDataSource,
          ),
          Provider<CommandsRepository>.value(value: commandsRepository),
          Provider<GeofencesRemoteDataSource>.value(
            value: geofencesRemoteDataSource,
          ),
          Provider<GeofencesRepository>.value(value: geofencesRepository),
          Provider<MaintenanceRemoteDataSource>.value(
            value: maintenanceRemoteDataSource,
          ),
          Provider<MaintenanceRepository>.value(value: maintenanceRepository),
          Provider<DriversRemoteDataSource>.value(
            value: driversRemoteDataSource,
          ),
          Provider<DriversRepository>.value(value: driversRepository),
          Provider<NotificationsRemoteDataSource>.value(
            value: notificationsRemoteDataSource,
          ),
          Provider<NotificationsRepository>.value(
            value: notificationsRepository,
          ),
          Provider<EventStreamService>.value(value: eventStreamService),
          ChangeNotifierProvider<GeofencesProvider>.value(
            value: geofencesProvider,
          ),
          ChangeNotifierProvider<MaintenanceProvider>.value(
            value: maintenanceProvider,
          ),
          ChangeNotifierProvider<DriversProvider>.value(value: driversProvider),
          ChangeNotifierProvider<InitialFleetSyncCoordinator>.value(
            value: fleetSyncCoordinator,
          ),
        ],
        child: GPSkuApp(appRouter: appRouter),
      ),
    ),
  );
}

class GPSkuApp extends StatelessWidget {
  final AppRouter appRouter;

  const GPSkuApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GPSku Telematics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF1E88E5),
          secondary: const Color(0xFF00ACC1),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
      ),
      routerConfig: appRouter.router,
    );
  }
}
