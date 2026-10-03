import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/features/polls/polls_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'polls_notifications_help_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  PollsService? polls,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(tester, location, overrides: laneOverrides(polls: polls));
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/polls_$name.png',
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Polls · Brands (33:26)', (tester) async {
    await _golden(tester, 'brands', Routes.polls);
  });

  testWidgets('Polls · Orchid Foods · open (33:169)', (tester) async {
    await _golden(tester, 'orchid_open', pollsOf('orchid-foods'));
  });

  testWidgets('Polls · Orchid Foods · voted (33:289)', (tester) async {
    await _golden(
      tester,
      'orchid_voted',
      pollsOf('orchid-foods'),
      act: (tester) => tester.tap(find.text('Zobo and ginger')),
    );
  });

  testWidgets('Sunline, already voted', (tester) async {
    await _golden(tester, 'sunline', pollsOf('sunline'));
  });

  testWidgets('a vote that does not go in', (tester) async {
    await _golden(
      tester,
      'vote_failed',
      pollsOf('unibooks'),
      polls: FailingPollsService(),
      act: (tester) => tester.tap(find.text('WhatsApp')),
    );
  });
}
