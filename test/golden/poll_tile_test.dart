import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/poll_tile.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final layout in IqPollTileLayout.values) {
    for (final state in IqPollTileState.values) {
      final name = 'poll_tile_${layout.name}_${state.name}';
      testWidgets(name, (tester) async {
        final tile = IqPollTile(layout: layout, state: state);
        await expectComponentGolden(tester, name, tile, size: tile.size);
      });
    }
  }
}
