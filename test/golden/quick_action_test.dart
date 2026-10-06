import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/quick_action.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqQuickActionKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'quick_action_${kind.name}',
        IqQuickAction(kind: kind),
        size: IqQuickAction.size,
      );
    });
  }
}
