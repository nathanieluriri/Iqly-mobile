import 'package:flutter/widgets.dart';

/// Phone-first layout. On wider windows (Windows desktop) the content column
/// is centred at phone width; there is no separate desktop design.
abstract final class Layout {
  static const double frameWidth = 390;
  static const double contentMaxWidth = 430;
  static const double wideBreakpoint = 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width > wideBreakpoint;
}

class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Layout.isWide(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
        child: child,
      ),
    );
  }
}
