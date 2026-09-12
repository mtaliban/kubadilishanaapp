import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

/// Admin shell listens to this to open the right page after FCM tap.
final ValueNotifier<int?> adminPageNotifier = ValueNotifier(null);

bool _currentUserIsAdmin = false;

/// Called from AuthProvider._setupRealtime() once user info is known.
void setAdminStatus(bool isAdmin) => _currentUserIsAdmin = isAdmin;

/// Admin: page index to open when notification is tapped.
int _adminPageFromType(String type) {
  switch (type) {
    case 'payment.submitted':
    case 'payment.approved':
    case 'payment.rejected':
    case 'payment.message':
    case 'payment.reply':
      return 3; // AdminPaymentsPage
    case 'feedback.new':
    case 'feedback.replied':
      return 5; // AdminFeedbackPage
    case 'user.registered':
    case 'match.found':
    case 'user.profile_updated':
      return 11; // AdminRealMatchesPage
    case 'password_reset.new':
      return 9; // AdminEventsPage
    default:
      return 0; // AdminDashboardPage
  }
}

/// User: route to navigate when notification is tapped.
String _userRouteFromType(String type) {
  switch (type) {
    case 'payment.submitted':
    case 'payment.approved':
    case 'payment.rejected':
    case 'payment.message':
    case 'payment.reply':
      return '/donate';
    case 'feedback.replied':
      return '/feedback';
    case 'match.found':
    case 'user.registered':
      return '/dashboard';
    default:
      return '/notifications';
  }
}

void handleNotificationTap(Map<String, String> data) {
  final type = data['type'] ?? '';
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;

  if (_currentUserIsAdmin) {
    adminPageNotifier.value = _adminPageFromType(type);
    nav.pushNamedAndRemoveUntil('/admin', (r) => false);
  } else {
    nav.pushNamed(_userRouteFromType(type));
  }
}
