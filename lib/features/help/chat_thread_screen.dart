import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/activations_data.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/live/live_help_service.dart' show LiveHelpService;
import '../../data/local/local_rows.dart';
import '../../data/support_files.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/chat_bubble_proposal.dart';
import '../../ui/chat_canvas.dart';
import '../../ui/chat_composer.dart';
import '../../ui/chat_header.dart';
import '../../ui/chat_media.dart';
import '../../ui/chat_pill.dart';
import '../../ui/chat_resolved_bar.dart';
import '../../ui/chat_ticks.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/toast.dart';
import '../activations/activation_format.dart' show activationLogoArt;
import '../activations/activations_routes.dart' show activationPath;
import '../activations/activations_state.dart' show activationProvider;
import '../more/more_widgets.dart' show goBack;
import '../settings/restore_account_screen.dart';
import 'chat_inbox_screen.dart';
import 'help_attachment_screen.dart';
import 'help_routes.dart';
import 'help_state.dart';
import 'help_widgets.dart';

/// "Today", "Yesterday", the weekday within the week, then the full date
/// ("8 Oct 2026"), as the date pills read.
String chatDay(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final back = (today.difference(day).inHours / Duration.hoursPerDay).round();
  if (back <= 0) return 'Today';
  if (back == 1) return 'Yesterday';
  if (back < 7) return DateFormat('EEEE').format(at);
  return DateFormat('d MMM y').format(at);
}

String _clock(DateTime at) =>
    DateFormat('h:mm a')
        .format(at)
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');

/// What a business thread pins at its top (1589:122097).
String businessAnswersHere(String business) =>
    '$business answers here. iQLY support can see this chat and steps in if '
    'there’s no answer in 2 days.';

