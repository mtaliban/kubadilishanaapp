/// Auth state — login, register, logout, session persistence, admin 2FA.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';

class AuthUser {
  final String userId;
  final String fullName;
  final String phone;
  final String? email;
  final String? category;
  final String? cadreCode;
  final String? cadreDisplay;
  final String? employmentSector;
  final bool isAdmin;
  final bool isVerified;
  final bool contactEnabled;
  final Map<String, dynamic>? currentStation;

  AuthUser({
    required this.userId,
    required this.fullName,
    required this.phone,
    this.email,
    this.category,
    this.cadreCode,
    this.cadreDisplay,
    this.employmentSector,
    this.isAdmin = false,
    this.isVerified = false,
    this.contactEnabled = false,
    this.currentStation,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        userId: json['user_id'] ?? '',
        fullName: json['full_name'] ?? '',
        phone: json['phone_primary'] ?? '',
        email: json['email'],
        category: json['category'],
        cadreCode: json['cadre_code'],
        cadreDisplay: json['cadre_display'],
        employmentSector: json['employment_sector'],
        isAdmin: json['is_admin'] ?? false,
        isVerified: json['is_verified'] ?? false,
        contactEnabled: json['contact_enabled'] ?? false,
        currentStation: json['current_station'],
      );

  AuthUser copyWith({bool? isVerified, bool? contactEnabled}) => AuthUser(
        userId: userId,
        fullName: fullName,
        phone: phone,
        email: email,
        category: category,
        cadreCode: cadreCode,
        cadreDisplay: cadreDisplay,
        employmentSector: employmentSector,
        isAdmin: isAdmin,
        isVerified: isVerified ?? this.isVerified,
        contactEnabled: contactEnabled ?? this.contactEnabled,
        currentStation: currentStation,
      );
}

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final NotificationService _notif = NotificationService();

  AuthUser? _user;
  bool _loading = false;
  String? _error;

  /// Admin 2FA: email inayosubiri OTP.
  String? pendingAdminEmail;

  AuthUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isVerified => _user?.isVerified ?? false;
  String? get error => _error;

  Future<bool> restoreSession() async {
    final token = await _api.loadToken();
    if (token == null) return false;
    try {
      _api.setToken(token);
      final res = await _api.getMe();
      _user = AuthUser.fromJson(res.data as Map<String, dynamic>);
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
    notifyListeners();
    try {
      final res = await _api.login(phone, password: password);
      final data = res.data as Map<String, dynamic>;
      if (data['two_factor_required'] == true) {
        _error = '2FA inahitajika — tumia akaunti ya admin';
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
      _error = _parseError(e);
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
      final data = res.data as Map<String, dynamic>;
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
    notifyListeners();
    try {
      final res = await _api.adminLoginOtp(email, code);
      final data = res.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      await _api.saveToken(token);
      _user = AuthUser.fromJson(data);
      _setupRealtime();
      pendingAdminEmail = null;
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

  Future<bool> register(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.register(data);
      final responseData = res.data as Map<String, dynamic>;
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
    _user = null;
    pendingAdminEmail = null;
    await _api.removeToken();
    notifyListeners();
  }

  void updateUser(AuthUser updated) {
    _user = updated;
    notifyListeners();
  }

  void _setupRealtime() {
    _api.loadToken().then((t) {
      if (t != null) _ws.connect(t);
    });

    _ws.on('account.disabled', (_) => logout());
    _ws.on('account.deleted', (_) => logout());

    _ws.on('user.verified', (event) {
      if (_user != null && event['user_id'] == _user!.userId) {
        _user = _user!.copyWith(isVerified: true, contactEnabled: true);
        notifyListeners();
      }
    });

    _notif.init();
  }

  String _parseError(dynamic e) {
    try {
      final response = (e as dynamic).response;
      final detail = response?.data?['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) return detail[0]['msg'] ?? detail.toString();
    } catch (_) {}
    final s = e.toString();
    if (s.contains('401')) return 'Namba ya simu au nenosiri si sahihi';
    if (s.contains('403')) return 'Hauruhusiwi kuingia';
    if (s.contains('422')) return 'Taarifa zilizowekwa si sahihi';
    if (s.contains('500')) return 'Hitilafu ya server — jaribu tena';
    return 'Hitilafu — jaribu tena';
  }
}
