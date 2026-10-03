import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/next_fab.dart';
import '../../ui/pressable.dart';
import '../../ui/top_bar.dart';

void goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// A text field's controller and focus, listened to as one.
class EntryInput {
  EntryInput([String text = ''])
    : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  Listenable get changes => Listenable.merge([controller, focus]);
  String get text => controller.text.trim();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// Field state as the B0 frames draw it: Active while focused, Valid once
/// a good value is left behind, Error when the screen says so.
IqFieldState? fieldStateFor(
  EntryInput input, {
  required bool valid,
  bool error = false,
}) {
  if (error) return IqFieldState.error;
  if (input.focus.hasFocus) return IqFieldState.active;
  if (valid) return IqFieldState.valid;
  return null;
}

/// The B0 step layout: Page top bar, content from 24 below it, and the
/// action bar pinned above the home indicator (and the keyboard).
class EntryScaffold extends StatelessWidget {
  const EntryScaffold({
    super.key,
    required this.onBack,
    required this.children,
    this.title = '',
    this.action,
  });

  final VoidCallback onBack;
  final List<Widget> children;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
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

class NextBar extends StatelessWidget {
  const NextBar({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

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
        child: IqNextFab(
          state: enabled ? IqNextFabState.enabled : IqNextFabState.disabled,
          onTap: onTap,
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

/// A Mob/Button text action on a 44 pt strip. The design sets it as an 18 pt
/// line; [linkSlack] is how far the strip reaches above and below it.
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
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: IqText.button.copyWith(color: IqColors.brand),
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
