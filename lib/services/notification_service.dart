/// Firebase Cloud Messaging — arifa za push (kama WhatsApp) + WebSocket bridge.
///
/// Muundo:
///  • Channels 3 za Android (Ujumbe / Mechi / Matangazo).
///  • Canvas large icon: bg la rangi ya aina + icon ya TABLER ya aina
///    (zile ZILE za drawer: coin, user_plus, speakerphone, message_2, bolt…)
///    — bila badge ya logo: Android inaonyesha logo ya app yenyewe kwenye
///    header ya arifa, badge ya ES ilikuwa inaficha icon ya aina.
///  • SubText "Kubadilishana · Malipo · dak 5" kwenye kila arifa.
///  • Action buttons: Jibu/Nimesoma (maoni), Thibitisha/Fungua (malipo-admin),
///    Tazama (malipo-user), Soma tangazo, Tazama mechi.
///  • Background handler (FirebaseMessaging.onBackgroundMessage).
///  • Dedupe: FCM + WS fingerprint na TTL ya sekunde 30.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FontLoader, MethodChannel, rootBundle;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'admin_otp_inbox.dart';
import 'api_service.dart';
import 'app_navigator.dart';
import 'network_service.dart';
import 'websocket_service.dart' show resolveNotificationEventType;

/// Lazima iwe top-level — inasajiliwa na Android mpangilio wa app ikiwa imufungwa.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // KASORO ILIYOKUWA: handler hii haifanyi chochote — DATA-ONLY push kwenye
  // background isolate ilifika KIMYA (Android tray inaonyesha payload ya
  // notification pekee; data-only zilisimama kwenye app). SASA: isolate ya
  // background inaanzisha flutter_local_notifications yake na KUONYESHA arifa
  // (channels 3 zile zile — Ujumbe/Mechi/Matangazo, sauti + vibration).
  // NB: notification != null → Android/FCM tray inaonyesha yenyewe (app
  // interactive au killed kabisa) — tunaruhusu system, KAMWE tunagongana.
  if (message.notification != null) return;
  try {
    final data = message.data;
    if (data.isEmpty) return;
    final type = data['type']?.toString() ?? '';
    if (type == 'admin.otp') return; // code ya admin — inbox ya app inaonyesha

    final svc = NotificationService();
    await svc.initForBackgroundIsolate();
    svc._showFromData(data); // title/body kutoka data (subscriber inatuma)
  } catch (_) {
    // Background isolate yenye shida — arifa ya system payload inaweza kubaki.
  }
}

// ─── Canvas large icon cache ──────────────────────────────────────────────────

final _iconBytesCache = <String, Uint8List>{};

bool _tablerFontLoaded = false;

/// Pakia font ya tabler-icons KABLA ya kupaint kwenye Canvas. Bila hii
/// glyph ya Tabler inaweza kuonekana kama box tupu — font ya package
/// haijakipakiwa kiotomate kwa painting moja kwa moja (lazy load yakuada).
Future<void> _ensureTablerFont() async {
  if (_tablerFontLoaded) return;
  _tablerFontLoaded = true;
  try {
    final bytes = await rootBundle
        .load('packages/flutter_tabler_icons/assets/fonts/tabler-icons.ttf');
    final loader = FontLoader('tabler-icons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  } catch (_) {
    _tablerFontLoaded = false; // jaribu tena arifa inayofuata
  }
}

/// Icon kubwa ya arifa: bg la rangi ya aina + icon ya Tabler ya aina
/// (zile zile za drawer) — hakuna badge ya logo. Inatumika kama largeIcon
/// ya notification kwenye Android.
Future<Uint8List> buildNotifLargeIcon(String type, {String? status}) async {
  final key = '$type|$status';
  final cached = _iconBytesCache[key];
  if (cached != null) return cached;

  const s = 192.0;
  const box = Rect.fromLTWH(8, 8, 160, 160);

  await _ensureTablerFont();

  final (iconData, bg, fg) = _iconLook(type, status);

  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, s, s));

  // Mstatili wa rangi na pembe laini
  c.drawRRect(
    RRect.fromRectAndRadius(box, const Radius.circular(40)),
    Paint()..color = bg,
  );

  // Icon ya aina katikati
  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 80,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: fg,
      ),
    ),
  )..layout();
  tp.paint(c, box.center - Offset(tp.width / 2, tp.height / 2));

  // HAKUNA badge ya logo hapa — Android tayari inaonyesha logo ya app
  // kwenye header ya arifa; badge (ES) ilikuwa inaficha icon ya aina.

  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer.asUint8List();
  _iconBytesCache[key] = bytes;
  return bytes;
}

