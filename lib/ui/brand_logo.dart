import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum IqBrandMark { logo, logomark }

/// Figma Tone=On light is [onLight], Tone=On dark is [onDark].
enum IqBrandTone { onLight, onDark }

/// The official iQLY Logo and Logomark, drawn from the unaltered files in
/// assets/brand. Never recoloured; size it by width or height only.
class IqBrandLogo extends StatelessWidget {
  const IqBrandLogo({
    super.key,
    this.mark = IqBrandMark.logo,
    this.tone = IqBrandTone.onLight,
    this.width,
    this.height,
  });

  final IqBrandMark mark;
  final IqBrandTone tone;
  final double? width;
  final double? height;

  String get asset => switch ((mark, tone)) {
    (IqBrandMark.logo, IqBrandTone.onLight) => 'assets/brand/iqly-logo.svg',
    (IqBrandMark.logo, IqBrandTone.onDark) =>
      'assets/brand/iqly-logo-cream.svg',
    (IqBrandMark.logomark, IqBrandTone.onLight) =>
      'assets/brand/iqly-logomark.svg',
    (IqBrandMark.logomark, IqBrandTone.onDark) =>
      'assets/brand/iqly-logomark-cream.svg',
  };

  @override
  Widget build(BuildContext context) {
    return SvgPicture(
      _AlphaMaskAssetLoader(asset),
      width: width,
      height: height,
      semanticsLabel: 'iQLY',
    );
  }
}

/// flutter_svg reads every mask as a luminance mask, while the official files
/// use alpha masks filled with brand purple, which would render the logomark
/// tile nearly transparent. Filling the mask shape white gives the same
/// coverage under either reading; the asset files stay byte-for-byte official.
class _AlphaMaskAssetLoader extends SvgAssetLoader {
  const _AlphaMaskAssetLoader(super.assetName);

  @override
  String provideSvg(ByteData? message) =>
      alphaMasksAsLuminance(super.provideSvg(message));

  @override
  SvgCacheKey cacheKey(BuildContext? context) => SvgCacheKey(
    theme: getTheme(context),
    colorMapper: colorMapper,
    keyData: ('alpha-mask', assetName),
  );

  @override
  bool operator ==(Object other) =>
      other is _AlphaMaskAssetLoader && other.assetName == assetName;

  @override
  int get hashCode => Object.hash(_AlphaMaskAssetLoader, assetName);
}

@visibleForTesting
String alphaMasksAsLuminance(String svg) => svg.replaceAllMapped(
  RegExp(r'(<mask\b[^>]*mask-type:\s*alpha[^>]*>)(.*?)(</mask>)', dotAll: true),
  (m) =>
      '${m[1]}'
      '${m[2]!.replaceAll(RegExp(r'fill="#[0-9A-Fa-f]{3,8}"'), 'fill="#FFFFFF"')}'
      '${m[3]}',
);
