import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/next_fab.dart';
import '../../ui/icon.dart';
import '../../ui/pressable.dart';
import '../../ui/step_mark.dart';
import '../../ui/step_mark_ring.dart';
import '../../ui/top_bar.dart';

void goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback, extra: NavDirection.back);
  }
}

/// A text field's controller, focus and error, listened to as one. The
/// error goes the moment the text changes.
class EntryInput {
  // The caret starts at the end so a programmatic focus shows no selection
  // handle, as a tap would not either.
  EntryInput([String text = ''])
    : controller = TextEditingController.fromValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      ),
      _text = text {
    controller.addListener(_onEdit);
  }

  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  final _error = ValueNotifier<String?>(null);
  final _fails = ValueNotifier<int>(0);
  String _text;

  Listenable get changes =>
      Listenable.merge([controller, focus, _error, _fails]);
  String get text => controller.text.trim();
  String? get error => _error.value;

  /// Failed submits so far; [Shake] replays on each.
  int get fails => _fails.value;

  /// A failed submit: [message] under the field, a shake and a buzz.
  void fail(String message) {
    _error.value = message;
    _fails.value++;
    errorHaptic();
  }

  void _onEdit() {
    if (controller.text == _text) return;
    _text = controller.text;
    _error.value = null;
  }

  void dispose() {
    controller.dispose();
    focus.dispose();
    _error.dispose();
    _fails.dispose();
  }
}

/// Field state as the B0 frames draw it: Error while the input holds one,
/// Active while focused, Valid once a good value is left behind.
IqFieldState? fieldStateFor(EntryInput input, {required bool valid}) {
  if (input.error != null) return IqFieldState.error;
  if (input.focus.hasFocus) return IqFieldState.active;
  if (valid) return IqFieldState.valid;
  return null;
}

