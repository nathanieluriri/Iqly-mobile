import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../entry/entry_widgets.dart';

/// B22 · Onboarding · Your avatar (582:28894) and Avatar · Crop photo
/// (590:29839): the Page top bar, a Mob/Display heading over its caption,
/// the [centre] 24 under them, and the primary over a 44 ghost at the foot.
class AvatarStepScaffold extends StatelessWidget {
  const AvatarStepScaffold({
    super.key,
    required this.title,
    required this.heading,
    required this.caption,
    required this.centre,
    required this.primary,
    required this.onPrimary,
    required this.ghost,
    required this.onGhost,
    required this.onBack,
  });

  final String title;
  final String heading;
  final String caption;
  final Widget centre;
  final String primary;
  final VoidCallback? onPrimary;
  final String ghost;
  final VoidCallback onGhost;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: title,
                  onBack: onBack,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s6,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            heading,
                            style: IqText.display.copyWith(color: IqColors.fg),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s1p5),
                        Text(
                          caption,
                          style: IqText.body.copyWith(color: IqColors.fg2),
                        ),
                        const SizedBox(height: IqSpace.s5 + IqSpace.s6),
                        Center(child: centre),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqButton(
                        label: primary,
                        showIcon: false,
                        width: double.infinity,
                        disabled: onPrimary == null,
                        onTap: onPrimary,
                      ),
                      GhostAction(label: ghost, onTap: onGhost),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