/// B21 · Thread (1589:118774, 1589:119167, 1589:122097, 1589:122537), with
/// health's `supportChannels`: one thread on the chat canvas. The header
/// says who answers (iQLY with its reply promise, a business with none),
/// Mark as resolved and what it is about; a business thread pins who
/// answers. Day pills, the unread count the thread opened with, "iQLY
/// support stepped in" where staff first wrote on a business thread, then
/// the bubbles with their files and the person's read ticks (`readBy`).
/// A resolved thread says so over the composer, and a message opens it
/// again. Opened from an activation's Ask for help with no thread yet
/// ([about], 1639:125529) it is empty under the pinned note, and the first
/// message opens the thread with the business.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, this.id, this.about})
    : assert(id != null || about != null);

  final String? id;

  /// The activation a new thread asks about.
  final String? about;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _reply = TextEditingController();
  late final HelpTicketsNotifier _tickets = ref.read(
    helpTicketsProvider.notifier,
  );
  String _key = LocalRows.newId();
  bool _sending = false;
  bool _resolving = false;
  Timer? _polling;

  /// The replies unread when the thread opened, counted once.
  int? _unreadAtOpen;

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    final id = widget.id;
    if (id == null) return;
    _tickets
      ..follow(id)
      ..opened(id);
    if (ref.read(supportLiveProvider)) {
      _polling = Timer.periodic(
        LiveHelpService.pollEvery,
        (_) => _tickets.follow(id),
      );
    }
  }

  @override
  void dispose() {
    final id = widget.id;
    if (id != null) _tickets.closed(id);
    _polling?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _refused(Object error) async {
    if (!mounted || error is! HelpRefused) return;
    if (error.failure == HelpFailure.closing && Flags.deleteAccount) {
      await showClosingAccount(context, ref);
      return;
    }
    IqToast.show(context, helpFailureText(error.failure));
  }

  void _attach(SupportSource source, String? business) => ref
      .read(helpDraftProvider.notifier)
      .addRecording(about: business, source: source);

  Future<void> _send(HelpTicket? ticket, Activation? activation) async {
    final draft = ref.read(helpDraftProvider);
    final file = draft.recording;
    final typed = _reply.text.trim();
    if (_sending || draft.upload != null) return;
    if (typed.isEmpty && file == null) return;
    final body = typed.isEmpty ? attachmentOnlyBody(file!.kind) : typed;
    setState(() => _sending = true);
    try {
      if (ticket == null) {
        final opened = await _tickets.open(
          HelpRequest(
            subject: helpSubject(activation),
            message: body,
            attachment: file,
            activation: activation,
            idempotencyKey: _key,
          ),
        );
        if (!mounted) return;
        ref.read(helpDraftProvider.notifier).sent();
        context.pushReplacement(helpThreadPath(opened.id));
        return;
      }
      await _tickets.reply(
        ticket.id,
        body,
        idempotencyKey: _key,
        attachments: [?file],
      );
      _reply.clear();
      _key = LocalRows.newId();
      ref.read(helpDraftProvider.notifier).sent();
    } catch (error) {
      if (error is HelpRefused && error.failure != HelpFailure.offline) {
        _key = LocalRows.newId();
      }
      errorHaptic();
      await _refused(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _redirected = false;

  /// Ask for help on an activation that already has an open thread opens
  /// that thread instead of a new one.
  void _toOpenThread() {
    final about = widget.about;
    final existing = ref
        .watch(conversationsProvider)
        .value
        ?.where(
          (t) =>
              t.activationId == about && t.status != HelpTicketStatus.resolved,
        )
        .firstOrNull;
    if (existing == null || _redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement(helpThreadPath(existing.id));
    });
  }

  Future<void> _resolve(String id) async {
    setState(() => _resolving = true);
    try {
      await _tickets.resolve(id);
      IqHaptics.success.play();
    } catch (error) {
      errorHaptic();
      await _refused(error);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    if (id == null) _toOpenThread();
    final ticket = id == null
        ? null
        : ref.watch(helpTicketsProvider.select((tickets) => tickets[id]));
    final failure = id != null && ticket == null
        ? ref.watch(helpLoadFailedProvider.select((ids) => ids[id]))
        : null;
    final aboutId = ticket?.activationId ?? widget.about;
    final activation = aboutId == null
        ? null
        : ref.watch(activationProvider(aboutId));
    final business =
        ticket?.channel == HelpChannel.business || widget.about != null;
    final name = ticket != null && business
        ? threadWith(ticket)
        : business
        ? activation?.business ?? 'The business'
        : iqlySupport;
    if (ticket != null && _unreadAtOpen == null) {
      _unreadAtOpen = unreadReplies(ticket);
      // Read once it shows, so the count it opened with is the one drawn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        whenArrived(context, () {
          if (mounted) _tickets.markRead(id!).catchError((Object _) {});
        });
      });
    }
    final now = ref.watch(clockProvider)();
    final draft = ref.watch(helpDraftProvider);
    final resolved = ticket?.status == HelpTicketStatus.resolved;
    final typed = _reply.text.trim().isNotEmpty || draft.recording != null;
    final avatar = business
        ? ClipOval(
            child: activation != null && ticket?.withLogo == null
                ? activationLogoArt(activation, size: 40)
                : threadAvatar(
                    ticket ??
                        HelpTicket(
                          id: '',
                          subject: '',
                          status: HelpTicketStatus.open,
                          messages: const [],
                          channel: HelpChannel.business,
                        ),
                  ),
          )
        : threadAvatar(
            const HelpTicket(
              id: '',
              subject: '',
              status: HelpTicketStatus.open,
              messages: [],
            ),
          );
    final topic = ticket?.topic;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: IqColors.bg,
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqChatHeader(
                  withWhom: business
                      ? IqChatHeaderWith.business
                      : IqChatHeaderWith.iqly,
                  avatar: avatar,
                  title: name,
                  subtitle: business ? null : DemoHelp.replyLine,
                  about: 'About: ${activation?.title ?? ticket?.subject ?? ''}',
                  aboutIcon: business
                      ? IqIcons.zap
                      : topic == 'payments'
                      ? IqIcons.wallet
                      : IqIcons.chat,
                  onBack: () => goBack(context),
                  onAbout: activation == null
                      ? null
                      : () => context.open(activationPath(activation.id)),
                  onResolve: ticket == null || resolved
                      ? null
                      : () => _resolve(ticket.id),
                  resolving: _resolving,
                ),
                Expanded(
                  child: IqChatCanvas(
                    child: ticket == null && failure != null
                        ? _LoadFailed(
                            gone: failure,
                            onRetry: () => _tickets.follow(id!),
                          )
                        : ListView(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(
                              IqSpace.s1,
                              IqSpace.s1,
                              IqSpace.s1,
                              IqSpace.s2,
                            ),
                            children: _parts(
                              ticket,
                              now,
                              business: business,
                              name: name,
                            ).reversed.toList(),
                          ),
                  ),
                ),
                if (resolved) const IqChatResolvedBar(),
                if (draft.upload != null ||
                    draft.recording != null ||
                    draft.refused != null)
                  _Pending(draft: draft),
                IqChatComposer(
                  state: typed
                      ? IqChatComposerState.typed
                      : IqChatComposerState.empty,
                  placeholder: 'Write to ${business ? name : 'support'}',
                  controller: _reply,
                  sending: _sending || (id != null && ticket == null),
                  onAttach: () => _attach(SupportSource.photos, name),
                  onVoiceNote: () => _attach(SupportSource.voiceNote, name),
                  onSend: () => _send(ticket, activation),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _parts(
    HelpTicket? ticket,
    DateTime now, {
    required bool business,
    required String name,
  }) {
    final parts = <Widget>[];
    void pill(IqChatPillKind kind, String label, {double top = 10}) =>
        parts.add(
          Padding(
            padding: EdgeInsets.fromLTRB(IqSpace.s2, top, IqSpace.s2, 0),
            child: Center(
              child: IqChatPill(kind: kind, label: label),
            ),
          ),
        );
    if (business) {
      parts.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4 - IqSpace.s1 + 2,
            IqSpace.s1,
            IqSpace.s4 - IqSpace.s1 + 2,
            0,
          ),
          child: IqChatPill(
            kind: IqChatPillKind.pinned,
            label: businessAnswersHere(name),
          ),
        ),
      );
    }
    if (ticket == null) return parts;
    final messages = ticket.messages;
    final unread = _unreadAtOpen ?? 0;
    final firstUnread = unread > 0 ? messages.length - unread : -1;
    String? lastDay;
    var steppedIn = false;
    HelpAuthor? lastAuthor;
    for (final (i, message) in messages.indexed) {
      final day = chatDay(message.at, now);
      var broke = false;
      if (day != lastDay) {
        pill(
          IqChatPillKind.date,
          day,
          top: parts.isEmpty ? IqSpace.s1 : IqSpace.s2,
        );
        lastDay = day;
        broke = true;
      }
      if (i == firstUnread) {
        pill(
          IqChatPillKind.unread,
          '$unread unread message${unread == 1 ? '' : 's'}',
        );
        broke = true;
      }
      final iqly =
          message.author == HelpAuthor.support &&
          (message.side == HelpSide.iqly ||
              (message.side == null && !message.fromBusiness));
      if (business && iqly && !steppedIn) {
        pill(IqChatPillKind.system, 'iQLY support stepped in');
        broke = true;
      }
      if (iqly) steppedIn = true;
      final tail = broke || message.author != lastAuthor;
      lastAuthor = message.author;
      parts.add(
        _bubble(ticket, message, tail: tail, business: business, iqly: iqly),
      );
    }
    if (ticket.supportTyping) {
      parts.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(IqSpace.s2, 10, IqSpace.s2, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TypingBubble(name: name),
          ),
        ),
      );
    }
    if (ticket.status == HelpTicketStatus.resolved) {
      final by = switch (ticket.resolvedBy) {
        HelpSide.you => 'You',
        HelpSide.iqly => iqlySupport,
        HelpSide.business => name,
        null => null,
      };
      if (by != null) {
        pill(IqChatPillKind.system, '$by marked this as resolved');
      }
    }
    return parts;
  }

  Widget _bubble(
    HelpTicket ticket,
    HelpMessage message, {
    required bool tail,
    required bool business,
    required bool iqly,
  }) {
    final you = message.author == HelpAuthor.you;
    final files = message.attachments;
    final only =
        files.isNotEmpty &&
        message.body == attachmentOnlyBody(files.first.kind);
    final read = ticket.readAt;
    final media = files.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final file in files)
                _media(file, you: you, wide: !only && message.body.isNotEmpty),
            ],
          );
    final bubble = IqChatBubbleProposal(
      from: you ? IqChatBubbleProposalFrom.you : IqChatBubbleProposalFrom.them,
      tail: tail ? IqChatBubbleProposalTail.on : IqChatBubbleProposalTail.off,
      layout:
          files.isNotEmpty &&
              files.first.kind == HelpAttachmentKind.image &&
              !only
          ? IqChatBubbleProposalLayout.inline
          : IqChatBubbleProposalLayout.stacked,
      body: only ? '' : message.body,
      time: _clock(message.at),
      sender: !you && business && tail
          ? (iqly ? iqlySupport : message.authorName ?? ticket.withName)
          : null,
      showSticker: iqly,
      ticks: you
          ? read != null && !read.isBefore(message.at)
                ? IqChatTicksState.read
                : IqChatTicksState.saved
          : null,
      media: media,
      maxWidth: 312,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(IqSpace.s2, tail ? 10 : 2, IqSpace.s2, 0),
      child: Align(
        alignment: you ? Alignment.centerRight : Alignment.centerLeft,
        child: MergeSemantics(child: bubble),
      ),
    );
  }

  Widget _media(HelpAttachment file, {required bool you, required bool wide}) {
    final tone = you ? IqChatMediaTone.ink : IqChatMediaTone.light;
    final open = file.url == null
        ? null
        : () => openHelpAttachment(context, file);
    final preview = file.preview;
    return switch (file.kind) {
      HelpAttachmentKind.image => IqChatMedia(
        kind: IqChatMediaKind.image,
        tone: tone,
        width: wide ? 302 : 210,
        image: preview == null ? null : Image.asset(preview, fit: BoxFit.cover),
        onTap: open,
        semanticLabel: file.name,
      ),
      HelpAttachmentKind.audio => IqChatMedia(
        kind: IqChatMediaKind.voice,
        tone: tone,
        duration: file.lengthLabel ?? '',
        onTap: open,
        semanticLabel: file.name,
      ),
      HelpAttachmentKind.video || HelpAttachmentKind.file => IqChatMedia(
        kind: IqChatMediaKind.file,
        tone: tone,
        width: 282,
        name: file.name,
        fileIcon: file.kind == HelpAttachmentKind.video
            ? IqIcons.video
            : IqIcons.document,
        meta: fileFacts(file),
        onTap: open,
      ),
    };
  }
}

