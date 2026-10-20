import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/core/navigation.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

List<String> _stack(WidgetTester tester) => [
  for (final page in openPages(
    _router(tester).routerDelegate.currentConfiguration,
  ))
    page.location.toString(),
];

Finder get _back => find.bySemanticsLabel('Back');

void main() {
  testWidgets('View the brief and View your submission take turns without '
      'piling up; Back then leaves at once', (tester) async {
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Bring the shop to the hostel'));
    final detail = _stack(tester);
    expect(detail, hasLength(2));
    final submission = tester.state(find.byType(SubmissionDetailScreen));

    for (var i = 0; i < 4; i++) {
      await _tap(tester, find.text('View the brief'));
      expect(find.byType(BriefDetailScreen), findsOneWidget);
      expect(_stack(tester), hasLength(3));
      await _tap(tester, find.text('View your submission'));
      expect(find.byType(BriefDetailScreen), findsNothing);
      expect(_stack(tester), detail);
    }
    expect(tester.state(find.byType(SubmissionDetailScreen)), submission);

    await _tap(tester, _back);
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
    expect(_stack(tester), [Routes.submissions]);
  });

  testWidgets('from the brief side the submission closes back to it', (
    tester,
  ) async {
    await pumpApp(tester, Routes.brief('c1'), overrides: discoverOverrides());
    for (var i = 0; i < 3; i++) {
      await _tap(tester, find.text('View your submission'));
      expect(find.byType(SubmissionDetailScreen), findsOneWidget);
      await _tap(tester, find.text('View the brief'));
      expect(find.byType(SubmissionDetailScreen), findsNothing);
      expect(_stack(tester), [Routes.brief('c1')]);
    }
  });

  testWidgets('a result, its submission and the brief: the loop closes back '
      'to the page already open, however deep', (tester) async {
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Not selected'));
    await _tap(tester, find.text('One counter for quick jobs'));
    expect(find.byType(ResultScreen), findsOneWidget);
    await _tap(tester, find.text('View your submission'));
    await _tap(tester, find.text('See what won'));
    await _tap(tester, find.text('Open the brief'));
    final deep = _stack(tester);
    expect(deep, hasLength(5));

    await _tap(tester, find.text('View your submission'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(_stack(tester), deep.take(3));

    _router(tester).open(deep[1]);
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(_stack(tester), deep.take(2));
  });

  testWidgets('a second tap on a link opens one page', (tester) async {
    await pumpApp(tester, submissionPath('s1'));
    final link = find.text('View the brief');
    await tester.tap(link);
    await tester.tap(link, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_stack(tester), [submissionPath('s1'), Routes.brief('c1')]);
  });

  testWidgets('closing back to an open page plays Back: the top page leaves '
      'over it, and pages between go without a move', (tester) async {
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    await _tap(tester, find.text('Not selected'));
    await _tap(tester, find.text('One counter for quick jobs'));
    await _tap(tester, find.text('View your submission'));
    await _tap(tester, find.text('See what won'));
    await _tap(tester, find.text('Open the brief'));
    final brief = find.byType(BriefDetailScreen);

    await tester.tap(find.text('View your submission'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(brief, findsOneWidget);
    expect(_opacity(tester, brief), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(brief, findsNothing);

    await _tap(tester, find.text('See what won'));
    await _tap(tester, find.text('Open the brief'));
    _router(tester).open(_stack(tester)[1]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(brief, findsOneWidget);
    expect(_opacity(tester, brief), inExclusiveRange(0, 1));
    expect(find.byType(SubmissionDetailScreen), findsNothing);
    expect(find.byType(ResultScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(brief, findsNothing);
  });

  testWidgets('a link to a tab switches tabs and closes what was over it', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Bring the shop to the hostel'));
    _router(tester).open(Routes.home);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_stack(tester), [Routes.home]);
  });
}

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
