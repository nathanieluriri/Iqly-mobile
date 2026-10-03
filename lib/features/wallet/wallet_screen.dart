import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/relative_time.dart';
import '../../core/responsive.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/activity_row.dart';
import '../../ui/balance_hero.dart';
import '../../ui/banner.dart';
import '../../ui/section_title.dart';
import '../../ui/top_bar.dart';
import '../discover/app_shell.dart';
import '../submissions/submission_widgets.dart' show SkeletonCard;
import 'wallet_format.dart';
import 'wallet_routes.dart';
import 'wallet_state.dart';

/// B5 · Wallet (37:24) with failed to load (165:8792) and no activity
/// (165:8921). It is the Wallet tab of the app shell, which draws the dock.
///
/// The first load goes through the LoadingGate (spec 2.6); the hero, the
/// Activity title and the rows then arrive 40 ms apart, once (spec 7.1).
/// The screen shows what the wallet held when it was last in view: a
/// withdrawal made from the sheet lands when the person is back here, so
/// the figures and the count roll and the new row opens in front of them
/// (spec 1.4, 5.17). Figures never count up from zero.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  WalletData? _shown;
  bool _inView = true;
  bool _retrying = false;
  Timer? _catchUp;
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = router;
    router?.routerDelegate.addListener(_onRoute);
    _inView = _atWallet;
  }

  /// The top route, pushed ones included, is the Wallet itself.
  bool get _atWallet {
    final router = _router;
    if (router == null || router.routerDelegate.currentConfiguration.isEmpty) {
      return true;
    }
    return router.state.uri.path == Routes.wallet;
  }

  void _onRoute() {
    if (!_atWallet) {
      _catchUp?.cancel();
      _inView = false;
      return;
    }
    if (_inView || (_catchUp?.isActive ?? false)) return;
    // Waits for the page on top to finish leaving.
    _catchUp = Timer(motion(context, IqDurations.screenBack, fade: true), () {
      if (mounted) setState(() => _inView = true);
    });
  }

  void _retry() {
    setState(() => _retrying = true);
    ref.read(walletProvider.notifier).retry();
  }

  @override
  void dispose() {
    _catchUp?.cancel();
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
    final data = wallet.hasValue && !wallet.hasError ? wallet.value : null;
    if (data != null && (_inView || _shown == null)) _shown = data;
    final shown = _shown;
    final failed = shown == null && wallet.hasError && !wallet.isLoading;

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
                  title: 'Wallet',
                  greeting: shown?.bankLine ?? ' ',
                  count: '$unread',
                  showCount: unread > 0,
                  onBell: () => context.push(Routes.notifications),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: shown == null,
                    skeletonNow: failed || _retrying,
                    skeleton: _Scroll(
                      child: _Placeholder(
                        failed: failed && !_retrying,
                        onRetry: _retry,
                      ),
                    ),
                    child: shown == null
                        ? const SizedBox.shrink()
                        : _Loaded(data: shown),
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

class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        IqSpace.s4,
        0,
        IqSpace.s4,
        AppShell.contentInset(context),
      ),
      child: child,
    );
  }
}

/// The wallet with its activity. Arrive plays once, when the data first
/// shows; rows that turn up later open their slot, then arrive.
class _Loaded extends ConsumerStatefulWidget {
  const _Loaded({required this.data});

  final WalletData data;

