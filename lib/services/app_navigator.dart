import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

/// Admin shell listens to this to open the right page after FCM tap.
final ValueNotifier<int?> adminPageNotifier = ValueNotifier(null);

bool _currentUserIsAdmin = false;

/// Called from AuthProvider._setupRealtime() once user info is known.
void setAdminStatus(bool isAdmin) => _currentUserIsAdmin = isAdmin;

/// Read admin status (kwa NotificationService role-aware routing).
bool adminPageNotifierAdminStatus() => _currentUserIsAdmin;

/// Admin: page index to open when notification is tapped.
/// Indices hizi zinalingana na _pageFor(i) katika admin_shell.dart:
///   0=Dashboard 1=Watumiaji 2=Wenzao 3=RealMatches 4=Data
///   5=Matangazo  6=Malipo   7=Contacts 8=Maoni 9=Reports
///   10=Monitoring 11=PasswordResets
int _adminPageFromType(String type) {
  switch (type) {
    case 'payment.submitted':
    case 'payment.approved':
    case 'payment.rejected':
    case 'payment.message':
    case 'payment.reply':
      return 6; // AdminPaymentsPage
    case 'feedback.new':
    case 'feedback.replied':
      return 8; // AdminFeedbackPage
    case 'user.registered':
      return 1; // AdminUsersV2Page
    case 'match.found':
    case 'user.profile_updated':
      return 2; // AdminMatchesPage
    case 'announcement':
    case 'announcement.new':
      return 5; // AdminAnnouncementsPage
    case 'password_reset.new':
      return 11; // AdminPasswordResetsPage
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
