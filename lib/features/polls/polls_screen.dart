import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart';
import 'polls_routes.dart';
import 'polls_state.dart';
import 'quick_poll_tile.dart';

/// B2 · Quick polls (33:26), behind Flags.polls: a sub page with the open
/// polls as Exp/PollTile, each raising its business's sheet. Opened from a
/// Discover tile, [open] names the business and its sheet rises over this
/// page, as Figma's tiles lead to 33:169.
///
/// The tiles arrive the first time the list shows in a session (MOTION-SPEC
/// §7.3) and stand still on later visits.
class PollsScreen extends ConsumerStatefulWidget {
  const PollsScreen({super.key, this.open});

  final String? open;

  @override
  ConsumerState<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends ConsumerState<PollsScreen> {
  bool _opened = false;

  void _openFromBubble(List<PollBusiness> businesses) {
    final open = widget.open;
    if (_opened || open == null) return;
    _opened = true;
    final business = businesses
        .where((b) => b.name == open || b.id == open)
        .firstOrNull;
    if (business == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push(pollsOf(business.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final polls = ref.watch(pollsProvider);
    final data = polls.hasValue && !polls.hasError ? polls.value : null;
    final failed = data == null && polls.hasError && !polls.isLoading;
    if (data != null) _openFromBubble(data);

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
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Quick polls',
                  onBack: () => leave(context),
                ),
                Expanded(
                  child: LoadingGate(
                    loading: data == null && !failed,
                    skeleton: const _Skeleton(),
                    child: failed
                        ? _Failed(
                            onRetry: () =>
                                ref.read(pollsProvider.notifier).retry(),
                          )
                        : data == null
                        ? const SizedBox.shrink()
                        : data.isEmpty
                        ? const _Empty()
                        : _Businesses(businesses: data),
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

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s4),
      children: [...children],
    );
  }
}

class _Businesses extends ConsumerStatefulWidget {
  const _Businesses({required this.businesses});

  final List<PollBusiness> businesses;

  @override
  ConsumerState<_Businesses> createState() => _BusinessesState();
}

class _BusinessesState extends ConsumerState<_Businesses> {
  late final bool _arrive = !ref.read(pollsArrivedProvider);

  @override
  void initState() {
    super.initState();
    if (_arrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(pollsArrivedProvider.notifier).arrived();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final businesses = widget.businesses;
    return Stagger(
      play: _arrive,
      child: _Page(
        children: [
          StaggerItem(
            index: 0,
            child: const IqSectionTitle(
              title: 'Open polls',
              showCount: false,
              showLink: false,
            ),
          ),
          for (final (i, business) in businesses.indexed) ...[
            SizedBox(height: i == 0 ? IqSpace.s3 : IqSpace.s2p5),
            StaggerItem(
              index: i + 1,
              child: QuickPollTile(
                key: ValueKey(business.id),
                business: business,
                onTap: () => context.push(pollsOf(business.id)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: IqSpace.s3),
          const IqSkeleton(kind: IqSkeletonKind.row),
        ],
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
        ),
        const SizedBox(height: IqSpace.s6),
        const _Note(
          title: 'Nothing to show yet',
          body: 'They will show here once they load.',
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const _Page(
      children: [
        SizedBox(height: IqSpace.s3),
        Appear(
          child: _Note(
            title: 'No open polls right now',
            body: 'New polls land here.',
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: IqText.cardTitle.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(
          body,
          textAlign: TextAlign.center,
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
      ],
    );
  }
}
