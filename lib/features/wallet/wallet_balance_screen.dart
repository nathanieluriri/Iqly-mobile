import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/top_bar.dart';
import '../../ui/wallet_card.dart';
import 'wallet_overview.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// B5 · Wallet · On its way (331:15089) and Earned so far (331:15098): sub
/// pages with the Page bar and Back, no dock; the card fixed on [balance].
class WalletBalanceScreen extends ConsumerWidget {
  const WalletBalanceScreen({super.key, required this.balance});

  final IqWalletCardBalance balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(walletProvider).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: balance == IqWalletCardBalance.earned
                      ? 'Earned so far'
                      : 'On its way',
                  onBack: () => leaveWallet(context),
                ),
                Expanded(
                  child: data == null
                      ? const SizedBox.shrink()
                      : WalletOverview(
                          data: data,
                          balance: balance,
                          bottomInset:
                              MediaQuery.viewPaddingOf(context).bottom +
                              IqSpace.s6,
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
