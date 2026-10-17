import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/wallet_service.dart';
import '../wallet/wallet_routes.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_state.dart';
import 'withdrawal_failed_screen.dart';
import 'withdrawal_tracker_screen.dart';

/// One withdrawal at `/wallet/withdrawals/:id`, opened from its activity
/// row, the payout row on Home or the payout notification: the tracker
/// (194:9752) while on hold, arrived (485:39669) once completed, the failed
/// page (194:9835) when failed or reversed. While open it follows the
/// withdrawal through [WalletService.watch], so the steps advance in place.
///
/// One the wallet does not hold (made on iqly.net, a wallet that did not
/// load, or withdrawals paused) is read by id; when that fails the page
/// shows the app's error banner and Try again (no frame draws it).
class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  StreamSubscription<Withdrawal>? _watch;
  Withdrawal? _read;
  bool _reading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      walletProvider,
      (previous, next) => _follow(next),
      fireImmediately: true,
    );
  }

  void _follow(AsyncValue<WalletData> wallet) {
    if (_watch != null) return;
    final held = wallet.value?.withdrawal(widget.id);
    if (held != null) {
      _watchFor(held);
      return;
    }
    if (wallet.isLoading && !wallet.hasError) return;
    if (_read != null || _reading || _failed) return;
    _reading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _readById();
    });
  }

  void _watchFor(Withdrawal withdrawal) {
    if (_watch != null || !withdrawal.onHold) return;
    _watch = ref.read(walletServiceProvider).watch(withdrawal).listen((latest) {
      if (!mounted) return;
      ref.read(walletProvider.notifier).replace(latest);
      if (_read != null) setState(() => _read = latest);
    });
  }

  Future<void> _readById() async {
    setState(() {
      _reading = true;
      _failed = false;
    });
    Withdrawal? found;
    var failed = false;
    try {
      found = await ref.read(walletServiceProvider).withdrawal(widget.id);
    } on Exception {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _read = found;
      _failed = failed || found == null;
    });
    if (found != null) _watchFor(found);
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final withdrawal =
        ref.watch(
          walletProvider.select(
            (wallet) => wallet.value?.withdrawal(widget.id),
          ),
        ) ??
        _read;
    if (withdrawal == null) {
      return _Waiting(onRetry: _failed ? _readById : null);
    }
    return withdrawal.failed
        ? WithdrawalFailedScreen(withdrawal: withdrawal)
        : WithdrawalTrackerScreen(withdrawal: withdrawal);
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
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
                if (retry != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                    child: IqBanner(
                      kind: IqBannerKind.error,
                      title: 'Couldn’t load. Check your connection.',
                      action: 'Try again',
                      onAction: retry,
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
