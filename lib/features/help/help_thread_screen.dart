import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/help_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';
import '../../ui/chat_bubble.dart';
import '../../ui/field.dart';
import '../../ui/ticket_tag.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../../data/help_service.dart';
import '../../data/local/local_rows.dart';
import '../../data/live/live_help_service.dart' show LiveHelpService;
import '../activations/activations_state.dart' show activationProvider;
import '../more/more_widgets.dart';
import '../settings/restore_account_screen.dart';
import 'help_attachment_screen.dart';
import 'help_routes.dart';
import 'help_state.dart';
import 'help_widgets.dart';
import 'support_screen.dart' show supportTime;

/// B10 · Help thread · replied (141:5876) and B21 · Chat with support
/// (431:19583), one thread screen for the one support inbox: the ticket's
/// state and subject, the messages with what was attached, then the reply
/// box; Send reply and Mark as resolved below. Opened from the request it
/// answers the bar reads Help (141:5876); from the inbox, Support
/// (431:19583). Opening it marks support's reply read.
///
/// Motion (MOTION-SPEC §7.7, §5.17): sent from the request, the message
/// arrives at +120 and its attachment line 120 after it. Each part that
/// lands while the thread is open opens its space first (240 ms ease-out)
/// and then arrives: the typing bubble, the person's own replies, and
/// support's reply, which takes the typing bubble's place as the tag
/// crosses to Support replied. Resolving crosses the tag to Resolved before
/// leaving. A thread opened later shows still; reduced motion cuts the
/// space open and fades the parts in.
///
/// On an API that names who wrote each reply (owner decision D4), a reply
/// from the business behind an activation shows the business's name, the
/// tag says it replied, and the reply box writes to it; iQLY support keeps
/// its name and sticker. Times a week old or more show their date.
class HelpThreadScreen extends ConsumerStatefulWidget {
  const HelpThreadScreen({super.key, required this.id, this.entry});

  final String id;
  final HelpThreadEntry? entry;

  @override
  ConsumerState<HelpThreadScreen> createState() => _HelpThreadScreenState();
}

class _HelpThreadScreenState extends ConsumerState<HelpThreadScreen> {
  /// A part landing in view opens its space over this, then arrives.
  static const _open = IqDurations.mark;

  final _reply = TextEditingController();
  late final bool _sent = widget.entry == HelpThreadEntry.sent;
  int? _shownMessages;
  bool? _typingShown;
  bool _typingArrives = false;

  /// Support's reply that took the typing bubble's place, and whether the
  /// bubble still holds it while its space opens.
  int? _heldReply;
  bool _holding = false;
  bool _resolving = false;
  bool _replying = false;

  /// The reply's Idempotency-Key, kept until the API answers it for sure.
  String _replyKey = LocalRows.newId();
  Timer? _hold;
  Timer? _leave;

  late final HelpTicketsNotifier _tickets = ref.read(
    helpTicketsProvider.notifier,
  );
  Timer? _polling;

