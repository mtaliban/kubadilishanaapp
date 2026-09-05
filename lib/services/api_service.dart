/// HTTP API client — Dio with auth interceptors, caching, retries.
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  late final Dio _dio;
  String? _token;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired — clear auth
          clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kv_token', token);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('kv_token');
    return _token;
  }

  Future<void> removeToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kv_token');
  }

  // ── Generic methods ──
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(path, data: data);

  // ── Auth ──
  Future<Response> login(String identifier, String password) =>
      post('${ApiConfig.auth}/login', data: {
        'identifier': identifier,
        'password': password,
      });

  Future<Response> adminLogin(String email, String password) =>
      post('${ApiConfig.auth}/admin/login', data: {
        'email': email,
        'password': password,
      });

  Future<Response> register(Map<String, dynamic> data) =>
      post('${ApiConfig.auth}/register', data: data);

  Future<Response> getMe() => get('${ApiConfig.auth}/me');

  Future<Response> forgotPassword(String phone) =>
      post('${ApiConfig.auth}/forgot-password', data: {'phone': phone});

  Future<Response> resetPassword(Map<String, dynamic> data) =>
      post('${ApiConfig.auth}/reset-password', data: data);

  Future<Response> checkPhone(String phone) =>
      get('${ApiConfig.auth}/check-phone/$phone');

  Future<Response> lookupByName(String name, String phone) =>
      post('${ApiConfig.auth}/lookup-by-name', data: {
        'full_name': name,
        'phone_primary': phone,
      });

  // ── FCM Token ──
  Future<Response> registerFcmToken(String token) =>
      post('${ApiConfig.auth}/fcm-token', data: {'token': token});

  Future<Response> removeFcmToken(String token) =>
      delete('${ApiConfig.auth}/fcm-token', data: {'token': token});

  // ── Dashboard ──
  Future<Response> getDashboard({Map<String, dynamic>? params}) =>
      get('/dashboard', queryParameters: params);

  // ── Profile ──
  Future<Response> updateProfile(Map<String, dynamic> data) =>
      put('/users/me', data: data);

  // ── Regions / Districts / Facilities ──
  Future<Response> getRegions() => get(ApiConfig.regions);
  Future<Response> getDistricts(int regionId) =>
      get('${ApiConfig.districts}?region_id=$regionId');
  Future<Response> getFacilities(int districtId) =>
      get('${ApiConfig.facilities}?district_id=$districtId');
  Future<Response> getCadres() => get(ApiConfig.cadres);
  Future<Response> getSubjects() => get(ApiConfig.subjects);
  Future<Response> getDepartments() => get(ApiConfig.departments);

  // ── Payments ──
  Future<Response> createPayment(Map<String, dynamic> data) =>
      post('${ApiConfig.payments}/donate', data: data);

  Future<Response> getPaymentStatus(String orderId) =>
      get('${ApiConfig.payments}/status/$orderId');

  // ── Feedback ──
  Future<Response> submitFeedback(Map<String, dynamic> data) =>
      post(ApiConfig.feedback, data: data);

  Future<Response> getMyFeedback() => get(ApiConfig.feedback);

  Future<Response> replyFeedback(String id, String message) =>
      post('${ApiConfig.feedback}/$id/reply', data: {'message': message});

  // ── Notifications ──
  Future<Response> getNotifications({int limit = 50}) =>
      get('${ApiConfig.notifications}?limit=$limit');

  Future<Response> getUnreadCount() =>
      get('${ApiConfig.notifications}/unread-count');

  Future<Response> markAllRead() =>
      post('${ApiConfig.notifications}/read-all');

  // ── Announcements ──
  Future<Response> getAnnouncements() => get(ApiConfig.announcements);

  // ── Admin ──
  Future<Response> adminStats() => get('${ApiConfig.admin}/stats');
  Future<Response> adminUsers({Map<String, dynamic>? params}) =>
      get('${ApiConfig.admin}/users', queryParameters: params);
  Future<Response> adminCreateUser(Map<String, dynamic> data) =>
      post('${ApiConfig.admin}/users', data: data);
  Future<Response> adminUpdateUser(String id, Map<String, dynamic> data) =>
      put('${ApiConfig.admin}/users/$id', data: data);
  Future<Response> adminDeleteUser(String id) =>
      delete('${ApiConfig.admin}/users/$id');
  Future<Response> adminGrant(String userId) =>
      post('${ApiConfig.admin}/users/$userId/grant-admin');
  Future<Response> adminRevoke(String userId) =>
      post('${ApiConfig.admin}/users/$userId/revoke-admin');

  // ── Contacts ──
  Future<Response> getContactActivity() =>
      get('${ApiConfig.messaging}/admin/contacts');
  Future<Response> logContact(String userId, String type) =>
      post('${ApiConfig.messaging}/call', data: {
        'to_user_id': userId,
        'contact_type': type,
      });
}
