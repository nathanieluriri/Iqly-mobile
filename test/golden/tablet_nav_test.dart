import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/tablet_nav.dart';

import 'golden.dart';

const _destinations = [
  IqTabletNavDestination(label: 'Discover', icon: IqIcons.discover),
  IqTabletNavDestination(
    label: 'Submissions',
    sidebarLabel: 'My submissions',
    icon: IqIcons.submissions,
  ),
  IqTabletNavDestination(label: 'Polls', icon: IqIcons.polls),
  IqTabletNavDestination(label: 'Activations', icon: IqIcons.zap),
  IqTabletNavDestination(label: 'Wallet', icon: IqIcons.wallet),
];

void main() {
  setUpAll(loadAppFonts);

  for (final layout in IqTabletNavLayout.values) {
    testWidgets(layout.name, (tester) async {
      final rail = layout == IqTabletNavLayout.rail;
      await expectComponentGolden(
        tester,
        'tablet_nav_${layout.name}',
        SizedBox(
          height: 640,
          child: IqTabletNav(
            layout: layout,
            destinations: _destinations,
            selected: 0,
            support: const IqTabletNavDestination(
              label: 'Support',
              icon: IqIcons.headset,
            ),
            showToggle: true,
          ),
        ),
        size: Size(rail ? 88 : 232, 640),
      );
    });
  }

  testWidgets('tapping an item reports its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IqTabletNav(destinations: _destinations, onSelect: taps.add),
        ),
      ),
    );
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(taps, [4]);
  });
}
