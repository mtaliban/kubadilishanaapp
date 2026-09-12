/// HTTP API client — Dio with auth interceptors, caching, retries.
library;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';
import 'app_cache.dart';

// Reusable TTL constants so call sites are self-documenting.
const _ttlStatic    = Duration(minutes: 30); // regions, cadres, departments
const _ttlSemiStatic = Duration(minutes: 15); // districts, facilities
const _ttlNormal    = Duration(minutes: 5);  // matches, profiles, admin lists
const _ttlShort     = Duration(minutes: 2);  // dashboard, stats

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
          clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

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

  // ── Helpers ──
  static String _cacheKey(String path, Map<String, dynamic>? q) {
    if (q == null || q.isEmpty) return path;
    final sorted = q.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return '$path?${sorted.map((e) => '${e.key}=${e.value}').join('&')}';
  }

  // ── Generic methods ──

  /// GET with optional in-memory cache.
  /// Pass [useCache: false] to force a fresh network call (e.g. pull-to-refresh).
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool useCache = true,
    Duration cacheTtl = _ttlNormal,
  }) async {
    final key = _cacheKey(path, queryParameters);
    if (useCache) {
      final cached = AppCache().get(key);
      if (cached != null) {
        return Response(
          data: cached,
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
        );
      }
    }
    final response = await _dio.get(path, queryParameters: queryParameters);
    if (useCache && response.statusCode == 200) {
      AppCache().set(key, response.data, ttl: cacheTtl);
    }
    return response;
  }

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);
  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);
  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.delete(path, data: data, queryParameters: queryParameters);

  // ── Auth ──
  Future<Response> login(String phone, {String? password}) =>
      post('/auth/login', data: {
        'phone': phone,
        if (password != null && password.isNotEmpty) 'password': password,
      });

  Future<Response> adminLoginStep1(String email, String password) =>
      post('/auth/admin/login', data: {'email': email, 'password': password});

  Future<Response> adminLoginOtp(String email, String code) =>
      post('/auth/login/2fa', data: {'email': email, 'code': code});

  Future<Response> register(Map<String, dynamic> data) =>
      post('/auth/register', data: data);

  Future<Response> getMe() => get('/auth/me', useCache: false);

  Future<Response> forgotPassword(String phone, {String? fullName}) =>
      post('/auth/forgot-password', data: {
        'phone': phone,
        if (fullName != null) 'full_name': fullName,
      });

  Future<Response> resetPassword(String phone, String newPassword) =>
      post('/auth/reset-password', data: {
        'phone': phone,
        'new_password': newPassword,
      });

  Future<Response> checkPhone(String phone) =>
      get('/auth/check-phone/${Uri.encodeComponent(phone)}', useCache: false);

  Future<Response> lookupByName(String name) =>
      post('/auth/lookup-by-name', data: {'full_name': name});

  // ── FCM Token ──
  Future<Response> registerFcmToken(String token) =>
      post('/auth/fcm-token', data: {'token': token});
  Future<Response> removeFcmToken(String token) =>
      delete('/auth/fcm-token', data: {'token': token});

  // ── Dashboard ──
  Future<Response> getDashboard({String scope = 'incoming', int limit = 100}) =>
      get('/matches/board',
          queryParameters: {'scope': scope, 'limit': limit},
          cacheTtl: _ttlShort);

  // ── Matches ──
  Future<Response> getMyMatches({int limit = 100}) =>
      get('/matches/me', queryParameters: {'limit': limit}, cacheTtl: _ttlShort);
  Future<Response> getTrueMatches({int limit = 100}) =>
      get('/matches/true', queryParameters: {'limit': limit}, cacheTtl: _ttlShort);
  Future<Response> getMatchStats() =>
      get('/matches/stats', cacheTtl: _ttlShort);

  // ── Profile / Users ──
  Future<Response> getMyProfile() =>
      get('/users/me', cacheTtl: _ttlShort);
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/users/me');
    AppCache().invalidatePrefix('/auth/me');
    return patch('/users/me', data: data);
  }
  Future<Response> changePassword(String currentPassword, String newPassword) =>
      post('/users/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
  Future<Response> updateNotificationPrefs(Map<String, dynamic> prefs) async {
    AppCache().invalidatePrefix('/users/me');
    return put('/users/me/notification-prefs', data: prefs);
  }
  Future<Response> getFollowedRegions() =>
      get('/users/me/followed-regions', cacheTtl: _ttlNormal);
  Future<Response> updateFollowedRegions(List<dynamic> regionIds) async {
    AppCache().invalidatePrefix('/users/me/followed-regions');
    return put('/users/me/followed-regions', data: {'region_ids': regionIds});
  }
  Future<Response> updateStation(Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/users/me');
    return put('/users/me/station', data: data);
  }
  Future<Response> updateDestinations(List<dynamic> destinations) async {
    AppCache().invalidatePrefix('/users/me');
    return put('/users/me/destinations', data: {'destinations': destinations});
  }
  Future<Response> getUserProfile(String userId) =>
      get('/users/$userId', cacheTtl: _ttlNormal);
  Future<Response> getOnlineUsers() =>
      get('/users/online', useCache: false);
  Future<Response> getRecentUsers({int limit = 20}) =>
      get('/users/recent', queryParameters: {'limit': limit}, cacheTtl: _ttlShort);
  Future<Response> getRecentlyActiveUsers({int minutes = 15}) =>
      get('/users/recently-active',
          queryParameters: {'minutes': minutes},
          useCache: false);

  // ── Locations (static reference data) ──
  Future<Response> getRegions() =>
      get('/locations/regions', cacheTtl: _ttlStatic);
  Future<Response> getDistricts(int regionId) =>
      get('/locations/regions/$regionId/districts', cacheTtl: _ttlSemiStatic);
  Future<Response> getFacilities(int districtId, {String category = 'health'}) =>
      get('/locations/districts/$districtId/facilities',
          queryParameters: {'category': category},
          cacheTtl: _ttlSemiStatic);
  Future<Response> getCadres({String? category}) =>
      get('/cadres',
          queryParameters: category != null ? {'category': category} : null,
          cacheTtl: _ttlStatic);
  Future<Response> getSubjects({String? level}) =>
      get('/cadres/subjects',
          queryParameters: level != null ? {'level': level} : null,
          cacheTtl: _ttlStatic);
  Future<Response> getDepartments() =>
      get('/locations/departments', cacheTtl: _ttlStatic);
  Future<Response> getFacilitiesByRegion(int regionId, {String category = 'health', String? employmentSector}) =>
      get('/locations/regions/$regionId/facilities', queryParameters: {
        'category': category,
        if (employmentSector != null) 'employment_sector': employmentSector,
      }, cacheTtl: _ttlSemiStatic);

  // ── Payments / Donations ──
  Future<Response> getDonationInfo() =>
      get('/payments/info', cacheTtl: _ttlNormal);
  Future<Response> createDonation({
    required int amount,
    required String smsText,
    String? phone,
  }) =>
      post('/payments/donate', data: {
        'amount': amount,
        'sms_text': smsText,
        'purpose': 'donation',
        if (phone != null) 'phone': phone,
      });
  Future<Response> getPaymentStatus(String orderId) =>
      get('/payments/status/$orderId', useCache: false);
  Future<Response> getPaymentHistory() =>
      get('/payments/my-history', cacheTtl: _ttlShort);

  // ── Feedback ──
  Future<Response> submitFeedback({
    required String subject,
    required String message,
  }) =>
      post('/feedback', data: {'subject': subject, 'message': message});
  Future<Response> getMyFeedback({int limit = 50}) =>
      get('/feedback/my', queryParameters: {'limit': limit}, cacheTtl: _ttlShort);

  // ── Notifications (real-time — never cache) ──
  Future<Response> getNotifications({int limit = 50}) =>
      get('/notifications', queryParameters: {'limit': limit}, useCache: false);
  Future<Response> getUnreadCount() =>
      get('/notifications/unread-count', useCache: false);
  Future<Response> markAllRead() async {
    AppCache().invalidatePrefix('/notifications');
    return post('/notifications/read-all');
  }
  Future<Response> markNotificationRead(String notificationId) async {
    AppCache().invalidatePrefix('/notifications');
    return post('/notifications/$notificationId/read');
  }

  // ── Messaging / Presence (real-time) ──
  Future<Response> getCallHistory({int limit = 100}) =>
      get('/messages/calls', queryParameters: {'limit': limit}, cacheTtl: _ttlShort);
  Future<Response> getPresence() =>
      get('/messages/presence', useCache: false);
  Future<Response> getUserPresence(String userId) =>
      get('/messages/presence/$userId', useCache: false);
  Future<Response> sendPaymentMessage(String orderId, String message) =>
      post('/payments/$orderId/message', data: {'message': message});
  Future<Response> getPaymentMessages(String orderId) =>
      get('/payments/$orderId/messages', useCache: false);

  // ── Announcements ──
  Future<Response> getAnnouncements() =>
      get('/announcements/active', cacheTtl: _ttlShort);
  Future<Response> getAnnouncementUnreadCount() =>
      get('/announcements/unread-count', useCache: false);
  Future<Response> dismissAnnouncement(String announcementId) async {
    AppCache().invalidatePrefix('/announcements');
    return post('/announcements/$announcementId/dismiss');
  }

  // ── Admin ──
  Future<Response> adminStats() =>
      get('/admin/stats', cacheTtl: _ttlShort);
  Future<Response> adminUsers({Map<String, dynamic>? params}) =>
      get('/admin/users', queryParameters: params, cacheTtl: _ttlShort);
  Future<Response> adminCreateUser(Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/admin/users');
    return post('/admin/users', data: data);
  }
  Future<Response> adminUpdateUser(String id, Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/admin/users');
    return patch('/admin/users/$id', data: data);
  }
  Future<Response> adminDeleteUser(String id) async {
    AppCache().invalidatePrefix('/admin/users');
    return delete('/admin/users/$id');
  }
  Future<Response> adminGrant(String userId) async {
    AppCache().invalidatePrefix('/admin/users');
    return post('/admin/users/$userId/grant-admin');
  }
  Future<Response> adminRevoke(String userId) async {
    AppCache().invalidatePrefix('/admin/users');
    return post('/admin/users/$userId/revoke-admin');
  }
  Future<Response> adminAllDonations({String? status}) =>
      get('/payments/admin/all',
          queryParameters: status != null ? {'status': status} : null,
          cacheTtl: _ttlShort);
  Future<Response> adminApproveDonation(String orderId, {String? note}) async {
    AppCache().invalidatePrefix('/payments/admin');
    return post('/payments/admin/$orderId/approve', data: {'note': note});
  }
  Future<Response> adminRejectDonation(String orderId, {String? note}) async {
    AppCache().invalidatePrefix('/payments/admin');
    return post('/payments/admin/$orderId/reject', data: {'note': note});
  }
  Future<Response> adminListFeedback({String status = '', String q = ''}) =>
      get('/feedback/admin/all',
          queryParameters: {'status': status, 'q': q},
          cacheTtl: _ttlShort);
  Future<Response> adminReplyFeedback(String feedbackId, String reply) async {
    AppCache().invalidatePrefix('/feedback/admin');
    return post('/feedback/admin/$feedbackId/reply', data: {'reply': reply});
  }
  Future<Response> adminDeleteFeedback(String feedbackId) async {
    AppCache().invalidatePrefix('/feedback/admin');
    return delete('/feedback/admin/$feedbackId');
  }
  Future<Response> adminListAnnouncements() =>
      get('/admin/announcements', cacheTtl: _ttlShort);
  Future<Response> adminSendAnnouncement(Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/admin/announcements');
    AppCache().invalidatePrefix('/announcements');
    return post('/admin/announcements', data: data);
  }
  Future<Response> adminDeleteAnnouncement(String id) async {
    AppCache().invalidatePrefix('/admin/announcements');
    AppCache().invalidatePrefix('/announcements');
    return delete('/admin/announcements/$id');
  }
  Future<Response> adminListMatches({int limit = 100}) =>
      get('/admin/matches', queryParameters: {'limit': limit}, cacheTtl: _ttlShort);
  Future<Response> adminRealMatches({String? category, String? cadreCode, int limit = 100}) =>
      get('/admin/real-matches', queryParameters: {
        if (category != null) 'category': category,
        if (cadreCode != null) 'cadre_code': cadreCode,
        'limit': limit,
      }, cacheTtl: _ttlShort);
  Future<Response> adminReports({int days = 365, String? region, String? category, String? level}) =>
      get('/admin/reports', queryParameters: {
        'days': days,
        if (region != null && region.isNotEmpty) 'region': region,
        if (category != null && category.isNotEmpty) 'category': category,
        if (level != null && level.isNotEmpty) 'level': level,
      }, cacheTtl: _ttlShort);
  Future<Response> adminListDepartments() =>
      get('/admin/departments', cacheTtl: _ttlSemiStatic);
  Future<Response> adminEvents({String? eventType, int limit = 100, int skip = 0}) =>
      get('/admin/events', queryParameters: {
        if (eventType != null) 'event_type': eventType,
        'limit': limit,
        'skip': skip,
      }, cacheTtl: _ttlShort);
  Future<Response> adminClearEvents() async {
    AppCache().invalidatePrefix('/admin/events');
    return post('/admin/events/clear');
  }
  Future<Response> getContactActivity({int limit = 100}) =>
      get('/messages/admin/contacts',
          queryParameters: {'limit': limit},
          cacheTtl: _ttlShort);
  Future<Response> logContact(String userId, String type) =>
      post('/messages/call', data: {'to_user_id': userId, 'contact_type': type});
  Future<Response> adminListPasswordResets({String status = 'pending'}) =>
      get('/admin/password-resets',
          queryParameters: {'status': status},
          cacheTtl: _ttlShort);
  Future<Response> adminApprovePasswordReset(String resetId) async {
    AppCache().invalidatePrefix('/admin/password-resets');
    return post('/admin/password-resets/$resetId/approve');
  }
  Future<Response> adminRejectPasswordReset(String resetId) async {
    AppCache().invalidatePrefix('/admin/password-resets');
    return post('/admin/password-resets/$resetId/reject');
  }
  Future<Response> adminGetSettings() =>
      get('/admin/settings/contact', cacheTtl: _ttlShort);
  Future<Response> adminUpdateContactSettings(bool requirePayment) async {
    AppCache().invalidatePrefix('/admin/settings');
    return put('/admin/settings/contact', data: {'require_payment': requirePayment});
  }
  Future<Response> adminToggleContact(String userId) async {
    AppCache().invalidatePrefix('/admin/users/$userId');
    return patch('/admin/users/$userId/contact-toggle');
  }
  Future<Response> adminGetData(String type) =>
      get('/admin/data/$type', cacheTtl: _ttlSemiStatic);
  Future<Response> adminGetUserMatches(String userId) =>
      get('/admin/users/$userId/matches', cacheTtl: _ttlShort);
  Future<Response> adminGetUserBoard(String userId) =>
      get('/admin/users/$userId/board', cacheTtl: _ttlShort);
  Future<Response> adminImportUsers(dynamic formData) async {
    AppCache().invalidatePrefix('/admin/users');
    return post('/admin/users/import', data: formData);
  }
  Future<Response> adminGetMonitoring() =>
      get('/admin/monitoring', cacheTtl: _ttlShort);
  Future<Response> adminListData(String type) =>
      get('/admin/data/$type', cacheTtl: _ttlSemiStatic);
  Future<Response> adminCreateData(String type, Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/admin/data/$type');
    return post('/admin/data/$type', data: data);
  }
  Future<Response> adminUpdateData(String type, String id, Map<String, dynamic> data) async {
    AppCache().invalidatePrefix('/admin/data/$type');
    return patch('/admin/data/$type/$id', data: data);
  }
  Future<Response> adminDeleteData(String type, String id) async {
    AppCache().invalidatePrefix('/admin/data/$type');
    return delete('/admin/data/$type/$id');
  }
  Future<Response> adminListCsvs() =>
      get('/admin/csv/list', cacheTtl: _ttlShort);
  Future<Response> adminExportCsv(String type) =>
      post('/admin/csv/export', data: {'type': type});
  Future<Response> adminDownloadCsv(String name) =>
      get('/admin/csv/download/$name', useCache: false);
  Future<Response> adminResendAnnouncement(String id) async {
    AppCache().invalidatePrefix('/admin/announcements');
    return post('/admin/announcements/$id/resend');
  }
  Future<Response> adminPaymentReply(String orderId, String message) =>
      post('/payments/admin/$orderId/reply', data: {'message': message});
  Future<Response> getDataVersion() =>
      get('/locations/data-version', cacheTtl: _ttlStatic);
}
