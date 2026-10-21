import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/help/chat_inbox_screen.dart';
import 'package:iqly_mobile/features/help/chat_thread_screen.dart';
import 'package:iqly_mobile/features/help/support_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/chat_resolved_bar.dart';
import 'package:iqly_mobile/ui/chat_ticks.dart';

import '../golden/screens/activations_harness.dart';
import '../golden/screens/app_harness.dart';
import '../golden/screens/help_harness.dart';
import '../golden/screens/polls_notifications_help_harness.dart';
import '../golden/screens/support_chat_screens_test.dart'
    show chatHelp, chatNow;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _label(String label) => find.bySemanticsLabel(label);

void main() {
  testWidgets('the inbox splits Open and Resolved and searches who, what '
      'and what was said', (tester) async {
    await pumpApp(
      tester,
      Routes.support,
      clock: () => chatNow,
      supportChannels: true,
      overrides: [
        ...laneOverrides(help: chatHelp()),
        ...helpActivations(),
      ],
    );
    expect(find.byType(ChatInboxScreen), findsOneWidget);
    expect(find.text('Open · 2'), findsOneWidget);
    expect(find.text('Resolved · 1'), findsOneWidget);
    expect(find.text('iQLY support'), findsOneWidget);
    expect(find.text('Orchid Foods'), findsOneWidget);
    expect(find.text('Kudi Box'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'recipes');
    await tester.pumpAndSettle();
    expect(find.text('iQLY support'), findsNothing);
    expect(find.text('Orchid Foods'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '');
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Resolved · 1'));
    expect(find.text('Kudi Box'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
  });

  testWidgets('a reply goes in saved, Mark as resolved closes the thread, '
      'and a message opens it again', (tester) async {
    await pumpApp(
      tester,
      Routes.support,
      clock: () => chatNow,
      supportChannels: true,
      overrides: [
        ...laneOverrides(help: chatHelp()),
        ...helpActivations(),
      ],
    );
    await _tap(tester, find.text('Withdrawal to Access Bank'));
    expect(find.byType(ChatThreadScreen), findsOneWidget);
    expect(find.text('Usually replies within a day'), findsOneWidget);
    expect(find.text('2 unread messages'), findsOneWidget);
    expect(_label('Voice note'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Thank you.');
    await tester.pumpAndSettle();
    await _tap(tester, _label('Send'));
    expect(find.text('Thank you.'), findsOneWidget);
    final ticks = tester.widgetList<IqChatTicks>(find.byType(IqChatTicks));
    expect(ticks.last.state, IqChatTicksState.saved);

    await _tap(tester, _label('Mark as resolved'));
    expect(find.byType(IqChatResolvedBar), findsOneWidget);
    expect(find.text('You marked this as resolved'), findsOneWidget);
    expect(_label('Mark as resolved'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'One more thing.');
    await tester.pumpAndSettle();
    await _tap(tester, _label('Send'));
    expect(find.byType(IqChatResolvedBar), findsNothing);
    expect(_label('Mark as resolved'), findsOneWidget);
  });

  testWidgets('a business thread makes no reply promise and pins who answers', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.support,
      clock: () => chatNow,
      supportChannels: true,
      overrides: [
        ...laneOverrides(help: chatHelp()),
        ...helpActivations(),
      ],
    );
    await _tap(tester, find.text('Orchid Foods'));
    expect(find.text('Usually replies within a day'), findsNothing);
    await tester.drag(find.byKey(chatThreadKey), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text(businessAnswersHere('Orchid Foods')), findsOneWidget);
    expect(find.text('iQLY support stepped in'), findsOneWidget);
    expect(find.text('Write to Orchid Foods'), findsOneWidget);
  });

  testWidgets('Ask for help on an activation opens the chat with its '
      'business, and the first message opens the thread', (tester) async {
    await pumpActivations(
      tester,
      activationPath('a2'),
      now: figmaNow,
      supportChannels: true,
      service: instantActivations(
        now: figmaNow,
        seed: Figma.world(figmaNow, kudiBox: Figma.proofSent),
      ),
      overrides: [...laneOverrides()],
    );
    await _tap(tester, find.text('Ask for help'));
    expect(find.byType(ChatThreadScreen), findsOneWidget);
    expect(find.text('Write to Kudi Box'), findsOneWidget);
    expect(find.text(businessAnswersHere('Kudi Box')), findsOneWidget);
    expect(find.text('Usually replies within a day'), findsNothing);

    await tester.enterText(
      find.byType(EditableText),
      'Sent proof of step 2, still says Checking.',
    );
    await tester.pumpAndSettle();
    await _tap(tester, _label('Send'));
    expect(
      find.text('Sent proof of step 2, still says Checking.'),
      findsOneWidget,
    );
    expect(find.text(businessAnswersHere('Kudi Box')), findsOneWidget);
  });

  testWidgets('without supportChannels the inbox before the redesign shows', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.support,
      overrides: [...laneOverrides(help: chatHelp())],
    );
    expect(find.byType(SupportScreen), findsOneWidget);
    expect(find.byType(ChatInboxScreen), findsNothing);
  });
}
