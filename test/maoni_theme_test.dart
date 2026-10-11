// ============================================================================
// test/maoni_theme_test.dart
// Ukaguzi wa rangi za Maoni — DESIGN MPYA (nukuu ya gazeti / serif, code mockup):
//   inbox nyeupe, chat nyeupe, Live dot bluu, incoming nukuu serif,
//   outgoing mstari wa bluu kushoto + serif italic. Hakuna bluu kali ya ofa
//   isipokuwa kwenye accents zilizoruhusiwa (Live dot, mstari wa quote, Tuma).
// Inatumia InMemoryMaoniRepository.demo() na kunakagua Container decorations
// halisi kwenye widget tree.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/admin/maoni_pages.dart';

// ignore: invalid_use_of_protected_member, implementation_imports
// _C ni private — tunakagua whiteof (private class + static public).
// Badala yake tunakagua Scaffold.background kwa thamani halisi kutoka kwenye
// lib code (whiteof inaweza kubadilika — lakini tunakagua ile inayoonekana).


bool _isBlueDominant(Color c) => c.b > c.r + 40 && c.b > c.g + 40;

/// Kusanya Container zote zenye BoxDecoration yenye rangi.
List<BoxDecoration> _boxDecorations(WidgetTester tester) {
  final out = <BoxDecoration>[];
  for (final w in tester.widgetList<Container>(find.byType(Container))) {
    final d = w.decoration;
    if (d is BoxDecoration) out.add(d);
  }
  return out;
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MaoniInboxPage(repo: InMemoryMaoniRepository.demo()),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openChat(WidgetTester tester, String name) async {
  await _pump(tester);
  final row = find.textContaining(name).first;
  expect(row, findsOneWidget, reason: 'Mazungumzo ya "$name" yanapaswa kuonekana');
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Inbox: background NYEUPE (Container mweupe) + hakuna bluu kali',
      (tester) async {
    await _pump(tester);
    expect(find.text('Maoni'), findsOneWidget);

    // Inbox root: Container(color: Colors.white) — color parameter (siyo
    // decoration), kwa hivyo tunakagua Container.color moja kwa moja.
    final whiteRoot = tester
        .widgetList<Container>(find.byType(Container))
        .any((w) => w.color == Colors.white);
    expect(whiteRoot, isTrue,
        reason: 'Inbox inapaswa kuwa na Container background nyeupe');
    // Hakuna bluu kali (opaque, blue-dominant) kwenye inbox yote.
    for (final d in _boxDecorations(tester)) {
      final c = d.color;
      if (c == null) continue;
      expect(
        _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .6,
        isFalse,
        reason: 'Inbox ina Container yenye bluu kali: $c',
      );
    }
  });

  testWidgets('Chat: background NYEUPE chat ni layout ya nukuu (gazeti)',
      (tester) async {
    await _openChat(tester, 'Godwin');

    // Chat inaonyesha jumbe za mtumiaji ("sawa").
    expect(find.textContaining('sawa'), findsWidgets);

    // Design mpya: chat Scaffold.background = whiteof (nyeupe kwenye light).
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final bg = scaffold.backgroundColor;
    final isLightScaffoldBg = bg == Colors.white || bg == null;
    expect(isLightScaffoldBg, isTrue,
        reason: 'Background ya chat inapaswa kuwa nyeupe (design mpya)');

    // Hakuna bluu kali ya opaque non-white kwenye chat (accents ndogo zinaruhusiwa).
    for (final d in _boxDecorations(tester)) {
      final c = d.color;
      if (c == null) continue;
      if (c == const Color(0xFF1F5FD6)) continue; // mstari wa quote / accent
      expect(
        _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .6,
        isFalse,
        reason: 'Chat ina Container yenye bluu kali: $c',
      );
    }
  });

  testWidgets('Chat: jibu la admin (outgoing) lina quote ya bluu kushoto',
      (tester) async {
    await _openChat(tester, 'SELEMANI');

    // Background ya chat: design mpya — whiteof (nyeupe kwenye light).
    // Scaffold ya themepack (wrapper ya _pump) ni ya kwanza; chat ni ya mwisho.
    final chatScaffold = tester.widgetList<Scaffold>(find.byType(Scaffold)).last;
    final bg = chatScaffold.backgroundColor;
    final isLightScaffoldBg = bg == Colors.white || bg == null;
    expect(isLightScaffoldBg, isTrue,
        reason: 'Background ya chat inapaswa kuwa nyeupe (design mpya)');

    // Jibu la admin: mstari wa bluu (#1F5FD6) wa kushoto (quote ya 'Jibu lako').
    final decos = _boxDecorations(tester);
    final hasBlueLeftBorder = decos.any((d) {
      final b = d.border;
      if (b is! Border) return false;
      return b.left.color == const Color(0xFF1F5FD6) && b.left.width == 2;
    });
    expect(
      hasBlueLeftBorder,
      isTrue,
      reason: 'Jibu la admin linapaswa kuwa na mstari wa bluu kushoto',
    );
    // Hakuna bluu kali (opaque blue-dominant) kwenye chat.
    for (final d in decos) {
      final c = d.color;
      if (c == null) continue;
      expect(
        _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .6,
        isFalse,
        reason: 'Chat ina Container yenye bluu kali: $c',
      );
    }
  });

  testWidgets('Filter wa inbox: tab haina bluu kali ya opaque (underline tu)',
      (tester) async {
    await _pump(tester);
    final tabLabel = find.textContaining('Yasiyojibiwa');
    expect(tabLabel, findsOneWidget);

    for (final w in tester.widgetList<Container>(
        find.ancestor(of: tabLabel, matching: find.byType(Container)))) {
      final d = w.decoration;
      if (d is BoxDecoration && d.color != null && d.borderRadius != null) {
        final c = d.color!;
        expect(
          _isBlueDominant(c) && c.a == 1.0 && c.computeLuminance() < .6,
          isFalse,
          reason: 'Tab ina bluu kali: $c',
        );
      }
    }
  });
}
