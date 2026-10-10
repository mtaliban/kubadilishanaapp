// NOTE (Buffy): Mockup ya ukurasa wa "Maoni na malalamiko" (orodha moja kwa moja
// + ReplyBox) iliyopeswa KAMA ILIVYO (sio sehemu ya app halisi — hiyo ni
// lib/screens/admin/admin_feedback_page.dart). Demo standalone yenye main() yake.
// Data hard-coded ya mfano; haipaswi kwa app halisi.

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

const kInk = Color(0xFF243049);
const kMut = Color(0xFF7A8496);
const kLine = Color(0xFFE3E7EE);
const kAc = Color(0xFF1F5FD6);
const kSoft = Color(0xFFE8EFFC);
const kErr = Color(0xFFB3261E);
const kBtnText = Color(0xFF5B6679);
const kDisabled = Color(0xFFB5BCC8);

const int kPageSize = 5; // idadi ya maoni kwa kila ukurasa

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maoni na malalamiko',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: kAc),
      ),
      home: const MaoniPage(),
    );
  }
}

class Maoni {
  final int id;
  final String name, phone, day, month, time, msg;
  String? rep;
  Maoni(this.id, this.name, this.phone, this.day, this.month, this.time,
      this.msg, this.rep);
}

class MaoniPage extends StatefulWidget {
  const MaoniPage({super.key});
  @override
  State<MaoniPage> createState() => _MaoniPageState();
}

class _MaoniPageState extends State<MaoniPage> {
  // Data ya mfano. Badilisha na data kutoka server yako.
  final List<Maoni> items = [
    Maoni(1, 'Nyaroso Ally Kiu…', '+255 783 ••• 900', '9', 'Okt', '07:41',
        'Mimi mgeni wadau. Je kwani kuna utaratibu wa kulipia naona nimeandikiwa hajalipia',
        'Okay unalipia system Kisha unakuwa na Uwezo wa kuaccess Kila kitu ndugu'),
    Maoni(2, 'Neema Joseph', '+255 7•• ••• •••', '9', 'Okt', '06:12',
        'Nimejaribu kuingia leo asubuhi lakini inaniambia kuna hitilafu. Naomba msaada.',
        null),
    Maoni(3, 'Erick Elias', '+255 759 ••• 199', '8', 'Okt', '05:49',
        'Napendekeza itengenezwe application',
        'ndio kaka Iko njiani inakuja inshallah ndugu'),
    Maoni(4, 'Maulidi Mtulia', '+255 655 ••• 490', '8', 'Okt', '05:19', 'Okay',
        'okay'),
    Maoni(5, 'Fred Yohana Ma…', '+255 752 ••• 170', '7', 'Okt', '10:54',
        'Nikimuona ninayefanana naye nawezaji kuwasiliana',
        'Unalipia support ya system then utaona wote hao na namba zao'),
  ];

  String tab = 'all'; // all | new | done
  String query = '';
  int page = 1;
  int? editId;

  List<Maoni> get filtered {
    final s = query.trim().toLowerCase();
    return items.where((i) {
      final okTab =
          tab == 'all' || (tab == 'new' ? i.rep == null : i.rep != null);
      final okQ = s.isEmpty ||
          '${i.name} ${i.phone} ${i.msg} ${i.rep ?? ''}'
              .toLowerCase()
              .contains(s);
      return okTab && okQ;
    }).toList();
  }

  List<String> get emptyText {
    if (query.trim().isNotEmpty) {
      return [
        'Hakuna matokeo',
        'Hakuna maoni yanayolingana na utafutaji wako. Jaribu neno lingine.'
      ];
    }
    if (tab == 'new') {
      return [
        'Umejibu yote',
        'Hakuna maoni yasiyojibiwa kwa sasa. Maoni mapya yataonekana hapa.'
      ];
    }
    if (tab == 'done') {
      return ['Bado hujajibu', 'Maoni uliyojibu yataonekana hapa.'];
    }
    return [
      'Hakuna maoni bado',
      'Live: maoni yote ya watumiaji yataonekana hapa papo hapo yanapofika.'
    ];
  }

