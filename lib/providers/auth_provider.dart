// Auth state — login, register, logout, session persistence, admin 2FA.
import 'package:flutter/material.dart';
import '../services/admin_badge_service.dart';
import '../services/api_service.dart';
import '../services/app_cache.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';
import '../services/app_navigator.dart';
import '../utils/safe_cast.dart';

class AuthUser {
  final String userId;
  final String fullName;
  final String phone;
  final String phoneAlt;
  final String? email;
  final String? category;
  final String? cadreCode;
  final String? cadreDisplay;
  final String? employmentSector;
  final bool isAdmin;
  final bool isVerified;
  final bool contactEnabled;
  final Map<String, dynamic>? currentStation;
  final List<String> subjects;
  final List<String> wantedRegions; // majina ya mikoa anayotaka kwenda

  AuthUser({
    required this.userId,
    required this.fullName,
    required this.phone,
    this.phoneAlt = '',
    this.email,
    this.category,
    this.cadreCode,
    this.cadreDisplay,
    this.employmentSector,
    this.isAdmin = false,
    this.isVerified = false,
    this.contactEnabled = false,
    this.currentStation,
    this.subjects = const [],
    this.wantedRegions = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        userId: json['user_id'] ?? '',
        fullName: json['full_name'] ?? '',
        phone: json['phone_primary'] ?? '',
        phoneAlt: json['phone_alt'] ?? '',
        email: json['email'],
        category: json['category'],
        cadreCode: json['cadre_code'],
        cadreDisplay: json['cadre_display'],
        employmentSector: json['employment_sector'],
        isAdmin: json['is_admin'] ?? false,
        isVerified: json['is_verified'] ?? false,
        contactEnabled: json['contact_enabled'] ?? false,
        currentStation: json['current_station'],
        subjects: (json['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [],
        wantedRegions: (json['desired_destinations'] as List?)
                ?.map((d) => (d is Map ? d['region_name'] : null)?.toString() ?? '')
                .where((r) => r.isNotEmpty)
                .toList() ??
            [],
      );

  AuthUser copyWith({bool? isVerified, bool? contactEnabled}) => AuthUser(
        userId: userId,
        fullName: fullName,
        phone: phone,
        phoneAlt: phoneAlt,
        email: email,
        category: category,
        cadreCode: cadreCode,
        cadreDisplay: cadreDisplay,
        employmentSector: employmentSector,
        isAdmin: isAdmin,
        isVerified: isVerified ?? this.isVerified,
        contactEnabled: contactEnabled ?? this.contactEnabled,
        currentStation: currentStation,
        subjects: subjects,
        wantedRegions: wantedRegions,
      );
}

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final NotificationService _notif = NotificationService();

  AuthUser? _user;
  bool _loading = false;
  String? _error;
  bool _errorIsNetwork = false;

  /// Admin 2FA: email inayosubiri OTP.
  String? pendingAdminEmail;

  AuthUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isVerified => _user?.isVerified ?? false;
  String? get error => _error;
  bool get errorIsNetwork => _errorIsNetwork;

  Future<bool> restoreSession() async {
    final token = await _api.loadToken();
    if (token == null) return false;
    try {
      _api.setToken(token);
      final res = await _api.getMe();
      _user = AuthUser.fromJson(asMap(res.data));
      _setupRealtime();
      notifyListeners();
      return true;
    } catch (_) {
      await _api.removeToken();
      return false;
    }
  }

  /// Login kwa NAMBA YA SIMU — password si lazima.
  Future<bool> login(String phone, {String? password}) async {
    _loading = true;
    _error = null;
    _errorIsNetwork = false;
    notifyListeners();
    try {
      final res = await _api.login(phone, password: password);
      final data = asMap(res.data);
      if (data['two_factor_required'] == true) {
        // Admin 2FA — save email, return false so UI shows OTP input
        pendingAdminEmail = data['email'] as String? ?? phone;
        _loading = false;
        notifyListeners();
        return false;
      }
      final token = data['access_token'] as String;
      await _api.saveToken(token);
      _user = AuthUser.fromJson(data);
      _setupRealtime();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorIsNetwork = _isNetworkError(e);
      _error = _errorIsNetwork
          ? 'Kosa la mtandao — tafadhali angalia muunganisho wako na ujaribu tena.'
          : _parseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin login step 1 — email + password → OTP inatumwa.
  /// Returns true kama OTP imetumwa (iende OTP screen).
  Future<bool> adminLoginStep1(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.adminLoginStep1(email, password);
      final data = asMap(res.data);
      if (data['two_factor_required'] == true) {
        pendingAdminEmail = data['email'] as String? ?? email;
        _loading = false;
        notifyListeners();
        return true; // → onyesha OTP screen
      }
      // Kama ingeweza kurudi token moja kwa moja (haipaswi kutokea):
      if (data['access_token'] != null) {
        await _api.saveToken(data['access_token'] as String);
        _user = AuthUser.fromJson(data);
        _setupRealtime();
        pendingAdminEmail = null;
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = 'Jibu lisilo la kawaida kutoka server';
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin login step 2 — OTP code → access_token.
  Future<bool> adminLoginOtp(String email, String code) async {
    _loading = true;
    _error = null;
    _errorIsNetwork = false;
    notifyListeners();
    try {
      final res = await _api.adminLoginOtp(email, code);
      final data = asMap(res.data);
      final token = data['access_token'] as String;
      await _api.saveToken(token);
      _user = AuthUser.fromJson(data);
      _setupRealtime();
      pendingAdminEmail = null;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorIsNetwork = _isNetworkError(e);
      _error = _errorIsNetwork
          ? 'Kosa la mtandao — tafadhali angalia muunganisho wako na ujaribu tena.'
          : _parseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.register(data);
      final responseData = asMap(res.data);
      final token = responseData['access_token'] as String?;
      if (token != null) {
        await _api.saveToken(token);
        _user = AuthUser.fromJson(responseData);
        _setupRealtime();
      }
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _notif.removeToken();
    _ws.disconnect();
    _ws.clearListeners(); // events za session ya zamani zisifanye kazi tena
    _user = null;
    pendingAdminEmail = null;
    await _api.removeToken();
    // ── ISOLATION YA SESSION ──
    // Cache yote ya GET (profiles, matches, admin lists, regions...) inafutwa
    // ili mtumiaji mpya asiweze kuona data za aliyekuwa hapo awali (TTL ya
    // cache ni dakika 2-30 — bila hii data za zamani zingerejea kwa screen).
    AppCache().clear();
    // Badges za admin (payments/feedback counts) ziwekwe sifuri.
    AdminBadgeService().stop();
    AdminBadgeService().reset();
    notifyListeners();
  }

  void updateUser(AuthUser updated) {
    _user = updated;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final res = await _api.getMe();
      _user = AuthUser.fromJson(asMap(res.data));
      notifyListeners();
    } catch (_) {}
  }

  void _setupRealtime() {
    _api.loadToken().then((t) {
      if (t != null) _ws.connect(t);
    });

    setAdminStatus(_user?.isAdmin ?? false);

    _ws.on('account.disabled', (_) => logout());
    _ws.on('account.deleted', (_) => logout());

    // ── Reference data imebadilishwa na admin (idara/somo/kada/mkoa/
    // wilaya/kituo) → FUATA cache zote za reference data ili usajili,
    // profile na filters vione vitu VIPYA MARA MOJA (bila kusubiri TTL
    // ya cache ya dakika 30). Screen zinazofunguka zitapakia upya.
    _ws.on('data.changed', (_) {
      AppCache().invalidatePrefix('/locations/regions');
      AppCache().invalidatePrefix('/locations/regions/');
      AppCache().invalidatePrefix('/locations/districts/');
      AppCache().invalidatePrefix('/cadres');
      AppCache().invalidatePrefix('/locations/departments');
      AppCache().invalidatePrefix('/admin/data/');
    });

    _ws.on('user.verified', (event) {
      if (_user != null && event['user_id'] == _user!.userId) {
        _user = _user!.copyWith(isVerified: true, contactEnabled: true);
        notifyListeners();
      }
    });

    // Delay notification init by 5s so it never blocks app startup
    Future.delayed(const Duration(seconds: 5), () {
      _notif.onNotificationTapped = handleNotificationTap;
      _notif.init().catchError((_) {});
    });

    // ── WebSocket events → arifa za ndani (kama WhatsApp) ──
    // Event yoyote ya arifa ikija na screen haiyofunguliwa, ionyeshe heads-up.
    // NotificationService inafanya dedupe dhidi ya FCM (event ile ile haionekani mara 2).
    _ws.onAny((event) {
      final type = (event['event'] ?? event['type'])?.toString() ?? '';
      if (type.isEmpty || type == 'pong') return;
      _notif.showFromEvent(event);
    });
  }

  bool _isNetworkError(dynamic e) {
    try {
      if ((e as dynamic).response != null) return false;
    } catch (_) {}
    final s = e.toString();
    return s.contains('SocketException') || s.contains('Network') ||
        s.contains('Connection') || s.contains('timeout') ||
        s.contains('Failed host') || s.contains('DioException');
  }

  String _parseError(dynamic e) {
    try {
      final response = (e as dynamic).response;
      final detail = response?.data?['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) return detail[0]['msg'] ?? detail.toString();
    } catch (_) {}
    final s = e.toString();
    if (s.contains('401')) return 'Namba ya simu au password si sahihi. Tafadhali kagua na ujaribu tena.';
    if (s.contains('403')) return 'Hauruhusiwi kuingia';
    if (s.contains('422')) return 'Taarifa zilizowekwa si sahihi';
    if (s.contains('500')) return 'Hitilafu ya server — jaribu tena';
    return 'Namba ya simu au password si sahihi. Tafadhali kagua na ujaribu tena.';
  }
}
