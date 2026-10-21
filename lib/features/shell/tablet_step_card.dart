import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/illustration.dart';

/// T3 (Mobile App · tablet): each onboarding
/// step on a tablet is one card centred on the cream canvas, 600 wide,
/// with the step's own layout inside it.
class TabletStepCard extends StatelessWidget {
  const TabletStepCard({super.key, required this.child, this.location = ''});

  final Widget child;
  final String location;

  static const double width = 600;

  /// Landscape onboarding questions: the figure on a cream pane (380)
  /// beside the step (520), T3. The welcome, resume and done steps carry
  /// their own figure.
  static bool _figured(String location) =>
      location.startsWith('/onboarding/') &&
      location != '/onboarding/done' &&
      location != '/onboarding/resume';

  static bool covers(String location) => const [
    '/onboarding',
    '/turn-on-notifications',
  ].any((r) => location == r || location.startsWith('$r/'));

  static Widget _withFigure(bool figured, Widget step) {
    if (!figured) return step;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: 380,
          child: ColoredBox(
            color: IqColors.bg,
            child: Center(child: IqFigure(IqFigures.thinker, width: 188)),
          ),
        ),
        Expanded(child: step),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final figured = Layout.isExpanded(context) && _figured(location);
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
            constraints: BoxConstraints(
              maxWidth: figured ? 900 : width,
              maxHeight: 900,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(IqRadius.xl2),
                border: Border.all(color: IqColors.line),
                boxShadow: IqShadows.sm,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(IqRadius.xl2),
                child: _withFigure(
                  figured,
                  LayoutBuilder(
                    builder: (context, box) => MediaQuery(
                      data: media.copyWith(
                        size: box.biggest,
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                        viewInsets: EdgeInsets.only(
                          bottom:
                              (media.viewInsets.bottom -
                                      pad.bottom -
                                      IqSpace.s6)
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
      ),
    );
  }
}
