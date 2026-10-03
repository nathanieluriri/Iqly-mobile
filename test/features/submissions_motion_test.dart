import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/highlight.dart';

import '../golden/screens/app_harness.dart';
import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);

/// The demo data with each submissions load answered when the test says so.
class _Held extends ScriptedRepository {
  _Held({this.failFirst = false});

  final bool failFirst;
  final loads = <Completer<List<Submission>>>[];

  @override
  Future<List<Submission>> submissions() {
    if (failFirst && loads.isEmpty) {
      loads.add(Completer());
      return Future.error(Exception('offline'));
    }
    final load = Completer<List<Submission>>();
    loads.add(load);
    return load.future;
  }

  void answer() => loads.last.complete(data.submissions);
}

Finder get _tab => find.descendant(
  of: find.byType(IqDock),
  matching: find.text('Submissions'),
);

ScrollPosition _list(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(MySubmissionsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// How far the [index]th arriving item of the list has faded in.
double _arrived(WidgetTester tester, int index) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(ArriveItem).at(index),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

/// How much of the [index]th status marker is drawn, 0 to 1.
double _marker(WidgetTester tester, int index) =>
    tester
        .widget<ClipRect>(
          find
              .descendant(
                of: find.byType(IqHighlight).at(index),
                matching: find.byType(ClipRect),
              )
              .first,
        )
        .clipper!
        .getClip(const Size(100, 10))
        .width /
    100;

double _greeting(WidgetTester tester) => tester
    .widgetList<FadeTransition>(
      find.ancestor(
        of: find.text('5 sent · 2 under review'),
        matching: find.byType(FadeTransition),
      ),
    )
    .fold(1.0, (o, w) => o * w.opacity.value);

/// Pumps frame by frame until [type] is first built, so the test sees the
/// page's very first frame (offstage, while heroes are measured).
Future<Finder> _firstFrameOf(WidgetTester tester, Type type) async {
  final page = find.byType(type, skipOffstage: false);
  for (var i = 0; i < 5 && page.evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(page, findsOneWidget);
  return page;
}

void main() {
  testWidgets('first visit: paper, the skeleton, then the list arrives', (
    tester,
  ) async {
    final repository = _Held();
    await pumpApp(
      tester,
      Routes.home,
      repository: repository,
      reducedMotion: false,
    );
    await tester.tap(_tab);
    await tester.pump();
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
    await tester.pump(_ms * 299);
    expect(find.byType(SkeletonCard), findsNothing);
    await tester.pump(_ms);
    await tester.pump();
    expect(find.byType(SkeletonCard), findsNWidgets(4));

    // The data lands at 400 and the greeting crossfades in at once; the
    // skeleton holds to 900.
    await tester.pump(_ms * 100);
    repository.answer();
    await tester.pump();
    await tester.pump();
    await tester.pump(_ms * 75);
    expect(_greeting(tester), closeTo(_eo(0.5), 0.05));
    expect(find.byType(SkeletonCard), findsNWidgets(4));
    expect(find.byType(ArriveItem), findsNothing);

    await tester.pump(_ms * 450);
    await tester.pump();
    expect(find.byType(ArriveItem), findsWidgets);
    // Under review title, then its two rows, 40 ms apart, 60 behind the
    // fading skeleton; each marker wipes 120 after its row.
    expect(_arrived(tester, 0), 0);
    await tester.pump(_ms * 170);
    expect(_arrived(tester, 0), closeTo(_eo(110 / 260), 0.03));
    expect(_arrived(tester, 1), closeTo(_eo(70 / 260), 0.03));
    expect(_arrived(tester, 2), closeTo(_eo(30 / 260), 0.03));
    expect(_marker(tester, 0), 0);
    await tester.pump(_ms * 80);
    expect(_marker(tester, 0), closeTo(_eo(30 / 240), 0.03));
    expect(_marker(tester, 1), 0);
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonCard), findsNothing);
    expect(_marker(tester, 0), 1);
    expect(_arrived(tester, 2), 1);

    // A second visit is chrome only: the list stands where it was.
    await tester.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('Discover')),
    );
    await tester.pumpAndSettle();
    await tester.tap(_tab);
    await tester.pump();
    expect(_arrived(tester, 0), 1);
    expect(repository.loads, hasLength(1));
  });

  testWidgets('reduced motion: the list fades in together, markers drawn', (
    tester,
  ) async {
    final repository = _Held();
    await pumpApp(tester, Routes.submissions, repository: repository);
    await tester.pump(_ms * 300);
    await tester.pump();
    expect(find.byType(SkeletonCard), findsNWidgets(4));
    repository.answer();
    await tester.pump();
    await tester.pump(_ms * 600);
    await tester.pump();
    await tester.pump(_ms * 75);
    expect(_arrived(tester, 0), closeTo(_eo(0.5), 0.05));
    expect(_arrived(tester, 2), _arrived(tester, 0));
    expect(_marker(tester, 0), 1);
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonCard), findsNothing);
  });

  testWidgets('a row opens its detail drawn on the first frame', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    await tester.tap(find.text('Bring the shop to the hostel'));
    final page = await _firstFrameOf(tester, SubmissionDetailScreen);
    for (final text in ['Bring the shop to the hostel', 'View the brief']) {
      expect(
        find.descendant(
          of: page,
          matching: find.text(text, skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: page,
        matching: find.byType(SubmissionStatusHero, skipOffstage: false),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the status marker flies into the header and back', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    final row = find.ancestor(
      of: find.text('Bring the shop to the hostel'),
      matching: find.byType(SubmissionRow),
    );
    final from = tester.getTopLeft(
      find.descendant(of: row, matching: find.byType(SubmissionStatusMark)),
    );
    final shuttle = find.byWidgetPredicate(
      (w) => w is SubmissionStatusMark && !w.wipe,
    );

    await tester.tap(row);
    await tester.pump();
    await tester.pump();
    await tester.pump(_ms * 150);
    expect(shuttle, findsOneWidget);
    final mid = tester.getTopLeft(shuttle);
    await tester.pumpAndSettle();
    final to = tester.getTopLeft(shuttle);
    expect(mid.dy, lessThan(from.dy));
    expect(mid.dy, greaterThan(to.dy));
    expect(mid.dx, lessThan(from.dx));
    expect(mid.dx, greaterThan(to.dx));

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await tester.pump(_ms * 120);
    expect(shuttle, findsOneWidget);
    final back = tester.getTopLeft(shuttle);
    expect(back.dy, greaterThan(to.dy));
    expect(back.dy, lessThan(from.dy));
    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(
      tester.getTopLeft(
        find.descendant(of: row, matching: find.byType(SubmissionStatusMark)),
      ),
      from,
    );
  });

  testWidgets('reduced motion: no flight, the detail crossfades in', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions);
    await tester.tap(find.text('Bring the shop to the hostel'));
    await tester.pump();
    await tester.pump();
    await tester.pump(_ms * 75);
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is SubmissionStatusMark && !w.wipe),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SubmissionDetailScreen),
        matching: find.byType(SubmissionStatusMark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Try again sends the banner up; a failed retry brings it back', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    final repository = _Held(failFirst: true);
    await pumpApp(
      tester,
      Routes.submissions,
      repository: repository,
      reducedMotion: false,
    );
    double banner() =>
        tester.getSize(find.byType(IqBanner, skipOffstage: false)).height;
    final height = banner();
    expect(height, greaterThan(0));
    expect(find.text('Nothing to show yet'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(_ms * 90);
    expect(banner(), lessThan(height));
    expect(banner(), greaterThan(0));
    await tester.pump(_ms * 100);
    expect(banner(), 0);
    // Waiting again: paper, then the skeleton.
    expect(find.text('Nothing to show yet'), findsNothing);
    await tester.pump(_ms * 120);
    await tester.pump();
    expect(find.byType(SkeletonCard), findsNWidgets(4));
    expect(haptics, isEmpty);

    repository.loads.last.completeError(Exception('offline'));
    await tester.pump();
    await tester.pump();
    await tester.pump(IqBanner.enter + _ms);
    expect(banner(), height);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('tapping the lit tab at its root scrolls the list to the top', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    final list = _list(tester);
    expect(list.maxScrollExtent, greaterThan(0));
    list.jumpTo(list.maxScrollExtent);
    await tester.pump();
    await tester.tap(_tab);
    await tester.pump();
    await tester.pump(_ms * 150);
    expect(list.pixels, greaterThan(0));
    expect(list.pixels, lessThan(list.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(list.pixels, 0);
    expect(haptics, isEmpty);
  });
}
