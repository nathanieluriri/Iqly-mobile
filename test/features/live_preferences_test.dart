import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/setting_row.dart';

import '../support/live_app.dart';

const _failed = 'Couldn’t load. Check your connection.';
const _read = 'GET /me/notification-preferences';

/// Notification preferences on the API when the switches cannot load (no
/// answer and no copy on the phone): the error banner and Try again, as the
/// app's other pages fail, and a read again on Try again and whenever the
/// page opens again.
void main() {
  testWidgets('a failed read shows the error banner, and Try again reads '
      'again', (tester) async {
    final api = accountApi()..offline = true;
    await pumpLive(tester, Routes.notificationPreferences, api);
    expect(find.byType(IqSettingRow), findsNothing);
    expect(find.text(_failed), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(api.to(_read), hasLength(1));

    api.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(api.to(_read), hasLength(2));
    expect(find.byType(IqSettingRow), findsWidgets);
    expect(find.text(_failed), findsNothing);
  });

  testWidgets('opening the page again after a failed read reads again', (
    tester,
  ) async {
    final api = accountApi()..offline = true;
    final (_, router) = await pumpLive(
      tester,
      Routes.notificationPreferences,
      api,
    );
    await tester.pump(const Duration(seconds: 65));
    expect(find.byType(IqSettingRow), findsNothing);
    expect(find.text(_failed), findsOneWidget);

    api.offline = false;
    router.go(Routes.more);
    await tester.pumpAndSettle();
    router.push(Routes.notificationPreferences);
    await tester.pumpAndSettle();
    expect(find.byType(IqSettingRow), findsWidgets);
    expect(find.text(_failed), findsNothing);
  });
}
