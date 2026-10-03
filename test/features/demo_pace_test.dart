import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/skeleton.dart';

import '../golden/screens/app_harness.dart';

/// The app's repository answers at the Figma prototype's pace, so each
/// loading state shows as long as the prototype holds it.
void main() {
  test('the app runs at prototype pace; test fakes default to none', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final app = container.read(repositoryProvider) as DemoRepository;
    expect(app.latency, same(DemoLatency.prototype));
    expect(DemoRepository(DemoData()).latency, same(DemoLatency.none));
    expect(DemoLatency.prototype.forBriefs(BriefsLoad.any), Duration.zero);
  });

  testWidgets('loading 1.2 s, refreshing 1 s, loading more 2 s', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      Routes.home,
      repository: DemoRepository(
        DemoData(now: figmaNow),
        latency: DemoLatency.prototype,
      ),
    );
    expect(find.byType(IqSkeleton), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Closing soon'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Closing soon'), findsOneWidget);

    container.read(discoverFeedProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('REFRESHING'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.text('REFRESHING'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('REFRESHING'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('LOADING MORE'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('LOADING MORE'), findsOneWidget);
    expect(find.text('That’s all 11 live briefs'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('That’s all 11 live briefs'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('My submissions loading 1.2 s', (tester) async {
    await pumpApp(
      tester,
      Routes.home,
      repository: DemoRepository(
        DemoData(now: figmaNow),
        latency: DemoLatency.prototype,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(IqDock),
        matching: find.text('Submissions'),
      ),
    );
    await tester.pump();
    expect(find.text('LOADING…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Bring the shop to the hostel'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Bring the shop to the hostel'), findsOneWidget);
  });
}
