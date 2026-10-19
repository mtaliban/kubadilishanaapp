/// AdminOtpInbox — kanzidata ndogo ya code za 2FA za admin zinazofika kwenye
/// app yenyewe (FCM push / WS event, type='admin.otp').
///
/// Kwa nini: hapo awali code ya 2FA ya admin ilikuwa INATUMWA KWA EMAIL pekee
/// — mbimi anabidi kufungua Gmail kutafuta tarakimu 6 kila mara anapoingia
/// (kasoro halisi). Sasa backend inamtumia pia FCM push yenye `otp` kwenye
/// data; AdminOtpStep inapokea na kuiweka KIOTOMATE kwenye boxes — hakuna
/// kwenda Gmail (Email ndiyo backup kama push haifiki).
///
/// Matumizi:
///   AdminOtpInbox.instance.codes.listen((code) { ...weka kwenye boxes... });
///   AdminOtpInbox.instance.push('123456');
library;

import 'dart:async';

class AdminOtpInbox {
  static final AdminOtpInbox instance = AdminOtpInbox._();
  AdminOtpInbox._();

  final _controller = StreamController<String>.broadcast();

  /// Stream ya code zinazofika (broadcast — AdminOtpStepMoja inasikiliza).
  Stream<String> get codes => _controller.stream;

  /// Ita mara code inafika (notification_service ndiyo mwenye kuita).
  void push(String code) {
    if (code.length != 6) return;
    _controller.add(code);
  }
}
