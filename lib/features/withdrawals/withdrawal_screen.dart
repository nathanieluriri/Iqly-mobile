import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../wallet/wallet_routes.dart';
import '../../theme/theme.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_state.dart';
import 'withdrawal_failed_screen.dart';
import 'withdrawal_tracker_screen.dart';

/// One withdrawal at `/wallet/withdrawals/:id`, opened from its activity
/// row, the payout row on Home or the payout notification: the tracker
/// (194:9752) while on hold, arrived (485:39669) once completed, the failed
/// page (194:9835) when failed or reversed. While open it follows the
/// withdrawal through [WalletService.watch], so the steps advance in place.
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
                  onBack: () => leaveWallet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
