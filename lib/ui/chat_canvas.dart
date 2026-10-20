import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'vector.dart';

/// Exp/ChatCanvas: the grey a thread's messages sit on, under the 384 pt
/// Exp/ChatPattern tile repeated from the top left. The pattern's ink is
/// the foreground at 5%, kept in the SVG.
class IqChatCanvas extends StatelessWidget {
  const IqChatCanvas({super.key, required this.child});

  final Widget child;

  static const double tile = 384;
  static const String pattern = 'assets/vectors/chat-canvas-pattern.svg';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IqColors.secondary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final across = (box.maxWidth / tile).ceil();
                    final down = (box.maxHeight / tile).ceil();
                    return OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: across * tile,
                      maxHeight: down * tile,
                      child: Column(
                        children: [
                          for (var y = 0; y < down; y++)
                            Row(
                              children: [
                                for (var x = 0; x < across; x++)
                                  const IqVector(
                                    pattern,
                                    color: IqColors.fg,
                                    width: tile,
                                    height: tile,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
