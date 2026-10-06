import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/illustration.dart';
import '../../ui/top_bar.dart';
import '../discover/app_shell.dart';
import '../submissions/submission_widgets.dart' show SkeletonCard;
import 'wallet_overview.dart';
import 'wallet_state.dart';

/// B5 · Wallet (37:24), the Wallet tab root, with its lenses: balance
/// hidden (331:15080), On its way and Earned through the balance tabs,
/// failed to load (165:8792) and no activity (165:8921). The shell draws
/// the dock.
///
/// The skeleton shows on the first load only; coming back to the tab shows
/// what is held and reloads behind it (designer answer 30).
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _retrying = false;
  bool _inView = true;
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = router;
    router?.routerDelegate.addListener(_onRoute);
  }

  bool get _atWallet {
    final router = _router;
    if (router == null || router.routerDelegate.currentConfiguration.isEmpty) {
      return true;
    }
    return router.state.uri.path == Routes.wallet;
  }

  void _onRoute() {
    final now = _atWallet;
    if (now && !_inView) {
      unawaited(ref.read(walletProvider.notifier).refreshQuietly());
    }
    _inView = now;
  }

  void _retry() {
    setState(() => _retrying = true);
    ref.read(walletProvider.notifier).retry();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(walletProvider, (previous, next) {
      if (!_retrying || next.isLoading) return;
      if (next.hasError) errorHaptic();
      setState(() => _retrying = false);
    });
    final wallet = ref.watch(walletProvider);
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final data = wallet.value;
    final failed = data == null && wallet.hasError && !wallet.isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  title: 'Wallet',
                  count: '$unread',
                  showCount: unread > 0,
                  onBell: () => context.push(Routes.notifications),
                  showWallet: false,
                ),
                Expanded(
                  child: failed && !_retrying
                      ? _Failed(onRetry: _retry)
                      : LoadingGate(
                          loading: data == null,
                          skeletonNow: _retrying,
                          skeleton: const _Skeletons(),
                          child: data == null
                              ? const SizedBox.shrink()
                              : WalletOverview(
                                  data: data,
                                  root: true,
                                  bottomInset: AppShell.contentInset(context),
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

/// The card, the actions and three rows as skeletons, 12 apart.
class _Skeletons extends StatelessWidget {
  const _Skeletons();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonCard(height: 142),
          SizedBox(height: IqSpace.s3),
          SkeletonCard(height: 68, radius: 14),
          SizedBox(height: IqSpace.s3),
          SkeletonCard(height: 64, radius: 12),
          SizedBox(height: IqSpace.s2),
          SkeletonCard(height: 64, radius: 12),
          SizedBox(height: IqSpace.s2),
          SkeletonCard(height: 64, radius: 12),
        ],
      ),
    );
  }
}

/// 165:8792: the Error banner over the Thinker and the two lines.
class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        0,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: 'Couldn’t load. Check your connection.',
            action: 'Try again',
            onAction: onRetry,
          ),
          const SizedBox(height: IqSpace.s3 + 32),
          const Center(child: IqFigure(IqFigures.thinker, width: 188.235)),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Couldn\'t load your wallet',
            textAlign: TextAlign.center,
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Check your data or Wi-Fi and try again.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }
}
