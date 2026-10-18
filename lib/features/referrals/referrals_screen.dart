import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/transitions.dart';
import '../../data/live/live_repository.dart' show liveModeProvider;
import '../../data/referrals_service.dart';
import '../../data/share_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../../ui/share_target.dart';
import '../../ui/pressable.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_state.dart';
import '../more/more_widgets.dart';
import 'invite_code_screen.dart';
import 'referrals_state.dart';

/// Puts the invite [code] on the clipboard and says so.
Future<void> copyInviteCode(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  IqHaptics.success.play();
  if (context.mounted) IqToast.show(context, 'Code copied');
}

/// B20 · Referrals (430:19109): the Gift figure, the ₦500 promise, the
/// person's code with Copy, then Invite friends (the share sheet,
/// 433:19672), Enter an invite code and Referral history, and the terms.
///
/// Enter an invite code shows only until the first win or 7 days after
/// sign-up (designer answer 41). The frame shows it for the sample account,
/// which has two wins: see the lane report. Live referrals have no reward
/// yet (contract 10.4), so the page and the message promise none.
class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  bool _copied = false;
  Timer? _reset;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(giftShineSpentProvider.notifier).spend();
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy(String code) async {
    await copyInviteCode(context, code);
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(ReferralsService.copiedFor, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final referrals = ref.watch(referralsProvider).value;
    final codeOpen = ref.watch(inviteCodeOpenProvider).value ?? false;
    final code = referrals?.code ?? '';
    final rewards = ref.watch(referralRewardsProvider);
    final unapplied = ref.watch(unappliedInviteProvider);
    return SubPage(
      title: 'Referrals',
      actionsPadding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s2,
        IqSpace.s4,
        IqSpace.s3,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s2,
          IqSpace.s4,
          0,
        ),
        children: [
          const Center(child: IqFigure(IqFigures.gift, width: 190)),
          const SizedBox(height: 14),
          Text(
            rewards ? 'Invite friends and earn' : 'Invite friends',
            textAlign: TextAlign.center,
            style: IqText.headline.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: Text(
              rewards
                  ? 'You both get ${referralReward()} when a friend you invite wins their '
                        'first brief.'
                  : 'Share your code. Friends add it when they join iQLY.',
              textAlign: TextAlign.center,
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 80,
            padding: const EdgeInsets.only(left: 18, right: 14),
            decoration: BoxDecoration(
              color: IqColors.tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your code'.toUpperCase(),
                        style: IqText.mono.copyWith(color: IqColors.fg2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: IqText.title.copyWith(color: IqColors.fg),
                      ),
                    ],
                  ),
                ),
                IqButton(
                  label: _copied ? 'Copied' : 'Copy',
                  kind: IqButtonKind.ghost,
                  rollLabel: true,
                  onTap: code.isEmpty ? null : () => _copy(code),
                ),
              ],
            ),
          ),
          if (unapplied != null) ...[
            const SizedBox(height: IqSpace.s3),
            Text(
              'Your friend’s code ${unapplied.code} wasn’t added. '
              '${InviteCodeScreen.errors[unapplied.outcome] ?? ''}',
              style: IqText.small.copyWith(color: IqColors.err),
            ),
          ],
        ],
      ),
      actions: [
        IqButton(
          label: 'Invite friends',
          showIcon: false,
          width: double.infinity,
          onTap: code.isEmpty ? null : () => showInviteSheet(context, code),
        ),
        if (codeOpen || unapplied != null)
          IqButton(
            label: 'Enter an invite code',
            kind: IqButtonKind.secondary,
            showIcon: false,
            width: double.infinity,
            onTap: () => context.open(Routes.inviteCode),
          ),
        IqButton(
          label: 'Referral history',
          kind: IqButtonKind.secondary,
          showIcon: false,
          width: double.infinity,
          onTap: () => context.open(Routes.referralHistory),
        ),
        Center(
          child: IqPressable(
            semanticLabel: 'Terms and conditions',
            onTap: () => context.open(Routes.terms),
            builder: (context, pressed) => SizedBox(
              height: 24,
              child: Center(
                child: Text(
                  'Terms and conditions',
                  style: IqText.smallStrong.copyWith(color: IqColors.brand),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// B20 · Invite · share sheet (433:19672): the message, the apps, Copy link
/// and Save image.
Future<void> showInviteSheet(BuildContext context, String code) async {
  final copied = await showIqSheet<bool>(
    Navigator.of(context, rootNavigator: true).context,
    (context) => Material(
      type: MaterialType.transparency,
      child: _InviteSheet(code: code),
    ),
    scrim: IqScrim.share,
  );
  if (copied == true && context.mounted) IqToast.show(context, 'Link copied');
}

class _InviteSheet extends ConsumerWidget {
  const _InviteSheet({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(referralsServiceProvider);
    final message = ReferralsService.message(
      code,
      rewards: ref.watch(referralRewardsProvider),
    );
    void close() => Navigator.of(context).pop();
    Future<void> share(ShareApp? app) async {
      await service.shareInvite(message, app: app);
      if (context.mounted) close();
    }

    // The app has no share path on the phone yet: a live launch offers only
    // what works, Copy link.
    final canShare = ref.watch(liveModeProvider).isPreview;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqTopBar(
            variant: IqTopBarVariant.sheet,
            title: 'Invite friends',
            onClose: close,
          ),
          const SizedBox(height: IqSpace.s1),
          Center(
            child: Container(
              width: 222,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: IqColors.tint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message'.toUpperCase(),
                    style: IqText.mono.copyWith(color: IqColors.fg2),
                  ),
                  const SizedBox(height: IqSpace.s2),
                  Text(
                    message,
                    style: IqText.body.copyWith(color: IqColors.fg),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: IqSpace.s4),
          if (canShare) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  for (final (kind, app) in const [
                    (IqShareTargetKind.whatsapp, ShareApp.whatsapp),
                    (IqShareTargetKind.instagram, ShareApp.instagram),
                    (IqShareTargetKind.x, ShareApp.x),
                    (IqShareTargetKind.telegram, ShareApp.telegram),
                    (IqShareTargetKind.more, null),
                  ])
                    IqShareTarget(kind: kind, onTap: () => share(app)),
                ],
              ),
            ),
            const SizedBox(height: IqSpace.s4),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              0,
              IqSpace.s4,
              IqSpace.s4,
            ),
            child: RowGroup(
              outlined: true,
              children: [
                IqListRow(
                  label: 'Copy link',
                  showDescription: false,
                  showChevron: false,
                  icon: IqIcons.link,
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: ReferralsService.link(code)),
                    );
                    IqHaptics.success.play();
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  divider: canShare,
                ),
                if (canShare)
                  IqListRow(
                    label: 'Save image',
                    showDescription: false,
                    showChevron: false,
                    icon: IqIcons.download,
                    divider: false,
                    onTap: () async {
                      await service.saveInviteImage(code);
                      if (context.mounted) close();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
