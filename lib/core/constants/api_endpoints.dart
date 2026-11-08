// Official Traccar REST API & WebSocket Endpoints

class ApiEndpoints {
  ApiEndpoints._();

  // Authentication & Session
  static const String session = '/api/session';
  static const String server = '/api/server';
  static const String users = '/api/users';

  // Fleet & Telematics
  static const String devices = '/api/devices';
  static const String positions = '/api/positions';
  static const String events = '/api/events';
  static const String geofences = '/api/geofences';
  static const String groups = '/api/groups';
  static const String drivers = '/api/drivers';
  static const String notifications = '/api/notifications';
  static const String reports = '/api/reports';
  static const String reportsRoute = '/api/reports/route';
  static const String reportsTrips = '/api/reports/trips';
  static const String reportsStops = '/api/reports/stops';
  static const String commands = '/api/commands';
  static const String commandsTypes = '/api/commands/types';
  static const String commandsSend = '/api/commands/send';
  static const String permissions = '/api/permissions';

  // Native WebSocket Endpoint
  static const String socket = '/api/socket';

  // Video Streaming
  static String liveStream(int deviceId, int channel) =>
      '/api/stream/$deviceId/$channel/live.m3u8';
}
