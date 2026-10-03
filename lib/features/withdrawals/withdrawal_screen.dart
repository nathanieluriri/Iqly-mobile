import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_state.dart';
import 'withdrawal_failed_screen.dart';
import 'withdrawal_tracker_screen.dart';

/// One withdrawal, opened from its Wallet activity row or the payout row on
/// Home: the B14 tracker (194:9752) while it is on hold and once it has
/// arrived, the B14 failed screen (194:9835) when the bank failed or
/// reversed it. While open it follows the withdrawal through
/// [WalletService.watch], so the steps advance in place.
///
/// Figma wires the tracker to Home after payout after 4 s as a stand-in for
/// the payout arriving; here the steps complete in place and the arrival
/// shows on Home (MOTION-SPEC §7.9).
class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  StreamSubscription<Withdrawal>? _watch;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      walletProvider,
      (previous, next) => _follow(next.value),
      fireImmediately: true,
    );
  }

  void _follow(WalletData? data) {
    if (_watch != null) return;
    final withdrawal = data?.withdrawal(widget.id);
    if (withdrawal == null || !withdrawal.onHold) return;
    _watch = ref.read(walletServiceProvider).watch(withdrawal).listen((latest) {
      if (mounted) ref.read(walletProvider.notifier).replace(latest);
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final withdrawal = ref.watch(
      walletProvider.select((wallet) => wallet.value?.withdrawal(widget.id)),
    );
    if (withdrawal == null) return const _Waiting();
    return withdrawal.failed
        ? WithdrawalFailedScreen(withdrawal: withdrawal)
        : WithdrawalTrackerScreen(withdrawal: withdrawal);
  }
}

/// Back on a withdrawal goes to the Wallet (Figma: back → B5 · Wallet).
void leaveWithdrawal(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.wallet);
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Withdrawal',
                  onBack: () => leaveWithdrawal(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
