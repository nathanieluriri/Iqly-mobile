import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/next_fab.dart';
import '../../ui/step_mark.dart';
import '../../ui/top_bar.dart';
import 'onboarding_draft.dart';

void goToStep(BuildContext context, WidgetRef ref, OnboardingStep step) {
  ref.read(onboardingDraftProvider.notifier).visit(step);
  context.go(step.route);
}

/// One question per screen: back, the step mark with the autosave check, a
/// Mob/Display question, the control, then Skip and the next button.
class OnboardingStepScaffold extends StatelessWidget {
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
    this.caption,
    this.nextLabel = 'Continue',
  });

  final IqStepMarkStep step;
  final IqIcons icon;
  final bool saved;
  final String title;
  final String? caption;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool nextEnabled;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: IqColors.bg,
          body: SafeArea(
            child: CenteredContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IqTopBar(
                    variant: IqTopBarVariant.page,
                    title: '',
                    onBack: onBack,
                  ),
                  SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IqSpace.s4,
                      ),
                      child: Row(
                        children: [
                          IqStepMark(step: step, icon: icon),
                          const Spacer(),
                          AutosaveCheck(saved: saved),
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
                            title,
                            style: IqText.display.copyWith(color: IqColors.fg),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: IqSpace.s1p5),
                            Text(
                              caption,
                              style: IqText.body.copyWith(color: IqColors.fg2),
                            ),
                            const SizedBox(height: IqSpace.s5),
                          ] else
                            const SizedBox(height: IqSpace.s6),
                          child,
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
                        IqButton(
                          label: 'Skip',
                          kind: IqButtonKind.ghost,
                          showIcon: false,
                          width: 45,
                          onTap: onSkip,
                        ),
                        const Spacer(),
                        IqNextFab(
                          state: nextEnabled
                              ? IqNextFabState.enabled
                              : IqNextFabState.disabled,
                          semanticLabel: nextLabel,
                          onTap: onNext,
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

/// Autosave is a check, never a sentence (brief section 0). It pops in, 0.6
/// to 1 with a small overshoot, when the step first saves.
class AutosaveCheck extends StatefulWidget {
  const AutosaveCheck({super.key, required this.saved});

  final bool saved;

  static const duration = Duration(milliseconds: 200);

  @override
  State<AutosaveCheck> createState() => _AutosaveCheckState();
}

class _AutosaveCheckState extends State<AutosaveCheck>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: AutosaveCheck.duration,
    value: widget.saved ? 1 : 0,
  );
  late final _overshoot = CurvedAnimation(
    parent: _pop,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
  late final _scale = Tween(begin: 0.6, end: 1.0).animate(_overshoot);
  late final _opacity = CurvedAnimation(
    parent: _pop,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
    reverseCurve: Curves.easeIn,
  );

  @override
  void didUpdateWidget(AutosaveCheck old) {
    super.didUpdateWidget(old);
    if (widget.saved == old.saved) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = widget.saved ? 1 : 0;
    } else if (widget.saved) {
      _pop.forward(from: 0);
    } else {
      _pop.reverse();
    }
  }

  @override
  void dispose() {
    _overshoot.dispose();
    _opacity.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.saved ? 'Saved' : null,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: const IqIcon(IqIcons.check, size: 20, color: IqColors.ok),
        ),
      ),
    );
  }
}

/// Welcome, Resume and Done: an illustration, a mono eyebrow and a display
/// title over the content, with full-width actions at the foot.
class OnboardingHeroScaffold extends StatelessWidget {
  const OnboardingHeroScaffold({
    super.key,
    required this.hero,
    required this.eyebrow,
    required this.title,
    required this.content,
    required this.actions,
    this.gap = IqSpace.s4,
  });

  final Widget hero;
  final String eyebrow;
  final String title;
  final List<Widget> content;
  final List<Widget> actions;

  /// Space between the stacked blocks: 16 on Welcome and Resume, 12 on Done.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        hero,
                        SizedBox(height: gap),
                        Text(
                          eyebrow.toUpperCase(),
                          style: IqText.mono.copyWith(color: IqColors.fg2),
                        ),
                        SizedBox(height: gap),
                        Text(
                          title,
                          style: IqText.display.copyWith(color: IqColors.fg),
                        ),
                        for (final child in content) ...[
                          SizedBox(height: gap),
                          child,
                        ],
                      ],
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
