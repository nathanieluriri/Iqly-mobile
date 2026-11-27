import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/discover_widgets.dart';
import 'package:iqly_mobile/features/discover/saved_briefs_screen.dart';
import 'package:iqly_mobile/features/more/saved_briefs_page.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/meta.dart';
import 'package:iqly_mobile/ui/ticket_card.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';
import '../golden/screens/more_harness.dart';

const _solarTitle = 'A tagline for a solar kiosk network';
const _orchidTitle = 'Naming a new sparkling water brand for Gen Z.';

Finder get _featureCards => find.byWidgetPredicate(
  (widget) => widget is IqBriefCard && widget.kind == IqBriefCardKind.feature,
);

Finder _card(String title) => find.byWidgetPredicate(
  (widget) => widget is IqBriefCard && widget.title == title,
);

Map<String, Object> _savedPrefs() {
  final demo = DemoData(now: figmaNow);
  final saved = [
    for (final id in ['c5', 'c4', 'c1'])
      demo.briefs.firstWhere((brief) => brief.id == id).toJson(),
  ];
  return {...signedInPrefs(), 'discover.savedBriefs': jsonEncode(saved)};
}

Future<void> _revealThirdCard(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _card(_orchidTitle),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(_card(_orchidTitle), findsOneWidget);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('phone Saved renders normal feature cards, not tickets', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.savedBriefs,
      prefs: _savedPrefs(),
      overrides: discoverOverrides(),
    );

    expect(find.byType(SavedBriefsScreen), findsOneWidget);
    expect(_featureCards, findsNWidgets(2));
    await _revealThirdCard(tester);
    expect(find.byType(IqTicketCard), findsNothing);
  });

  testWidgets('More Saved briefs renders normal feature cards, not tickets', (
    tester,
  ) async {
    await pumpMore(tester, Routes.moreSavedBriefs, prefs: _savedPrefs());

    expect(find.byType(MoreSavedBriefsPage), findsOneWidget);
    expect(_featureCards, findsNWidgets(3));
    expect(find.byType(IqTicketCard), findsNothing);
  });

  testWidgets('Saved cards keep their facts, bookmark and navigation', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.savedBriefs,
      prefs: _savedPrefs(),
      overrides: discoverOverrides(),
    );

    expect(container.read(savedBriefsProvider).value, hasLength(3));
    final cards = tester.widgetList<IqBriefCard>(_featureCards).toList();
    expect(cards, hasLength(2));
    for (final card in cards) {
      expect(card.onTap, isNotNull);
      expect(card.onBookmarkChanged, isNotNull);
      expect(card.bookmark, IqBookmarkState.on);
      final facts = card.meta.whereType<IqMeta>().toList();
      expect(facts.any((fact) => fact.kind == IqMetaKind.reward), isTrue);
      expect(
        facts.any(
          (fact) =>
              fact.kind == IqMetaKind.deadline ||
              fact.kind == IqMetaKind.urgent,
        ),
        isTrue,
      );
    }

    final solar = cards.firstWhere((card) => card.title == _solarTitle);
    expect(
      solar.meta.whereType<IqMeta>().map((fact) => fact.label),
      containsAll(['₦150k', '2 min', '6h left']),
    );

    await tester.tap(_card(_solarTitle));
    await tester.pumpAndSettle();
    expect(find.byType(BriefDetailScreen), findsOneWidget);
  });

  testWidgets('re-saving a leaving Saved card cancels its removal', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.savedBriefs,
      prefs: _savedPrefs(),
      overrides: discoverOverrides(),
      reducedMotion: false,
    );
    final bookmark = find.descendant(
      of: _card(_solarTitle),
      matching: find.byType(IqBookmark),
    );

    await tester.tap(bookmark);
    await tester.pump();
    expect(
      container.read(savedBriefsProvider).value!.map((brief) => brief.id),
      isNot(contains('c5')),
    );
    expect(_card(_solarTitle), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(bookmark);
    await tester.pumpAndSettle();

    expect(
      container.read(savedBriefsProvider).value!.map((brief) => brief.id),
      contains('c5'),
    );
    expect(_card(_solarTitle), findsOneWidget);
  });

  testWidgets('offline populated Saved keeps cards and the offline banner', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.savedBriefs,
      repository: ScriptedRepository([BriefsCall.fail]),
      prefs: _savedPrefs(),
      overrides: discoverOverrides(),
    );

    expect(_featureCards, findsNWidgets(2));
    expect(find.text('Offline. Saved briefs still load.'), findsOneWidget);
    await _revealThirdCard(tester);
  });

  testWidgets('offline empty Saved keeps the existing empty state', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.savedBriefs,
      repository: ScriptedRepository([BriefsCall.fail]),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
      overrides: discoverOverrides(),
    );

    expect(_featureCards, findsNothing);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('Offline. Saved briefs still load.'), findsNothing);
  });

  testWidgets('Saved feature cards lay out at double text scale', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.savedBriefs,
      prefs: _savedPrefs(),
      overrides: discoverOverrides(),
    );
    final briefs = container.read(savedBriefsProvider).value!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final brief in briefs) BriefFeatureCard(brief: brief),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_featureCards, findsNWidgets(3));
  });
}
