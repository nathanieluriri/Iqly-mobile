import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/features/activations/activation_screen.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/poll_card.dart';
import 'package:iqly_mobile/ui/poll_option.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/step_row.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/tablet_harness.dart';

class _HistoryPolls extends DemoPollsService {
  _HistoryPolls(this.now) : super(delay: Duration.zero, clock: () => now);

  final DateTime now;
  final pages = <String?>[];
  int sends = 0;

  Poll _poll(String id, String question, {bool answered = false}) => Poll(
    id: id,
    question: question,
    choices: const ['Yes', 'No'],
    votes: answered ? const [2, 3] : const [0, 0],
    closesAt: answered
        ? now.subtract(const Duration(days: 30))
        : now.add(const Duration(days: 1)),
    closed: answered,
    chosen: answered ? 1 : null,
  );

  PollBusiness _business(List<Poll> polls) =>
      PollBusiness(id: 'business', name: 'Test business', polls: polls);

  @override
  Future<List<PollBusiness>> businesses({bool fresh = false}) async => [
    _business([
      _poll('open', 'A poll to answer'),
      _poll('done', 'A poll I answered', answered: true),
    ]),
  ];

  @override
  Future<PollHistoryPage> history({String? cursor}) async {
    pages.add(cursor);
    return cursor == null
        ? PollHistoryPage(
            businesses: [
              _business([_poll('done', 'A poll I answered', answered: true)]),
            ],
            nextCursor: 'next',
          )
        : PollHistoryPage(
            businesses: [
              _business([_poll('older', 'An older poll', answered: true)]),
            ],
          );
  }

  @override
  Future<Poll> vote(String pollId, int choice) async {
    sends++;
    return _poll(pollId, 'Unexpected vote');
  }

  @override
  Future<Poll> answer(String pollId, List<PollAnswer> answers) async {
    sends++;
    return _poll(pollId, 'Unexpected answer');
  }
}

class _HistoryActivations extends DemoActivationsService {
  _HistoryActivations(this.now)
    : super(
        seed: [DemoActivations(now).orchidFoods, _finishedActivation(now)],
        clock: () => now,
        load: Duration.zero,
        delay: Duration.zero,
        step: null,
      );

  final DateTime now;
  final pages = <String?>[];

  @override
  Future<List<Activation>> activations({bool fresh = false}) async => [
    DemoActivations(now).orchidFoods,
  ];

  @override
  Future<ActivationHistoryPage> history({String? cursor}) async {
    pages.add(cursor);
    return cursor == null
        ? const ActivationHistoryPage(activations: [], nextCursor: 'next')
        : ActivationHistoryPage(activations: [_finishedActivation(now)]);
  }
}

class _FlakyPollHistory extends _HistoryPolls {
  _FlakyPollHistory(super.now);

  bool fail = true;

  @override
  Future<PollHistoryPage> history({String? cursor}) async {
    if (cursor != null && fail) {
      fail = false;
      pages.add(cursor);
      throw StateError('Offline');
    }
    return super.history(cursor: cursor);
  }
}

class _FlakyActivationHistory extends _HistoryActivations {
  _FlakyActivationHistory(super.now);

  bool fail = true;

  @override
  Future<ActivationHistoryPage> history({String? cursor}) async {
    if (cursor != null && fail) {
      fail = false;
      pages.add(cursor);
      throw StateError('Offline');
    }
    return super.history(cursor: cursor);
  }
}

class _FirstPagePollHistory extends _HistoryPolls {
  _FirstPagePollHistory(super.now);

  bool fail = true;

  @override
  Future<List<PollBusiness>> businesses({bool fresh = false}) async => [
    _business([_poll('open', 'A poll to answer')]),
  ];

  @override
  Future<PollHistoryPage> history({String? cursor}) async {
    if (fail) {
      fail = false;
      throw StateError('Offline');
    }
    return super.history(cursor: cursor);
  }
}

class _FirstPageActivationHistory extends _HistoryActivations {
  _FirstPageActivationHistory(super.now);

  bool fail = true;

