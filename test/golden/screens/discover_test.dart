import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'discover_harness.dart';

Future<void> _golden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/discover_$name.png'),
);

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('192:8644 For you (B1 Home 31:24)', (tester) async {
    await pumpApp(tester, Routes.home);
    await _golden('for_you');
  });

  testWidgets('192:9042 loading', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.hang]),
    );
    await _golden('loading');
  });

  testWidgets('192:8909 refreshing', (tester) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.data, BriefsCall.hang]),
    );
    container.read(discoverFeedProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await _golden('refreshing');
  });

  testWidgets('192:9179 loading more', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.data, BriefsCall.hang]),
    );
    await _scrollToEnd(tester);
    await _golden('loading_more');
  });

  testWidgets('192:9334 end of list', (tester) async {
    await pumpApp(tester, Routes.home);
    await _scrollToEnd(tester);
    await _golden('end_of_list');
  });

  testWidgets('165:8285 no briefs', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.empty]),
    );
    await _golden('no_briefs');
  });

  testWidgets('165:8401 failed to load', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.fail]),
    );
    await _golden('failed');
  });

  testWidgets('192:9763 Filters, order by interests (B1 31:397)', (
    tester,
  ) async {
    await pumpApp(tester, Routes.filters);
    await _golden('filters');
  });

  testWidgets('192:9707 Brief detail, saved (B1 31:665)', (tester) async {
    await pumpApp(tester, Routes.brief('c5'));
    await _golden('brief_detail');
  });

  testWidgets('250:12333 Saved briefs', (tester) async {
    await pumpApp(tester, Routes.savedBriefs);
    await _golden('saved');
  });

  testWidgets('250:12609 Saved briefs offline', (tester) async {
    final demo = DemoData(now: figmaNow);
    final saved = [
      for (final id in ['c5', 'c4'])
        demo.briefs.firstWhere((b) => b.id == id).toJson(),
    ];
    await pumpApp(
      tester,
      Routes.savedBriefs,
      repository: ScriptedRepository([BriefsCall.fail]),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': jsonEncode(saved)},
    );
    await _golden('saved_offline');
  });

  testWidgets('250:12880 Saved briefs empty', (tester) async {
    await pumpApp(
      tester,
      Routes.savedBriefs,
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
    );
    await _golden('saved_empty');
  });
}
