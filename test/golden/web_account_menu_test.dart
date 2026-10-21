import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/tablet_icon.dart';
import 'package:iqly_mobile/ui/web_account_menu.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('account menu', (tester) async {
    await expectComponentGolden(
      tester,
      'web_account_menu',
      const IqWebAccountMenu(
        name: 'Adaeze Okafor',
        email: 'adaeze@example.com',
        avatar: ColoredBox(color: IqColors.tintStrong),
        items: [
          IqWebAccountMenuItem(label: 'Your details', icon: IqIcons.profile),
          IqWebAccountMenuItem(
            label: 'Referrals',
            icon: IqIcons.gift,
            trail: 'Earn ₦500',
          ),
          IqWebAccountMenuItem(
            label: 'iQL points',
            icon: IqIcons.medal,
            trail: '1,240',
          ),
          IqWebAccountMenuItem(
            label: 'Settings',
            tabletIcon: IqTabletIcons.settings,
          ),
          IqWebAccountMenuItem(
            label: 'Sign out',
            icon: IqIcons.logout,
            dividerBefore: true,
          ),
        ],
      ),
      size: const Size(272, 320),
    );
  });
}