  @override
  Future<ActivationHistoryPage> history({String? cursor}) async {
    if (fail) {
      fail = false;
      throw StateError('Offline');
    }
    return ActivationHistoryPage(activations: [_finishedActivation(now)]);
  }
}

class _AccountPollHistory extends _HistoryPolls {
  _AccountPollHistory(super.now, this.account, this.older);

  final String? account;
  final Completer<PollHistoryPage> older;

  @override
  Future<List<PollBusiness>> businesses({bool fresh = false}) async => [];

  @override
  Future<PollHistoryPage> history({String? cursor}) async {
    if (account != 'first') return const PollHistoryPage(businesses: []);
    if (cursor != null) return older.future;
    return PollHistoryPage(
      businesses: [
        _business([_poll('done', 'First account poll', answered: true)]),
      ],
      nextCursor: 'next',
    );
  }
}

class _AccountActivationHistory extends _HistoryActivations {
  _AccountActivationHistory(super.now, this.account, this.older);

  final String? account;
  final Completer<ActivationHistoryPage> older;

  @override
  Future<List<Activation>> activations({bool fresh = false}) async => [];

  @override
  Future<ActivationHistoryPage> history({String? cursor}) async {
    if (account != 'first') return const ActivationHistoryPage(activations: []);
    if (cursor != null) return older.future;
    return ActivationHistoryPage(
      activations: [_finishedActivation(now)],
      nextCursor: 'next',
    );
  }
}

class _StaleActivations extends DemoActivationsService {
  _StaleActivations(this.now)
    : super(
        seed: [_finishedActivation(now)],
        clock: () => now,
        load: Duration.zero,
        delay: Duration.zero,
        step: null,
      );

  final DateTime now;

