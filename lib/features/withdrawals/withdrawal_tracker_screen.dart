import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_routes.dart';
import 'withdrawal_widgets.dart';

/// B14 · Withdrawal · tracker (194:9752) and arrived (485:39669): the
/// amount, the receipt with its Pending or Arrived tag, and the steps.
/// "Get help with this withdrawal" opens Help.
///
/// Motion (spec 7.9): the receipt arrives and draws its tear line; a step
/// that completes while the page is open inks in place.
class WithdrawalTrackerScreen extends ConsumerWidget {
  const WithdrawalTrackerScreen({super.key, required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Withdrawal',
                  onBack: () => leaveWallet(context),
                ),
                Expanded(
                  child: Stagger(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(IqSpace.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WithdrawalAmount(withdrawal: withdrawal),
                          const SizedBox(height: IqSpace.s3),
                          StaggerItem(
                            index: 0,
                            child: WithdrawalReceipt(
                              withdrawal: withdrawal,
                              now: now,
                            ),
                          ),
                          const SizedBox(height: IqSpace.s3),
                          WithdrawalTimeline(withdrawal: withdrawal, now: now),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: SizedBox(
                    height: 44,
                    child: OverflowBox(
                      maxHeight: IqButton.height,
                      child: IqButton(
                        label: 'Get help with this withdrawal',
                        kind: IqButtonKind.ghost,
                        showIcon: false,
                        width: double.infinity,
                        onTap: () => context.push(Routes.help),
                      ),
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