// Icon + rangi chodzi HII hii ya drawer (NavItem.accent) — mwonekano
// wa arifa ya simu ufanane na wa app: coin=Malipo, message_2=Maoni,
// user_plus=Watu anajiunga, speakerphone=Matangazo, bolt=Mechi.
(IconData, Color, Color) _iconLook(String type, String? status) {
  return switch (type) {
    'payment.approved'  => (TablerIcons.circle_check,  const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'payment.rejected'  => (TablerIcons.circle_x,      const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    'payment.submitted' ||
    'payment.message'   ||
    'payment.reply'     => (TablerIcons.coin,          const Color(0xFFDBEAFE), const Color(0xFF1565C0)),
    'match.found'       ||
    'match.new'         => (TablerIcons.bolt,          const Color(0xFFFFE0B2), const Color(0xFFE64A19)),
    'user.registered'   => (TablerIcons.user_plus,     const Color(0xFFEDE7F6), const Color(0xFF6D28D9)),
    'announcement'      ||
    'announcement.new'  => (TablerIcons.speakerphone,  const Color(0xFFFCE4EC), const Color(0xFFD81B60)),
    _                   => (TablerIcons.message_2,     const Color(0xFFDCEDC8), const Color(0xFF558B2F)),
  };
}

// ─── NotificationService ──────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FirebaseMessaging? _fcmRef;
  FirebaseMessaging get _fcm => _fcmRef ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  Function(Map<String, String>)? onNotificationTapped;
  String? get fcmToken => _fcmToken;
  bool _initialized = false;
  bool _tokenNeedsRetry = false;
  bool _networkHooked = false;

  // ── Dedupe (FCM + WS) ────────────────────────────────────────────────────
  // Ufunguo ni UTAMBULISHO (notification_id / type+id+title) — SI title/body
  // pekee. Hapo awali FCM na WS zilikuwa na fingerprint tofauti hata kwa
  // event ile ile → arifa mara 2; au FCM ikifika kimya kwanza (title ya
  // backend tofauti na ya app) ilinyamazisha WS event halisi.
  final Map<String, DateTime> _recent = {};
  static const _dedupeTtl = Duration(seconds: 30);

  bool _isDuplicate(String type, String id, String title, String body) {
    final key = '$type|${id.isNotEmpty ? id : '$title|$body'}';
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t) > _dedupeTtl);
    if (_recent.containsKey(key)) return true;
    _recent[key] = now;
    return false;
  }

  // ── Initialise ────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (!_initialized) {
      _initialized = true;

      initNetworkListener();

      try {
        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        );
        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onLocalTap,
        );
        final android = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(const AndroidNotificationChannel(
          'kubadilishana_messages_v2', 'Ujumbe',
          description: 'Ujumbe mpya kutoka kwa wenzako',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));
        await android?.createNotificationChannel(const AndroidNotificationChannel(
          'kubadilishana_matches_v2', 'Mechi',
          description: 'Mechi mpya zilizopatikana',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));
        await android?.createNotificationChannel(const AndroidNotificationChannel(
          'kubadilishana_general_v2', 'Matangazo',
          description: 'Matangazo na taarifa za jumla',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ));
      } catch (_) {}

      // BATTERY OPTIMIZATION (Android): simu nyingi (MIUI/Oppo/Samsung)
      // hazinzi background apps → FCM push haifikia wakati app imefungwa
      // (badge kwenye DB, arifa hapana). Tunaomba system dialog ya
      // "Ruhusu kufanya kazi bila optimization" — MARA MOJA tu kwa app.
      _ensureBatteryExemption();

      // Token refresh: sikiliza MARA MOJA tu — kila _ensurePermissionAndToken
      // inayofuata (login mpya / retry) isiongeze listener nyingine.
      try {
        _fcm.onTokenRefresh.listen((t) { _fcmToken = t; _registerToken(t); });
      } catch (_) {}

      try {
        FirebaseMessaging.onMessage.listen((msg) {
          final n    = msg.notification;
          final type = msg.data['type']?.toString() ?? '';
          // OTP ya admin inafika kwa app yenyewe (FCM push) — inbox inai-subiri
          // na kuiweka KIOTOMATE kwenye boxes za code (2FA) — hakuna kwenda
          // Gmail kutafuta code (kasoro halisi ya kwenda email kila wakati).
          if (type == 'admin.otp') {
            final otp = msg.data['otp']?.toString() ??
                (msg.notification?.body ?? '');
            final digits = otp.replaceAll(RegExp(r'\D'), '');
            if (digits.length == 6) AdminOtpInbox.instance.push(digits);
            return; // isiwe na arifa ndogo nyingine — inbox inaonyesha.
          }
          if (n != null) {
            if (_isDuplicate(type, msg.data['notification_id']?.toString() ?? '',
                n.title ?? '', n.body ?? '')) return;
            _show(type: type, title: n.title ?? 'Kubadilishana',
                body: n.body ?? '', payload: msg.data);
          } else if (msg.data.isNotEmpty) {
            _showFromData(msg.data);
          }
        });

        FirebaseMessaging.onMessageOpenedApp
            .listen((msg) => _notifyTap(msg.data));
        _fcm.getInitialMessage().then((msg) {
          if (msg != null) _notifyTap(msg.data);
        }).catchError((_) {});
      } catch (_) {}
    }

    // HII INAUITWA KILA LOGIN (si run ya kwanza tu!): logout inaondoa token
    // kwenye server ($pull /fcm-token), kisha login inayofuata LAZIMA
    // isajili upya — vinginevyo push hazifiki hadi app ifunguliwe upya
    // (kasoro halisi: init ya zamani ilipita kimya kwa logins za pili).
    await _ensurePermissionAndToken();
  }

  /// INIT ya background isolate (FCM data-only ikija app ikimagana):
  /// plugin + channels 3 tu — BILA listeners (WS/network) — isolate hii
  /// inaisha mara handler imemaliza.
  Future<void> initForBackgroundIsolate() async {
    if (_initialized) return;
    _initialized = true;
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _localNotifications.initialize(initSettings);
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'kubadilishana_messages_v2', 'Ujumbe',
        description: 'Ujumbe mpya kutoka kwa wenzako',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'kubadilishana_matches_v2', 'Mechi',
        description: 'Mechi mpya zilizopatikana',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'kubadilishana_general_v2', 'Matangazo',
        description: 'Matangazo na taarifa za jumla',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
    } catch (_) {
      _initialized = false; // jaribu tena arifa inayofuata
    }
  }

  static const MethodChannel _batteryChannel =
      MethodChannel('kubadilishana/battery');

  /// Omba App-standby exemption (Doze whitelist) — ARIFA ZA BACKGROUND
  /// HAZIFIKI kwenye simu nyingi bila hii. Dialog ya mfumo huonyeshwa
  /// mara MMOJA tu (bendera kwenye SharedPreferences), mtumiaji akikubali
  /// app inaingia kwenye whitelist na push zinafika hata app imefungwa.
  Future<void> _ensureBatteryExemption() async {
    if (!Platform.isAndroid) return;
    try {
      final needs = await _batteryChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      if (needs != true) return; // tayari kwenye whitelist
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('battery_prompt_shown') == true) return;
      await prefs.setBool('battery_prompt_shown', true);
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {
      // Channel haipo (simu pekee) au simu imekataa — siyo kosa kizuia app.
    }
  }

  /// Ruhusa ya POST_NOTIFICATIONS (Android 13+) + token ya FCM.
  ///
  /// Hapo awali: ombi moja tu — mtumiaji akikataa (au kubonyeza nje ya
  /// dialog) token HAIPATIKANI kamwe → backend inaona "no_tokens" → hakuna
  /// push kwenye simu hiyo MILELE, hata kuingia upya. Sasa: tunajaribu
  /// mara 3, na mtumiaji akikataa tunaweza kuomba tena kesho (Android
  /// inaruhusu mara mbili tu mfululizo; baada ya hapo dialog haionyeshwi
  /// tena — tunahifadhi hali ili user apate njia ya kuiruhusu kwa mkono).
  Future<void> _ensurePermissionAndToken({bool retryAttempt = false}) async {
    try {
      var settings = await _fcm.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
          retryAttempt) {
        settings = await _fcm.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
      }

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        await _fetchAndRegisterToken();
      } else {
        // Ruhusa imekataliwa — alama na upange jaribio la baadaye.
        _tokenNeedsRetry = true;
        _schedulePermissionRetry(retryAttempt ? 2 : 1);
      }
    } catch (_) {
      _tokenNeedsRetry = true;
    }
  }

  Future<void> _fetchAndRegisterToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      _tokenNeedsRetry = false;
      if (_fcmToken != null) await _registerToken(_fcmToken!);
      // onTokenRefresh imesikilizwa mara moja ndani ya init — hapa ni
      // ku-register tu (server inatumia $addToSet, ku-rudiana ni salama).
    } catch (_) {
      // Token imeshindikana (mtandao n.k.) — tajaribu tena mtandao ukireja.
      _tokenNeedsRetry = true;
    }
  }

  void _schedulePermissionRetry(int attempt) {
    // Mara 3 tu kila session (baada ya sekunde 30, 120, 270) — usimwague
    // mtumiaji dialog kila wakati.
    if (attempt > 3) return;
    Future.delayed(Duration(seconds: 30 * attempt * attempt), () async {
      if (_tokenNeedsRetry) await _ensurePermissionAndToken(retryAttempt: true);
    });
  }

  /// Iitwa mara moja wakati wa init — mtandao ukireja (offline → online)
  /// jaribio la token linalyochelewa linapigwa papo hapo (FIX: token
  /// ilipatikana mara moja tu, hakuna retry wala kusikiliza mtandao).
  void initNetworkListener() {
    if (_networkHooked) return;
    _networkHooked = true;
    NetworkService().addOnlineListener(() async {
      if (!_tokenNeedsRetry) return;
      await _fetchAndRegisterToken();
    });
  }

  void _onLocalTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final raw  = jsonDecode(response.payload!) as Map<String, dynamic>;
      final data = raw.map((k, v) => MapEntry(k, v.toString()));
      _notifyTap(data);
    } catch (_) {}
  }

  void _notifyTap(Map<dynamic, dynamic> data) {
    final safe = data.map((k, v) => MapEntry(k.toString(), v.toString()));
    onNotificationTapped?.call(safe);
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiService().registerFcmToken(token);
      _tokenNeedsRetry = false;
    } catch (_) {
      // USAJILI WA TOKEN IMESHINDIKANA (offline / hitilafu ndogo) — USIIMIMIZE!
      //
      // catch (_){} ya zamani ilificha kosa kabisa: token haikuwahi kuingia
      // kwenye server, hivyo apps zingine WSHN zinaonekana kwenye app
      // (WebSocket badges) lakini push haifiki simu — ndiyo kasoro halisi
      // mtumiaji anaionayo: "badge ina namba, arifa haipo".
      //
      // Sas'i: alama _tokenNeedsRetry ili kujaribu tena mara hizi mbili:
      //  1) mtandao ukireja (NetworkService.addOnlineListener), au
      //  2) marudio ya _ensurePermissionAndToken (login mpya / retry).
      _tokenNeedsRetry = true;
    }
  }

  // ── Kuonyesha arifa ───────────────────────────────────────────────────────

  Future<void> _show({
    required String type,
    required String title,
    required String body,
    Map<dynamic, dynamic>? payload,
  }) async {
    try {
      // Canvas large icon (cached)
      ByteArrayAndroidBitmap? largeIcon;
      try {
        final bytes = await buildNotifLargeIcon(
          type, status: payload?['status']?.toString());
        largeIcon = ByteArrayAndroidBitmap(bytes);
      } catch (_) {}

      final categoryLabel = _categoryLabel(type);
      final channelId     = _channelId(type);
      final channelName   = _channelName(channelId);
      final isUrgent      = channelId != 'kubadilishana_general_v2';

      final android = AndroidNotificationDetails(
        channelId, channelName,
        importance:       isUrgent ? Importance.max  : Importance.high,
        priority:         isUrgent ? Priority.max    : Priority.high,
        icon:             'ic_notification',
        largeIcon:        largeIcon ?? const DrawableResourceAndroidBitmap('ic_notification_large'),
        color:            const Color(0xFF1E40AF),
        subText:          'Kubadilishana · $categoryLabel',
        enableLights:     true,
        ledColor:         const Color(0xFF1E40AF),
        ledOnMs:          800,
        ledOffMs:         1500,
        enableVibration:  true,
        playSound:        true,
        channelShowBadge: true,
        when:             DateTime.now().millisecondsSinceEpoch,
        showWhen:         true,
        visibility:       NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle:  title,
          summaryText:   categoryLabel,
        ),
        actions: _actionsFor(type),
        category: (type.startsWith('feedback') || type == 'admin.reply')
            ? AndroidNotificationCategory.message
            : AndroidNotificationCategory.event,
      );

      await _localNotifications.show(
        (type + title).hashCode & 0x7fffffff,
        title,
        body,
        NotificationDetails(android: android),
        payload: jsonEncode(payload ?? {'type': type}),
      );
    } catch (_) {}
  }

  void _showFromData(Map<String, dynamic> data) {
    final type  = data['type']?.toString() ?? '';
    final title = data['title']?.toString() ??
        data['notification_title']?.toString() ?? 'Kubadilishana';
    final body  = data['body']?.toString() ??
        data['message']?.toString() ??
        data['notification_body']?.toString() ?? '';
    if (body.isEmpty && title.isEmpty) return;
    if (_isDuplicate(type, data['notification_id']?.toString() ?? '',
        title, body)) { return; }
    _show(type: type, title: title, body: body, payload: data);
  }

  void showFromEvent(Map<String, dynamic> event) {
    final type = resolveNotificationEventType(event);
    // OTP ya admin kupitia WS pia (kama FCM haifiki) — inbox already.
    if (type == 'admin.otp') {
      final raw = (event['otp'] ??
              (event['data'] is Map ? (event['data'] as Map)['otp'] : null))
          ?.toString() ??
          '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 6) AdminOtpInbox.instance.push(digits);
      return;
    }

    const adminNotifiable = {
      'payment.submitted', 'payment.message',
      'feedback.new', 'user.registered', 'password_reset.new',
      'match.found', 'match.new',
    };
    const userNotifiable = {
      'notification', 'notification.new',
      'message.new', 'message', 'message.sent',
      'call.initiated',
      'match.found', 'match.new',
      'user.registered', // mtu anayefaa amejiunga (destination-based)
      'user.verified',
      'payment.approved', 'payment.rejected',
      'payment.message', 'payment.reply',
      'feedback.replied', 'admin.reply',
      'announcement', 'announcement.new',
    };

    final isAdmin   = adminPageNotifierAdminStatus();
    final notifiable = isAdmin ? adminNotifiable : userNotifiable;
    if (!notifiable.contains(type)) return;

    Map<String, dynamic> d = event;
    for (final k in const ['data', 'payload', 'notification']) {
      final nested = event[k];
      if (nested is Map) {
        d = nested.map((k2, v2) => MapEntry(k2.toString(), v2));
        break;
      }
    }

    final title = d['title']?.toString() ??
        event['title']?.toString() ?? _titleForType(type);
    final body  = d['body']?.toString() ??
        d['message']?.toString() ??
        event['body']?.toString() ??
        event['message']?.toString() ?? '';
    if (body.isEmpty && type != 'match.found' && type != 'user.registered') { return; }
    // Dedupe na FCM: backend inatuma notification_id ILE ILE kwenye WS
    // payload na FCM data — tuingia kwa id, si title+body.
    final nid = (d['notification_id'] ?? event['notification_id'] ??
                 d['id'] ?? event['id'])?.toString() ?? '';
    if (_isDuplicate(type, nid, title, body)) { return; }

    _show(type: type, title: title, body: body, payload: event);
  }

  Future<void> removeToken() async {
    if (_fcmToken != null) {
      try { await ApiService().removeFcmToken(_fcmToken!); } catch (_) {}
    }
    _recent.clear();
    _tokenNeedsRetry = false;
    _fcmToken = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<AndroidNotificationAction> _actionsFor(String type) {
    // Hakuna vitufe — gusa notification uingie app, fanya ndani.
    return const [];
  }

  static String _categoryLabel(String type) {
    if (type.startsWith('payment'))                          { return 'Malipo'; }
    if (type.startsWith('feedback') || type == 'admin.reply') { return 'Maoni'; }
    if (type.startsWith('match'))                            { return 'Mechi'; }
    if (type.startsWith('announcement'))                     { return 'Tangazo'; }
    if (type == 'user.registered')                           { return 'Watumiaji'; }
    return 'Arifa';
  }

  static String _channelId(String type) {
    if (type.startsWith('payment') ||
        type.startsWith('feedback') ||
        type == 'admin.reply') { return 'kubadilishana_messages_v2'; }
    if (type.startsWith('match') ||
        type == 'user.registered') { return 'kubadilishana_matches_v2'; }
    if (type.startsWith('message') || type.startsWith('call') ||
        type.startsWith('chat')) { return 'kubadilishana_messages_v2'; }
    return 'kubadilishana_general_v2';
  }

  static String _channelName(String id) => switch (id) {
    'kubadilishana_messages_v2' => 'Ujumbe',
    'kubadilishana_matches_v2'  => 'Mechi',
    _                           => 'Matangazo',
  };

  static String _titleForType(String type) => switch (type) {
    'message.new'      || 'message'             => 'Ujumbe mpya',
    'message.sent'                               => 'Ujumbe mpya',
    'call.initiated'                             => 'Simu mpya',
    'match.found'      || 'match.new'           => 'Mechi mpya imepatikana!',
    'user.verified'                              => 'Akaunti yaidhinishwa',
    'payment.approved'                           => 'Malipo yameidhinishwa ✓',
    'payment.rejected'                           => 'Malipo hayakuidhinishwa',
    'payment.submitted'                          => 'Malipo mapya — angalia',
    'feedback.new'                               => 'Maoni mapya ya mtumiaji',
    'feedback.replied' || 'admin.reply'          => 'Admini amejibu maoni yako',
    'user.registered'                            => 'Mtu anayefaa amejiunga!',
    'password_reset.new'                         => 'Ombi la kubadilisha nywila',
    'announcement'     || 'announcement.new'     => 'Tangazo jipya',
    _                                            => 'Kubadilishana',
  };
}
