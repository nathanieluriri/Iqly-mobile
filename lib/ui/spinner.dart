import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import 'vector.dart';

/// The web-kit Spinner (lucide loader-circle, 1.33 stroke at 16 px),
/// turning once a second; still under reduced motion. Buttons wait on it,
/// and so do a chat's files and its Updating line.
class IqSpinner extends StatefulWidget {
  const IqSpinner({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  State<IqSpinner> createState() => _IqSpinnerState();
}

class _IqSpinnerState extends State<IqSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: IqDurations.spinnerTurn,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _turn,
        child: IqVector(
          'assets/vectors/button-spinner.svg',
          color: widget.color,
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}
