import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';

/// Placeholder until row B0 is built: logo and the shipped tagline only.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(IqSpace.s4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/brand/iqly-logo.svg', width: 120),
                    const SizedBox(height: IqSpace.s6),
                    const Text(
                      'The arena for bold African thinkers.',
                      style: IqText.headline,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
