import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';

/// The paper of the B5 sheets: 28 top corners, sized to its content, lifted
/// over the keyboard and clear of the home indicator.
class WalletSheet extends StatelessWidget {
  const WalletSheet({
    super.key,
    required this.children,
    this.clearIndicator = true,
  });

  final List<Widget> children;

  /// False when the sheet's own bottom padding already clears the home
  /// indicator (483:22222 pads 28 and lets the indicator sit over it).
  final bool clearIndicator;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (Layout.isTablet(context)) {
      // T11: the 480 dialog draws the card; the sheet gives its rows.
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: IqSpace.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }
    return CenteredContent(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                media.size.height - media.viewInsets.bottom - media.padding.top,
          ),
          child: Material(
            color: IqColors.bg,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                SizedBox(
                  height: media.viewInsets.bottom > 0 || !clearIndicator
                      ? 0
                      : media.viewPadding.bottom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A barrier that dims nothing: a sheet raised over another B5 sheet hides
/// that one and keeps its scrim (483:22222 shows one scrim, one sheet).
final Color clearScrim = IqColors.bg.withValues(alpha: 0);

/// Raises [builder] over the sheet around [context], which [cover] hides
/// until the new sheet has gone.
Future<T?> showOverSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  required ValueChanged<bool> cover,
}) async {
  cover(true);
  final result = await showIqSheet<T>(context, builder, scrim: clearScrim);
  cover(false);
  return result;
}

/// Keeps [child] laid out but unseen while [covered].
class SheetCover extends StatelessWidget {
  const SheetCover({super.key, required this.covered, required this.child});

  final bool covered;
  final Widget child;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: !covered,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: child,
  );
}
