import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/empty_state.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/skeleton.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';

class _Inbox extends DemoHelpService {
  _Inbox({this.answer})
    : super(delay: Duration.zero, uploadStep: Duration.zero);

  Future<List<HelpTicket>> Function()? answer;
  int calls = 0;

  @override
  Future<List<HelpTicket>> conversations() {
    calls++;
    return answer?.call() ?? super.conversations();
  }
}

void main() {
  testWidgets('no conversations: the centred empty state, never a blank '
      'page', (tester) async {
    await pumpApp(
      tester,
      Routes.support,
      overrides: laneOverrides(help: _Inbox(answer: () async => const [])),
    );
    expect(find.byType(IqEmptyState), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Start one and the replies land here.'), findsOneWidget);
    expect(find.text('Your conversations'), findsNothing);
    expect(find.text('Start a new conversation'), findsOneWidget);
  });

  testWidgets('loading: the title over row skeletons until the answer', (
    tester,
  ) async {
    final held = Completer<List<HelpTicket>>();
    await pumpApp(
      tester,
      Routes.support,
      settle: false,
      overrides: laneOverrides(help: _Inbox(answer: () => held.future)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IqSkeleton), findsNWidgets(3));
    expect(find.text('Your conversations'), findsOneWidget);
    expect(find.byType(IqEmptyState), findsNothing);

    held.complete(const []);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(IqSkeleton), findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('a failed load says so and Try again loads the inbox', (
    tester,
  ) async {
    var fail = true;
    late final _Inbox inbox;
    inbox = _Inbox(
      answer: () async {
        if (fail) throw Exception('offline');
        return const [];
      },
    );
    await pumpApp(
      tester,
      Routes.support,
      overrides: laneOverrides(help: inbox),
    );
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    expect(find.text('Nothing to show yet'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(inbox.calls, 2);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('conversations: the title and one row each', (tester) async {
    await pumpApp(
      tester,
      Routes.support,
      overrides: laneOverrides(help: _Inbox()),
    );
    expect(find.text('Your conversations'), findsOneWidget);
    expect(find.byType(IqListRow), findsWidgets);
    expect(find.byType(IqEmptyState), findsNothing);
  });
}
