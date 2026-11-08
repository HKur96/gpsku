// Platform Secure Storage Service (Android Keystore + EncryptedSharedPreferences / iOS Keychain)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  /// Saves user credentials securely when Remember Me is enabled.
  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    try {
      await _storage.write(key: StorageKeys.savedEmail, value: email);
      await _storage.write(key: StorageKeys.savedPassword, value: password);
      await _storage.write(key: StorageKeys.rememberMeEnabled, value: 'true');
    } catch (e, stack) {
      AppLogger.error('Failed to save credentials in secure storage', e, stack);
    }
  }

  /// Retrieves saved credentials for auto-fill or transparent re-auth.
  Future<({String? email, String? password})> getSavedCredentials() async {
    try {
      final email = await _storage.read(key: StorageKeys.savedEmail);
      final password = await _storage.read(key: StorageKeys.savedPassword);
      return (email: email, password: password);
    } catch (e, stack) {
      AppLogger.error(
        'Failed to read credentials from secure storage',
        e,
        stack,
      );
      return (email: null, password: null);
    }
  }

  /// Checks if Remember Me is opted in.
  Future<bool> isRememberMeEnabled() async {
    try {
      final val = await _storage.read(key: StorageKeys.rememberMeEnabled);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Clears stored password on logout or session expiration.
  /// If Remember Me was active, retains email for auto-fill convenience.
  Future<void> clearPassword() async {
    try {
      await _storage.delete(key: StorageKeys.savedPassword);
    } catch (e) {
      AppLogger.error('Failed to delete saved password', e);
    }
  }

  /// Completely clears all stored credentials and preferences.
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      AppLogger.error('Failed to clear secure storage', e);
    }
  }

  /// Persists session cookie string for offline/session-resume awareness.
  Future<void> saveSessionCookie(String cookie) async {
    try {
      await _storage.write(key: StorageKeys.savedSessionCookie, value: cookie);
    } catch (_) {}
  }

  /// Reads persisted session cookie string.
  Future<String?> getSavedSessionCookie() async {
    try {
      return await _storage.read(key: StorageKeys.savedSessionCookie);
    } catch (_) {
      return null;
    }
  }

  /// Deletes persisted session cookie.
  Future<void> clearSessionCookie() async {
    try {
      await _storage.delete(key: StorageKeys.savedSessionCookie);
    } catch (_) {}
  }
}
