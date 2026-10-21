import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The icons the tablet layouts add (Exp/Icon/settings, sidebar-collapse,
/// sidebar-expand; Icon/circle-check, circle-dashed), exported from the
/// tablet frames. They are held as SVG text so the tablet layouts ship as
/// a code patch; they move to assets/icons with the next release.
enum IqTabletIcons {
  settings(18, _settings),
  sidebarCollapse(24, _sidebarCollapse),
  sidebarExpand(24, _sidebarExpand),
  circleCheck(14, _circleCheck),
  circleDashed(18, _circleDashed);

  const IqTabletIcons(this.box, this.paths);

  final double box;
  final String paths;

  String get svg =>
      '<svg width="$box" height="$box" viewBox="0 0 $box $box" fill="none" '
      'xmlns="http://www.w3.org/2000/svg">$paths</svg>';
}

class IqTabletIcon extends StatelessWidget {
  const IqTabletIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 24,
  });

  final IqTabletIcons icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      icon.svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

const _settings =
    '<path d="M14.0853 7.43412L15.75 7.875V10.125L14.0853 10.5659L13.7052 '
    '11.4932L14.5642 12.9755L12.9755 14.5642L11.4932 13.7052L10.5659 '
    '14.0853L10.125 15.75H7.875L7.43412 14.0853L6.50676 13.7052L5.02449 '
    '14.5642L3.43581 12.9755L4.29476 11.4932L3.9147 10.5659L2.25 10.125V7.875'
    'L3.9147 7.43412L4.29476 6.50676L3.43581 5.02449L5.02449 3.43581L6.50676 '
    '4.29476L7.43412 3.9147L7.875 2.25H10.125L10.5659 3.9147L11.4932 '
    '4.29476L12.9755 3.43581L14.5642 5.02449L13.7052 6.50676L14.0853 '
    '7.43412ZM11.2804 9C11.2804 8.3952 11.0402 7.81517 10.6125 7.38751C10.1848 '
    '6.95985 9.6048 6.7196 9 6.7196C8.3952 6.7196 7.81517 6.95985 7.38751 '
    '7.38751C6.95985 7.81517 6.7196 8.3952 6.7196 9C6.7196 9.6048 6.95985 '
    '10.1848 7.38751 10.6125C7.81517 11.0402 8.3952 11.2804 9 11.2804C9.6048 '
    '11.2804 10.1848 11.0402 10.6125 10.6125C11.0402 10.1848 11.2804 9.6048 '
    '11.2804 9Z" fill-rule="evenodd" clip-rule="evenodd" fill="#000"/>';

const _panel =
    '<path d="M6 4H18C18.7956 4 19.5587 4.31607 20.1213 4.87868C20.6839 '
    '5.44129 21 6.20435 21 7V17C21 17.7956 20.6839 18.5587 20.1213 '
    '19.1213C19.5587 19.6839 18.7956 20 18 20H6C5.20435 20 4.44129 19.6839 '
    '3.87868 19.1213C3.31607 18.5587 3 17.7956 3 17V7C3 6.20435 3.31607 '
    '5.44129 3.87868 4.87868C4.44129 4.31607 5.20435 4 6 4ZM10 6H17.5C17.8978 '
    '6 18.2794 6.15804 18.5607 6.43934C18.842 6.72064 19 7.10218 19 7.5V16.5C19 '
    '16.8978 18.842 17.2794 18.5607 17.5607C18.2794 17.842 17.8978 18 17.5 '
    '18H10V6Z" fill-rule="evenodd" clip-rule="evenodd" fill="#000"/>';

const _sidebarCollapse =
    '$_panel<path d="M14.7314 8.35937C15.085 7.93518 15.7164 7.8779 16.1406 '
    '8.23144C16.5648 8.58502 16.6221 9.21638 16.2686 9.64062L14.3018 '
    '12L16.2686 14.3594C16.6221 14.7836 16.5648 15.415 16.1406 15.7686C15.7164 '
    '16.1221 15.085 16.0648 14.7314 15.6406L12.2314 12.6406C11.9224 12.2698 '
    '11.9224 11.7302 12.2314 11.3594L14.7314 8.35937Z" fill="#000"/>';

const _sidebarExpand =
    '$_panel<path d="M12.3594 8.23144C12.7836 7.8779 13.415 7.93518 13.7686 '
    '8.35937L16.2686 11.3594C16.5776 11.7302 16.5776 12.2698 16.2686 '
    '12.6406L13.7686 15.6406C13.415 16.0648 12.7836 16.1221 12.3594 '
    '15.7686C11.9352 15.415 11.8779 14.7836 12.2314 14.3594L14.1973 12L12.2314 '
    '9.64062C11.8779 9.21638 11.9352 8.58502 12.3594 8.23144Z" fill="#000"/>';

const _circleCheck =
    '<path d="M12.8337 7.00033C12.8337 10.222 10.222 12.8337 7.00033 '
    '12.8337C3.77866 12.8337 1.16699 10.222 1.16699 7.00033C1.16699 3.77866 '
    '3.77866 1.16699 7.00033 1.16699C10.222 1.16699 12.8337 3.77866 12.8337 '
    '7.00033Z" stroke-width="1.16667" stroke-linecap="round" '
    'stroke-linejoin="round" stroke="#000"/><path d="M5.25 6.99967L6.41667 '
    '8.16634L8.75 5.83301" stroke-width="1.16667" stroke-linecap="round" '
    'stroke-linejoin="round" stroke="#000"/>';

const _circleDashed =
    '<g stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" '
    'stroke="#000"><path d="M7.5752 1.66875C8.5502 1.44375 9.4502 1.44375 '
    '10.4252 1.66875"/><path d="M10.4252 16.3652C9.4502 16.5152 8.5502 '
    '16.5152 7.5752 16.3652"/><path d="M13.207 2.79004C14.032 3.31504 14.707 '
    '3.99004 15.232 4.81504"/><path d="M1.66875 10.4252C1.44375 9.4502 '
    '1.44375 8.5502 1.66875 7.5752"/><path d="M15.2096 13.207C14.6846 '
    '14.032 14.0096 14.707 13.1846 15.232"/><path d="M16.3652 7.5752C16.5152 '
    '8.5502 16.5152 9.4502 16.3652 10.4252"/><path d="M2.79004 4.80039C3.31504 '
    '3.97539 3.99004 3.30039 4.81504 2.77539"/><path d="M4.80039 '
    '15.2096C3.97539 14.6846 3.30039 14.0096 2.77539 13.1846"/></g>';
