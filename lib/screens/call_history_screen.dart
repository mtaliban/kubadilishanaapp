/// Call/contact history screen — lists all logged contacts (/messages/calls).
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cached_repository.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/no_cached_data_widget.dart';

// OFFLINE-FIRST — funguo ya diski ya historia ya kupigiana ya mtumiaji.
const _kCallsKey = 'page:user/call-history';

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

bool _nd(BuildContext c__) => Theme.of(c__).brightness == Brightness.dark;
Color _kGrey100T(BuildContext c__) => _nd(c__) ? const Color(0xFF212833) : _kGrey100;
Color _kGrey200T(BuildContext c__) => _nd(c__) ? const Color(0xFF2A3240) : _kGrey200;
Color _kGrey400T(BuildContext c__) => _nd(c__) ? const Color(0xFF64748B) : _kGrey400;
Color _kGrey500T(BuildContext c__) => _nd(c__) ? const Color(0xFF9AA8C7) : _kGrey500;
Color _kGrey700T(BuildContext c__) => _nd(c__) ? const Color(0xFFCBD5E1) : _kGrey700;
Color _kGrey900T(BuildContext c__) => _nd(c__) ? const Color(0xFFE7ECF8) : _kGrey900;
Color _kBlue50T(BuildContext c__) => _nd(c__) ? const Color(0xFF1C2A44) : _kBlue50;
Color _kBlueT(BuildContext c__) => _nd(c__) ? const Color(0xFF7AA7FF) : _kBlue;

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<dynamic> _allCalls = [];
  List<dynamic> _filtered = [];
  bool _loading = true; // bado tuna diski KABISA
  String _filter = 'Zote';

  static const _filters = ['Zote', 'Simu', 'SMS', 'WhatsApp'];

  void _onWs(dynamic _) {
    if (mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    // DISKI PAPO HAPO — historia ya diski KWA FRAME YA KWANZA (hakuna spring).
    CachedRepository().hydrate(_kCallsKey, _applyCalls);
    _load();
    // Mtumiaji akipigiwa simu/SMS/WhatsApp, historia inajisasisha PAPO HAPO
    WebSocketService().on('contact.activity', _onWs);
  }

  void _applyCalls(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final calls = data is List ? data : <dynamic>[];
    setState(() {
      _allCalls = calls;
      _applyFilter(_filter);
      _loading = false;
    });
  }

  @override
  void dispose() {
    WebSocketService().off('contact.activity', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: historia ya diski inabaki.
    if (_allCalls.isEmpty) setState(() => _loading = true);
    await CachedRepository().loadPage(_kCallsKey, _fetchCalls, _applyCalls);
    if (mounted && _loading) setState(() => _loading = false);
  }

  /// API ya ukurasa huu — huitwa na CachedRepository nyuma ya pazia.
  Future<dynamic> _fetchCalls() async =>
      (await ApiService().getCallHistory()).data;

  void _applyFilter(String filter) {
    _filter = filter;
    if (filter == 'Zote') {
      _filtered = List.from(_allCalls);
    } else {
      final typeKey = _swahiliToType(filter);
      _filtered =
          _allCalls.where((c) => c['contact_type'] == typeKey).toList();
    }
  }

  String _swahiliToType(String swahili) {
    switch (swahili) {
      case 'Simu':
        return 'call';
      case 'SMS':
        return 'sms';
      case 'WhatsApp':
        return 'whatsapp';
      default:
        return swahili.toLowerCase();
    }
  }

  String _typeToSwahili(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return 'Simu';
      case 'sms':
        return 'SMS';
      case 'whatsapp':
        return 'WhatsApp';
      default:
        return type;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return Icons.phone;
      case 'sms':
        return Icons.sms;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.contact_phone;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return Colors.green;
      case 'sms':
        return Colors.blue;
      case 'whatsapp':
        return const Color(0xFF25D366);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      body: Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: _kGrey100T(context), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey700T(context))),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kBlue50T(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBlueT(context).withValues(alpha: 0.2))),
                child: Icon(Icons.history_rounded, size: 20, color: _kBlueT(context))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Historia ya Mawasiliano',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900T(context))),
                Text('Simu, SMS na WhatsApp zako',
                    style: TextStyle(fontSize: 12, color: _kGrey500T(context))),
              ])),
            ]),
          ),
          Container(height: 1, color: _kGrey200T(context)),
          // Filter row — SingleChildScrollView: font kubwa haikiuki chips
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _applyFilter(f)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? _kBlueT(context) : _kGrey100T(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? _kBlueT(context) : _kGrey200T(context),
                          ),
                        ),
                        child: Text(f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white : _kGrey500T(context))),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(height: 1, color: _kGrey200T(context)),

          // Body
          Expanded(
            child: _loading && _allCalls.isEmpty
                // Bado hakuna diski — NoCachedDataWidget (spinner mtandaoni,
                // "download" ikoni bila mtandao).
                ? const Center(child: NoCachedDataWidget())
                : _allCalls.isEmpty &&
                        CachedRepository().readOrNull<dynamic>(_kCallsKey) == null
                    // HAKUNA data diski + API imeshindwa — widget MOYA ya
                    // "haijapakuliwa" (pull-to-refresh pekee).
                    ? const NoCachedDataWidget(
                        hint: 'Vuta chini kupakia — historia zitahifadhiwa kwenye simu.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? _EmptyState(filter: _filter)
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final call = _filtered[i];
                                  return _CallCard(
                                    call: call,
                                    iconForType: _iconForType,
                                    colorForType: _colorForType,
                                    typeToSwahili: _typeToSwahili,
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  final dynamic call;
  final IconData Function(String) iconForType;
  final Color Function(String) colorForType;
  final String Function(String) typeToSwahili;

  const _CallCard({
    required this.call,
    required this.iconForType,
    required this.colorForType,
    required this.typeToSwahili,
  });

  @override
  Widget build(BuildContext context) {
    final direction = call['direction']?.toString() ?? 'out';
    final withName = call['with_full_name']?.toString() ?? 'Mtumiaji';
    final contactType = call['contact_type']?.toString() ?? 'call';
    final initiatedAt = call['initiated_at']?.toString() ?? '';

    final dateStr = initiatedAt.contains('T')
        ? initiatedAt.split('T').first
        : initiatedAt;

    final icon = iconForType(contactType);
    final color = colorForType(contactType);
    final swahiliType = typeToSwahili(contactType);
    final isOut = direction == 'out';
    final dirIcon = isOut ? Icons.call_made : Icons.call_received;
    final dirColor = isOut ? const Color(0xFF1D4ED8) : const Color(0xFF16A34A);
    final dirLabel = isOut ? 'Ilitoka' : 'Iliingia';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200T(context)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Icon(icon, color: color, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(withName,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900T(context)),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Icon(dirIcon, size: 11, color: dirColor),
            const SizedBox(width: 3),
            Text('$dirLabel · $swahiliType',
              style: TextStyle(fontSize: 11, color: _kGrey500T(context))),
          ]),
        ])),
        if (dateStr.isNotEmpty)
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kGrey100T(context),
                borderRadius: BorderRadius.circular(8)),
              child: Text(dateStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kGrey500T(context))),
            ),
          ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kGrey100T(context),
                  borderRadius: BorderRadius.circular(18)),
                child: Center(child: Icon(Icons.history_rounded, size: 28, color: _kGrey400T(context))),
              ),
              const SizedBox(height: 16),
              Text(
                filter == 'Zote'
                    ? 'Hakuna historia ya mawasiliano'
                    : 'Hakuna rekodi za $filter',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kGrey700T(context)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text('Mawasiliano yako yataonekana hapa',
                style: TextStyle(fontSize: 12, color: _kGrey400T(context)),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}