import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/screens/app_harness.dart';

const _ms = Duration(milliseconds: 1);

/// Sends Android's back swipe [method] as the engine does; true when a page
/// took the swipe.
Future<bool?> _swipe(
  WidgetTester tester,
  String method, {
  bool button = false,
}) async {
  bool? taken;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, {
        'touchOffset': button ? null : [380.0, 420.0],
        'progress': method == 'startBackGesture' ? 0.0 : 0.4,
        'swipeEdge': 1,
      }),
    ),
    (reply) {
      if (reply == null) return;
      final result = const StandardMethodCodec().decodeEnvelope(reply);
      if (result is bool) taken = result;
    },
  );
  return taken;
}

/// Opens a submission from My submissions; the rect My submissions had
/// while it showed.
Future<Rect> _openSubmission(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  await pumpApp(tester, Routes.submissions, reducedMotion: reducedMotion);
  final full = _rect(tester, MySubmissionsScreen);
  await tester.tap(find.text('Bring the shop to the hostel'));
  await tester.pumpAndSettle();
  expect(find.byType(SubmissionDetailScreen), findsOneWidget);
  return full;
}

Rect _rect(WidgetTester tester, Type screen) =>
    tester.getRect(find.byType(screen, skipOffstage: false));

double _opacity(WidgetTester tester, Type screen) {
  var opacity = 1.0;
  for (final o in tester.widgetList<Opacity>(
    find.ancestor(
      of: find.byType(screen, skipOffstage: false),
      matching: find.byType(Opacity),
    ),
  )) {
    opacity *= o.opacity;
  }
  return opacity;
}

bool _gesture(WidgetTester tester) => tester
    .state<NavigatorState>(
      find
          .ancestor(
            of: find.byType(SubmissionDetailScreen, skipOffstage: false),
            matching: find.byType(Navigator),
          )
          .first,
    )
    .userGestureInProgress;

void main() {
  testWidgets('the swipe shows the page beneath at 90% and holds there; '
      'letting go grows it to full size as the page closes', (tester) async {
    final full = await _openSubmission(tester);

    expect(await _swipe(tester, 'startBackGesture'), isTrue);
    await tester.pump();
    await tester.pump(_ms * 30);
    expect(_opacity(tester, SubmissionDetailScreen), inExclusiveRange(0, 1));
    expect(_rect(tester, SubmissionDetailScreen).left, greaterThan(0));
    await tester.pump(_ms * 171);

    final held = _rect(tester, MySubmissionsScreen);
    expect(held.width, closeTo(full.width * 0.9, 0.5));
    expect(held.center.dx, closeTo(full.center.dx, 0.5));
    expect(_opacity(tester, MySubmissionsScreen), 1);
    expect(_opacity(tester, SubmissionDetailScreen), 0);
    expect(_rect(tester, SubmissionDetailScreen).left, closeTo(195, 0.5));

    await _swipe(tester, 'updateBackGestureProgress');
    await tester.pump(_ms * 500);
    expect(_rect(tester, MySubmissionsScreen), held);
    expect(find.byType(SubmissionDetailScreen, skipOffstage: false), findsOne);

    await _swipe(tester, 'commitBackGesture');
    await tester.pump();
    await tester.pump(_ms * 100);
    final growing = _rect(tester, MySubmissionsScreen).width;
    expect(growing, greaterThan(held.width));
    expect(growing, lessThan(full.width));
    await tester.pump(_ms * 101);
    await tester.pump();
    expect(_rect(tester, MySubmissionsScreen), full);
    expect(
      find.byType(SubmissionDetailScreen, skipOffstage: false),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
  });

  testWidgets('taking the swipe back returns to the page over 240', (
    tester,
  ) async {
    await _openSubmission(tester);
    final page = _rect(tester, SubmissionDetailScreen);
    await _swipe(tester, 'startBackGesture');
    await tester.pump();
    await tester.pump(_ms * 201);
    expect(_gesture(tester), isTrue);

    await _swipe(tester, 'cancelBackGesture');
    await tester.pump();
    await tester.pump(_ms * 120);
    expect(_opacity(tester, SubmissionDetailScreen), inExclusiveRange(0, 1));
    await tester.pump(_ms * 121);
    await tester.pump();
    expect(_rect(tester, SubmissionDetailScreen), page);
    expect(_opacity(tester, SubmissionDetailScreen), 1);
    expect(find.byType(MySubmissionsScreen), findsNothing);
    expect(_gesture(tester), isFalse);
  });

  testWidgets('reduced motion: the pages crossfade in place and the page '
      'beneath stays full size', (tester) async {
    final full = await _openSubmission(tester, reducedMotion: true);
    final page = _rect(tester, SubmissionDetailScreen);

    await _swipe(tester, 'startBackGesture');
    await tester.pump();
    await tester.pump(_ms * 75);
    expect(_rect(tester, MySubmissionsScreen), full);
    expect(_rect(tester, SubmissionDetailScreen), page);
    expect(_opacity(tester, MySubmissionsScreen), inExclusiveRange(0, 1));
    await tester.pump(_ms * 76);

    await _swipe(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(SubmissionDetailScreen), findsNothing);
    expect(_rect(tester, MySubmissionsScreen), full);
  });

  testWidgets("a tab's first page, the back button and iOS leave the swipe to "
      'the system', (tester) async {
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    expect(await _swipe(tester, 'startBackGesture'), isFalse);
    await _swipe(tester, 'cancelBackGesture');

    await tester.tap(find.text('Bring the shop to the hostel'));
    await tester.pumpAndSettle();
    expect(await _swipe(tester, 'startBackGesture', button: true), isFalse);
    await _swipe(tester, 'commitBackGesture', button: true);
    await tester.pumpAndSettle();
    expect(find.byType(SubmissionDetailScreen), findsNothing);
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
  });

  testWidgets('iOS keeps its own edge swipe', (tester) async {
    await _openSubmission(tester);
    expect(await _swipe(tester, 'startBackGesture'), isFalse);
    await _swipe(tester, 'cancelBackGesture');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a page still arriving leaves the swipe to the system', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions, reducedMotion: false);
    await tester.tap(find.text('Bring the shop to the hostel'));
    await tester.pump();
    await tester.pump(_ms * 100);
    expect(await _swipe(tester, 'startBackGesture'), isFalse);
    await _swipe(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(_gesture(tester), isFalse);
  });

  testWidgets('a page another link closes during the swipe is not closed '
      'twice', (tester) async {
    await _openSubmission(tester);
    await _swipe(tester, 'startBackGesture');
    await tester.pump();
    await tester.pump(_ms * 201);
    GoRouter.of(
      tester.element(find.byType(SubmissionDetailScreen, skipOffstage: false)),
    ).go(Routes.wallet);
    await tester.pump();
    await _swipe(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SubmissionDetailScreen), findsNothing);
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(_rect(tester, WalletScreen).width, 390);
  });
}
