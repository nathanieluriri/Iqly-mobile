import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/activation_ticket.dart';
import 'package:iqly_mobile/ui/button.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  const heights = {
    IqActivationTicketKind.hero: 269.0,
    IqActivationTicketKind.list: 272.0,
    IqActivationTicketKind.started: 272.0,
    IqActivationTicketKind.full: 269.0,
    IqActivationTicketKind.closed: 269.0,
  };

  for (final kind in IqActivationTicketKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'activation_ticket_${kind.name}',
        stillMotion(
          SizedBox(width: 358, child: IqActivationTicket(kind: kind)),
        ),
        size: Size(358, heights[kind]!),
      );
    });
  }

  testWidgets('the ticket and its action take taps', (tester) async {
    var opened = 0;
    var started = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 358,
            child: IqActivationTicket(
              kind: IqActivationTicketKind.list,
              onTap: () => opened++,
              onAction: () => started++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IqButton));
    await tester.tap(find.text('Open a Kudi Box account and save ₦1,000'));
    expect(started, 1);
    expect(opened, 1);
  });

  testWidgets('full and closed tickets have no action', (tester) async {
    var started = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 358,
            child: IqActivationTicket(
              kind: IqActivationTicketKind.closed,
              onAction: () => started++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IqButton));
    expect(started, 0);
    expect(find.text('Ended'), findsOneWidget);
  });
}
