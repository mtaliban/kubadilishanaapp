/// MUDA ULIOPITA (mfano wa WhatsApp) — "Sasa hivi", "dak 7", "saa 2",
/// "Jana", "siku 3", halafu "d Mon" kwa za kale.
///
/// Inatumika kwenye kurasa za arifa na maoni — kila sehemu inayoonyesha
/// tarehe/saa ya kitu kilichotokea napata mfano mwelekeo huu badala ya
/// "20 Okt · 14:05" pekee (mtumiaji hakuonyesha MUDA ULIOPITA — "dak 7").
library;

const List<String> kTimeAgoMonths = [
  'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
];

/// String ya ISO → muda uliopita mfupi. Iso tupu/isiyoeleweka → '' (mwisho:
/// UI inaonyesha kino ka protector — hakuna kitu kikubwa kinachoharibika).
String timeAgoShort(String iso) {
  if (iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return timeAgoShortFromDateTime(d);
}

/// Thamani ya muda (DateTime) → muda uliopita mfupi.
///
/// Kanuni:
///  • sekunde chini ya 1      → 'Sasa hivi'
///  • dakika < 60            → 'dak 7'
///  • saa < 24               → 'saa 2'
///  • saa < 48               → 'Jana'
///  • siku < 30              → 'siku 3'
///  • kwa zaidi ya 30 siku   → '20 Sep' (siku + mwezi)
///
/// [at] hutolewa na tests ili muda usibadirikane kati ya wakati
/// halisi na wa test — referral haiwahitaji.
String timeAgoShortFromDateTime(DateTime d, {DateTime? at}) {
  try {
    final local = d.toLocal();
    final ref = (at ?? DateTime.now()).toLocal();
    var diff = ref.difference(local);
    // ARIFA ZILIKUWA ZINABAKIA 'Sasa hivi' MILELE kama simu ya mtumiaji iko
    // NYUMA kidogo ya saa ya server (arifa inaweza kuonekana inatangulia
    // wakati wa simu → diff hasi → inabaki 'Sasa hivi' milele). Tumia
    // TOFAUTI KAMILI (abs): arifa yenye 'dak 7' hata kwa simu iliyopinda
    // inaonyesha 'dak 7', si 'Sasa hivi' milele.
    if (diff.inSeconds < 0) diff = -diff;
    if (diff.inMinutes < 1) return 'Sasa hivi';
    if (diff.inMinutes < 60) return 'dak ${diff.inMinutes}';
    if (diff.inHours < 24) return 'saa ${diff.inHours}';
    if (diff.inHours < 48) return 'Jana';
    if (diff.inDays < 30) return 'siku ${diff.inDays}';
    return '${local.day} ${kTimeAgoMonths[local.month - 1]}';
  } catch (_) {
    return '';
  }
}
