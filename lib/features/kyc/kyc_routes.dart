import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import 'kyc_sheet.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: IqColors.bg,
    body: SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: KycSheet(
          onClose: () => context.pop(),
          onComplete: (_) => context.pop(),
        ),
      ),
    ),
  );
}
