import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The brush icon set (Figma Exp/Icon/*). Each SVG is one flattened "ink"
/// vector exported at 1x and recoloured at runtime; never re-exported at a
/// different stroke.
enum IqIcons {
  discover,
  submissions,
  wallet,
  profile,
  polls,
  bell,
  search,
  filter,
  clock,
  bank,
  trophy,
  plus,
  close,
  check,
  back,
  forward,
  down,
  arrow,
  minus,
  info,
  success,
  error,
  warning,
  menu,
  video,
  play,
  timer,
  upload,
  chat,
  offline,
  bookmark,
  share,
  refresh,
  receipt,
  mail,
  lock,
  link,
  download,
  pin,
  eye,
  eyeOff,
  heart,
  zap,
  flag,
  star,
  help,
  history,
  shield,
  eraser,
  award,
  sparkles,
  headset,
  lifebuoy,
  gift,
  logout,
  copy,
  document,
  users,
  medal,
  invite,
  ticket,
  more,
  phone,
  cake,
  graduation,
  briefcase,
  building,
  book;

  /// Figma names the file in kebab case (Exp/Icon/eye-off).
  String get asset =>
      'assets/icons/${name.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}')}.svg';
}

class IqIcon extends StatelessWidget {
  const IqIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 24,
    this.semanticLabel,
  });

  final IqIcons icon;
  final Color color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
