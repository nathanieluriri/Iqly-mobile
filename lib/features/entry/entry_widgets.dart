import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/pressable.dart';
import '../../ui/step_mark.dart';
import '../../ui/top_bar.dart';
import '../shell/tablet_entry.dart';

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

  /// A submit with this field still empty: focus, a shake and a buzz, no
  /// words (the B0 frames show the button live while a field is empty).
  void nudge() {
    focus.requestFocus();
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
    this.rejected = false,
    this.inputFormatters,
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

  /// Draws Error with no words under the field, for a page that explains
  /// the problem in its banner.
  final bool rejected;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Shake(
      trigger: input.fails,
      child: IqField(
        size: IqFieldSize.large,
        label: label,
        value: '',
        help: input.error ?? '',
        state: rejected
            ? IqFieldState.error
            : fieldStateFor(input, valid: valid),
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
        inputFormatters: inputFormatters,
      ),
    );
  }
}

/// The B0 page layout: Page top bar, content from 24 below it, and the
/// action bar pinned above the home indicator (and the keyboard).
///
/// Motion (MOTION-SPEC 4.1, 4.3): the back button holds still across a push
/// between two of these screens; the step mark and the action button are
/// chrome too (see [StepMarkChrome] and [EntryAction]). With [settle] the
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
    this.showBack = true,
    this.tabletFooter,
  });

  final VoidCallback onBack;

  /// Under the button in the tablet entry split ("New to iQLY? Sign up").
  final Widget? tabletFooter;

  /// Reset link sent draws its Page bar with the back layer hidden.
  final bool showBack;
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
    if (TabletEntryScope.of(context)) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: IqColors.bg,
          resizeToAvoidBottomInset: hasFields,
          body: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.all(IqSpace.s6),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, box.maxHeight - IqSpace.s6 * 2),
                ),
                child: Center(
                  child: SizedBox(
                    width: TabletEntryScope.formWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [content, ?action, ?tabletFooter],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
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
                  showBack: showBack,
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

/// Exp/StepMark as chrome: it holds its place across a push between two
/// steps while the arriving step's bars fade over the leaving ones.
class StepMarkChrome extends StatelessWidget {
  const StepMarkChrome({super.key, required this.step});

  final IqStepMarkStep step;

  @override
  Widget build(BuildContext context) {
    // The tablet sign-up frames (1854:62713) draw no step mark.
    if (TabletEntryScope.of(context)) return const SizedBox.shrink();
    return ChromeHero(
      tag: ChromeTags.stepMark,
      shuttle: (context, progress, from, to) => Stack(
        children: [
          from,
          FadeTransition(
            opacity: progress.drive(CurveTween(curve: IqCurves.easeOut)),
            child: to,
          ),
        ],
      ),
      child: IqStepMark(step: step),
    );
  }
}

/// The primary button in a B0 action bar (88 pt: 12 over it, 24 under),
/// chrome that holds still across a push while its label crosses to the
/// arriving page's; [loading] while the page's call is in flight.
class EntryAction extends StatelessWidget {
  const EntryAction({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TabletEntryScope.of(context)
          ? const EdgeInsets.only(top: IqSpace.s6, bottom: IqSpace.s4)
          : const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              IqSpace.s6,
            ),
      child: ChromeHero(
        tag: ChromeTags.next,
        child: IqButton(
          label: label,
          showIcon: false,
          width: double.infinity,
          loading: loading,
          disabled: disabled,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// A ghost action on its Figma 44 pt slot: the 52 pt pill keeps its text
/// centred where the frame draws it.
class GhostAction extends StatelessWidget {
  const GhostAction({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OverflowBox(
        maxHeight: IqButton.defaultHeight,
        child: IqButton(
          label: label,
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          loading: loading,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Primary over a 44 pt ghost, 8 apart, on the home indicator (B0
/// 227:11209, 227:11263).
class EntryButtons extends StatelessWidget {
  const EntryButtons({
    super.key,
    required this.primary,
    required this.onPrimary,
    required this.ghost,
    required this.onGhost,
    this.primaryLoading = false,
    this.ghostLoading = false,
  });

  final String primary;
  final VoidCallback onPrimary;
  final String ghost;
  final VoidCallback onGhost;
  final bool primaryLoading;
  final bool ghostLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TabletEntryScope.of(context)
          ? const EdgeInsets.only(top: IqSpace.s6)
          : const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s3, IqSpace.s4, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqButton(
            label: primary,
            showIcon: false,
            width: double.infinity,
            loading: primaryLoading,
            onTap: onPrimary,
          ),
          const SizedBox(height: IqSpace.s2),
          GhostAction(label: ghost, loading: ghostLoading, onTap: onGhost),
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
      tactile: false,
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

/// An Exp/Banner Error in a B0 page's content (480:19882): it opens with
/// [margin] above it while [message] is set and folds away when cleared.
class EntryBanner extends StatefulWidget {
  const EntryBanner({
    super.key,
    required this.message,
    this.action,
    this.onAction,
    this.margin = const EdgeInsets.only(top: IqSpace.s4),
  });

  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry margin;

  @override
  State<EntryBanner> createState() => _EntryBannerState();
}

class _EntryBannerState extends State<EntryBanner> {
  late String _last = widget.message ?? '';

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message != null) _last = message;
    return Semantics(
      liveRegion: true,
      child: IqBanner(
        kind: IqBannerKind.error,
        title: _last,
        action: widget.action,
        showAction: widget.action != null,
        onAction: widget.onAction,
        visible: message != null,
        margin: widget.margin,
      ),
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
