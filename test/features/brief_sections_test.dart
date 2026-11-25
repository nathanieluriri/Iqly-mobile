import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/ui/brief_sections.dart';

Brief _brief({
  String? overview,
  String? problemStatement,
  List<String> deliverables = const [],
}) => Brief(
  id: 'brief-1',
  title: 'A useful brief',
  body: '<p>Fallback body.</p>',
  overview: overview,
  problemStatement: problemStatement,
  deliverables: deliverables,
  tier: Tier.standard,
  category: Category.other,
  rewardPoolKobo: 100000,
  status: BriefStatus.closed,
  deadline: null,
  businessName: 'PlaSpool',
  createdAt: DateTime(2026, 11, 1),
);

Future<void> _pump(WidgetTester tester, Brief brief) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: BriefSections(brief: brief)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'brief sections keep overview, problem, and deliverables distinct',
    (tester) async {
      await _pump(
        tester,
        _brief(
          overview: '<p>Overview copy.</p>',
          problemStatement: '<p>Problem copy.</p>',
          deliverables: ['First deliverable', 'Second deliverable'],
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Overview copy.'), findsOneWidget);
      expect(find.text('The problem'), findsOneWidget);
      expect(find.text('Problem copy.'), findsOneWidget);
      expect(find.text('Deliverables'), findsOneWidget);
      expect(find.text('First deliverable'), findsOneWidget);
      expect(find.text('Second deliverable'), findsOneWidget);
      expect(find.text('Fallback body.'), findsNothing);
    },
  );

  testWidgets('brief sections fall back to body text when overview is absent', (
    tester,
  ) async {
    await _pump(tester, _brief());

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Fallback body.'), findsOneWidget);
    expect(find.text('The problem'), findsNothing);
    expect(find.text('Deliverables'), findsNothing);
  });
}
