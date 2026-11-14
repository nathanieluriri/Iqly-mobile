import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/discover/tablet_discover.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/chip.dart';
import 'package:iqly_mobile/ui/poll_tile.dart';
import 'package:iqly_mobile/ui/progress_line.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';
import '../golden/screens/tablet_harness.dart';

void main() {
  test('a poll is in progress only while some answers are still open', () {
    final now = DateTime.utc(2026, 11, 14);
    final orchid = demoPolls(now).first;
    expect(orchid.inProgress, isFalse);
    final started = orchid.withPoll(orchid.polls.first.withVote(0));
    expect(started.inProgress, isTrue);
    expect(started.progress, greaterThan(0));
    expect(started.progress, lessThan(1));
  });

  test('a draft and a started activation both fill the bar', () {
    expect(
      const Draft(briefId: 'c5', editedAt: DateTime(2026), step: 1).progress,
      closeTo(1 / 3, 0.001),
    );
    final now = DateTime.utc(2026, 11, 14);
    final kudi = DemoActivations(
      now,
    ).kudiBox.withProgress(DemoActivations(now).stuckAtStep2);
    expect(kudi.inProgressAt(now), isTrue);
    expect(kudi.runProgress, closeTo(2 / 4, 0.001));
  });

  test('Pick up is offered only when something is already started', () {
    final now = DateTime.utc(2026, 11, 14);
    final orchid = demoPolls(now).first;
    expect(
      hasPickUpWork(
        drafts: const [Draft(briefId: 'c5', editedAt: DateTime(2026))],
        polls: [orchid],
        activations: [DemoActivations(now).orchidFoods],
        now: now,
      ),
      isFalse,
    );
    expect(
      hasPickUpWork(
        drafts: const [
          Draft(briefId: 'c5', editedAt: DateTime(2026), title: 'A tagline'),
        ],
        polls: const [],
        activations: const [],
        now: now,
      ),
      isTrue,
    );
    expect(
      hasPickUpWork(
        drafts: const [],
        polls: [orchid.withPoll(orchid.polls.first.withVote(0))],
        activations: const [],
        now: now,
      ),
      isTrue,
    );
    expect(
      hasPickUpWork(
        drafts: const [],
        polls: const [],
        activations: [
          DemoActivations(
            now,
          ).kudiBox.withProgress(DemoActivations(now).stuckAtStep2),
        ],
        now: now,
      ),
      isTrue,
    );
  });

  testWidgets('Pick up is first and only shows started work', (tester) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      overrides: discoverOverrides(),
    );
    expect(find.byType(HomeScreen), findsOneWidget);

    final chips = tester.widgetList<IqChip>(find.byType(IqChip)).toList();
    expect(chips.first.label, 'Pick up');
    expect(chips.map((c) => c.label).take(3), ['Pick up', 'For you', 'All']);
    expect(find.text('Which flavour should we launch first?'), findsOneWidget);
    expect(find.text('Rate 3 recipes in the Orchid Foods app'), findsOneWidget);

    await tester.tap(find.text('Pick up'));
    await tester.pumpAndSettle();
    expect(container.read(discoverFiltersProvider).pickUp, isTrue);
    expect(find.text('Which flavour should we launch first?'), findsNothing);
    expect(find.text('Rate 3 recipes in the Orchid Foods app'), findsNothing);
    expect(
      find.text('Open a Kudi Box account and save ₦1,000.00'),
      findsOneWidget,
    );
    expect(find.text('A tagline for a solar kiosk network'), findsOneWidget);
    expect(
      find.text(
        'How should a campus bookshop sell online?',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.byType(IqProgressLine), findsWidgets);

    final kudi = tester.widget<IqBriefCard>(
      find.byWidgetPredicate(
        (w) =>
            w is IqBriefCard && w.title.startsWith('Open a Kudi Box account'),
      ),
    );
    expect(kudi.progress, isNotNull);
  });

  testWidgets('a started poll keeps its question count, not Continue', (
    tester,
  ) async {
    await pumpApp(tester, Routes.home, overrides: discoverOverrides());
    final open = tester.widget<IqPollTile>(
      find.byWidgetPredicate(
        (w) =>
            w is IqPollTile &&
            w.question == 'Which flavour should we launch first?',
      ),
    );
    expect(open.progress, isNull);
    expect(open.meta, isNot(contains('Continue')));
  });

  testWidgets('Pick up stays off the row when nothing is started', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      repository: ScriptedRepository()..data.drafts.clear(),
      overrides: [
        ...discoverOverrides(),
        activationsServiceProvider.overrideWithValue(
          DemoActivationsService(
            seed: [DemoActivations(figmaNow).orchidFoods],
            clock: () => figmaNow,
            load: Duration.zero,
            delay: Duration.zero,
          ),
        ),
      ],
    );
    expect(find.text('Pick up'), findsNothing);
    expect(
      tester.widgetList<IqChip>(find.byType(IqChip)).first.label,
      'For you',
    );
    container.read(discoverFiltersProvider.notifier).showPickUp();
    await tester.pumpAndSettle();
    expect(container.read(discoverFiltersProvider).pickUp, isFalse);
    expect(container.read(discoverFiltersProvider).forYou, isTrue);
    expect(find.text('Pick up'), findsNothing);
  });

  testWidgets('tablet Pick up stays off when there is no draft', (
    tester,
  ) async {
    await pumpTablet(
      tester,
      Routes.home,
      repository: ScriptedRepository()..data.drafts.clear(),
      overrides: discoverOverrides(),
    );
    expect(find.byType(TabletDiscover), findsOneWidget);
    expect(find.text('Pick up'), findsNothing);
    expect(find.text('For you'), findsOneWidget);
  });
}
