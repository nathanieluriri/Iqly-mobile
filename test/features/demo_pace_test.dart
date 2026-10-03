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
    final start = tester.binding.clock.now();
    final container = await pumpApp(
      tester,
      Routes.home,
      repository: DemoRepository(
        DemoData(now: figmaNow),
        latency: DemoLatency.prototype,
      ),
    );
    // LoadingGate: paper for 300 ms, then the skeletons until the data.
    await _at(tester, start, 299);
    expect(find.byType(IqSkeleton), findsNothing);
    await _at(tester, start, 301);
    expect(find.byType(IqSkeleton), findsWidgets);
    await _at(tester, start, 1199);
    expect(find.text('Closing soon'), findsNothing);
    await _at(tester, start, 1201);
    await tester.pumpAndSettle();
    expect(find.text('Closing soon'), findsOneWidget);
    expect(find.byType(IqSkeleton), findsNothing);

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

    final tap = tester.binding.clock.now();
    await tester.tap(
      find.descendant(
        of: find.byType(IqDock),
        matching: find.text('Submissions'),
      ),
    );
    await tester.pump();
    expect(find.text('LOADING…'), findsNothing);
    await _at(tester, tap, 301);
    expect(find.text('LOADING…'), findsOneWidget);
    await _at(tester, tap, 1199);
    expect(find.text('Bring the shop to the hostel'), findsNothing);
    await _at(tester, tap, 1201);
    await tester.pumpAndSettle();
    expect(find.text('Bring the shop to the hostel'), findsOneWidget);
    expect(find.text('LOADING…'), findsNothing);
  });
}

/// Pumps until [ms] after [start] on the test clock, then one more frame.
Future<void> _at(WidgetTester tester, DateTime start, int ms) async {
  final left = start
      .add(Duration(milliseconds: ms))
      .difference(tester.binding.clock.now());
  if (left > Duration.zero) await tester.pump(left);
  await tester.pump();
}
