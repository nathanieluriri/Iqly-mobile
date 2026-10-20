import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/features/polls/polls_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'discover_harness.dart';
import 'polls_notifications_help_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  PollsService? polls,
  DateTime Function()? clock,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(
    tester,
    location,
    overrides: pollsLane(polls: polls),
    clock: clock,
  );
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await precacheImages(tester);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/polls_$name.png',
  );
}

Future<void> _vote(WidgetTester tester, String choice) async {
  await tester.ensureVisible(find.text(choice));
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Quick polls (33:26)', (tester) async {
    await _golden(tester, 'quick_polls', Routes.polls);
  });

  testWidgets('Quick polls, closed poll (480:22779)', (tester) async {
    await _golden(
      tester,
      'closed',
      Routes.polls,
      clock: () => figmaNow.add(const Duration(days: 1, minutes: 1)),
    );
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Orchid Foods · 3 questions · Q1 (1600:33055)', (tester) async {
    await _golden(tester, 'orchid_q1', pollsOf('orchid-foods'));
  });

  testWidgets('Orchid Foods · 3 questions · Q1 voted (1600:33231)', (
    tester,
  ) async {
    await _golden(
      tester,
      'orchid_q1_voted',
      pollsOf('orchid-foods'),
      act: (tester) => _vote(tester, 'Zobo and ginger'),
    );
  });

  testWidgets('Orchid Foods · 3 questions · Q2 (1600:33423)', (tester) async {
    await _golden(
      tester,
      'orchid_q2',
      pollsOf('orchid-foods'),
      act: (tester) async {
        await _vote(tester, 'Zobo and ginger');
        await tapText(tester, 'Next question');
      },
    );
  });

  testWidgets('Orchid Foods · 3 questions · Q2 voted (1600:33608)', (
    tester,
  ) async {
    await _golden(
      tester,
      'orchid_q2_voted',
      pollsOf('orchid-foods'),
      act: (tester) async {
        await _vote(tester, 'Zobo and ginger');
        await tapText(tester, 'Next question');
        await _vote(tester, 'A little');
      },
    );
  });

  testWidgets('Orchid Foods · 3 questions · Q3 (1600:33807)', (tester) async {
    await _golden(
      tester,
      'orchid_q3',
      pollsOf('orchid-foods'),
      act: (tester) async {
        await _vote(tester, 'Zobo and ginger');
        await tapText(tester, 'Next question');
        await _vote(tester, 'A little');
        await tapText(tester, 'Next question');
      },
    );
  });

  testWidgets('Orchid Foods · 3 questions · Q2 skipped (1600:33991)', (
    tester,
  ) async {
    await _golden(
      tester,
      'orchid_q2_skipped',
      pollsOf('orchid-foods'),
      act: (tester) async {
        await _vote(tester, 'Tiger nut');
        await tapText(tester, 'Next question');
      },
    );
  });

  testWidgets('Orchid Foods · 3 questions · done (1600:34175)', (tester) async {
    await _golden(
      tester,
      'orchid_done',
      pollsOf('orchid-foods'),
      act: (tester) async {
        await _vote(tester, 'Zobo and ginger');
        await tapText(tester, 'Next question');
        await _vote(tester, 'A little');
        await tapText(tester, 'Next question');
        await _vote(tester, '1 litre bottle');
        await tapText(tester, 'Done');
      },
    );
  });

  testWidgets('Orchid Foods · full screen (345:15957)', (tester) async {
    await _golden(tester, 'orchid_full', pollPageOf('orchid-foods'));
  });

  testWidgets('a vote that does not go in', (tester) async {
    await _golden(
      tester,
      'vote_failed',
      pollsOf('unibooks'),
      polls: FailingPollsService(),
      act: (tester) => _vote(tester, 'WhatsApp sellers'),
    );
  });
}
