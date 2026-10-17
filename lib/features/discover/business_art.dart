import 'package:flutter/widgets.dart';

import '../../data/activations_data.dart';
import '../../data/demo_data.dart';

import '../../ui/sample_cover.dart';
import '../../ui/sample_logo.dart';

final _sampleLogo = RegExp(r'^assets/samples/logos/([a-z-]+)\.svg$');
final _sampleCover = RegExp(r'^assets/samples/covers/([a-z-]+)-(\d)\.jpg$');

IqSampleLogoBrand _brand(String slug) => IqSampleLogoBrand.values.firstWhere(
  (b) => b.slug == slug,
  orElse: () => IqSampleLogoBrand.private,
);

/// A business logo from the data: the Sample/Logo art for the demo's asset
/// paths, the image at a URL from the API, the anonymous mark when unset or
/// when the image cannot be had.
Widget businessLogo(String? source, {double size = 120}) {
  if (source != null && source.startsWith('http')) {
    return Image.network(
      source,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          IqSampleLogo(IqSampleLogoBrand.private, size: size),
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
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const IqSampleCover(IqSampleLogoBrand.private),
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

/// The activation's business logo. Activations carry no art yet, so the
/// sample businesses' logos stand in by name.
String? activationLogo(Activation activation) {
  final art = _activationArt[activation.business];
  return art == null ? null : DemoData.logoOf(art.$1);
}

/// The activation's photo. The Orchid Foods recipes activation shows the
/// grocery shot, as Figma's Activations card does (31:24).
String? activationCover(Activation activation) {
  final art = _activationArt[activation.business];
  return art == null ? null : DemoData.coverOf(art.$2);
}
