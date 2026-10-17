import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/help_data.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/chat_bubble.dart';
import '../../ui/field.dart';
import '../../ui/ticket_tag.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../../data/help_service.dart';
import '../../data/live/live_help_service.dart' show LiveHelpService;
import '../more/more_widgets.dart';
import '../settings/restore_account_screen.dart';
import 'help_routes.dart';
import 'help_state.dart';
import 'help_widgets.dart';

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
class HelpThreadScreen extends ConsumerStatefulWidget {
  const HelpThreadScreen({super.key, required this.id, this.entry});

  final String id;
  final HelpThreadEntry? entry;

  @override
  ConsumerState<HelpThreadScreen> createState() => _HelpThreadScreenState();
}

class _HelpThreadScreenState extends ConsumerState<HelpThreadScreen> {
  static final _time = DateFormat('EEE, h:mm a');

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

  static String _at(DateTime at) =>
      _time.format(at).replaceAll('AM', 'am').replaceAll('PM', 'pm');

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
      await ref.read(helpTicketsProvider.notifier).reply(widget.id, body);
      _reply.clear();
    } catch (error) {
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
    final failed =
        ticket == null &&
        ref.watch(
          helpLoadFailedProvider.select((ids) => ids.contains(widget.id)),
        );
    if (ticket != null) _note(ticket);
    final shownMessages = _shownMessages ?? 0;
    final thread = ticket == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _thread(ticket, shownMessages),
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
                      ? failed
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

  List<Widget> _thread(HelpTicket ticket, int shown) {
    final open = motion(context, _open);
    final held = _holding ? _heldReply : null;
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
          child: _message(message, arriving: arriving, delay: delay),
        ),
      );
      for (final attachment in message.attachments) {
        final line = Align(
          alignment: message.author == HelpAuthor.you
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            'Attached ${[attachment.name, ?attachment.lengthLabel, attachment.sizeLabel].join(' · ')}',
            style: IqText.small.copyWith(color: IqColors.fg3),
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
}
