import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/web_app_bar.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final unread in [true, false]) {
    testWidgets(unread ? 'unread' : 'all read', (tester) async {
      await expectComponentGolden(
        tester,
        'web_app_bar_${unread ? 'unread' : 'read'}',
        SizedBox(
          width: 734,
          child: IqWebAppBar(
            name: 'Adaeze Okafor',
            avatar: const ColoredBox(color: IqColors.tintStrong),
            unread: '3',
            showUnread: unread,
          ),
        ),
        size: const Size(734, 64),
      );
    });
  }
}
