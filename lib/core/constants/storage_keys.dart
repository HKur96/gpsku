// Storage Keys for Platform Secure Storage & Local Shared Preferences

class StorageKeys {
  StorageKeys._();

  // Secure Storage Keys (Platform Keystore / Keychain)
  static const String savedEmail = 'saved_email';
  static const String savedPassword = 'saved_password';
  static const String rememberMeEnabled = 'remember_me_enabled';
  static const String savedSessionCookie = 'saved_session_cookie';

  // Shared Preferences Keys (Non-sensitive configurations)
  static const String serverBaseUrl = 'server_base_url';
  static const String mapStyle = 'map_style';
  static const String soundAlertEnabled = 'sound_alert_enabled';
}
