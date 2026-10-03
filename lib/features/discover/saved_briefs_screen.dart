import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/skeleton.dart';
import 'app_shell.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';

/// B12 · Saved briefs (250:12333), offline (250:12609) and empty
/// (250:12880). The saved copies live on the device, so the list still
/// opens when the feed cannot load.
class SavedBriefsScreen extends ConsumerWidget {
  const SavedBriefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedBriefsProvider);
    final offline = ref.watch(discoverFeedProvider).hasError;
    final briefs = saved.value;

    final List<Widget> body;
    if (briefs == null) {
      body = [
        for (var i = 0; i < 2; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: IqSkeleton(),
          ),
      ];
    } else if (briefs.isEmpty) {
      body = [const _Empty()];
    } else {
      body = [
        if (offline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: IqBanner(
              kind: IqBannerKind.offline,
              title: 'Offline. Saved briefs still load.',
              showAction: false,
            ),
          ),
        for (final brief in briefs) Center(child: BriefTicket(brief: brief)),
      ];
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: IqColors.bg,
      body: SafeArea(
        bottom: false,
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoverTopBar(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: AppShell.contentInset(context),
                  ),
                  children: gapped([
                    const FeedChips(selected: FeedChip.saved),
                    ...body,
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 144,
            child: Center(
              child: IqIcon(IqIcons.bookmark, size: 96, color: IqColors.fg),
            ),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Nothing saved yet',
            style: IqText.display.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            'Tap the bookmark on any brief.',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          IqButton(
            label: 'Browse briefs',
            showIcon: false,
            width: double.infinity,
            onTap: () => browseForYou(context, ref),
          ),
        ],
      ),
    );
  }
}
