import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/activations_data.dart';
import '../../data/help_data.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/balance_hero.dart';
import '../../ui/button.dart';
import '../../ui/chat_bubble.dart';
import '../../ui/field.dart';
import '../../ui/ticket_tag.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart';
import '../wallet/wallet_format.dart';
import '../wallet/wallet_state.dart';
import 'help_routes.dart';
import 'help_state.dart';
import 'help_widgets.dart';

/// B10 · Help thread · replied (141:5876): the ticket's state and subject,
/// the person's message with what was attached, support's reply and the
/// balance with the activation's reward in it (credited by the reply, or
/// already paid when it came), then a reply box under the action bar. Mark
/// as resolved closes the ticket and goes back to the activation (B9
/// Reward credited); View wallet opens the Wallet tab.
///
/// Motion (MOTION-SPEC §7.7, Figma 168:1080): sent from the request, the
/// message arrives at +120 and its attachment line 120 after it; support
/// types (the dots hold the pulse) until its bubble arrives; the tag
/// crosses to Support replied; the updated balance arrives and its changed
/// digits roll from the old figures at +400. Resolving crosses the tag to
/// Resolved before leaving. A thread opened later shows still.
class HelpThreadScreen extends ConsumerStatefulWidget {
  const HelpThreadScreen({super.key, required this.id, this.entry});

  final String id;
  final HelpThreadEntry? entry;

  @override
  ConsumerState<HelpThreadScreen> createState() => _HelpThreadScreenState();
}

class _HelpThreadScreenState extends ConsumerState<HelpThreadScreen> {
  static final _time = DateFormat('EEE, h:mm a');

  final _reply = TextEditingController();
  late final bool _sent = widget.entry == HelpThreadEntry.sent;
  int? _shownMessages;
  bool? _creditShown;
  bool _rolled = true;
  bool _resolving = false;
  bool _replying = false;
  Timer? _roll;
  Timer? _leave;

  @override
  void initState() {
    super.initState();
    ref.read(helpTicketsProvider.notifier).follow(widget.id);
  }

  @override
  void dispose() {
    _roll?.cancel();
    _leave?.cancel();
    _reply.dispose();
    super.dispose();
  }

  static String _at(DateTime at) =>
      _time.format(at).replaceAll('AM', 'am').replaceAll('PM', 'pm');

