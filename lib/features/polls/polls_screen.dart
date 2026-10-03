import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/polls_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/section_title.dart';
import '../../ui/skeleton.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart';
import '../wallet/wallet_motion.dart' show LoadingGate;
import 'polls_routes.dart';
import 'polls_state.dart';

/// B2 · Polls · Brands (33:26), behind Flags.polls: the businesses with
/// open polls as Exp/ListRow, each raising its sheet. Opened from a
/// Discover bubble, [open] names the business and its sheet rises over this
/// page, as Figma's bubbles lead to 33:169.
///
/// The rows arrive the first time the list shows in a session (MOTION-SPEC
/// §7.3) and stand still on later visits.
///
/// Figma over brief: the frame titles the section "Brands with open polls";
/// the product says "business", never "brand", so it reads "Businesses".
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
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Polls',
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

const _intro = 'Vote, then see results.';

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s4),
      children: [
        Text(_intro, style: IqText.body.copyWith(color: IqColors.fg2)),
        const SizedBox(height: IqSpace.s3),
        ...children,
      ],
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
    final now = ref.watch(clockProvider)();
    return Stagger(
      play: _arrive,
      child: _Page(
        children: [
          StaggerItem(
            index: 0,
            child: IqSectionTitle(
              title: 'Businesses with open polls',
              count: '${businesses.length}',
              showLink: false,
            ),
          ),
          for (final (i, business) in businesses.indexed) ...[
            const SizedBox(height: IqSpace.s3),
            StaggerItem(
              index: i + 1,
              child: IqListRow(
                key: ValueKey(business.id),
                label: business.name,
                description: businessLine(business, now),
                icon: IqIcons.polls,
                divider: i < businesses.length - 1,
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
