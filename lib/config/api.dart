/// API configuration — base URL, WebSocket URL, timeouts.
class ApiConfig {
  // Production EC2 backend
  static const String baseUrl = 'https://api.16-171-23-21.sslip.io';

  static String get apiUrl => '$baseUrl';
  static String get wsUrl => baseUrl.replaceFirst('http', 'ws');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // API paths
  static const String auth = '/auth';
  static const String admin = '/admin';
  static const String payments = '/payments';
  static const String messaging = '/messages';
  static const String feedback = '/feedback';
  static const String announcements = '/announcements';
  static const String notifications = '/notifications';
  static const String regions = '/regions';
  static const String districts = '/districts';
  static const String facilities = '/facilities';
  static const String cadres = '/cadres';
  static const String subjects = '/subjects';
  static const String departments = '/departments';
  static const String matches = '/matches';
}
