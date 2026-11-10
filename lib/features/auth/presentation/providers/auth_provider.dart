import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  totpRequired,
  failure,
}

/// Core authentication state manager using ChangeNotifier.
class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;
  final VoidCallback? onCancelReAuth;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  bool _isRememberMe = false;
  String? _savedEmail;

  AuthProvider({required this.authRepository, this.onCancelReAuth});

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isRememberMe => _isRememberMe;
  String? get savedEmail => _savedEmail;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;

  /// Canonical developer/emulator access check reusing active session & [UserModel] role flags.
  bool get canAccessDeveloperTools =>
      isAuthenticated && (_currentUser?.isDeveloperModeAllowed ?? false);

  /// Validates session on startup or restores saved email/credentials.
  Future<void> checkInitialAuth() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    // Check for saved credentials / Remember Me preference first
    final credsResult = await authRepository.getSavedCredentials();
    credsResult.fold((_) {}, (creds) {
      _savedEmail = creds.email;
      _isRememberMe = creds.rememberMe;
    });

    // Try validating existing active HTTP session
    final sessionResult = await authRepository.getCurrentSession();
    sessionResult.fold(
      (failure) async {
        // If session is expired but we have saved credentials, try transparent re-login
        if (_isRememberMe && _savedEmail != null) {
          final creds = credsResult.getOrElse(
            (_) => (email: null, password: null, rememberMe: false),
          );
          if (creds.password != null && creds.password!.isNotEmpty) {
            final reauthSuccess = await transparentReAuth();
            if (reauthSuccess) return;
          }
        }
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      },
      (user) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
      },
    );
  }

  /// Performs user login with email and password, plus optional 2FA code.
  Future<bool> login({
    required String email,
    required String password,
    String? code,
    bool rememberMe = false,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    final result = await authRepository.login(
      email: email,
      password: password,
      code: code,
      rememberMe: rememberMe,
    );

    return result.fold(
      (failure) {
        if (failure.message == 'TOTP_REQUIRED') {
          _status = AuthStatus.totpRequired;
          _errorMessage = '2FA verification code required.';
        } else {
          _status = AuthStatus.failure;
          _errorMessage = failure.message;
        }
        notifyListeners();
        return false;
      },
      (user) {
        _currentUser = user;
        _isRememberMe = rememberMe;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      },
    );
  }

  /// Transparent re-authentication hook invoked by QueuedReAuthInterceptor on 401.
  Future<bool> transparentReAuth() async {
    final credsResult = await authRepository.getSavedCredentials();
    return credsResult.fold((_) => false, (creds) async {
      if (creds.email == null || creds.password == null) return false;

      final result = await authRepository.login(
        email: creds.email!,
        password: creds.password!,
        rememberMe: true,
      );

      return result.fold(
        (failure) {
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false;
        },
        (user) {
          _currentUser = user;
          _status = AuthStatus.authenticated;
          notifyListeners();
          return true;
        },
      );
    });
  }

  /// Signs the user out, clearing session cookie and sensitive credentials.
  Future<void> logout() async {
    onCancelReAuth?.call();
    await authRepository.logout();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Called when session has definitively expired.
  void handleSessionExpired() {
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = 'Session expired. Please log in again.';
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
