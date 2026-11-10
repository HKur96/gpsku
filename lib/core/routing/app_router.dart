import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/emulator/presentation/widgets/telemetry_emulator_sheet.dart';
import '../../features/fleet/presentation/screens/fleet_shell_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/reports/presentation/screens/route_history_screen.dart';
import '../../features/settings/presentation/screens/app_settings_screen.dart';

/// Application router configuration using GoRouter with declarative auth redirection.
class AppRouter {
  final AuthProvider authProvider;

  static const Set<String> _developerRoutes = {
    '/emulator',
    '/settings/developer',
    '/settings/emulator',
  };

  AppRouter({required this.authProvider});

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthenticating =
          authProvider.status == AuthStatus.authenticating ||
          authProvider.status == AuthStatus.initial;
      final isLoggingIn = state.matchedLocation == '/login';

      if (isAuthenticating) {
        return null; // Stay on current screen while verifying session
      }

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      if (isAuthenticated && isLoggingIn) {
        return '/';
      }

      if (_developerRoutes.contains(state.matchedLocation) &&
          !authProvider.canAccessDeveloperTools) {
        return '/settings';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const FleetShellScreen(),
      ),
      GoRoute(
        path: '/route-history',
        name: 'route-history',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final deviceId = extra['deviceId'] as int? ?? 0;
          final deviceName = extra['deviceName'] as String? ?? 'Kendaraan';
          return RouteHistoryScreen(deviceId: deviceId, deviceName: deviceName);
        },
      ),
      GoRoute(
        path: '/notification-settings',
        name: 'notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const AppSettingsScreen(),
        routes: [
          GoRoute(
            path: 'developer',
            name: 'settings-developer',
            builder: (context, state) => const AppSettingsScreen(),
          ),
          GoRoute(
            path: 'emulator',
            name: 'settings-emulator',
            builder: (context, state) =>
                const TelemetryEmulatorSheet(isFullScreen: true),
          ),
        ],
      ),
      GoRoute(
        path: '/emulator',
        name: 'emulator',
        builder: (context, state) =>
            const TelemetryEmulatorSheet(isFullScreen: true),
      ),
    ],
  );
}
