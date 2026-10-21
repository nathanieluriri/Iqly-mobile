import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/bookmark.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/tablet_action_bar.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('brief action bar', (tester) async {
    await expectComponentGolden(
      tester,
      'tablet_action_bar',
      const SizedBox(
        width: 734,
        child: IqTabletActionBar(
          title: '₦150,000',
          caption: 'Closes in 6h · 12 spots left',
          actions: [
            IqBookmark(state: IqBookmarkState.on),
            IqButton(label: 'Start your submission', width: 248),
          ],
        ),
      ),
      size: const Size(734, 84),
    );
  });
}
