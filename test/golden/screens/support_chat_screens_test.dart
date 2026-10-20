import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'help_harness.dart';
import 'polls_notifications_help_harness.dart';

/// The B21 chat frames read on Tuesday 20 October at 9:41.
final chatNow = DateTime(2026, 10, 20, 9, 41);

DemoHelpService chatHelp({bool empty = false}) {
  final help = DemoHelpService(
    delay: Duration.zero,
    uploadStep: Duration.zero,
    replyAfter: null,
    seededAt: chatNow,
    clock: () => chatNow,
  );
  return empty ? _EmptyHelp() : help;
}

class _EmptyHelp extends DemoHelpService {
  _EmptyHelp()
    : super(delay: Duration.zero, replyAfter: null, seededAt: DateTime(2026));

  @override
  Future<List<HelpTicket>> conversations() async => const [];
}

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  HelpService? help,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(
    tester,
    location,
    clock: () => chatNow,
    supportChannels: true,
    overrides: [
      ...laneOverrides(help: help ?? chatHelp()),
      ...helpActivations(),
    ],
  );
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await precacheImages(tester);
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/chat_$name.png');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('B21 · Support inbox (1589:118540)', (tester) async {
    await _golden(tester, 'inbox', Routes.support);
  });

  testWidgets('B21 · Support inbox · empty (1589:118626)', (tester) async {
    await _golden(
      tester,
      'inbox_empty',
      Routes.support,
      help: chatHelp(empty: true),
    );
  });

  testWidgets('B21 · Support inbox · resolved', (tester) async {
    await _golden(
      tester,
      'inbox_resolved',
      Routes.support,
      act: (tester) => tester.tap(find.text('Resolved · 1')),
    );
  });

  testWidgets('B21 · Thread · iQLY support · earlier (1589:118774)', (
    tester,
  ) async {
    await _golden(
      tester,
      'thread_iqly_earlier',
      helpThreadPath('withdrawal'),
      act: (tester) =>
          tester.drag(find.byType(ListView).last, const Offset(0, 2000)),
    );
  });

  testWidgets('B21 · Thread · iQLY support · latest, typing (1589:119167)', (
    tester,
  ) async {
    await _golden(
      tester,
      'thread_iqly_latest',
      helpThreadPath('withdrawal'),
      act: (tester) => tester.enterText(
        find.byType(EditableText),
        'Thank you, I’ll do that now.',
      ),
    );
  });

  testWidgets('B21 · Thread · Orchid Foods (1589:122097)', (tester) async {
    await _golden(tester, 'thread_orchid', helpThreadPath('orchid-foods'));
  });

  testWidgets('B21 · Thread · resolved, Kudi Box (1589:122537)', (
    tester,
  ) async {
    await _golden(tester, 'thread_resolved', helpThreadPath('kudi-box'));
  });

  testWidgets('B21 · Thread · Kudi Box, new from the activation '
      '(1639:125529)', (tester) async {
    await _golden(tester, 'thread_new', kudiBoxHelp, help: _EmptyHelp());
  });
}
