import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/next_fab.dart';
import '../../ui/step_mark.dart';
import '../../ui/top_bar.dart';
import 'onboarding_draft.dart';

/// Opens [step]; [back] plays the move as a step back.
void goToStep(
  BuildContext context,
  WidgetRef ref,
  OnboardingStep step, {
  bool back = false,
}) {
  ref.read(onboardingDraftProvider.notifier).visit(step);
  context.go(step.route, extra: back ? NavDirection.back : null);
}

/// One question per screen: back, the step mark with the autosave check, a
/// Mob/Display question, the control, then Skip and the next button.
///
/// Motion (MOTION-SPEC 4.1): between steps the chrome holds still while the
/// question rides the push, the control trailing the title by 40 ms: back,
/// Skip and the next button stay, the step mark morphs, the autosave check
/// and the next button crossfade to the arriving step's look. Tapping the
/// next button while it is off shakes the [caption] that says what is
/// missing ("Pick at least 2"); no haptic.
class OnboardingStepScaffold extends StatefulWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.icon,
    required this.saved,
    required this.title,
    required this.child,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
    required this.nextEnabled,
    this.answer,
    this.caption,
    this.nextLabel = 'Continue',
  });

  final IqStepMarkStep step;
  final IqIcons icon;
  final bool saved;

  /// What the step has saved; a new answer re-stamps the autosave check.
  final Object? answer;
  final String title;
  final String? caption;
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

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: IqColors.bg,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: CenteredContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChromeHero(
                    tag: ChromeTags.back,
                    child: IqTopBar(
                      variant: IqTopBarVariant.page,
                      title: '',
                      onBack: widget.onBack,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                      ),
                      child: Row(
                        children: [
                          ChromeHero(
                            tag: ChromeTags.stepMark,
                            shuttle: IqStepMark.shuttle,
                            child: IqStepMark(
                              step: widget.step,
                              icon: widget.icon,
                            ),
                          ),
                          const Spacer(),
                          ChromeHero(
                            tag: ChromeTags.autosave,
                            shuttle: ChromeHero.crossfade(AutosaveCheck.shows),
                            child: AutosaveCheck(
                              saved: widget.saved,
                              answer: widget.answer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        IqSpace.s4,
                        caption == null ? IqSpace.s4 : IqSpace.s6,
                        IqSpace.s4,
                        IqSpace.s4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.title,
                            style: IqText.display.copyWith(color: IqColors.fg),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: IqSpace.s1p5),
                            Shake(
                              trigger: _missing,
                              child: Text(
                                caption,
                                style: IqText.body.copyWith(
                                  color: IqColors.fg2,
                                ),
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
                      IqSpace.s4,
                      IqSpace.s4,
                      28,
                    ),
                    child: Row(
                      children: [
                        ChromeHero(
                          tag: ChromeTags.skip,
                          child: IqButton(
                            label: 'Skip',
                            kind: IqButtonKind.ghost,
                            showIcon: false,
                            width: 45,
                            onTap: widget.onSkip,
                          ),
                        ),
                        const Spacer(),
                        ChromeHero(
                          tag: ChromeTags.next,
                          shuttle: ChromeHero.crossfade(IqNextFab.lit),
                          child: IqNextFab(
                            state: widget.nextEnabled
                                ? IqNextFabState.enabled
                                : IqNextFabState.disabled,
                            semanticLabel: widget.nextLabel,
                            onTap: widget.onNext,
                            onTapDisabled: caption == null
                                ? null
                                : () => setState(() => _missing++),
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
      ),
    );
  }
}

/// Autosave is a check, never a sentence (brief section 0). Motion
/// (MOTION-SPEC 5.10): the step's first save stamps it in, .6 to 1 with a
/// small overshoot (200 ms); each later save, a new [answer], re-stamps it
/// from 1.15 (160 ease-out); a cleared answer fades it out (150 ease-in).
/// Reduced motion: it shows and goes at once.
class AutosaveCheck extends StatefulWidget {
  const AutosaveCheck({super.key, required this.saved, this.answer});

  final bool saved;
  final Object? answer;

  static const duration = IqDurations.swap;

  /// Whether [look] (an [AutosaveCheck]) shows the check.
  static bool shows(Widget look) => (look as AutosaveCheck).saved;

  @override
  State<AutosaveCheck> createState() => _AutosaveCheckState();
}

class _AutosaveCheckState extends State<AutosaveCheck>
    with TickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: AutosaveCheck.duration,
    value: widget.saved ? 1 : 0,
  );
  late final _scale = _pop.drive(
    Tween<double>(
      begin: IqScale.pop,
      end: 1,
    ).chain(CurveTween(curve: IqCurves.stamp)),
  );
  late final _opacity = _pop.drive(
    CurveTween(curve: const Interval(0, 0.5, curve: IqCurves.easeOut)),
  );
  late final _restamp = AnimationController(
    vsync: this,
    duration: IqDurations.tick,
    value: 1,
  );
  late final _land = _restamp.drive(
    Tween<double>(
      begin: IqScale.stampLand,
      end: 1,
    ).chain(CurveTween(curve: IqCurves.easeOut)),
  );

  @override
  void didUpdateWidget(AutosaveCheck old) {
    super.didUpdateWidget(old);
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.saved != old.saved) {
      if (reduced) {
        _pop.value = widget.saved ? 1 : 0;
      } else if (widget.saved) {
        _pop.forward(from: 0);
      }
    } else if (widget.saved && widget.answer != old.answer && !reduced) {
      _restamp.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _restamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.saved ? 'Saved' : null,
      child: AnimatedOpacity(
        opacity: widget.saved ? 1 : 0,
        duration: widget.saved
            ? Duration.zero
            : motion(context, IqDurations.crossfade),
        curve: IqCurves.easeIn,
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: ScaleTransition(
              scale: _land,
              child: const IqIcon(IqIcons.check, size: 20, color: IqColors.ok),
            ),
          ),
        ),
      ),
    );
  }
}

