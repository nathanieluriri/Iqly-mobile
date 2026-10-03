import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/ticket_tag.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const sizes = {
    IqTicketTagKind.open: Size(78, 28),
    IqTicketTagKind.replied: Size(141, 28),
    IqTicketTagKind.resolved: Size(101, 28),
  };

  for (final kind in IqTicketTagKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'ticket_tag_${kind.name}',
        IqTicketTag(kind: kind),
        size: sizes[kind]!,
      );
    });
  }
}
