import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../../ui/step_mark.dart';
import '../../ui/top_bar.dart';
import '../entry/entry_widgets.dart';
import 'onboarding_draft.dart';

/// Pushes [step] over the page that opens it, so back returns there
/// (answer 26).
void goToStep(BuildContext context, WidgetRef ref, OnboardingStep step) {
  ref.read(onboardingDraftProvider.notifier).visit(step);
  context.push(step.route);
}

/// Back to the opener, or [fallback] when the step was opened on its own
/// (a cold launch into Resume, say).
void leaveStep(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback, extra: NavDirection.back);
  }
}

/// One question per screen (B11 188:8171, 188:8255, 223:10826, 188:8390):
/// Page top bar, the step mark 21 into a 48 pt strip, the Mob/Display
/// question 16 under it (24 with a caption, whose header Figma pads by 8),
/// the control 24 under that (20 under a caption), then Continue and "Skip for now" at the foot. An error [banner]
/// sits 16 under the strip, the question 24 under it (480:20079).
///
/// Motion (MOTION-SPEC 4.1): between steps the chrome holds still while the
/// question rides the push, the control trailing the title by 40 ms; the
/// step mark and the foot buttons stay, the step mark crossing to the
/// arriving step's bars. Tapping Continue while it is off shakes the
/// [caption] that says what is missing ("Pick at least 2"); no haptic.
class OnboardingStepScaffold extends StatefulWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
    required this.nextEnabled,
    this.caption,
    this.banner,
    this.nextLabel = 'Continue',
  });

  final IqStepMarkStep step;
  final String title;
  final String? caption;
  final String? banner;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool nextEnabled;
  final String nextLabel;

  @override
  State<OnboardingStepScaffold> createState() => _OnboardingStepScaffoldState();
}

class _OnboardingStepScaffoldState extends State<OnboardingStepScaffold> {
  int _missing = 0;

  /// The last banner shown, kept while it folds away.
  String _banner = '';

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption;
    final banner = widget.banner;
    if (banner != null) _banner = banner;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: '',
                  onBack: widget.onBack,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    21,
                    IqSpace.s4,
                    21,
                  ),
                  child: StepMarkChrome(step: widget.step),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s4,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: IqBanner(
                            kind: IqBannerKind.error,
                            title: _banner,
                            showAction: false,
                            visible: banner != null,
                            margin: const EdgeInsets.only(bottom: IqSpace.s6),
                          ),
                        ),
                        if (caption != null) const SizedBox(height: IqSpace.s2),
                        Semantics(
                          header: true,
                          child: Text(
                            widget.title,
                            style: IqText.display.copyWith(color: IqColors.fg),
                          ),
                        ),
                        if (caption != null) ...[
                          const SizedBox(height: IqSpace.s1p5),
                          Shake(
                            trigger: _missing,
                            child: Text(
                              caption,
                              style: IqText.body.copyWith(color: IqColors.fg2),
                            ),
                          ),
                          const SizedBox(height: IqSpace.s5),
                        ] else
                          const SizedBox(height: IqSpace.s6),
                        PushTrail(child: widget.child),
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
                      ChromeHero(
                        tag: ChromeTags.next,
                        child: _Next(
                          label: widget.nextLabel,
                          enabled: widget.nextEnabled,
                          onTap: widget.onNext,
                          onTapDisabled: caption == null
                              ? null
                              : () => setState(() => _missing++),
                        ),
                      ),
                      ChromeHero(
                        tag: ChromeTags.skip,
                        child: GhostAction(
                          label: 'Skip for now',
                          onTap: widget.onSkip,
                        ),
                      ),
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

/// The step's primary button. Off, it still takes a tap so the step can
/// say what is missing.
class _Next extends StatelessWidget {
  const _Next({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.onTapDisabled,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onTapDisabled;

  @override
  Widget build(BuildContext context) {
    final button = IqButton(
      label: label,
      showIcon: false,
      width: double.infinity,
      disabled: !enabled,
      onTap: onTap,
    );
    final onTapDisabled = this.onTapDisabled;
    if (enabled || onTapDisabled == null) return button;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapDisabled,
      child: button,
    );
  }
}

/// The Figma "group" around Exp/ListRows (188:8099, 188:8570): card fill,
/// a 1 pt line stroke and 16 corners, the rows inset by the stroke.
class OnboardingGroup extends StatelessWidget {
  const OnboardingGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IqColors.card,
        border: Border.all(color: IqColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(1),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Welcome, Resume and Done (188:8099, 188:8443, 188:8490): an Exp/Figure
/// hero 24 under the status bar, a Mob/Display title and the content, with
/// full-width actions at the foot (primary over a 44 pt ghost, 8 apart).
///
/// Motion (MOTION-SPEC 6.11, 6.17, 5.32): one controller of [entrance]: the
/// figure rises in at 0, the title appears at +120 and the screen sets its
/// own content beats; the actions come with the page. A screen come back to
/// stands still.
class OnboardingHeroScaffold extends StatelessWidget {
  const OnboardingHeroScaffold({
    super.key,
    required this.figure,
    required this.title,
    required this.content,
    required this.primary,
    required this.onPrimary,
    this.ghost,
    this.onGhost,
    this.heroHeight = 208,
    this.figureTop = IqSpace.s2,
    this.titleGap = IqSpace.s4,
    this.entrance,
  });

  final IqFigures figure;
  final String title;
  final List<Widget> content;
  final String primary;
  final VoidCallback onPrimary;
  final String? ghost;
  final VoidCallback? onGhost;

  /// The hero slot; the figure (188 x 200) is clipped to it (Done is 171).
  final double heroHeight;
  final double figureTop;
  final double titleGap;

  /// How long the entrance runs, to the end of its last beat; by default
  /// the end of a line appearing at +160.
  final Duration? entrance;

  static const double figureWidth = 188.24;

  @override
  Widget build(BuildContext context) {
    final ghost = this.ghost;
    final arriving = arrivalOf(context) == NavDirection.forward;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      IqSpace.s6,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: Sequence(
                      length:
                          entrance ??
                          IqMomentTiming.bodyAt + IqDurations.appear,
                      play: arriving,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: heroHeight,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                maxHeight: double.infinity,
                                child: Padding(
                                  padding: EdgeInsets.only(top: figureTop),
                                  child: IqFigure(
                                    figure,
                                    width: figureWidth,
                                    arrive: arriving,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: titleGap),
                          Beat(
                            at: IqMomentTiming.titleAt,
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: IqText.display.copyWith(
                                  color: IqColors.fg,
                                ),
                              ),
                            ),
                          ),
                          ...content,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqButton(
                        label: primary,
                        showIcon: false,
                        width: double.infinity,
                        onTap: onPrimary,
                      ),
                      if (ghost != null) ...[
                        const SizedBox(height: IqSpace.s2),
                        GhostAction(label: ghost, onTap: onGhost ?? () {}),
                      ],
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
