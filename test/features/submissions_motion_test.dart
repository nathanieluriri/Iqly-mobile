import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_widgets.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/top_bar.dart';

import '../golden/golden.dart';
import '../golden/screens/app_harness.dart';
import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);

double _ei(double t) => IqCurves.easeIn.transform(t);

/// The product of every fade above [of].
double _opacity(WidgetTester tester, Finder of) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(
      of: of,
      matching: find.byWidgetPredicate(
        (w) => w is FadeTransition || w is Opacity,
      ),
    ),
  )) {
    opacity *= widget is FadeTransition
        ? widget.opacity.value
        : (widget as Opacity).opacity;
  }
  return opacity;
}

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
  setUpAll(loadAppFonts);

  testWidgets('first visit: paper under the still Segmented, the skeleton, '
      'then the cards arrive; a later visit shows them at once', (
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
    expect(find.byType(SubmissionsSegmented), findsOneWidget);
    await tester.pump(_ms * 299);
    expect(find.byType(SkeletonSubmissionCard), findsNothing);
    expect(find.byType(SubmissionsSegmented), findsOneWidget);
    await tester.pump(_ms);
    await tester.pump();
    expect(find.byType(SkeletonSubmissionCard), findsNWidgets(3));

    // The data lands at 400; the skeleton holds to 900, fades, and the
    // cards come in at 960, 40 apart.
    await tester.pump(_ms * 100);
    repository.answer();
    await tester.pump();
    await tester.pump();
    await tester.pump(_ms * 500);
    expect(find.byType(ArriveItem), findsNothing);
    await tester.pump(_ms * 60);
    expect(find.byType(ArriveItem), findsWidgets);
    await tester.pump(_ms * 110);
    expect(_arrived(tester, 0), greaterThan(_arrived(tester, 1)));
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonSubmissionCard), findsNothing);
    expect(_arrived(tester, 1), 1);

    await tester.tap(
      find.descendant(of: find.byType(IqDock), matching: find.text('Discover')),
    );
    await tester.pumpAndSettle();
    await tester.tap(_tab);
    await tester.pump();
    expect(find.byType(SkeletonSubmissionCard), findsNothing);
    expect(_arrived(tester, 0), 1);
    expect(repository.loads, hasLength(1));
  });

  testWidgets('a quiet refresh keeps the cards on screen', (tester) async {
    final repository = _Held();
    final container = await pumpApp(
      tester,
      Routes.submissions,
      repository: repository,
      settle: false,
    );
    repository.answer();
    await tester.pumpAndSettle();
    container.read(mySubmissionsProvider.notifier).refreshQuietly();
    await tester.pump();
    await tester.pump(_ms * 1000);
    expect(repository.loads, hasLength(2));
    expect(find.text('Bring the shop to the hostel'), findsOneWidget);
    expect(find.byType(SkeletonSubmissionCard), findsNothing);
    repository.loads.last.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Bring the shop to the hostel'), findsOneWidget);
  });

  testWidgets('a lens switch crosses the content, 200 ms, and keeps the '
      'chrome still', (tester) async {
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    final segmented = tester.getTopLeft(find.byType(SubmissionsSegmented));
    await tester.tap(find.text('Winners · 2'));
    await tester.pump();
    await tester.pump(_ms * 100);
    final fading = find.byWidgetPredicate(
      (w) => w is RawImage && w.fit == BoxFit.fill,
    );
    expect(fading, findsOneWidget);
    expect(tester.getTopLeft(find.byType(SubmissionsSegmented)), segmented);
    await tester.pump(_ms * 110);
    expect(fading, findsNothing);
    expect(find.text('₦62,500.00 won from 2 briefs'), findsOneWidget);
  });

  testWidgets('a card opens its detail drawn on the first frame', (
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
  });

  testWidgets('View the brief and back: the back button holds and the '
      'titles cross in step, with no fallback underline (spec 4.3)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      submissionPath('s1'),
      reducedMotion: false,
      settle: false,
    );
    await tester.pump(_ms * 800);
    final bar = tester.getTopLeft(find.byType(IqTopBar));

    double flying(String title) {
      final text = find.text(title).last;
      final style = tester.renderObject<RenderParagraph>(text).text.style;
      expect(style?.decoration, isNull);
      return _opacity(tester, text);
    }

    await tester.tap(find.text('View the brief'));
    await tester.pump();
    await tester.pump();
    await tester.pump(_ms * 60);
    expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
    expect(flying('Submission'), closeTo(1 - _ei(0.5), 0.02));
    await tester.pump(_ms * 400);
    expect(find.text('Submission'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await tester.pump();
    expect(flying('Submission'), 0);
    await tester.pump(_ms * 48);
    expect(tester.getTopLeft(find.byType(IqTopBar).last), bar);
    await tester.pump(_ms * 144);
    expect(flying('Submission'), 1);
    await tester.pump(_ms * 100);
    expect(find.text('Submission'), findsOneWidget);
  });

  testWidgets('a failed retry plays the error haptic', (tester) async {
    final haptics = recordHaptics(tester);
    final repository = _Held(failFirst: true);
    await pumpApp(
      tester,
      Routes.submissions,
      repository: repository,
      reducedMotion: false,
    );
    expect(find.byType(IqBanner), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(_ms * 400);
    await tester.pump();
    expect(find.byType(SkeletonSubmissionCard), findsNWidgets(3));
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    repository.loads.last.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(IqBanner), findsOneWidget);
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets('the lit tab is inert: tapping it leaves the list where it is', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.submissions,
      reducedMotion: false,
    );
    container
        .read(submissionsTabProvider.notifier)
        .select(SubmissionsTab.notSelected);
    tester.view.physicalSize = const Size(390, 560);
    await tester.pumpAndSettle();
    final list = _list(tester);
    expect(list.maxScrollExtent, greaterThan(0));
    list.jumpTo(list.maxScrollExtent);
    await tester.pump();
    final end = list.pixels;
    await tester.tap(_tab);
    await tester.pumpAndSettle();
    expect(list.pixels, end);
  });
}
