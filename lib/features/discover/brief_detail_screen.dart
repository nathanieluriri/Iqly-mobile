import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../data/device.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/bookmark.dart';
import '../../ui/brief_hero.dart';
import '../../ui/button.dart';
import '../../ui/setting_row.dart';
import '../../ui/skeleton.dart';
import '../../ui/switch.dart';
import '../../ui/top_bar.dart';
import '../submissions/submissions_routes.dart';
import 'business_art.dart';
import 'discover_routes.dart';
import 'discover_state.dart';
import 'discover_widgets.dart';

/// B1 · Brief detail (476:17315), a sub page: Page top bar with Back, the
/// bookmark beside it (192:9707 when saved), Exp/BriefHero, the business,
/// the ask, its chips and the brief, then one button: "Start your
/// submission", "View your submission" once sent (480:22463), or "Closed ·
/// results soon" disabled once closed (480:22572). A saved brief that is
/// still open offers "Remind me".
///
/// Motion (spec 6.22, 4.3): the page pushes in already drawn from [initial],
/// the brief the person tapped (or one already loaded), and its content
/// settles 40 ms apart; only a cold open by URL waits behind LoadingGate.
class BriefDetailScreen extends ConsumerWidget {
  const BriefDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final Brief? initial;

  /// A copy of the brief that is already on the device: the feed or the
  /// saved list, if either has loaded.
  static Brief? _known(WidgetRef ref, String id) {
    Brief? find(Iterable<Brief>? briefs) =>
        briefs?.where((b) => b.id == id).firstOrNull;
    return (ref.exists(discoverFeedProvider)
            ? find(ref.read(discoverFeedProvider).value?.briefs)
            : null) ??
        (ref.exists(savedBriefsProvider)
            ? find(ref.read(savedBriefsProvider).value)
            : null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(briefDetailProvider(id));
    final brief = loaded.value ?? initial ?? _known(ref, id);
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
                Stack(
                  children: [
                    IqTopBar(
                      variant: IqTopBarVariant.page,
                      title: '',
                      onBack: () => leave(context),
                    ),
                    if (brief != null && Flags.savedBriefs)
                      Positioned(
                        right: IqSpace.s4,
                        top: IqSpace.s1p5,
                        child: _BookmarkButton(brief: brief),
                      ),
                  ],
                ),
                Expanded(
                  child: LoadingGate(
                    loading: brief == null && loaded.isLoading,
                    skeleton: const _Skeleton(),
                    child: brief == null
                        ? const SizedBox.shrink()
                        : _Body(brief: brief),
                  ),
                ),
                if (brief != null) _ActionBar(brief: brief),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The action bar (76 high): the one thing to do with the brief.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final closed = !brief.isLive || (left != null && left <= Duration.zero);
    final sent = ref.watch(briefSubmissionProvider(brief.id));
    final Widget button;
    if (sent != null) {
      button = IqButton(
        label: 'View your submission',
        kind: IqButtonKind.secondary,
        width: double.infinity,
        onTap: () => context.open(submissionPath(sent)),
      );
    } else {
      button = IqButton(
        label: closed ? 'Closed · results soon' : 'Start your submission',
        width: double.infinity,
        disabled: closed,
        onTap: () => context.open(Routes.submitTo(brief.id)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s3,
        IqSpace.s4,
        IqSpace.s3,
      ),
      child: button,
    );
  }
}

/// A cold open's wait: the eyebrow, title and fact lines.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s2, IqSpace.s4, 0),
      child: LayoutBuilder(
        builder: (context, box) {
          Widget line(double share) => IqSkeleton(
            kind: IqSkeletonKind.line,
            width: box.maxWidth * share,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(0.4),
              const SizedBox(height: IqSpace.s3),
              line(1),
              const SizedBox(height: IqSpace.s2),
              line(0.7),
              const SizedBox(height: IqSpace.s6),
              for (var i = 0; i < 3; i++) ...[
                line(1),
                const SizedBox(height: IqSpace.s6),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(savedBriefsProvider).value?.any((b) => b.id == brief.id) ??
        false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IqColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: IqColors.brand, width: 1.5),
      ),
      child: IqBookmark(
        state: saved ? IqBookmarkState.on : IqBookmarkState.off,
        onChanged: (state) => ref
            .read(savedBriefsProvider.notifier)
            .setSaved(brief, state == IqBookmarkState.on),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final closed = !brief.isLive;
    final reminders = ref.watch(closeRemindersProvider).value ?? const {};
    final saved =
        ref.watch(savedBriefsProvider).value?.any((b) => b.id == brief.id) ??
        false;
    final canRemind =
        Flags.closeReminders &&
        saved &&
        !closed &&
        left != null &&
        left > Duration.zero;
    final remindersLoaded = ref.watch(closeRemindersProvider).hasValue;
    Widget inset(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: child,
    );
    return Stagger(
      move: StaggerMove.settle,
      child: ListView(
        padding: const EdgeInsets.only(bottom: IqSpace.s6),
        children: [
          StaggerItem(
            index: 0,
            child: IqBriefHero(
              cover: businessCover(brief.cover),
              logo: businessLogo(brief.logo),
              showDots: false,
              height: 232,
            ),
          ),
          const SizedBox(height: 5),
          StaggerItem(
            index: 0,
            child: inset(
              Padding(
                padding: const EdgeInsets.only(left: 66),
                child: Text(
                  businessLabel(brief),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.smallStrong.copyWith(color: IqColors.fg),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          StaggerItem(
            index: 1,
            child: inset(
              Text(
                brief.title,
                style: IqText.headline.copyWith(color: IqColors.fg),
              ),
            ),
          ),
          const SizedBox(height: 14),
          StaggerItem(
            index: 1,
            child: inset(
              Wrap(
                spacing: IqSpace.s1p5,
                runSpacing: IqSpace.s1p5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: briefMeta(brief, now),
              ),
            ),
          ),
          const SizedBox(height: 14),
          StaggerItem(
            index: 2,
            child: inset(
              Text(brief.body, style: IqText.body.copyWith(color: IqColors.fg)),
            ),
          ),
          if (canRemind) ...[
            const SizedBox(height: 14),
            StaggerItem(
              index: 3,
              // A first value that loads after the page opens shows at once;
              // only a person's flip animates the switch.
              child: KeyedSubtree(
                key: ValueKey(remindersLoaded),
                child: inset(
                  IqSettingRow(
                    label: 'Remind me',
                    description: 'An hour before close',
                    divider: false,
                    state: reminders.contains(brief.id)
                        ? IqSwitchState.on
                        : IqSwitchState.off,
                    onChanged: (state) async {
                      final on = state == IqSwitchState.on;
                      await ref
                          .read(closeRemindersProvider.notifier)
                          .setReminder(brief.id, on);
                      if (on) {
                        await ref
                            .read(deviceServiceProvider)
                            .requestNotificationPermission();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