  void _noteCredit(HelpTicket ticket) {
    final credited = ticket.credit != null;
    final shown = _creditShown;
    _creditShown = credited;
    if (shown == null || shown || !credited) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _rolled = false;
    _roll = Timer(IqDurations.handoff, () {
      if (mounted) setState(() => _rolled = true);
    });
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      await ref.read(helpTicketsProvider.notifier).resolve(widget.id);
    } catch (_) {
      if (mounted) setState(() => _resolving = false);
      errorHaptic();
      return;
    }
    if (!mounted) return;
    setState(() => _resolving = false);
    IqHaptics.success.play();
    _leave = Timer(
      motion(context, IqDurations.crossfade + IqDurations.chain),
      () {
        if (mounted) leave(context);
      },
    );
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _replying) return;
    setState(() => _replying = true);
    try {
      await ref.read(helpTicketsProvider.notifier).reply(widget.id, body);
      _reply.clear();
    } catch (_) {
      errorHaptic();
    }
    if (mounted) setState(() => _replying = false);
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(
      helpTicketsProvider.select((tickets) => tickets[widget.id]),
    );
    final wallet = ref.watch(walletProvider).value;
    if (ticket != null) {
      _noteCredit(ticket);
      _shownMessages ??= _sent ? 0 : ticket.messages.length;
    }
    final shownMessages = _shownMessages ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'Help',
                  onBack: () => leave(context),
                ),
                Expanded(
                  child: ticket == null
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            IqSpace.s4,
                            0,
                            IqSpace.s4,
                            IqSpace.s3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._thread(ticket, shownMessages, wallet),
                              const SizedBox(height: IqSpace.s3),
                              IqField(
                                label: 'Reply',
                                value: 'Write to support',
                                controller: _reply,
                                minLines: 1,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.send,
                                onSubmitted: _send,
                              ),
                            ],
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: IqSpace.s4,
                    vertical: IqSpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqButton(
                        label: 'Mark as resolved',
                        showIcon: false,
                        width: double.infinity,
                        disabled:
                            ticket == null ||
                            ticket.status == HelpTicketStatus.resolved,
                        loading: _resolving,
                        onTap: _resolve,
                      ),
                      const SizedBox(height: IqSpace.s2),
                      IqButton(
                        label: 'View wallet',
                        kind: IqButtonKind.ghost,
                        showIcon: false,
                        width: double.infinity,
                        onTap: () => context.go(Routes.wallet),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _thread(HelpTicket ticket, int shown, WalletData? wallet) {
    final parts = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IqTicketTag(
              kind: switch (ticket.status) {
                HelpTicketStatus.open => IqTicketTagKind.open,
                HelpTicketStatus.replied => IqTicketTagKind.replied,
                HelpTicketStatus.resolved => IqTicketTagKind.resolved,
              },
            ),
            const SizedBox(height: IqSpace.s2),
            Text(
              ticket.subject,
              style: IqText.title.copyWith(color: IqColors.fg),
            ),
          ],
        ),
      ),
    ];
    for (final (i, message) in ticket.messages.indexed) {
      final arriving = i >= shown;
      final first = _sent && i == 0;
      final delay = first ? IqDurations.chain : Duration.zero;
      parts.add(
        KeyedSubtree(
          key: ValueKey('message-$i'),
          child: _message(message, arriving: arriving, delay: delay),
        ),
      );
      final attachment = message.attachment;
      if (attachment != null) {
        final line = Text(
          [
            'Attached',
            attachment.name,
            attachment.lengthLabel,
            attachment.sizeLabel,
          ].join(' · ').toUpperCase(),
          style: IqText.mono.copyWith(color: IqColors.fg3),
        );
        parts.add(
          arriving
              ? Appear(
                  delay:
                      delay +
                      IqChatBubble.arrive +
                      IqChatBubble.attachmentDelay,
                  child: line,
                )
              : line,
        );
      }
    }
    if (ticket.supportTyping) {
      parts.add(const Appear(key: ValueKey('typing'), child: TypingBubble()));
    }
    final award = _award(ticket, wallet);
    if (award != null && wallet != null) {
      parts.addAll(_balance(award, wallet));
    }
    return [
      for (final (i, part) in parts.indexed) ...[
        if (i > 0) const SizedBox(height: IqSpace.s3),
        part,
      ],
    ];
  }

  Widget _message(
    HelpMessage message, {
    required bool arriving,
    required Duration delay,
  }) {
    final you = message.author == HelpAuthor.you;
    IqChatBubble bubble(bool animate) => IqChatBubble(
      from: you ? IqChatBubbleFrom.you : IqChatBubbleFrom.support,
      body: message.body,
      time: _at(message.at),
      animate: animate,
    );
    final aligned = Align(
      alignment: you ? Alignment.centerRight : Alignment.centerLeft,
      child: arriving && delay > Duration.zero
          ? Later(delay: delay, standIn: bubble(false), child: bubble(true))
          : bubble(arriving),
    );
    return MergeSemantics(child: aligned);
  }

  /// The reward support's reply speaks for: the one it credited, or the
  /// activation's own payout already in the wallet when it replied.
  static LedgerEntry? _award(HelpTicket ticket, WalletData? wallet) {
    final credit = ticket.credit;
    if (credit != null) return credit;
    final about = ticket.activationId;
    if (about == null || wallet == null || !ticket.answered) return null;
    final paid = Activation.creditIdOf(about);
    return wallet.ledger.where((l) => l.id == paid).firstOrNull;
  }

  /// UPDATED BALANCE: the wallet after the credit, footing to the wallet's
  /// totals. When the credit lands on screen the hero shows the figures
  /// before it and rolls the changed digits at +400.
  List<Widget> _balance(LedgerEntry credit, WalletData wallet) {
    final ledger = [
      for (final l in wallet.ledger)
        if (l.id != credit.id) l,
      if (_rolled) credit,
    ];
    final totals = walletTotals(ledger, wallet.withdrawals);
    final (whole, decimals) = nairaParts(totals.withdrawableKobo);
    final hero = IqBalanceHero(
      amount: whole,
      decimals: decimals,
      onHold: naira(totals.pendingWithdrawalsKobo),
      earned: naira(totals.totalEarnedKobo),
      holdLabel: 'On hold · ${wallet.onHoldCount} pending',
      showWithdraw: false,
      figureBuilder: (text, style) => RollingText(text, style: style),
    );
    final label = Text(
      'Updated balance'.toUpperCase(),
      style: IqText.mono.copyWith(color: IqColors.fg3),
    );
    if (_rolled && _roll == null) return [label, hero];
    return [
      Appear(
        key: const ValueKey('balance-label'),
        delay: IqDurations.chain,
        child: label,
      ),
      Appear(
        key: const ValueKey('balance'),
        delay: IqDurations.chain,
        child: hero,
      ),
    ];
  }
}
