import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../discover/discover_state.dart';
import '../discover/discover_widgets.dart';
import 'more_widgets.dart';

/// B7 · Saved briefs (485:39490): the saved briefs as their own page inside
/// More (designer answer 27), Page top bar and Back, no dock. The saved
/// copies live on the device, so the page opens offline, under the Offline
/// banner of the Discover Saved lens (250:12609); with nothing saved it
/// shows that lens's empty state (250:12880).
///
/// The cards are Discover's brief tickets, the shared widget on dev; the
/// frame draws Exp/BriefCard Feature, which the Discover lane brings in.
class MoreSavedBriefsPage extends ConsumerWidget {
  const MoreSavedBriefsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedBriefsProvider).value;
    final offline = ref.watch(discoverFeedProvider).hasError;
    return SubPage(
      title: 'Saved briefs',
      body: saved == null
          ? const SizedBox.shrink()
          : saved.isEmpty
          ? IqEmptyFill(
              child: IqEmptyState(
                figure: IqFigures.saver,
                title: 'Nothing saved yet',
                body: 'Tap the bookmark on any brief.',
                action: 'Browse briefs',
                onAction: () => browseForYou(context, ref),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s4,
                0,
                IqSpace.s4,
                IqSpace.s4,
              ),
              children: [
                IqBanner(
                  kind: IqBannerKind.offline,
                  title: 'Offline. Saved briefs still load.',
                  showAction: false,
                  visible: offline,
                  margin: const EdgeInsets.only(bottom: IqSpace.s3),
                ),
                for (final brief in saved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: IqSpace.s3),
                    child: Center(child: BriefTicket(brief: brief)),
                  ),
              ],
            ),
    );
  }
}