/// "PDF · 1 page · 64 KB", or a video's "0:31 · 12 MB".
String fileFacts(HelpAttachment file) {
  final dot = file.name.lastIndexOf('.');
  final pages = file.pages;
  return [
    if (file.kind == HelpAttachmentKind.file && dot >= 0)
      file.name.substring(dot + 1).toUpperCase(),
    if (pages != null) '$pages page${pages == 1 ? '' : 's'}',
    ?file.lengthLabel,
    file.sizeLabel,
  ].join(' · ');
}

/// The file going with the next message, over the composer: its upload,
/// what it is once up (with Remove), or why the API refused it.
class _Pending extends ConsumerWidget {
  const _Pending({required this.draft});

  final HelpDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = draft.upload;
    final file = upload?.file ?? draft.recording;
    final refused = draft.refused;
    final text = refused != null
        ? helpRefusalWords(refused, draft.refusedKind).title ??
              'That file can’t be sent'
        : file == null
        ? ''
        : upload != null
        ? '${file.name} · ${(upload.progress * 100).round()}%'
        : '${file.name} · ${file.sizeLabel}';
    return Container(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s2,
        IqSpace.s3,
        IqSpace.s2,
      ),
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(top: BorderSide(color: IqColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqText.small.copyWith(
                color: refused != null ? IqColors.err : IqColors.fg2,
              ),
            ),
          ),
          if (draft.recording != null)
            IqChatRoundButton(
              icon: IqIcons.close,
              semanticLabel: 'Remove',
              onTap: () =>
                  ref.read(helpDraftProvider.notifier).removeRecording(),
            ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.gone, required this.onRetry});

  final bool gone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (gone) {
      return const IqEmptyFill(
        child: IqEmptyState(
          figure: IqFigures.sender,
          title: 'This conversation is gone',
          body: 'It is no longer in your inbox. Start a new one from Support.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(IqSpace.s4),
      child: Align(
        alignment: Alignment.topCenter,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
        ),
      ),
    );
  }
}
