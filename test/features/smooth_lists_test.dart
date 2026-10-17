import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/illustration.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/svg_precache.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/app_harness.dart';
import '../golden/screens/wallet_harness.dart';

class _ManyBanks extends WalletRepository {
  @override
  Future<List<Bank>> banks() async => [
    for (var i = 0; i < 300; i++)
      Bank(code: '${1000 + i}', name: 'Bank ${i.toString().padLeft(3, '0')}'),
  ];
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Select bank builds only the banks in view, however many '
      'there are', (tester) async {
    await pumpApp(
      tester,
      Routes.selectBank,
      repository: _ManyBanks(),
      overrides: walletOverrides(),
    );
    final built = find.byType(IqListRow).evaluate().length;
    expect(built, greaterThan(5));
    expect(built, lessThan(30));
    expect(find.text('Bank 000'), findsOneWidget);
    expect(find.text('Bank 299', skipOffstage: false), findsNothing);
  });

  testWidgets('every SVG the app ships is parsed ahead and kept, so a page '
      'draws its icons on its first frame', (tester) async {
    svg.cache.clear();
    addTearDown(() => svg.cache.maximumSize = 100);
    final cached = await tester.runAsync(precacheSvgs);
    final manifest = await tester.runAsync(
      () => AssetManifest.loadFromAssetBundle(rootBundle),
    );
    final shipped = manifest!
        .listAssets()
        .where(
          (path) => svgFolders.any(path.startsWith) && path.endsWith('.svg'),
        )
        .length;
    expect(shipped, greaterThan(100));
    final layers = IqIllustrations.values.length * 2;
    expect(cached, shipped + layers);
    expect(svg.cache.count, shipped + layers);
    expect(svg.cache.maximumSize, greaterThanOrEqualTo(shipped * 2));
    for (final icon in IqIcons.values) {
      final loader = SvgAssetLoader(icon.asset);
      expect(
        loader.loadBytes(null),
        isA<SynchronousFuture<ByteData>>(),
        reason: icon.asset,
      );
    }
    for (final kind in IqIllustrations.values) {
      for (final layer in kind.layers) {
        expect(
          layer.loadBytes(null),
          isA<SynchronousFuture<ByteData>>(),
          reason: kind.asset,
        );
      }
    }
  });
}