  @override
  Widget build(BuildContext context) {
    final nNew = items.where((i) => i.rep == null).length;
    final total = items.length;
    final all = filtered;
    int pages = (all.length + kPageSize - 1) ~/ kPageSize;
    if (pages < 1) pages = 1;
    if (page > pages) page = pages;
    final start = (page - 1) * kPageSize;
    final rows = all.skip(start).take(kPageSize).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            _header(nNew),
            _tabs(total, nNew),
            _search(),
            if (rows.isEmpty) _empty(),
            ...rows.map(_item),
            if (rows.isNotEmpty) _pagination(pages),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _header(int nNew) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Maoni na malalamiko',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                      letterSpacing: -0.5),
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(radius: 3.5, backgroundColor: kAc),
              const SizedBox(width: 6),
              const Text('Live',
                  style: TextStyle(
                      color: kAc, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nNew > 0
                ? '$nNew ${nNew == 1 ? 'ujumbe unasubiri' : 'jumbe zinasubiri'} jibu lako.'
                : 'Soma maoni ya watumiaji na uwajibu.',
            style: const TextStyle(color: kMut, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _tabs(int total, int nNew) {
    final data = <List<dynamic>>[
      ['all', 'Yote', total],
      ['new', 'Yasiyojibiwa', nNew],
      ['done', 'Yaliyojibiwa', total - nNew],
    ];
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: data.map((t) {
            final on = tab == t[0];
            return GestureDetector(
              onTap: () => setState(() {
                tab = t[0] as String;
                page = 1;
                editId = null;
              }),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: on ? kAc : Colors.transparent, width: 2)),
                ),
                child: Text('${t[1]} ${t[2]}',
                    style: TextStyle(
                        fontSize: 13,
                        color: on ? kInk : kMut,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _search() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: TextField(
        onChanged: (v) => setState(() {
          query = v;
          page = 1;
          editId = null;
        }),
        style: const TextStyle(fontSize: 13, color: kInk),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Tafuta jina, namba au ujumbe',
          hintStyle: TextStyle(color: kMut, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: kMut),
          prefixIconConstraints: BoxConstraints(minWidth: 28),
        ),
      ),
    );
  }

  Widget _empty() {
    final e = emptyText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                const BoxDecoration(color: kSoft, shape: BoxShape.circle),
            child: const Icon(Icons.speaker_notes_off_outlined,
                color: kAc, size: 30),
          ),
          const SizedBox(height: 14),
          Text(e[0],
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: kInk)),
          const SizedBox(height: 6),
          Text(e[1],
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMut, fontSize: 13, height: 1.45)),
        ],
      ),
    );
  }

  Widget _item(Maoni i) {
    final editing = i.rep == null || editId == i.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(i.day,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: kInk)),
                const SizedBox(height: 2),
                Text(i.month,
                    style: const TextStyle(fontSize: 11, color: kMut)),
                const SizedBox(height: 8),
                Text(i.time, style: const TextStyle(fontSize: 11, color: kMut)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk)),
                const SizedBox(height: 1),
                Text(i.phone,
                    style: const TextStyle(fontSize: 11, color: kMut)),
                const SizedBox(height: 8),
                Text(i.msg,
                    style: const TextStyle(
                        fontSize: 15, height: 1.4, color: kInk)),
                const SizedBox(height: 10),
                if (!editing) ...[
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: kAc, width: 2))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Jibu lako',
                            style: TextStyle(fontSize: 11, color: kMut)),
                        const SizedBox(height: 2),
                        Text(i.rep!,
                            style: const TextStyle(
                                fontSize: 13, height: 1.4, color: kInk)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => editId = i.id),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Hariri jibu',
                          style: TextStyle(fontSize: 12, color: kBtnText)),
                    ),
                  ),
                ] else
                  ReplyBox(
                    key: ValueKey('reply-${i.id}-${i.rep}'),
                    initial: i.rep ?? '',
                    isEdit: i.rep != null,
                    onSend: (text) => setState(() {
                      i.rep = text;
                      editId = null;
                    }),
                    onCancel: () => setState(() => editId = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagination(int pages) {
    Widget circle(Widget child, bool on, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? kAc : Colors.transparent,
            border: Border.all(color: on ? kAc : kLine),
          ),
          child: child,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          circle(
              Icon(Icons.chevron_left,
                  size: 18, color: page > 1 ? kInk : kDisabled),
              false,
              page > 1
                  ? () => setState(() {
                        page--;
                        editId = null;
                      })
                  : null),
          for (int k = 1; k <= pages; k++)
            circle(
                Text('$k',
                    style: TextStyle(
                        fontSize: 13,
                        color: k == page ? Colors.white : kInk,
                        fontWeight:
                            k == page ? FontWeight.w600 : FontWeight.w400)),
                k == page,
                () => setState(() {
                      page = k;
                      editId = null;
                    })),
          circle(
              Icon(Icons.chevron_right,
                  size: 18, color: page < pages ? kInk : kDisabled),
              false,
              page < pages
                  ? () => setState(() {
                        page++;
                        editId = null;
                      })
                  : null),
        ],
      ),
    );
  }
}

/// Kisanduku cha jibu: kinaanza mstari mmoja, kinatanuka maneno yakiongezeka,
/// na kitufe cha kutuma kipo ndani yake chini kulia.
class ReplyBox extends StatefulWidget {
  final String initial;
  final bool isEdit;
  final ValueChanged<String> onSend;
  final VoidCallback onCancel;
  const ReplyBox({
    super.key,
    required this.initial,
    required this.isEdit,
    required this.onSend,
    required this.onCancel,
  });
  @override
  State<ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<ReplyBox> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  String? error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      setState(() => error = 'Andika jibu kwanza');
      return;
    }
    widget.onSend(v); // hapa weka pia API call ya kutuma jibu kwenye server
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(21),
      borderSide: const BorderSide(color: Color(0xFFD3D9E4)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Stack(
          children: [
            TextField(
              controller: _c,
              autofocus: widget.isEdit,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              onChanged: (_) {
                if (error != null) setState(() => error = null);
              },
              style: const TextStyle(fontSize: 14, height: 1.35, color: kInk),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Andika jibu lako…',
                hintStyle: const TextStyle(color: kMut, fontSize: 14),
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 46, 12),
                enabledBorder: border,
                focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: kAc, width: 1.5)),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: GestureDetector(
                onTap: _send,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration:
                      const BoxDecoration(color: kAc, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 17),
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child:
                Text(error!, style: const TextStyle(color: kErr, fontSize: 12)),
          ),
        if (widget.isEdit)
          GestureDetector(
            onTap: widget.onCancel,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 0, 6),
              child: Text('Ghairi',
                  style: TextStyle(fontSize: 12, color: kBtnText)),
            ),
          ),
      ],
    );
  }
}
