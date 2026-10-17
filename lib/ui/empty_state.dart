import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'illustration.dart';

/// The full-page empty state, one layout for every list in the app (owner,
/// 17 Oct): the art over the title, the line and a primary button, all
/// centred. It is Discover's empty feed (165:8285); Figma has no component
/// of its own for it. The button shows only with [onAction], and a screen
/// gives one only when it leads somewhere other than where the person is.
///
/// Motion: the art rises in, then the title and line appear at +80 and
/// +120, then the button (spec 6.24).
class IqEmptyState extends StatelessWidget {
  const IqEmptyState({
    super.key,
    this.figure = IqFigures.writer,
    this.art,
    required this.title,
    this.body,
    this.action,
    this.onAction,
  });

  final IqFigures figure;

  /// Art in place of [figure], such as an Exp/Illustration.
  final Widget? art;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          art ??
              SizedBox(
                height: 200,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: IqFigure(figure, width: 188, arrive: true),
                  ),
                ),
              ),
          const SizedBox(height: IqSpace.s3),
          Appear(
            delay: IqDurations.stagger * 2,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: IqText.title.copyWith(color: IqColors.fg),
              ),
            ),
          ),
          if (body case final body?) ...[
            const SizedBox(height: IqSpace.s3),
            Appear(
              delay: IqDurations.stagger * 3,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: IqText.body.copyWith(color: IqColors.fg2),
                ),
              ),
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: IqSpace.s3),
            Appear(
              delay: IqDurations.stagger * 4,
              child: IqButton(label: action, showIcon: false, onTap: onAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// Holds [child] in the middle of the height it is given, scrolling when
/// that is too short. [bottom] keeps clear of what covers the page's foot.
class IqEmptyFill extends StatelessWidget {
  const IqEmptyFill({super.key, required this.child, this.bottom = 0});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: box.maxWidth,
            minHeight: math.max(0, box.maxHeight - bottom),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// [IqEmptyFill] as the last sliver of a scroll view: [child] in the middle
/// of the space the slivers above leave.
class IqSliverEmptyFill extends StatelessWidget {
  const IqSliverEmptyFill({super.key, required this.child, this.bottom = 0});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Center(child: child),
      ),
    );
  }
}
