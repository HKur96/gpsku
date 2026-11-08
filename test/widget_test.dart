import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/network/session_cookie_jar.dart';
import 'package:gpsku/core/security/secure_storage_service.dart';
import 'package:gpsku/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gpsku/features/auth/data/models/user_model.dart';
import 'package:gpsku/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gpsku/features/auth/presentation/providers/auth_provider.dart';
import 'package:gpsku/features/auth/presentation/screens/login_screen.dart';
import 'package:provider/provider.dart';

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<UserModel> login({
    required String email,
    required String password,
    String? code,
  }) async {
    return const UserModel(id: 1, name: 'Admin', email: 'admin@gpsku.id');
  }

  @override
  Future<UserModel> getCurrentSession() async {
    throw Exception('No session');
  }

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('LoginScreen bootstrap smoke test', (WidgetTester tester) async {
    final remote = _FakeAuthRemoteDataSource();
    final storage = SecureStorageService();
    final cookieJar = SessionCookieJar();
    final repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      secureStorage: storage,
      cookieJar: cookieJar,
    );
    final authProvider = AuthProvider(authRepository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const LoginScreen(),
        ),
      ),
    );

    // Verify key bootstrap UI widgets are rendered
    expect(find.text('GPSku Telematics'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember Me'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
