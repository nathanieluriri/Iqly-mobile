import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'illustration.dart';

/// Where the app's SVGs live, in the order they are needed: icons are on
/// nearly every page, the vectors under fields, titles and markers, the
/// illustrations on empty and done states.
const svgFolders = [
  'assets/icons/',
  'assets/vectors/',
  'assets/illustrations/',
];

/// Room for every SVG the app ships, each illustration's two colour layers
/// too, and some to spare. flutter_svg keeps 100 by default, fewer than the
/// app has, so pages evicted each other's pictures and parsed them again on
/// every visit: a blank first frame, then a relayout mid-transition.
int svgCacheSize(int assets) => assets * 3 + 32;

/// Parses every SVG the app ships into flutter_svg's cache, one after the
/// other so the parse never crowds a frame, so a page opening for the first
/// time draws its icons, strokes and illustration layers on its first
/// frame. Answers how many it cached.
Future<int> precacheSvgs({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(assets);
  final paths = [
    for (final folder in svgFolders)
      for (final path in manifest.listAssets())
        if (path.startsWith(folder) && path.endsWith('.svg')) path,
  ];
  svg.cache.maximumSize = svgCacheSize(paths.length);
  final loaders = [
    for (final path in paths) SvgAssetLoader(path),
    for (final kind in IqIllustrations.values) ...kind.layers,
  ];
  var cached = 0;
  for (final loader in loaders) {
    try {
      await loader.loadBytes(null);
      cached++;
    } on Object catch (_) {
      // A picture that will not parse is left to fail where it is shown.
    }
    await Future<void>.delayed(Duration.zero);
  }
  return cached;
}
