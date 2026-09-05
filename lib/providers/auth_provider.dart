/// Auth state management — login, register, logout, session persistence.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';

class AuthUser {
  final String userId;
  final String fullName;
  final String phone;
  final String? category;
  final String? cadreCode;
  final bool isAdmin;
  final bool isVerified;
  final bool contactEnabled;
  final Map<String, dynamic>? currentStation;

  AuthUser({
    required this.userId,
    required this.fullName,
    required this.phone,
    this.category,
    this.cadreCode,
    this.isAdmin = false,
    this.isVerified = false,
    this.contactEnabled = false,
    this.currentStation,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone_primary'] ?? '',
      category: json['category'],
      cadreCode: json['cadre_code'],
      isAdmin: json['is_admin'] ?? false,
      isVerified: json['is_verified'] ?? false,
      contactEnabled: json['contact_enabled'] ?? false,
      currentStation: json['current_station'],
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final NotificationService _notif = NotificationService();

  AuthUser? _user;
  bool _loading = false;
  String? _error;

  AuthUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isVerified => _user?.isVerified ?? false;
  String? get error => _error;

  /// Try to restore session from saved token.
  Future<bool> restoreSession() async {
    final token = await _api.loadToken();
    if (token == null) return false;

    try {
      _api.setToken(token);
      final res = await _api.getMe();
      _user = AuthUser.fromJson(res.data);
      _setupRealtime();
      notifyListeners();
      return true;
    } catch (e) {
      await _api.removeToken();
      return false;
    }
  }

  /// Login with phone + password.
  Future<bool> login(String phone, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.login(phone, password);
      final data = res.data;

      if (data['two_factor_required'] == true) {
        _error = '2FA inahitajika';
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

  /// Admin login with email + password.
  Future<bool> adminLogin(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.adminLogin(email, password);
      final data = res.data;
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

  /// Register new user.
  Future<bool> register(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.register(data);
      final responseData = res.data;
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

  /// Logout.
  Future<void> logout() async {
    await _notif.removeToken();
    _ws.disconnect();
    _user = null;
    await _api.removeToken();
    notifyListeners();
  }

  void _setupRealtime() {
    // Connect WebSocket for real-time updates
    final token = _api.setToken; // just ensure token is set
    // Connect WS with token
    _api.loadToken().then((t) {
      if (t != null) _ws.connect(t);
    });

    // Listen for account changes (disabled/deleted by admin)
    _ws.on('account.disabled', (_) => logout());
    _ws.on('account.deleted', (_) => logout());
    _ws.on('user.verified', (event) {
      if (_user != null && event['user_id'] == _user!.userId) {
        _user = AuthUser(
          userId: _user!.userId,
          fullName: _user!.fullName,
          phone: _user!.phone,
          category: _user!.category,
          cadreCode: _user!.cadreCode,
          isAdmin: _user!.isAdmin,
          isVerified: true,
          contactEnabled: true,
          currentStation: _user!.currentStation,
        );
        notifyListeners();
      }
    });

    // Register FCM token
    _notif.init();
  }

  /// Update user data in-place (after profile update or admin change).
  void updateUser(AuthUser updated) {
    _user = updated;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e.toString().contains('401')) return 'Namba au nenosiri si sahihi';
    if (e.toString().contains('403')) return 'Hauruhusiwi kuingia';
    if (e.toString().contains('500')) return 'Hitilafu ya server — jaribu tena';
    return 'Hitilafu — jaribu tena';
  }
}
