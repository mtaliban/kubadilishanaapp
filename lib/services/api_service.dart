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

  // ── Generic methods ──
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);
  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);
  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);
  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.delete(path, data: data, queryParameters: queryParameters);

  // ── Auth ──
  /// Login kwa NAMBA YA SIMU tu — password si lazima kwa watumiaji wa kawaida.
  Future<Response> login(String phone, {String? password}) =>
      post('/auth/login', data: {
        'phone': phone,
        if (password != null && password.isNotEmpty) 'password': password,
      });

  /// Admin login (step 1) — email + password → OTP inatumwa kwa email.
  /// Response: {two_factor_required: true, email: ..., message: ...}
  Future<Response> adminLoginStep1(String email, String password) =>
      post('/auth/admin/login', data: {'email': email, 'password': password});

  /// Admin login (step 2) — OTP code → access_token.
  Future<Response> adminLoginOtp(String email, String code) =>
      post('/auth/login/2fa', data: {'email': email, 'code': code});

  Future<Response> register(Map<String, dynamic> data) =>
      post('/auth/register', data: data);

  Future<Response> getMe() => get('/auth/me');

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
      get('/auth/check-phone/${Uri.encodeComponent(phone)}');

  Future<Response> lookupByName(String name) =>
      post('/auth/lookup-by-name', data: {'full_name': name});

  // ── FCM Token ──
  Future<Response> registerFcmToken(String token) =>
      post('/auth/fcm-token', data: {'token': token});
  Future<Response> removeFcmToken(String token) =>
      delete('/auth/fcm-token', data: {'token': token});

  // ── Dashboard (board) ──
  /// Inapata orodha ya watu wanaokuja mkoa wako — endpoint halisi.
  Future<Response> getDashboard({String scope = 'incoming', int limit = 100}) =>
      get('/matches/board', queryParameters: {'scope': scope, 'limit': limit});

  // ── Matches ──
  Future<Response> getMyMatches({int limit = 100}) =>
      get('/matches/me', queryParameters: {'limit': limit});
  Future<Response> getTrueMatches({int limit = 100}) =>
      get('/matches/true', queryParameters: {'limit': limit});
  Future<Response> getMatchStats() => get('/matches/stats');

  // ── Profile / Users ──
  Future<Response> getMyProfile() => get('/users/me');
  Future<Response> updateProfile(Map<String, dynamic> data) =>
      patch('/users/me', data: data);
  Future<Response> changePassword(String currentPassword, String newPassword) =>
      post('/users/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
  Future<Response> updateNotificationPrefs(Map<String, dynamic> prefs) =>
      put('/users/me/notification-prefs', data: prefs);
  Future<Response> getFollowedRegions() => get('/users/me/followed-regions');
  Future<Response> updateFollowedRegions(List<dynamic> regionIds) =>
      put('/users/me/followed-regions', data: {'region_ids': regionIds});
  Future<Response> updateStation(Map<String, dynamic> data) =>
      put('/users/me/station', data: data);
  Future<Response> updateDestinations(List<dynamic> destinations) =>
      put('/users/me/destinations', data: {'destinations': destinations});
  Future<Response> getUserProfile(String userId) => get('/users/$userId');
  Future<Response> getOnlineUsers() => get('/users/online');
  Future<Response> getRecentUsers({int limit = 20}) =>
      get('/users/recent', queryParameters: {'limit': limit});
  Future<Response> getRecentlyActiveUsers({int minutes = 15}) =>
      get('/users/recently-active', queryParameters: {'minutes': minutes});

  // ── Locations ──
  Future<Response> getRegions() => get('/locations/regions');
  Future<Response> getDistricts(int regionId) =>
      get('/locations/regions/$regionId/districts');
  Future<Response> getFacilities(int districtId, {String category = 'health'}) =>
      get('/locations/districts/$districtId/facilities',
          queryParameters: {'category': category});
  Future<Response> getCadres({String? category}) =>
      get('/cadres', queryParameters: category != null ? {'category': category} : null);
  Future<Response> getSubjects({String? level}) =>
      get('/cadres/subjects', queryParameters: level != null ? {'level': level} : null);
  Future<Response> getDepartments() => get('/locations/departments');

  // ── Payments / Donations ──
  /// Pata namba ya admin ya kulipiana.
  Future<Response> getDonationInfo() => get('/payments/info');

  /// Tuma mchango — sms_text ni lazima (SMS ya uthibitisho kutoka simu).
  Future<Response> createDonation({
    required int amount,
    required String smsText,
    String? phone,
  }) =>
      post('/payments/donate', data: {
        'amount': amount,
        'sms_text': smsText,
        if (phone != null) 'phone': phone,
      });

  Future<Response> getPaymentStatus(String orderId) =>
      get('/payments/status/$orderId');

  /// Historia ya michango yangu yote.
  Future<Response> getPaymentHistory() => get('/payments/my-history');

  // ── Feedback ──
  /// Tuma maoni — subject na message zinahitajika.
  Future<Response> submitFeedback({
    required String subject,
    required String message,
  }) =>
      post('/feedback', data: {'subject': subject, 'message': message});

  /// Maoni yangu + majibu ya admin.
  Future<Response> getMyFeedback({int limit = 50}) =>
      get('/feedback/my', queryParameters: {'limit': limit});

  // ── Notifications ──
  Future<Response> getNotifications({int limit = 50}) =>
      get('/notifications', queryParameters: {'limit': limit});

  Future<Response> getUnreadCount() => get('/notifications/unread-count');

  Future<Response> markAllRead() => post('/notifications/read-all');

  Future<Response> markNotificationRead(String notificationId) =>
      post('/notifications/$notificationId/read');

  // ── Messaging / Presence ──
  Future<Response> getCallHistory({int limit = 100}) =>
      get('/messages/calls', queryParameters: {'limit': limit});
  Future<Response> getPresence() => get('/messages/presence');
  Future<Response> getUserPresence(String userId) =>
      get('/messages/presence/$userId');
  Future<Response> sendPaymentMessage(String orderId, String message) =>
      post('/payments/$orderId/message', data: {'message': message});
  Future<Response> getPaymentMessages(String orderId) =>
      get('/payments/$orderId/messages');

  // ── Announcements ──
  /// Matangazo ya sasa (active).
  Future<Response> getAnnouncements() => get('/announcements/active');
  Future<Response> getAnnouncementUnreadCount() =>
      get('/announcements/unread-count');

  /// Ondoa tangazo — haonekani tena kwa mtumiaji huyu.
  Future<Response> dismissAnnouncement(String announcementId) =>
      post('/announcements/$announcementId/dismiss');

  // ── Admin ──
  Future<Response> adminStats() => get('/admin/stats');
  Future<Response> adminUsers({Map<String, dynamic>? params}) =>
      get('/admin/users', queryParameters: params);
  Future<Response> adminCreateUser(Map<String, dynamic> data) =>
      post('/admin/users', data: data);
  Future<Response> adminUpdateUser(String id, Map<String, dynamic> data) =>
      patch('/admin/users/$id', data: data);
  Future<Response> adminDeleteUser(String id) => delete('/admin/users/$id');
  Future<Response> adminGrant(String userId) =>
      post('/admin/users/$userId/grant-admin');
  Future<Response> adminRevoke(String userId) =>
      post('/admin/users/$userId/revoke-admin');
  Future<Response> adminAllDonations({String? status}) =>
      get('/payments/admin/all',
          queryParameters: status != null ? {'status': status} : null);
  Future<Response> adminApproveDonation(String orderId, {String? note}) =>
      post('/payments/admin/$orderId/approve', data: {'note': note});
  Future<Response> adminRejectDonation(String orderId, {String? note}) =>
      post('/payments/admin/$orderId/reject', data: {'note': note});
  Future<Response> adminListFeedback({String status = '', String q = ''}) =>
      get('/feedback/admin/all',
          queryParameters: {'status': status, 'q': q});
  Future<Response> adminReplyFeedback(String feedbackId, String reply) =>
      post('/feedback/admin/$feedbackId/reply', data: {'reply': reply});
  Future<Response> adminDeleteFeedback(String feedbackId) =>
      delete('/feedback/admin/$feedbackId');
  Future<Response> adminListAnnouncements() => get('/admin/announcements');
  Future<Response> adminSendAnnouncement(Map<String, dynamic> data) =>
      post('/admin/announcements', data: data);
  Future<Response> adminDeleteAnnouncement(String id) =>
      delete('/admin/announcements/$id');
  Future<Response> adminListMatches({int limit = 100}) =>
      get('/admin/matches', queryParameters: {'limit': limit});
  Future<Response> adminRealMatches({String? category, String? cadreCode, int limit = 100}) =>
      get('/admin/real-matches', queryParameters: {
        if (category != null) 'category': category,
        if (cadreCode != null) 'cadre_code': cadreCode,
        'limit': limit,
      });
  Future<Response> adminReports({int days = 30}) =>
      get('/admin/reports', queryParameters: {'days': days});
  Future<Response> adminEvents({String? eventType, int limit = 100, int skip = 0}) =>
      get('/admin/events', queryParameters: {
        if (eventType != null) 'event_type': eventType,
        'limit': limit,
        'skip': skip,
      });
  Future<Response> adminClearEvents() => post('/admin/events/clear');
  Future<Response> getContactActivity({int limit = 100}) =>
      get('/messages/admin/contacts', queryParameters: {'limit': limit});
  Future<Response> logContact(String userId, String type) =>
      post('/messages/call', data: {'to_user_id': userId, 'contact_type': type});
  Future<Response> adminListPasswordResets({String status = 'pending'}) =>
      get('/admin/password-resets', queryParameters: {'status': status});
  Future<Response> adminApprovePasswordReset(String resetId) =>
      post('/admin/password-resets/$resetId/approve');
  Future<Response> adminRejectPasswordReset(String resetId) =>
      post('/admin/password-resets/$resetId/reject');
  Future<Response> adminGetSettings() => get('/admin/settings/contact');
  Future<Response> adminUpdateContactSettings(bool requirePayment) =>
      put('/admin/settings/contact', data: {'require_payment': requirePayment});
  Future<Response> adminToggleContact(String userId) =>
      patch('/admin/users/$userId/contact-toggle');
  Future<Response> adminGetData(String type) => get('/admin/data/$type');
  Future<Response> adminGetUserMatches(String userId) =>
      get('/admin/users/$userId/matches');
  Future<Response> adminGetUserBoard(String userId) =>
      get('/admin/users/$userId/board');
  Future<Response> adminImportUsers(dynamic formData) =>
      post('/admin/users/import', data: formData);
  Future<Response> adminGetMonitoring() => get('/admin/monitoring');
  Future<Response> adminListData(String type) => get('/admin/data/$type');
  Future<Response> adminCreateData(String type, Map<String, dynamic> data) =>
      post('/admin/data/$type', data: data);
  Future<Response> adminUpdateData(String type, String id, Map<String, dynamic> data) =>
      patch('/admin/data/$type/$id', data: data);
  Future<Response> adminDeleteData(String type, String id) =>
      delete('/admin/data/$type/$id');
  Future<Response> adminListCsvs() => get('/admin/csv/list');
  Future<Response> adminExportCsv(String type) =>
      post('/admin/csv/export', data: {'type': type});
  Future<Response> adminDownloadCsv(String name) =>
      get('/admin/csv/download/$name');
  Future<Response> adminResendAnnouncement(String id) =>
      post('/admin/announcements/$id/resend');
  Future<Response> adminPaymentReply(String orderId, String message) =>
      post('/payments/admin/$orderId/reply', data: {'message': message});
  Future<Response> getDataVersion() => get('/locations/data-version');
}
