import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../../ui/top_bar.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// B5 · Withdrawal pending (38:147), the moment after a withdrawal is sent:
/// the Sender figure arrives, then the title, the line and the fact, 40 ms
/// apart. The Page bar has no back (as drawn); Done goes back to the
/// opener.
///
/// Figma slip: the fact reads ₦7,500.00, the old ₦12,500.00 less the
/// ₦5,000.00; it is what is left now ([WalletTotals.withdrawableKobo]).
class WithdrawalPendingScreen extends ConsumerWidget {
  const WithdrawalPendingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletProvider).value;
    final withdrawal = data?.withdrawal(id);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Withdraw',
                  showBack: false,
                ),
                Expanded(
                  child: withdrawal == null || data == null
                      ? const SizedBox.shrink()
                      : Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: IqSpace.s4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Center(
                                  child: IqFigure(
                                    IqFigures.sender,
                                    width: 188.235,
                                    arrive: true,
                                  ),
                                ),
                                const SizedBox(height: IqSpace.s4),
                                Appear(
                                  delay: IqDurations.stagger * 2,
                                  child: Text(
                                    '${naira(withdrawal.amountKobo)} is on its way',
                                    textAlign: TextAlign.center,
                                    style: IqText.title.copyWith(
                                      color: IqColors.fg,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: IqSpace.s4),
                                Appear(
                                  delay: IqDurations.stagger * 3,
                                  child: Text(
                                    'To ${withdrawal.destination ?? ''}. '
                                    'Usually arrives in minutes. '
                                    'Can take up to 24 hours.',
                                    textAlign: TextAlign.center,
                                    style: IqText.body.copyWith(
                                      color: IqColors.fg2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: IqSpace.s4),
                                Appear(
                                  delay: IqDurations.stagger * 4,
                                  child: _Fact(
                                    label: 'Left in your wallet',
                                    value: naira(data.totals.withdrawableKobo),
                                  ),
                                ),
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
                    label: 'Done',
                    showIcon: false,
                    width: double.infinity,
                    onTap: () => leaveWallet(context),
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

/// The fact row of 38:147: a hairline over a 43 tall row.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(
            color: IqColors.line,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          SizedBox(
            height: 43,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: IqText.small.copyWith(color: IqColors.fg3),
                  ),
                ),
                const SizedBox(width: IqSpace.s3),
                Text(
                  value,
                  style: IqText.figureSmall.copyWith(color: IqColors.fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
