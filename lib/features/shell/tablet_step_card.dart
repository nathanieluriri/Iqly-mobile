import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// T2 and T3 (Mobile App · tablet): each sign-up, sign-in and onboarding
/// step on a tablet is one card centred on the cream canvas, 600 wide,
/// with the step's own layout inside it.
class TabletStepCard extends StatelessWidget {
  const TabletStepCard({super.key, required this.child});

  final Widget child;

  static const double width = 600;

  static bool covers(String location) => const [
    '/sign-up',
    '/sign-in',
    '/verify-email',
    '/forgot-password',
    '/onboarding',
    '/turn-on-notifications',
  ].any((r) => location == r || location.startsWith('$r/'));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pad = media.viewPadding;
    return ColoredBox(
      color: IqColors.bg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          IqSpace.s6,
          pad.top + IqSpace.s6,
          IqSpace.s6,
          pad.bottom + IqSpace.s6,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: width, maxHeight: 900),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(IqRadius.xl2),
                border: Border.all(color: IqColors.line),
                boxShadow: IqShadows.sm,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(IqRadius.xl2),
                child: LayoutBuilder(
                  builder: (context, box) => MediaQuery(
                    data: media.copyWith(
                      size: box.biggest,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.only(
                        bottom:
                            (media.viewInsets.bottom - pad.bottom - IqSpace.s6)
                                .clamp(0.0, double.infinity),
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
