import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/screens/more_harness.dart';

void main() {
  testWidgets('holding the version line on More stays on More', (tester) async {
    await pumpMore(tester, Routes.more);
    final version = find.textContaining('IQLY FOR');
    await tester.scrollUntilVisible(version, 300);
    await tester.longPress(version);
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.textContaining('IQLY FOR'), findsOneWidget);
  });
}