  @override
  ConsumerState<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends ConsumerState<_Loaded> {
  late final Set<String> _known = {
    for (final item in widget.data.activity) _keyOf(item),
  };
  final _added = <String>{};

  static String _keyOf(ActivityItem item) =>
      item.award?.id ?? item.withdrawal!.id;

  @override
  void didUpdateWidget(_Loaded old) {
    super.didUpdateWidget(old);
    for (final item in widget.data.activity) {
      if (_known.add(_keyOf(item))) _added.add(_keyOf(item));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final now = ref.watch(clockProvider)();
    final totals = data.totals;
    final (whole, decimals) = nairaParts(totals.withdrawableKobo);
    final activity = data.activity;

    final items = <Widget>[
      IqBalanceHero(
        amount: whole,
        decimals: decimals,
        onHold: naira(totals.pendingWithdrawalsKobo),
        earned: naira(totals.totalEarnedKobo),
        holdLabel: 'On hold · ${data.onHoldCount} pending',
        onWithdraw: () => context.push(Routes.withdraw),
      ),
      IqSectionTitle(
        title: 'Activity',
        count: '${activity.length}',
        showLink: false,
      ),
      if (activity.isEmpty) const _NoActivity(),
      for (final (i, item) in activity.indexed)
        _ActivityItemRow(
          key: ValueKey(_keyOf(item)),
          item: item,
          now: now,
          divider: i < activity.length - 1,
        ),
    ];

    return Stagger(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          IqSpace.s4,
          0,
          IqSpace.s4,
          AppShell.contentInset(context),
        ),
        children: [for (final (i, item) in items.indexed) _slot(i, item)],
      ),
    );
  }

  /// The 8 above a row travels with it, so an inserted row opens its own
  /// gap.
  Widget _slot(int index, Widget item) {
    final key = item.key;
    final spaced = index == 0
        ? item
        : Padding(
            padding: const EdgeInsets.only(top: IqSpace.s2),
            child: item,
          );
    if (key is ValueKey<String> && _added.contains(key.value)) {
      return _Inserted(key: key, child: spaced);
    }
    return KeyedSubtree(
      key: key ?? ValueKey(index),
      child: StaggerItem(index: index, child: spaced),
    );
  }
}

/// A row that turns up while the list is in view: its slot opens over
/// 240 ms, then it arrives (spec 5.17). A cut under reduced motion.
class _Inserted extends StatefulWidget {
  const _Inserted({super.key, required this.child});

  final Widget child;

  @override
  State<_Inserted> createState() => _InsertedState();
}

class _InsertedState extends State<_Inserted> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      Collapse(open: _open, child: widget.child);
}

class _ActivityItemRow extends StatelessWidget {
  const _ActivityItemRow({
    super.key,
    required this.item,
    required this.now,
    required this.divider,
  });

  final ActivityItem item;
  final DateTime now;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final award = item.award;
    if (award != null) {
      return MergeSemantics(
        child: IqActivityRowAward(
          amount: '+${naira(award.amountKobo)}',
          when: timeAgoShort(award.createdAt, now),
          divider: divider,
        ),
      );
    }
    final withdrawal = item.withdrawal!;
    return MergeSemantics(
      child: IqActivityRowWithdrawal(
        amount: naira(withdrawal.amountKobo),
        when: timeAgoShort(withdrawal.createdAt, now),
        status: withdrawal.statusWord,
        divider: divider,
        onTap: () => context.push(withdrawalPath(withdrawal.id)),
      ),
    );
  }
}

/// The empty block of 165:8921: no illustration, 24 above and below.
class _NoActivity extends StatelessWidget {
  const _NoActivity();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s6),
      child: Column(
        children: [
          Text(
            'No activity yet',
            textAlign: TextAlign.center,
            style: IqText.cardTitle.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'Rewards and withdrawals land here.',
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }
}

/// The standalone Figma Skeleton cards of 165:8792: the hero, then three
/// rows, 8 apart. Loading shows them without the banner.
class _Skeletons extends StatelessWidget {
  const _Skeletons();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonCard(height: 204),
        SizedBox(height: IqSpace.s2),
        SkeletonCard(height: 64, radius: 12),
        SizedBox(height: IqSpace.s2),
        SkeletonCard(height: 64, radius: 12),
        SizedBox(height: IqSpace.s2),
        SkeletonCard(height: 64, radius: 12),
      ],
    );
  }
}

/// The skeletons of 165:8792, with the Error banner over them once the load
/// failed: it slides down and pushes them (240), and slides away (180) on
/// Try again while the retry loads under the same skeletons (spec 5.21).
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
          visible: failed,
        ),
        AnimatedPadding(
          duration: motion(context, failed ? IqBanner.enter : IqBanner.exit),
          curve: failed ? IqCurves.easeOut : IqCurves.easeIn,
          padding: EdgeInsets.only(top: failed ? IqSpace.s2 : 0),
          child: const _Skeletons(),
        ),
      ],
    );
  }
}