  @override
  void initState() {
    super.initState();
    _tickets
      ..follow(widget.id)
      ..opened(widget.id);
    if (ref.read(supportLiveProvider)) {
      _polling = Timer.periodic(
        LiveHelpService.pollEvery,
        (_) => _tickets.follow(widget.id),
      );
    }
    // Marking read rebuilds the inbox beneath, so it waits for the push to
    // land rather than stutter it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      whenArrived(context, () {
        if (mounted) _tickets.markRead(widget.id).catchError((Object _) {});
      });
    });
  }

  @override
  void dispose() {
    _tickets.closed(widget.id);
    _polling?.cancel();
    _hold?.cancel();
    _leave?.cancel();
    _reply.dispose();
    super.dispose();
  }

  String _at(DateTime at) => supportTime(at, ref.read(clockProvider)());

  /// Notes what lands while the thread is open, so it can open its space
  /// and arrive; what was there when it opened shows still.
  void _note(HelpTicket ticket) {
    final first = _shownMessages == null;
    _shownMessages ??= _sent ? 0 : ticket.messages.length;
    final moving = !MediaQuery.disableAnimationsOf(context);

    final typing = ticket.supportTyping;
    if (!first && typing && _typingShown != true) _typingArrives = true;
    final replied =
        ticket.messages.isNotEmpty &&
        ticket.messages.last.author == HelpAuthor.support;
    if (moving && _typingShown == true && !typing && replied) {
      _heldReply = ticket.messages.length - 1;
      _holding = true;
      _hold?.cancel();
      _hold = Timer(_open, () {
        if (mounted) setState(() => _holding = false);
      });
    }
    _typingShown = typing;
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      await ref.read(helpTicketsProvider.notifier).resolve(widget.id);
    } catch (error) {
      if (mounted) setState(() => _resolving = false);
      errorHaptic();
      await _refused(error);
      return;
    }
    if (!mounted) return;
    setState(() => _resolving = false);
    IqHaptics.success.play();
    _leave = Timer(
      motion(context, IqDurations.crossfade + IqDurations.chain),
      () {
        if (mounted) goBack(context);
      },
    );
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _replying) return;
    setState(() => _replying = true);
    try {
      await ref
          .read(helpTicketsProvider.notifier)
          .reply(widget.id, body, idempotencyKey: _replyKey);
      _reply.clear();
      _replyKey = LocalRows.newId();
    } catch (error) {
      // Only a reply the API may have taken keeps its key for the retry.
      if (error is HelpRefused && error.failure != HelpFailure.offline) {
        _replyKey = LocalRows.newId();
      }
      errorHaptic();
      if (mounted) setState(() => _replying = false);
      await _refused(error);
      return;
    }
    if (mounted) setState(() => _replying = false);
  }

  /// What the API refused, said as the app says it elsewhere; a closing
  /// account is offered Restore.
  Future<void> _refused(Object error) async {
    if (!mounted || error is! HelpRefused) return;
    if (error.failure == HelpFailure.closing && Flags.deleteAccount) {
      await showClosingAccount(context, ref);
      return;
    }
    IqToast.show(context, helpFailureText(error.failure));
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(
      helpTicketsProvider.select((tickets) => tickets[widget.id]),
    );
    final failure = ticket == null
        ? ref.watch(helpLoadFailedProvider.select((ids) => ids[widget.id]))
        : null;
    if (ticket != null) _note(ticket);
    final names = ref.watch(helpAuthorNamesProvider);
    final about = ticket?.activationId;
    final business = !names || about == null
        ? null
        : ticket?.business ??
              ref.watch(activationProvider(about))?.business ??
              'the business';
    final shownMessages = _shownMessages ?? 0;
    final thread = ticket == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _thread(ticket, shownMessages, names: names),
          );

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
                  title: _sent && ticket?.activationId != null
                      ? 'Help'
                      : 'Support',
                  onBack: () => goBack(context),
                ),
                Expanded(
                  child: thread == null
                      ? failure == true
                            ? const IqEmptyFill(
                                child: IqEmptyState(
                                  figure: IqFigures.sender,
                                  title: 'This conversation is gone',
                                  body:
                                      'It is no longer in your inbox. Start a '
                                      'new one from Support.',
                                ),
                              )
                            : failure == false
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: IqSpace.s4,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: IqBanner(
                                    kind: IqBannerKind.error,
                                    title:
                                        'Couldn’t load. Check your connection.',
                                    action: 'Try again',
                                    onAction: () => _tickets.follow(widget.id),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink()
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
                              // AnimatedSize cannot run at zero duration, so
                              // reduced motion goes without it.
                              if (MediaQuery.disableAnimationsOf(context))
                                thread
                              else
                                AnimatedSize(
                                  duration: _open,
                                  curve: IqCurves.easeOut,
                                  alignment: Alignment.topCenter,
                                  child: thread,
                                ),
                              const SizedBox(height: IqSpace.s3),
                              IqField(
                                label: 'Reply',
                                value: 'Write to ${business ?? 'support'}',
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
                        label: 'Send reply',
                        showIcon: false,
                        width: double.infinity,
                        disabled: ticket == null,
                        loading: _replying,
                        onTap: () => _send(_reply.text),
                      ),
                      const SizedBox(height: IqSpace.s1),
                      SizedBox(
                        height: 44,
                        child: IqButton(
                          label: 'Mark as resolved',
                          kind: IqButtonKind.ghost,
                          showIcon: false,
                          disabled:
                              ticket == null ||
                              ticket.status == HelpTicketStatus.resolved,
                          loading: _resolving,
                          onTap: _resolve,
                        ),
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

  List<Widget> _thread(HelpTicket ticket, int shown, {required bool names}) {
    final open = motion(context, _open);
    final held = _holding ? _heldReply : null;
    final reply = ticket.lastReply;
    final parts = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IqTicketTag(
              kind: switch (held == null
                  ? ticket.status
                  : HelpTicketStatus.open) {
                HelpTicketStatus.open => IqTicketTagKind.open,
                HelpTicketStatus.replied => IqTicketTagKind.replied,
                HelpTicketStatus.resolved => IqTicketTagKind.resolved,
              },
              label:
                  names &&
                      held == null &&
                      ticket.status == HelpTicketStatus.replied &&
                      reply != null &&
                      reply.fromBusiness
                  ? '${reply.authorName} replied'
                  : null,
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
      if (i == held) continue;
      final arriving = i >= shown;
      final first = _sent && i == 0;
      final delay = first
          ? IqDurations.chain
          : i == _heldReply
          ? Duration.zero
          : open;
      parts.add(
        KeyedSubtree(
          key: ValueKey('message-$i'),
          child: _message(
            message,
            arriving: arriving,
            delay: delay,
            names: names,
          ),
        ),
      );
      for (final attachment in message.attachments) {
        final words =
            'Attached ${[attachment.name, ?attachment.lengthLabel, attachment.sizeLabel].join(' · ')}';
        final text = Text(
          words,
          style: IqText.small.copyWith(
            color: attachment.url == null ? IqColors.fg3 : IqColors.brand,
          ),
        );
        final line = Align(
          alignment: message.author == HelpAuthor.you
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: attachment.url == null
              ? text
              : IqPressable(
                  semanticLabel: words,
                  onTap: () => openHelpAttachment(context, attachment),
                  builder: (context, pressed) =>
                      PressDim(pressed: pressed, child: text),
                ),
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
    if (ticket.supportTyping || held != null) {
      final slot = Stack(
        children: [
          if (held != null)
            Opacity(
              opacity: 0,
              child: _message(
                ticket.messages[held],
                arriving: false,
                delay: Duration.zero,
                names: names,
              ),
            ),
          const TypingBubble(key: ValueKey('dots')),
        ],
      );
      parts.add(
        Appear(
          key: const ValueKey('typing'),
          delay: _typingArrives ? open : Duration.zero,
          child: slot,
        ),
      );
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
    required bool names,
  }) {
    final you = message.author == HelpAuthor.you;
    final business = names && message.fromBusiness;
    IqChatBubble bubble(bool animate) => IqChatBubble(
      from: you ? IqChatBubbleFrom.you : IqChatBubbleFrom.support,
      body: message.body,
      time: _at(message.at),
      name: business ? message.authorName! : iqlySupport,
      showSticker: !business,
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
}
