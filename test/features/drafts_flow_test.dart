import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/drafts/drafts_screen.dart';
import 'package:iqly_mobile/features/drafts/drafts_state.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submit/pick_brief_screen.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';
import 'package:iqly_mobile/ui/draft_row.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/section_title.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/submissions_harness.dart';
import '../golden/screens/submit_harness.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _text(String text) => find.text(text).last;

/// The section title's link: its hit band is the 72 pt at the right edge.
Finder _link() => find.descendant(
  of: find.byType(IqSectionTitle),
  matching: find.byType(IqPressable),
);

DemoRepository _sample() => DemoRepository(DemoData(now: figmaNow));

void main() {
  test('the drafts read as the frames write them', () {
    final now = figmaNow;
    expect(
      editedAgo(now.subtract(const Duration(hours: 2)), now),
      '2 hours ago',
    );
    expect(editedAgo(now.subtract(const Duration(days: 1)), now), 'yesterday');
    expect(editedAgo(now.subtract(const Duration(days: 3)), now), '3 days ago');
    final data = DemoData(now: now);
    final items = [
      for (final d in data.drafts)
        DraftItem(d, data.briefs.firstWhere((b) => b.id == d.briefId)),
    ];
    expect(draftMeta(items[0], now), 'Unibooks · Step 2 of 3 · 2 hours ago');
    expect(draftMeta(items[1], now), 'Sunline · Step 1 of 3 · yesterday');
    expect(
      draftActionsBody(items[0], now),
      'Unibooks · Step 2 of 3 · edited 2 hours ago. Pick up where you '
      'stopped, or discard it.',
    );
    expect(
      draftsEntryDescription(items, now),
      'Unibooks and Sunline · last edited 2 hours ago',
    );
    expect(businessOf(null), 'Private business');
  });

  testWidgets('My submissions opens Drafts; back returns to it', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions, repository: _sample());
    expect(find.text('Drafts · 2'), findsOneWidget);
    expect(
      find.text('Unibooks and Sunline · last edited 2 hours ago'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Drafts · 2'));
    expect(find.byType(DraftsScreen), findsOneWidget);
    expect(find.text('2 drafts'), findsOneWidget);
    expect(find.text('Unibooks · Step 2 of 3 · 2 hours ago'), findsOneWidget);
    expect(find.text('Sunline · Step 1 of 3 · yesterday'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
  });

  testWidgets('Empty My submissions offers Pick a brief', (tester) async {
    await pumpApp(
      tester,
      Routes.submissions,
      repository: EmptySubmissionsRepository(),
    );
    await _tap(tester, find.text('Browse briefs'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(PickBriefScreen), findsOneWidget);
    expect(find.text('Pick a brief'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
  });

  testWidgets('tap a draft, Continue writing resumes it; back to Drafts', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submissions,
      repository: _sample(),
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Drafts · 2'));
    await _tap(tester, find.text('Charge up, stay connected'));
    expect(find.byType(IqConfirmSheet), findsOneWidget);
    expect(
      find.text(
        'Sunline · Step 1 of 3 · edited yesterday. Pick up where you '
        'stopped, or discard it.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Continue writing'));
    expect(find.byType(SubmitScreen), findsOneWidget);
    expect(find.text('No light? We dey'), findsOneWidget);
    expect(find.text('4 more characters to go'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Back'));
    await _tap(tester, find.text('Keep writing'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Discard draft'));
    expect(find.byType(DraftsScreen), findsOneWidget);
    expect(find.text('1 draft'), findsOneWidget);
  });

  testWidgets('Discard draft asks, then the row goes', (tester) async {
    final repository = _sample();
    await pumpApp(tester, Routes.drafts, repository: repository);
    await _tap(tester, find.text('No light? We dey'));
    await _tap(tester, find.text('Discard draft'));
    expect(find.text('Discard this draft?'), findsOneWidget);
    expect(
      find.text('It only lives on this phone. This cannot be undone.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Keep draft'));
    expect(find.text('2 drafts'), findsOneWidget);

    await _tap(tester, find.text('No light? We dey'));
    await _tap(tester, find.text('Discard draft'));
    await _tap(tester, _text('Discard'));
    expect(find.text('1 draft'), findsOneWidget);
    expect(find.text('No light? We dey'), findsNothing);
    expect(repository.data.drafts.single.briefId, 'c5');
  });

  testWidgets('long press selects; Select all, Discard 2 behind a confirm; '
      'the last one gone leaves Drafts', (tester) async {
    final repository = _sample();
    await pumpApp(tester, Routes.submissions, repository: repository);
    await _tap(tester, find.text('Drafts · 2'));

    await tester.longPress(find.text('No light? We dey'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    expect(
      tester
          .widgetList<IqDraftRow>(find.byType(IqDraftRow))
          .map((r) => (r.mode, r.selected)),
      [(IqDraftRowMode.selecting, true), (IqDraftRowMode.selecting, false)],
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DraftsScreen), findsOneWidget);
    expect(find.text('2 drafts'), findsOneWidget);

    await _tap(tester, _link());
    expect(find.text('0 selected'), findsOneWidget);
    final discard = find.byWidgetPredicate(
      (w) => w is IqButton && w.label == 'Discard 0 drafts',
    );
    expect(tester.widget<IqButton>(discard).disabled, isTrue);
    await _tap(tester, _link());
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Deselect all'), findsOneWidget);

    await _tap(tester, find.text('Discard 2 drafts'));
    expect(find.text('Discard 2 drafts?'), findsOneWidget);
    expect(
      find.text('They only live on this phone. This cannot be undone.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Keep them'));
    expect(find.text('2 selected'), findsOneWidget);

    await _tap(tester, find.text('Discard 2 drafts'));
    await _tap(tester, _text('Discard 2 drafts'));
    expect(repository.data.drafts, isEmpty);
    expect(find.byType(DraftsScreen), findsNothing);
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
    expect(find.text('Drafts · 2'), findsNothing);
  });

  testWidgets('Cancel leaves selecting', (tester) async {
    await pumpApp(tester, Routes.drafts, repository: _sample());
    await _tap(tester, _link());
    await _tap(tester, find.text('Cancel'));
    expect(find.text('2 drafts'), findsOneWidget);
    expect(
      tester.widgetList<IqDraftRow>(find.byType(IqDraftRow)).map((r) => r.mode),
      everyElement(IqDraftRowMode.standard),
    );
  });
}
