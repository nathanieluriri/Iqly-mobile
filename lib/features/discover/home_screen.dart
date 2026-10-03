import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../onboarding/setup_nudge.dart';

/// Placeholder until row B1 is built.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Padding(
              padding: const EdgeInsets.all(IqSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Discover', style: IqText.display),
                  const SizedBox(height: IqSpace.s3),
                  const SetupNudge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