/// A Large Field bound to an [EntryInput]. Valid draws no check, as on the
/// B0 frames; Error shows its icon and help, and the field shakes on each
/// failed submit.
class EntryField extends StatelessWidget {
  const EntryField({
    super.key,
    required this.input,
    required this.label,
    this.valid = false,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final EntryInput input;
  final String label;
  final bool valid;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Shake(
      trigger: input.fails,
      child: IqField(
        size: IqFieldSize.large,
        label: label,
        value: '',
        help: input.error ?? '',
        state: fieldStateFor(input, valid: valid),
        showStatus: input.error != null,
        showNote: false,
        controller: input.controller,
        focusNode: input.focus,
        obscureText: obscureText,
        autofocus: autofocus,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// The B0 step layout: Page top bar, content from 24 below it, and the
/// action bar pinned above the home indicator (and the keyboard).
///
/// Motion (MOTION-SPEC 4.1, 4.3): the back button holds still across a push
/// between two of these screens while the bar's title crossfades (out over
/// 0 to 120 ms, in over 60 to 240); the step mark and the next button are
/// chrome too (see [EntryStepMark] and [NextBar]). With [settle] the
/// content items (wrapped in StaggerItem) rise 8 into place 40 apart as
/// the page arrives (spec 1.3); a moment instead scripts its [entrance]
/// with Beats. Neither replays on a page come back to.
class EntryScaffold extends StatelessWidget {
  const EntryScaffold({
    super.key,
    required this.onBack,
    required this.children,
    this.title = '',
    this.action,
    this.hasFields = true,
    this.settle = false,
    this.entrance,
  });

  final VoidCallback onBack;
  final List<Widget> children;
  final String title;
  final Widget? action;

  /// Screens without fields keep their layout, the home indicator's
  /// padding included, while a keyboard slides over them.
  final bool hasFields;
  final bool settle;

  /// The length of a moment's scripted entrance, to its last beat's end.
  final Duration? entrance;

  @override
  Widget build(BuildContext context) {
    final arriving = arrivalOf(context) == NavDirection.forward;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (settle) {
      content = Stagger(
        move: StaggerMove.settle,
        play: arriving,
        child: content,
      );
    }
    final entrance = this.entrance;
    if (entrance != null) {
      content = Sequence(length: entrance, play: arriving, child: content);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: hasFields,
        body: SafeArea(
          maintainBottomViewPadding: !hasFields,
          child: CenteredContent(
            child: Column(
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
                    child: content,
                  ),
                ),
                ?action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A B0 step mark, chrome that morphs across a push (spec 4.1).
class EntryStepMark extends StatelessWidget {
  const EntryStepMark({
    super.key,
    required this.step,
    required this.icon,
    this.swingIcon = false,
  });

  final IqStepMarkStep step;
  final IqIcons icon;
  final bool swingIcon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ChromeHero(
        tag: ChromeTags.stepMark,
        shuttle: IqStepMarkRing.shuttle,
        child: IqStepMarkRing(step: step, icon: icon, swingIcon: swingIcon),
      ),
    );
  }
}

/// The next button at the foot of a B0 step, chrome that holds still across
/// a push and crossfades to the arriving step's look; [loading] while the
/// step's call is in flight.
class NextBar extends StatelessWidget {
  const NextBar({
    super.key,
    required this.enabled,
    required this.onTap,
    this.loading = false,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s3,
        IqSpace.s4,
        IqSpace.s6,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: ChromeHero(
          tag: ChromeTags.next,
          shuttle: ChromeHero.crossfade(IqNextFab.lit),
          child: IqNextFab(
            state: enabled ? IqNextFabState.enabled : IqNextFabState.disabled,
            loading: loading,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// Primary over ghost, 8 apart, 12 from the home indicator.
class EntryButtons extends StatelessWidget {
  const EntryButtons({
    super.key,
    required this.primary,
    required this.onPrimary,
    required this.ghost,
    required this.onGhost,
    this.primaryLoading = false,
    this.primaryDisabled = false,
    this.ghostLoading = false,
  });

  final String primary;
  final VoidCallback onPrimary;
  final String ghost;
  final VoidCallback onGhost;
  final bool primaryLoading;
  final bool primaryDisabled;
  final bool ghostLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(IqSpace.s3)
          .copyWith(left: IqSpace.s4, right: IqSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqButton(
            label: primary,
            showIcon: false,
            width: double.infinity,
            loading: primaryLoading,
            disabled: primaryDisabled,
            onTap: onPrimary,
          ),
          const SizedBox(height: IqSpace.s2),
          IqButton(
            label: ghost,
            kind: IqButtonKind.ghost,
            showIcon: false,
            width: double.infinity,
            loading: ghostLoading,
            onTap: onGhost,
          ),
        ],
      ),
    );
  }
}

/// A Mob/Button text action on a 44 pt strip, dimming to .6 while pressed.
/// The design sets it as an 18 pt line; [linkSlack] is how far the strip
/// reaches above and below it. A new label (Show to Hide) crossfades over
/// 120 ms, a cut under reduced motion.
class EntryLink extends StatelessWidget {
  const EntryLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const double linkSlack = 13;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, pressed) => SizedBox(
        height: 44,
        child: Align(
          widthFactor: 1,
          child: PressDim(
            pressed: pressed,
            child: AnimatedSwitcher(
              duration: motion(context, IqDurations.press),
              switchInCurve: IqCurves.easeOut,
              switchOutCurve: IqCurves.easeOut,
              child: Text(
                label,
                key: ValueKey(label),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: IqText.button.copyWith(color: IqColors.brand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Already with us? Sign in" and "Remembered? Sign in".
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.lead,
    required this.link,
    required this.onTap,
    this.alignment = MainAxisAlignment.center,
  });

  final String lead;
  final String link;
  final VoidCallback onTap;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Flexible(
          child: Text(
            lead,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
        ),
        const SizedBox(width: IqSpace.s1p5),
        EntryLink(label: link, onTap: onTap),
      ],
    );
  }
}

class EntryTitle extends StatelessWidget {
  const EntryTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: IqText.display.copyWith(color: IqColors.fg)),
    );
  }
}
