import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';

import '../golden/screens/submissions_harness.dart';

Future<void> _boot(WidgetTester tester, IqlyRepository repository) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final router = GoRouter(
    initialLocation: Routes.submissions,
    routes: [
      GoRoute(
        path: Routes.submissions,
        builder: (context, state) => const MySubmissionsScreen(),
      ),
      ...submissionRoutes,
      GoRoute(
        path: '/briefs/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Brief ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list to detail, the brief and back; results for decided rows', (
    tester,
  ) async {
    await _boot(tester, DemoRepository(DemoData()));
    expect(find.text('5 sent · 2 under review'), findsOneWidget);
    expect(find.text('SENT 30D AGO · ₦50,000.00 AWARDED'), findsOneWidget);

    await tester.tap(find.text('Bring the shop to the hostel'));
    await tester.pumpAndSettle();
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(
      find.text('Results land here when Unibooks decides.'),
      findsOneWidget,
    );
    expect(find.text('In 20 days'), findsOneWidget);

    await tester.tap(find.text('View the brief'));
    await tester.pumpAndSettle();
    expect(find.text('Brief c6'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(MySubmissionsScreen), findsOneWidget);

    await tester.tap(find.text('Ekpe: a name riders own'));
    await tester.pumpAndSettle();
    expect(find.text('Your result'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('One counter for quick jobs'),
      100,
    );
    await tester.tap(find.text('One counter for quick jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Your result'), findsOneWidget);
  });

  testWidgets('failed to load, Try again loads the list', (tester) async {
    final repository = FailingSubmissionsRepository();
    await _boot(tester, repository);
    expect(find.text('Nothing to show yet'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Bring the shop to the hostel'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('empty state browses briefs', (tester) async {
    await _boot(tester, EmptySubmissionsRepository());
    expect(find.text('0 sent'), findsOneWidget);
    await tester.tap(find.text('Browse briefs'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
