import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/ui/proof_tile.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'help_harness.dart';
import 'polls_notifications_help_harness.dart';

Future<void> _write(WidgetTester tester) async {
  await tester.tap(find.byType(IqProofTile));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText), figmaMessage);
  await tester.pumpAndSettle();
}

Future<void> _golden(
  WidgetTester tester,
  String name, {
  HelpService? help,
  bool names = false,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(
    tester,
    kudiBoxHelp,
    overrides: [
      ...laneOverrides(help: help),
      ...helpActivations(),
      if (names) helpAuthorNamesProvider.overrideWithValue(true),
    ],
  );
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/help_$name.png');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Help request (141:5818)', (tester) async {
    await _golden(tester, 'request', act: _write);
  });

  testWidgets('Help request before anything is written', (tester) async {
    await _golden(tester, 'request_empty');
  });

  testWidgets('Help thread · replied (141:5876)', (tester) async {
    await _golden(
      tester,
      'thread_replied',
      act: (tester) async {
        await _write(tester);
        await tester.tap(find.text('Send to support'));
      },
    );
  });

  testWidgets('Help request to the business (D4, no frame)', (tester) async {
    await _golden(tester, 'request_business', names: true, act: _write);
  });

  testWidgets('Help thread answered by the business (D4, no frame)', (
    tester,
  ) async {
    await _golden(
      tester,
      'thread_business',
      help: _BusinessHelpService(),
      names: true,
      act: (tester) async {
        await _write(tester);
        await tester.tap(find.text('Send to Kudi Box'));
      },
    );
  });

  testWidgets('Help thread while support types', (tester) async {
    await _golden(
      tester,
      'thread_typing',
      help: TypingHelpService(),
      act: (tester) async {
        await _write(tester);
        await tester.tap(find.text('Send to support'));
      },
    );
  });
}

/// The demo's answers, signed by the business the request is about.
class _BusinessHelpService extends DemoHelpService {
  _BusinessHelpService()
    : super(
        delay: Duration.zero,
        uploadStep: Duration.zero,
        typingAfter: Duration.zero,
        replyAfter: Duration.zero,
        clock: () => DateTime(2026, 10, 3, 15, 6),
      );

  @override
  Stream<HelpTicket> watch(String ticketId) => super
      .watch(ticketId)
      .map(
        (ticket) => ticket.copyWith(
          messages: [
            for (final m in ticket.messages)
              m.author == HelpAuthor.you
                  ? m
                  : HelpMessage(
                      author: m.author,
                      body: m.body,
                      at: m.at,
                      attachment: m.attachment,
                      more: m.more,
                      authorName: 'Kudi Box',
                    ),
          ],
        ),
      );
}
