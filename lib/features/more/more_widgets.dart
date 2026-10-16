import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';

/// Back to the opener; a page opened on its own (a deep link) falls back to
/// More.
void goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.more, extra: NavDirection.back);
  }
}

/// A sub page of More: the Page top bar with Back and [title], [body]
/// below it and an optional [actions] bar over the home indicator, which
/// toasts float above. No dock.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.actionsPadding = const EdgeInsets.fromLTRB(
      IqSpace.s4,
      IqSpace.s3,
      IqSpace.s4,
      IqSpace.s3,
    ),
    this.onBack,
    this.hasFields = true,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final EdgeInsets actionsPadding;
  final VoidCallback? onBack;

  /// False for a page without text entry: it then holds still while a
  /// keyboard left over from the page before drops away.
  final bool hasFields;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: hasFields,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: title,
                  onBack: onBack ?? () => goBack(context),
                ),
                Expanded(child: body),
                if (actions.isNotEmpty)
                  Padding(
                    padding: actionsPadding,
                    child: IqToastFloor(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, action) in actions.indexed) ...[
                            if (i > 0) const SizedBox(height: IqSpace.s2),
                            action,
                          ],
                        ],
                      ),
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

/// The scroll body of a sub page: 16 side gutters, [top] above the first
/// child.
class SubPageList extends StatelessWidget {
  const SubPageList({
    super.key,
    required this.children,
    this.top = 0,
    this.gap = IqSpace.s2,
  });

  final List<Widget> children;
  final double top;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(IqSpace.s4, top, IqSpace.s4, IqSpace.s4),
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) SizedBox(height: gap),
          child,
        ],
      ],
    );
  }
}

/// A stack of Exp/ListRows. [outlined] gives it the hairline card of Your
/// profile and Notifications (radius 16).
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children, this.outlined = false});

  final List<Widget> children;
  final bool outlined;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!outlined) return column;
    return Container(
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: IqColors.line),
      ),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: column,
    );
  }
}

/// A centred empty or done state: the figure, a title, a line and an
/// optional button.
class FigureState extends StatelessWidget {
  const FigureState({
    super.key,
    required this.figure,
    required this.title,
    required this.body,
    this.action,
    this.bodyInset = IqSpace.s4,
  });

  final Widget figure;
  final String title;
  final String body;
  final Widget? action;

  /// The body line's side inset (45 on the B20 and B21 done states).
  final double bodyInset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        figure,
        const SizedBox(height: IqSpace.s3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: IqText.title.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s3),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: bodyInset),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ),
        if (action case final action?) ...[
          const SizedBox(height: IqSpace.s3),
          action,
        ],
      ],
    );
  }
}
