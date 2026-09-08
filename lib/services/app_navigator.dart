import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

String _routeFromNotifType(String type) {
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
  final route = _routeFromNotifType(type);
  appNavigatorKey.currentState?.pushNamed(route);
}
