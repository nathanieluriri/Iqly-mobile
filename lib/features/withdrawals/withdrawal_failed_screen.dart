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
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_routes.dart';
import 'withdrawal_screen.dart';
import 'withdrawal_widgets.dart';

/// B14 · Withdrawal · failed (194:9835): the bank's reason in the Error
/// banner, the hero amount, the receipt without a tag, and the steps up to
/// "Failed at the bank". Check bank details opens Select bank; the pick
/// opens the Withdraw sheet with the same amount, to the same bank or
/// another one.
///
/// Motion (spec 7.9, 4.3): the banner slides down, the receipt arrives and
/// draws its tear line, and the failed step on err never breathes (a
/// failure does not pulse). Check bank details pushes Select bank, the back
/// button holding while the titles cross.
///
/// Figma over the row note: there is no separate Retry button; Check bank
/// details is the retry. The banner adds "Nothing left your wallet." to
/// the bank's words: a failed withdrawal releases its hold.
class WithdrawalFailedScreen extends ConsumerWidget {
  const WithdrawalFailedScreen({super.key, required this.withdrawal});

  final Withdrawal withdrawal;

  static String reasonLine(Withdrawal withdrawal) {
    final reason = withdrawal.failureReason;
    return reason == null
        ? 'Nothing left your wallet.'
        : '$reason Nothing left your wallet.';
  }

  Future<void> _checkBankDetails(BuildContext context) async {
    final bank = await context.push<Bank>(Routes.selectBank);
    if (bank == null || !context.mounted) return;
    context.go(
      withdrawLocation(amountKobo: withdrawal.amountKobo, bankCode: bank.code),
    );
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
                  onBack: () => leaveWithdrawal(context),
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
                    label: 'Check bank details',
                    showIcon: false,
                    width: double.infinity,
                    onTap: () => _checkBankDetails(context),
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