/// Welcome, Resume and Done: an illustration, a mono eyebrow and a display
/// title over the content, with full-width actions at the foot.
///
/// Motion (MOTION-SPEC 6.11, 6.17, 5.32): the screen's entrance runs on one
/// controller of [entrance]: the eyebrow appears at +80 and the title at
/// +120, and the screen sets its own illustration and content beats; the
/// actions come with the page. A screen come back to stands still.
class OnboardingHeroScaffold extends StatelessWidget {
  const OnboardingHeroScaffold({
    super.key,
    required this.hero,
    required this.eyebrow,
    required this.title,
    required this.content,
    required this.actions,
    this.gap = IqSpace.s4,
    this.entrance,
  });

  final Widget hero;
  final String eyebrow;
  final String title;
  final List<Widget> content;
  final List<Widget> actions;

  /// Space between the stacked blocks: 16 on Welcome and Resume, 12 on Done.
  final double gap;

  /// How long the entrance runs, to the end of its last beat; by default
  /// the end of a line appearing at +160.
  final Duration? entrance;

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
                      play: arrivalOf(context) == NavDirection.forward,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          hero,
                          SizedBox(height: gap),
                          Beat(
                            at: IqMomentTiming.eyebrowAt,
                            child: Text(
                              eyebrow.toUpperCase(),
                              style: IqText.mono.copyWith(color: IqColors.fg2),
                            ),
                          ),
                          SizedBox(height: gap),
                          Beat(
                            at: IqMomentTiming.titleAt,
                            child: Text(
                              title,
                              style: IqText.display.copyWith(
                                color: IqColors.fg,
                              ),
                            ),
                          ),
                          for (final child in content) ...[
                            SizedBox(height: gap),
                            child,
                          ],
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
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: IqSpace.s2),
                        actions[i],
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

/// How a moment's illustration comes in: its entrance on a fresh arrival,
/// none on a screen come back to.
IqIllustrationEntrance heroEntrance(
  BuildContext context, [
  IqIllustrationEntrance entrance = IqIllustrationEntrance.rise,
]) => arrivalOf(context) == NavDirection.forward
    ? entrance
    : IqIllustrationEntrance.none;
