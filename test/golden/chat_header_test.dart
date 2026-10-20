import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_header.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/support_sticker.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('with iQLY', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_header_iqly',
      SizedBox(
        width: 390,
        child: IqChatHeader(
          avatar: const IqSupportSticker(),
          subtitle: 'Usually replies within a day',
          onResolve: () {},
        ),
      ),
      size: const Size(390, 101),
      padding: 0,
    );
  });

  testWidgets('with a business', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_header_business',
      SizedBox(
        width: 390,
        child: IqChatHeader(
          withWhom: IqChatHeaderWith.business,
          avatar: const ClipOval(child: ColoredBox(color: IqColors.err)),
          title: 'Orchid Foods',
          subtitle: 'Usually replies within a day',
          about: 'About: Rate 3 recipes in the Orchid Foods app',
          aboutIcon: IqIcons.zap,
          onResolve: () {},
          onAbout: () {},
        ),
      ),
      size: const Size(390, 101),
      padding: 0,
    );
  });
}
