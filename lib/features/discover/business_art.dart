import 'package:flutter/widgets.dart';

import '../../data/activations_data.dart';
import '../../data/demo_data.dart';
import '../../theme/theme.dart';
import '../../ui/network_image.dart';
import '../../ui/sample_cover.dart';
import '../../ui/sample_logo.dart';

final _sampleLogo = RegExp(r'^assets/samples/logos/([a-z-]+)\.svg$');
final _sampleCover = RegExp(r'^assets/samples/covers/([a-z-]+)-(\d)\.jpg$');

IqSampleLogoBrand _brand(String slug) => IqSampleLogoBrand.values.firstWhere(
  (b) => b.slug == slug,
  orElse: () => IqSampleLogoBrand.private,
);

Widget _networkArt(
  String source, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget error,
  bool round = false,
}) {
  return IqNetworkImage(
    url: source,
    width: width,
    height: height,
    fit: fit,
    round: round,
    error: error,
  );
}

/// A list mark: the photo, a sample brand, the first letter, or the
/// anonymous mark when the business keeps its name out.
Widget businessMark({String? logo, String? name, double size = 40}) {
  if (logo != null && logo.isNotEmpty) return businessLogo(logo, size: size);
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) {
    return IqSampleLogo(IqSampleLogoBrand.private, size: size);
  }
  final brand = IqSampleLogoBrand.values
      .where(
        (b) => b != IqSampleLogoBrand.private && trimmed.startsWith(b.label),
      )
      .firstOrNull;
  if (brand != null) return IqSampleLogo(brand, size: size);
  return _LetterMark(
    letter: trimmed.characters.first.toUpperCase(),
    size: size,
  );
}

class _LetterMark extends StatelessWidget {
  const _LetterMark({required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: IqColors.tintStrong,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: IqText.label.copyWith(
          color: IqColors.brand,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// A business logo from the data: the Sample/Logo art for the demo's asset
/// paths, the image at a URL from the API, the anonymous mark when unset or
/// when the image cannot be had.
Widget businessLogo(String? source, {double size = 120}) {
  if (source != null && source.startsWith('http')) {
    return _networkArt(
      source,
      width: size,
      height: size,
      round: true,
      error: IqSampleLogo(IqSampleLogoBrand.private, size: size),
    );
  }
  final slug = source == null ? null : _sampleLogo.firstMatch(source)?[1];
  return IqSampleLogo(
    slug == null ? IqSampleLogoBrand.private : _brand(slug),
    size: size,
  );
}

/// A business photo from the data, as [businessLogo] reads its logo.
Widget businessCover(String? source) {
  if (source != null && source.startsWith('http')) {
    return _networkArt(
      source,
      error: const IqSampleCover(IqSampleLogoBrand.private),
    );
  }
  final match = source == null ? null : _sampleCover.firstMatch(source);
  if (match == null) return const IqSampleCover(IqSampleLogoBrand.private);
  return IqSampleCover(_brand(match[1]!), shot: int.parse(match[2]!));
}

const _activationArt = {
  'Orchid Foods': ('orchid-foods', 'basket-ng'),
  'Kudi Box': ('kudi-box', 'kudi-box'),
  'Unibooks': ('unibooks', 'unibooks'),
};

/// The activation's business logo: the API's, or in the preview the
/// sample business's by name.
String? activationLogo(Activation activation) {
  if (activation.live) return activation.logoUrl;
  final art = _activationArt[activation.business];
  return art == null ? null : DemoData.logoOf(art.$1);
}

/// The activation's photo. The Orchid Foods recipes activation shows the
/// grocery shot, as Figma's Activations card does (31:24).
String? activationCover(Activation activation) {
  if (activation.live) return activation.imageUrl;
  final art = _activationArt[activation.business];
  return art == null ? null : DemoData.coverOf(art.$2);
}
