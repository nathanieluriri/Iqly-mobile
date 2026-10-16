import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_routes.dart';
import 'withdrawal_widgets.dart';

/// B14 · Withdrawal · failed (194:9835) and reversed (no frame; built on
/// the failed one, designer answer 7): the bank's reason in the Error
/// banner, the amount, the receipt without a tag and the steps up to the
/// failure. Fix bank account opens Select bank.
///
/// Failed means nothing left the wallet; reversed means it left and came
/// back. The banner says which.
class WithdrawalFailedScreen extends ConsumerWidget {
  const WithdrawalFailedScreen({super.key, required this.withdrawal});

  final Withdrawal withdrawal;

  static String reasonLine(Withdrawal withdrawal) {
    final reason = withdrawal.failureReason;
    final outcome = withdrawal.status == WithdrawalStatus.reversed
        ? 'Back in your wallet.'
        : 'Nothing left your wallet.';
    return reason == null ? outcome : '$reason $outcome';
  }

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
                          IqBanner(
                            kind: IqBannerKind.error,
                            title: reasonLine(withdrawal),
                            showAction: false,
                          ),
                          const SizedBox(height: IqSpace.s3),
                          WithdrawalAmount(withdrawal: withdrawal),
                          const SizedBox(height: IqSpace.s3),
                          StaggerItem(
                            index: 0,
                            child: WithdrawalReceipt(
                              withdrawal: withdrawal,
                              now: now,
                              showStatus: false,
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
                  child: IqButton(
                    label: 'Fix bank account',
                    showIcon: false,
                    width: double.infinity,
                    onTap: () => context.open(Routes.selectBank),
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