  @override
  Future<List<Activation>> activations({bool fresh = false}) async => [
    DemoActivations(now).kudiBox,
  ];
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Activation _finishedActivation(DateTime now) {
  final source = DemoActivations(now).kudiBox;
  return Activation(
    id: source.id,
    business: source.business,
    title: source.title,
    minutes: source.minutes,
    rewardKobo: source.rewardKobo,
    closesAt: source.closesAt,
    spotsLeft: source.spotsLeft,
    spotsTotal: source.spotsTotal,
    steps: source.steps,
    link: source.link,
    confirmationMode: source.confirmationMode,
    rewardMode: source.rewardMode,
    completedCount: 42,
    progress: ActivationProgress(
      startedAt: now.subtract(const Duration(days: 1)),
      confirmedAt: [
        for (var i = 0; i < source.steps.length; i++)
          now.subtract(const Duration(hours: 1)),
      ],
      paidAt: now,
    ),
  );
}

void main() {
  test('history remains complete when an older list is still cached', () {
    final service = _HistoryPolls(figmaNow);
    final completed = service._business([
      service._poll('same', 'Answered', answered: true),
    ]);
    final stale = service._business([service._poll('same', 'Answered')]);
    final merged = mergePollBusinesses([completed], [stale]);
    expect(merged.single.polls.single.voted, isTrue);
  });

  test('history is visible only to the account that loaded it', () {
    final page = PollHistoryPage(businesses: const [], account: 'first');
    expect(pollHistoryFor(AsyncData(page), 'first'), same(page));
    expect(pollHistoryFor(AsyncData(page), 'second'), isNull);
    final activations = ActivationHistoryPage(
      activations: const [],
      account: 'first',
    );
    expect(
      activationHistoryFor(AsyncData(activations), 'first'),
      same(activations),
    );
    expect(activationHistoryFor(AsyncData(activations), 'second'), isNull);
  });

  testWidgets('poll history opens saved choices and loads another page', (
    tester,
  ) async {
    final service = _HistoryPolls(figmaNow);
    await pumpApp(
      tester,
      Routes.polls,
      overrides: [pollsServiceProvider.overrideWithValue(service)],
    );
    expect(find.text('A poll to answer'), findsOneWidget);
    expect(find.text('A poll I answered'), findsNothing);

    await _tap(tester, find.text('Completed'));
    expect(find.text('A poll to answer'), findsNothing);
    expect(find.text('A poll I answered'), findsOneWidget);
    await _tap(tester, find.text('A poll I answered'));
    expect(find.text('5 votes'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    final card = tester.widget<IqPollCard>(find.byType(IqPollCard));
    expect(card.onVote, isNull);
    final choice = tester.widget<IqPollOption>(
      find.byWidgetPredicate((w) => w is IqPollOption && w.label == 'No'),
    );
    expect(choice.state, IqPollOptionState.chosen);
    await _tap(tester, find.text('No'));
    expect(service.sends, 0);
    await _tap(
      tester,
      find.byWidgetPredicate(
        (w) => w is IqPressable && w.semanticLabel == 'Close',
      ),
    );

    await _tap(tester, find.text('Load more'));
    expect(service.pages, [null, 'next']);
    expect(find.text('An older poll'), findsOneWidget);
    await _tap(tester, find.text('An older poll'));
    expect(find.text('5 votes'), findsOneWidget);
    expect(service.sends, 0);
  });

  testWidgets('poll history keeps its results when another page fails', (
    tester,
  ) async {
    final service = _FlakyPollHistory(figmaNow);
    await pumpApp(
      tester,
      Routes.polls,
      overrides: [pollsServiceProvider.overrideWithValue(service)],
    );
    await _tap(tester, find.text('Completed'));
    await _tap(tester, find.text('Load more'));
    expect(find.text('A poll I answered'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text('An older poll'), findsOneWidget);
    expect(service.pages, [null, 'next', 'next']);
  });

  testWidgets('poll history retries a failed first page', (tester) async {
    final service = _FirstPagePollHistory(figmaNow);
    await pumpApp(
      tester,
      Routes.polls,
      overrides: [pollsServiceProvider.overrideWithValue(service)],
    );
    await _tap(tester, find.text('Completed'));
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text('A poll I answered'), findsOneWidget);
  });

  testWidgets('poll history drops late pages after an account switch', (
    tester,
  ) async {
    final older = Completer<PollHistoryPage>();
    final service = _HistoryPolls(figmaNow);
    final container = await pumpApp(
      tester,
      Routes.polls,
      prefs: {...signedInPrefs(), 'session.userId': 'first'},
      overrides: [
        pollsServiceProvider.overrideWith(
          (ref) =>
              _AccountPollHistory(figmaNow, ref.watch(accountProvider), older),
        ),
      ],
    );
    await _tap(tester, find.text('Completed'));
    expect(find.text('First account poll'), findsOneWidget);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await container.read(sessionProvider.notifier).setUserId('second');
    await tester.pumpAndSettle();
    expect(find.text('First account poll'), findsNothing);
    older.complete(
      PollHistoryPage(
        businesses: [
          service._business([
            service._poll('older', 'First account older poll', answered: true),
          ]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First account older poll'), findsNothing);
  });

  testWidgets('completed activations open their confirmed steps read-only', (
    tester,
  ) async {
    final finished = _finishedActivation(figmaNow);
    await pumpApp(
      tester,
      Routes.activations,
      overrides: [
        activationsServiceProvider.overrideWithValue(
          DemoActivationsService(
            seed: [DemoActivations(figmaNow).orchidFoods, finished],
            clock: () => figmaNow,
            load: Duration.zero,
            delay: Duration.zero,
            step: null,
          ),
        ),
      ],
    );
    expect(find.text(finished.title), findsNothing);
    await _tap(tester, find.text('Completed'));
    await _tap(tester, find.text(finished.title));
    expect(find.byType(ActivationScreen), findsOneWidget);
    expect(find.text('Completed steps'), findsOneWidget);
    expect(find.text('42 people completed this activation.'), findsOneWidget);
    expect(find.text('Start activation'), findsNothing);
    expect(find.text('Open Kudi Box'), findsNothing);
    final rows = tester.widgetList<IqStepRow>(find.byType(IqStepRow));
    expect(rows.length, finished.steps.length);
    expect(rows.every((row) => row.state == IqStepRowState.done), isTrue);
  });

  testWidgets('older completed activations load and open from history', (
    tester,
  ) async {
    final service = _HistoryActivations(figmaNow);
    await pumpApp(
      tester,
      Routes.activations,
      overrides: [activationsServiceProvider.overrideWithValue(service)],
    );
    await _tap(tester, find.text('Completed'));
    expect(find.text('No completed activations on this page'), findsOneWidget);
    await _tap(tester, find.text('Load more'));
    expect(service.pages, [null, 'next']);
    await _tap(tester, find.text(_finishedActivation(figmaNow).title));
    expect(find.text('Completed steps'), findsOneWidget);
    expect(find.text('42 people completed this activation.'), findsOneWidget);
    expect(find.text('Start activation'), findsNothing);
  });

  testWidgets('activation history retries a failed page', (tester) async {
    final service = _FlakyActivationHistory(figmaNow);
    await pumpApp(
      tester,
      Routes.activations,
      overrides: [activationsServiceProvider.overrideWithValue(service)],
    );
    await _tap(tester, find.text('Completed'));
    await _tap(tester, find.text('Load more'));
    expect(find.text('Try again'), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text(_finishedActivation(figmaNow).title), findsOneWidget);
    expect(service.pages, [null, 'next', 'next']);
  });

  testWidgets('activation history retries a failed first page', (tester) async {
    final service = _FirstPageActivationHistory(figmaNow);
    await pumpApp(
      tester,
      Routes.activations,
      overrides: [activationsServiceProvider.overrideWithValue(service)],
    );
    await _tap(tester, find.text('Completed'));
    expect(find.text("Couldn't load. Check your connection."), findsOneWidget);
    await _tap(tester, find.text('Try again'));
    expect(find.text(_finishedActivation(figmaNow).title), findsOneWidget);
  });

  testWidgets('activation history drops late pages after an account switch', (
    tester,
  ) async {
    final older = Completer<ActivationHistoryPage>();
    final container = await pumpApp(
      tester,
      Routes.activations,
      prefs: {...signedInPrefs(), 'session.userId': 'first'},
      overrides: [
        activationsServiceProvider.overrideWith(
          (ref) => _AccountActivationHistory(
            figmaNow,
            ref.watch(accountProvider),
            older,
          ),
        ),
      ],
    );
    await _tap(tester, find.text('Completed'));
    final title = _finishedActivation(figmaNow).title;
    expect(find.text(title), findsOneWidget);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await container.read(sessionProvider.notifier).setUserId('second');
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
    older.complete(
      ActivationHistoryPage(activations: [_finishedActivation(figmaNow)]),
    );
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('a stale open copy cannot make completed history actionable', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.activations,
      overrides: [
        activationsServiceProvider.overrideWithValue(
          _StaleActivations(figmaNow),
        ),
      ],
    );
    await _tap(tester, find.text('Completed'));
    await _tap(tester, find.text(_finishedActivation(figmaNow).title));
    expect(find.text('Completed steps'), findsOneWidget);
    expect(find.text('Start activation'), findsNothing);
    expect(find.text('Open Kudi Box'), findsNothing);
  });

  testWidgets('tablet polls keep completed results openable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = _HistoryPolls(figmaNow);
    await pumpTablet(
      tester,
      Routes.polls,
      overrides: [pollsServiceProvider.overrideWithValue(service)],
    );
    expect(find.text('A poll to answer'), findsOneWidget);
    await _tap(tester, find.text('Completed'));
    await _tap(tester, find.text('A poll I answered'));
    expect(find.text('5 votes'), findsOneWidget);
    expect(tester.widget<IqPollCard>(find.byType(IqPollCard)).onVote, isNull);
  });

  testWidgets('tablet completed activations show the finished steps', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final finished = _finishedActivation(figmaNow);
    await pumpTablet(
      tester,
      Routes.activations,
      overrides: [
        activationsServiceProvider.overrideWithValue(
          DemoActivationsService(
            seed: [DemoActivations(figmaNow).orchidFoods, finished],
            clock: () => figmaNow,
            load: Duration.zero,
            delay: Duration.zero,
            step: null,
          ),
        ),
      ],
    );
    await _tap(tester, find.text('Completed'));
    await _tap(tester, find.text(finished.title));
    expect(find.text('Completed steps'), findsOneWidget);
    expect(find.text('42 people completed this activation.'), findsOneWidget);
    expect(find.text('Start activation'), findsNothing);
  });
}
