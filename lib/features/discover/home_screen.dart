import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../entry/first_tip.dart';

/// Placeholder until row B1 is built.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FirstTipOverlay(
        child: Scaffold(
          backgroundColor: IqColors.bg,
          body: SafeArea(
            child: CenteredContent(
              child: Padding(
                padding: const EdgeInsets.all(IqSpace.s4),
                child: Text('Discover', style: IqText.display),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
