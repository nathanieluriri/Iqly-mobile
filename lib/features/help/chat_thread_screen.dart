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
import '../../ui/confirm_sheet.dart';
import '../../ui/empty_state.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../../ui/pressable.dart';
import '../../ui/recording_player.dart';
import '../../ui/skeleton.dart';
import '../../ui/toast.dart';
import '../activations/activation_format.dart' show activationLogoArt;
import '../activations/activations_routes.dart' show activationPath;
import '../activations/activations_state.dart' show activationProvider;
import '../more/more_widgets.dart' show RowGroup, goBack;
import '../settings/restore_account_screen.dart';
import 'chat_files.dart';
import 'chat_inbox_screen.dart';
import 'chat_state.dart';
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

/// What the mic says until voice notes ship in a release.
const voiceNotesComing = 'Voice notes are coming in the next update';

/// The thread's scroll view, the day pinned over it while it scrolls, and
/// the skeleton before its first answer.
const chatThreadKey = ValueKey('chat thread');
const chatPinnedDayKey = ValueKey('pinned day');
const chatSkeletonKey = ValueKey('thread skeleton');

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
///
/// As WhatsApp does (owner, 21 Oct): a short thread starts at the top under
/// its day, a long one opens at the newest message with the day of what is
/// on screen pinned at the top while it scrolls, and what is read stays in
/// place when new messages land. The thread opens at once as the phone
/// kept it while it reads again (Updating under the name); with nothing
/// kept, skeleton bubbles hold the canvas. + offers the kinds of file the
/// API takes before any picker opens, the file waits over the composer as
/// a preview, and a message shows at once, its picture from the phone,
/// while the file goes up.
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
  final _list = GlobalKey<_ThreadListState>();
  late final HelpTicketsNotifier _tickets = ref.read(
    helpTicketsProvider.notifier,
  );
  late final HelpUploadsNotifier _uploads = ref.read(
    helpUploadsProvider.notifier,
  );
  String _key = LocalRows.newId();

  /// The upload of the file waiting to go with the next message.
  String? _staged;
  bool _sending = false;
  bool _resolving = false;
  Timer? _polling;

  /// The replies unread when the thread opened, counted once, and again
  /// once if the API's answer has more than the phone's copy had.
  int? _unreadAtOpen;
  bool _freshCounted = false;

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    _uploads;
    final id = widget.id;
    if (widget.about != null) {
      final inbox = ref.read(helpInboxProvider.notifier);
      Future.microtask(() => inbox.refresh(quiet: true));
    }
    if (id == null) return;
    _tickets
      ..follow(id)
      ..opened(id);
    if (ref.read(supportLiveProvider)) {
      _polling = Timer.periodic(
        LiveHelpService.pollEvery,
        (_) => _tickets.follow(id, quiet: true),
      );
    }
  }

  @override
  void dispose() {
    final id = widget.id;
    if (id != null) _tickets.closed(id);
    _polling?.cancel();
    final staged = _staged;
    if (staged != null) {
      final uploads = _uploads;
      Future.microtask(() => uploads.cancel(staged));
    }
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

  Future<void> _attach(String business) async {
    final source = await chooseChatAttachment(
      context,
      documents: ref.read(supportDocumentsProvider),
    );
    if (source == null || !mounted) return;
    final key = await _uploads.pick(source, about: business);
    if (key == null) return;
    if (!mounted) {
      _uploads.cancel(key);
      return;
    }
    final previous = _staged;
    if (previous != null) _uploads.cancel(previous);
    setState(() => _staged = key);
  }

  void _unstage() {
    final staged = _staged;
    if (staged == null) return;
    _uploads.cancel(staged);
    setState(() => _staged = null);
  }

  Future<void> _send(HelpTicket? ticket, Activation? activation) async {
    final typed = _reply.text.trim();
    final stagedKey = _staged;
    final staged = stagedKey == null
        ? null
        : ref.read(helpUploadsProvider)[stagedKey];
    if (_sending || (staged != null && staged.failed)) return;
    if (widget.id != null && ticket == null) return;
    if (typed.isEmpty && staged == null) return;
    final body = typed.isEmpty ? attachmentOnlyBody(staged!.file.kind) : typed;
    final id = widget.id;
    if (ticket != null && id != null) {
      ref
          .read(helpOutgoingProvider.notifier)
          .send(
            id,
            body: body,
            key: _key,
            file: staged?.file,
            upload: stagedKey,
          );
      _reply.clear();
      _key = LocalRows.newId();
      setState(() => _staged = null);
      _list.currentState?.toEnd();
      return;
    }
    setState(() => _sending = true);
    try {
      final file = stagedKey == null
          ? null
          : await _uploads.uploaded(stagedKey);
      final opened = await _tickets.open(
        HelpRequest(
          subject: helpSubject(activation),
          message: body,
          attachment: file,
          activation: activation,
          idempotencyKey: _key,
        ),
      );
      if (stagedKey != null) _uploads.sent(stagedKey);
      _staged = null;
      if (!mounted) return;
      context.pushReplacement(helpThreadPath(opened.id));
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
        .watch(helpInboxTicketsProvider)
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

  void _countUnread(String id, HelpTicket ticket, HelpSync sync) {
    final first = _unreadAtOpen == null;
    if (first) {
      _unreadAtOpen = unreadReplies(ticket);
      // Read once it shows, so the count it opened with is the one drawn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        whenArrived(context, () {
          if (mounted) _tickets.markRead(id).catchError((Object _) {});
        });
      });
    }
    if (sync == HelpSync.updating || _freshCounted) return;
    _freshCounted = true;
    final fresh = unreadReplies(ticket);
    if (!first && fresh > (_unreadAtOpen ?? 0)) _unreadAtOpen = fresh;
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
    final sync = id == null
        ? HelpSync.idle
        : ref.watch(helpSyncProvider.select((s) => s[id] ?? HelpSync.idle));
    final row = id != null && ticket == null
        ? ref
              .watch(helpInboxTicketsProvider)
              ?.where((t) => t.id == id)
              .firstOrNull
        : null;
    final known = ticket ?? row;
    final aboutId = known?.activationId ?? widget.about;
    final activation = aboutId == null
        ? null
        : ref.watch(activationProvider(aboutId));
    final business =
        known?.channel == HelpChannel.business || widget.about != null;
    final name = known != null && business
        ? threadWith(known)
        : business
        ? activation?.business ?? 'The business'
        : iqlySupport;
    if (id != null && ticket != null) _countUnread(id, ticket, sync);
    final now = ref.watch(clockProvider)();
    final outgoing = id == null
        ? const <HelpOutgoing>[]
        : ref.watch(
            helpOutgoingProvider.select((o) => o[id] ?? const <HelpOutgoing>[]),
          );
    final stagedKey = _staged;
    final staged = stagedKey == null
        ? null
        : ref.watch(helpUploadsProvider.select((u) => u[stagedKey]));
    final resolved = ticket?.status == HelpTicketStatus.resolved;
    final typed = _reply.text.trim().isNotEmpty || staged != null;
    final avatar = business
        ? ClipOval(
            child: activation != null && known?.withLogo == null
                ? activationLogoArt(activation, size: 40)
                : threadAvatar(
                    known ??
                        const HelpTicket(
                          id: '',
                          subject: '',
                          status: HelpTicketStatus.open,
                          messages: [],
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
    final title = activation?.title ?? known?.subject;
    final topic = known?.topic;
    final loading = id != null && ticket == null && failure == null;
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
                  about: title == null || title.isEmpty
                      ? null
                      : 'About: $title',
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
                  sync: ticket == null
                      ? IqChatSync.none
                      : switch (sync) {
                          HelpSync.idle => IqChatSync.none,
                          HelpSync.updating => IqChatSync.updating,
                          HelpSync.failed => IqChatSync.failed,
                        },
                  onRetry: id == null ? null : () => _tickets.follow(id),
                ),
                Expanded(
                  child: IqChatCanvas(
                    child: ticket == null && failure != null
                        ? _LoadFailed(
                            gone: failure,
                            onRetry: () => _tickets.follow(id!),
                          )
                        : LoadingGate(
                            loading: loading,
                            skeleton: const _ThreadSkeleton(),
                            child: _ThreadList(
                              key: _list,
                              entries: _entries(
                                ticket,
                                outgoing,
                                now,
                                business: business,
                                name: name,
                              ),
                            ),
                          ),
                  ),
                ),
                if (resolved) const IqChatResolvedBar(),
                if (staged != null)
                  _Staged(
                    upload: staged,
                    onRemove: _unstage,
                    onRetry: () => _uploads.retry(stagedKey!),
                  ),
                IqToastFloor(
                  child: IqChatComposer(
                    state: typed
                        ? IqChatComposerState.typed
                        : IqChatComposerState.empty,
                    placeholder: 'Write to ${business ? name : 'support'}',
                    controller: _reply,
                    sending: _sending || (id != null && ticket == null),
                    onAttach: () => _attach(name),
                    onVoiceNote: () => IqToast.show(context, voiceNotesComing),
                    onSend: () => _send(ticket, activation),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_Entry> _entries(
    HelpTicket? ticket,
    List<HelpOutgoing> outgoing,
    DateTime now, {
    required bool business,
    required String name,
  }) {
    final entries = <_Entry>[];
    String? lastDay;
    void pill(
      String key,
      IqChatPillKind kind,
      String label, {
      double top = 10,
      bool day = false,
    }) => entries.add(
      _Entry(
        ValueKey(key),
        Padding(
          padding: EdgeInsets.fromLTRB(IqSpace.s2, top, IqSpace.s2, 0),
          child: Center(
            child: IqChatPill(kind: kind, label: label),
          ),
        ),
        day: lastDay,
        isDay: day,
      ),
    );
    void dayOf(DateTime at) {
      final day = chatDay(at, now);
      if (day == lastDay) return;
      lastDay = day;
      pill(
        'day $day',
        IqChatPillKind.date,
        day,
        top: entries.isEmpty ? IqSpace.s1 : IqSpace.s2,
        day: true,
      );
    }

    if (business) {
      entries.add(
        _Entry(
          const ValueKey('pinned'),
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
        ),
      );
    }
    final messages = ticket?.messages ?? const <HelpMessage>[];
    final unread = _unreadAtOpen ?? 0;
    final firstUnread = unread > 0 ? messages.length - unread : -1;
    var steppedIn = false;
    HelpAuthor? lastAuthor;
    for (final (i, message) in messages.indexed) {
      final before = lastDay;
      dayOf(message.at);
      var broke = before != lastDay;
      if (i == firstUnread) {
        pill(
          'unread',
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
        pill('stepped in', IqChatPillKind.system, 'iQLY support stepped in');
        broke = true;
      }
      if (iqly) steppedIn = true;
      final tail = broke || message.author != lastAuthor;
      lastAuthor = message.author;
      entries.add(
        _Entry(
          ValueKey('message $i'),
          _bubble(ticket!, message, tail: tail, business: business, iqly: iqly),
          day: lastDay,
          isMessage: true,
        ),
      );
    }
    if (ticket != null && ticket.supportTyping) {
      entries.add(
        _Entry(
          const ValueKey('typing'),
          Padding(
            padding: const EdgeInsets.fromLTRB(IqSpace.s2, 10, IqSpace.s2, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TypingBubble(name: name),
            ),
          ),
          day: lastDay,
        ),
      );
    }
    if (ticket != null && ticket.status == HelpTicketStatus.resolved) {
      final by = switch (ticket.resolvedBy) {
        HelpSide.you => 'You',
        HelpSide.iqly => iqlySupport,
        HelpSide.business => name,
        null => null,
      };
      if (by != null) {
        pill('resolved', IqChatPillKind.system, '$by marked this as resolved');
      }
    }
    for (final out in outgoing) {
      final before = lastDay;
      dayOf(out.at);
      final tail = before != lastDay || lastAuthor != HelpAuthor.you;
      lastAuthor = HelpAuthor.you;
      entries.add(
        _Entry(
          ValueKey('outgoing ${out.id}'),
          _outgoing(widget.id!, out, tail: tail),
          day: lastDay,
          isMessage: true,
        ),
      );
    }
    return entries;
  }

  Widget _bubble(
    HelpTicket ticket,
    HelpMessage message, {
    required bool tail,
    required bool business,
    required bool iqly,
  }) {
    final you = message.author == HelpAuthor.you;
    final read = ticket.readAt;
    return _place(
      you: you,
      tail: tail,
      bubble: _proposal(
        you: you,
        tail: tail,
        body: message.body,
        files: message.attachments,
        time: _clock(message.at),
        sender: !you && business && tail
            ? (iqly ? iqlySupport : message.authorName ?? ticket.withName)
            : null,
        iqly: iqly,
        ticks: you
            ? read != null && !read.isBefore(message.at)
                  ? IqChatTicksState.read
                  : IqChatTicksState.saved
            : null,
      ),
    );
  }

  Widget _outgoing(String ticketId, HelpOutgoing out, {required bool tail}) {
    final upload = out.upload;
    final going = upload == null
        ? null
        : ref.watch(helpUploadsProvider.select((u) => u[upload]?.progress));
    final bubble = _proposal(
      you: true,
      tail: tail,
      body: out.body,
      files: [?out.file],
      time: _clock(out.at),
      ticks: out.failed ? null : IqChatTicksState.sending,
      uploading: out.failed || upload == null ? null : going ?? 0,
    );
    final notifier = ref.read(helpOutgoingProvider.notifier);
    final failure = out.failure;
    final refusesFile =
        failure == HelpFailure.tooLarge ||
        failure == HelpFailure.tooLong ||
        failure == HelpFailure.fileType;
    return _place(
      you: true,
      tail: tail,
      bubble: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bubble,
          if (out.failed)
            _NotSent(
              text: refusesFile
                  ? helpRefusalWords(failure!, out.file?.kind).title ??
                        'That file can’t be sent'
                  : helpFailureText(failure),
              action: refusesFile ? 'Remove' : 'Try again',
              onAction: refusesFile
                  ? () => notifier.remove(ticketId, out.id)
                  : () => notifier.retry(ticketId, out.id),
            ),
        ],
      ),
    );
  }

  Widget _place({
    required bool you,
    required bool tail,
    required Widget bubble,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(IqSpace.s2, tail ? 10 : 2, IqSpace.s2, 0),
    child: Align(
      alignment: you ? Alignment.centerRight : Alignment.centerLeft,
      child: MergeSemantics(child: bubble),
    ),
  );

  Widget _proposal({
    required bool you,
    required bool tail,
    required String body,
    required List<HelpAttachment> files,
    required String time,
    String? sender,
    bool iqly = false,
    IqChatTicksState? ticks,
    double? uploading,
  }) {
    final only =
        files.isNotEmpty && body == attachmentOnlyBody(files.first.kind);
    final media = files.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final file in files)
                _media(
                  file,
                  you: you,
                  wide: !only && body.isNotEmpty,
                  uploading: uploading,
                ),
            ],
          );
    final visual =
        files.isNotEmpty &&
        (files.first.kind == HelpAttachmentKind.image ||
            files.first.kind == HelpAttachmentKind.video);
    return IqChatBubbleProposal(
      from: you ? IqChatBubbleProposalFrom.you : IqChatBubbleProposalFrom.them,
      tail: tail ? IqChatBubbleProposalTail.on : IqChatBubbleProposalTail.off,
      layout: visual && !only
          ? IqChatBubbleProposalLayout.inline
          : IqChatBubbleProposalLayout.stacked,
      body: only ? '' : body,
      time: time,
      sender: sender,
      showSticker: iqly,
      ticks: ticks,
      media: media,
      maxWidth: 312,
    );
  }

  Widget _media(
    HelpAttachment file, {
    required bool you,
    required bool wide,
    double? uploading,
  }) {
    final tone = you ? IqChatMediaTone.ink : IqChatMediaTone.light;
    final open = file.url == null && !isLocalFile(file) && file.preview == null
        ? null
        : () => openHelpAttachment(context, file);
    return switch (file.kind) {
      HelpAttachmentKind.image => ChatPicture(
        file: file,
        tone: tone,
        width: wide ? 302 : 210,
        uploading: uploading,
        onTap: uploading == null ? open : null,
      ),
      HelpAttachmentKind.video => ChatVideo(
        file: file,
        tone: tone,
        width: wide ? 302 : 210,
        uploading: uploading,
        onTap: uploading == null ? open : null,
      ),
      HelpAttachmentKind.audio => IqChatMedia(
        kind: IqChatMediaKind.voice,
        tone: tone,
        duration: file.lengthLabel ?? '',
        onTap: open,
        semanticLabel: file.name,
      ),
      HelpAttachmentKind.file => ChatDocument(
        file: file,
        tone: tone,
        facts: uploading == null
            ? fileFacts(file)
            : '${(uploading * 100).round()}% · ${file.sizeLabel}',
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

/// The kinds of file + offers, before any picker opens (owner, 21 Oct): only
/// what the API takes (contract 12.1), so the person knows what they are
/// sending, [documents] while health says `supportDocuments`. Voice notes
/// are the mic's, never a file here. No frame draws it: the app's own sheet
/// of rows, as Use a photo's is, hugging them over the home indicator as
/// WhatsApp's does.
Future<SupportSource?> chooseChatAttachment(
  BuildContext context, {
  bool documents = false,
}) {
  return showIqSheet<SupportSource>(
    context,
    scrim: IqScrim.picker,
    (context) => Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: IqColors.bg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(IqConfirmSheet.radius),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s2,
          IqSpace.s4,
          IqSpace.s4 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: IqColors.line2,
                  borderRadius: BorderRadius.circular(IqRadius.full),
                ),
              ),
            ),
            const SizedBox(height: IqSpace.s4),
            RowGroup(
              outlined: true,
              children: [
                IqListRow(
                  label: 'Photos and videos',
                  description:
                      'Pictures up to 10 MB, videos up to 60 s and 50 MB',
                  icon: IqIcons.background,
                  onTap: () => Navigator.of(context).pop(SupportSource.photos),
                ),
                IqListRow(
                  label: 'Take a photo',
                  showDescription: false,
                  icon: IqIcons.camera,
                  divider: DeviceSupportFiles.canRecordVideo || documents,
                  onTap: () => Navigator.of(context).pop(SupportSource.camera),
                ),
                if (DeviceSupportFiles.canRecordVideo)
                  IqListRow(
                    label: 'Record a video',
                    description: 'Up to 20 s and 50 MB',
                    icon: IqIcons.video,
                    divider: documents,
                    onTap: () => Navigator.of(context).pop(SupportSource.video),
                  ),
                if (documents)
                  IqListRow(
                    label: 'Document',
                    description:
                        'PDF, Word, Excel, PowerPoint, TXT or CSV up to 10 MB',
                    icon: IqIcons.document,
                    divider: false,
                    onTap: () =>
                        Navigator.of(context).pop(SupportSource.document),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// One line of a thread: [day] is the day it falls on, for the day pinned
/// at the top while the thread scrolls; [isDay] marks a day's own pill and
/// [isMessage] a message, counted when new ones wait below.
class _Entry {
  const _Entry(
    this.key,
    this.child, {
    this.day,
    this.isDay = false,
    this.isMessage = false,
  });

  final Key key;
  final Widget child;
  final String? day;
  final bool isDay;
  final bool isMessage;
}

/// The thread's lines, built only near the screen: a short thread starts
/// at the top, a long one opens at its newest line. While it scrolls, the
/// day of the top line rides pinned at the top, gone a moment after it
/// stops. Scrolled up, new messages wait below what is being read, so
/// nothing moves: the round down arrow counts them and takes the thread to
/// its end, as reaching the end does.
class _ThreadList extends StatefulWidget {
  const _ThreadList({super.key, required this.entries});

  final List<_Entry> entries;

  @override
  State<_ThreadList> createState() => _ThreadListState();
}

class _ThreadListState extends State<_ThreadList> {
  final _scroll = ScrollController();
  final _boxes = <Key, GlobalKey>{};
  late List<_Entry> _shown = widget.entries;
  int _waiting = 0;
  bool _away = false;
  String? _pinned;
  bool _scrolling = false;
  Timer? _hide;

  /// How far up the thread counts as away from its end.
  static const double _awayAt = 160;

  bool get _atEnd => !_scroll.hasClients || _scroll.offset <= IqSpace.s6;

  /// Back to the newest line, as after the person sends.
  void toEnd() {
    _adopt();
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    final duration = motion(context, IqDurations.screen);
    if (duration == Duration.zero) {
      _scroll.jumpTo(0);
      return;
    }
    _scroll.animateTo(0, duration: duration, curve: IqCurves.easeOut);
  }

  void _adopt() {
    if (identical(_shown, widget.entries) && _waiting == 0) return;
    setState(() {
      _shown = widget.entries;
      _waiting = 0;
    });
  }

  @override
  void didUpdateWidget(_ThreadList old) {
    super.didUpdateWidget(old);
    final next = widget.entries;
    final shown = _shown;
    final appended =
        next.length > shown.length &&
        [for (var i = 0; i < shown.length; i++) next[i].key == shown[i].key]
            .every((same) => same);
    if (!_atEnd && appended) {
      _shown = next.sublist(0, shown.length);
      _waiting = next.skip(shown.length).where((e) => e.isMessage).length;
    } else {
      _shown = next;
      _waiting = 0;
    }
    final keys = {for (final entry in next) entry.key};
    _boxes.removeWhere((key, _) => !keys.contains(key));
  }

  @override
  void dispose() {
    _hide?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// The day of the top line on screen, unless that line is its day's
  /// own pill.
  String? _topDay() {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    for (final entry in _shown) {
      final box = _boxes[entry.key]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top + box.size.height <= IqSpace.s2) continue;
      return entry.isDay ? null : entry.day;
    }
    return null;
  }

  bool _onScroll(ScrollNotification note) {
    if (note.depth != 0) return false;
    final away = note.metrics.pixels > _awayAt;
    if (away != _away) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _away = away);
      });
    }
    if (_atEnd && _waiting > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _adopt();
      });
    }
    if (note is ScrollStartNotification || note is ScrollUpdateNotification) {
      _hide?.cancel();
      // A scroll can be told mid-layout, when no box may be measured.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final day = _topDay();
        if (!_scrolling || day != _pinned) {
          setState(() {
            _scrolling = true;
            _pinned = day;
          });
        }
      });
    } else if (note is ScrollEndNotification) {
      _hide?.cancel();
      _hide = Timer(IqDurations.pinnedDay, () {
        if (mounted) setState(() => _scrolling = false);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinned;
    final shown = _shown;
    final index = {for (final (i, e) in shown.indexed) e.key: i};
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ListView.builder(
              key: chatThreadKey,
              controller: _scroll,
              reverse: true,
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: IqSpace.s2),
              itemCount: shown.length,
              findChildIndexCallback: (key) {
                final i = key is ValueKey<Key> ? index[key.value] : null;
                return i == null ? null : shown.length - 1 - i;
              },
              itemBuilder: (context, i) {
                final entry = shown[shown.length - 1 - i];
                return KeyedSubtree(
                  key: ValueKey<Key>(entry.key),
                  child: KeyedSubtree(
                    key: _boxes.putIfAbsent(entry.key, GlobalKey.new),
                    child: entry.child,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: IqSpace.s2,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _scrolling && pinned != null ? 1 : 0,
                duration: motion(context, IqDurations.appear, fade: true),
                curve: IqCurves.easeOut,
                child: Center(
                  child: pinned == null
                      ? const SizedBox.shrink()
                      : IqChatPill(
                          key: chatPinnedDayKey,
                          kind: IqChatPillKind.date,
                          label: pinned,
                        ),
                ),
              ),
            ),
          ),
          if (_away || _waiting > 0)
            Positioned(
              right: IqSpace.s3,
              bottom: IqSpace.s3,
              child: _ToNewest(count: _waiting, onTap: toEnd),
            ),
        ],
      ),
    );
  }
}

/// The round down arrow over a thread scrolled up, with how many new
/// messages wait below.
class _ToNewest extends StatelessWidget {
  const _ToNewest({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IqChatRoundButton(
          icon: IqIcons.down,
          semanticLabel: count > 0
              ? '$count new message${count == 1 ? '' : 's'}'
              : 'Newest messages',
          onTap: onTap,
        ),
        if (count > 0)
          Positioned(
            top: -IqSpace.s1,
            right: -IqSpace.s1,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: IqSpace.s1p5),
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IqColors.accent,
                  borderRadius: BorderRadius.circular(IqRadius.full),
                ),
                child: Text(
                  '$count',
                  style: IqText.smallStrong.copyWith(color: IqColors.primaryFg),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Skeleton bubbles on the canvas while a thread the phone never kept is
/// read: a day, then their lines and the person's, top down.
class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  Widget _bubble(List<double> lines, {bool you = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(IqSpace.s2, 10, IqSpace.s2, 0),
    child: Align(
      alignment: you ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(IqSpace.s3),
        decoration: BoxDecoration(
          color: IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.lg),
          boxShadow: IqShadows.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, width) in lines.indexed) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              IqSkeleton(kind: IqSkeletonKind.line, width: width),
            ],
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: chatSkeletonKey,
      label: 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: IqSpace.s2),
            child: Center(
              child: IqSkeleton(kind: IqSkeletonKind.line, width: 72),
            ),
          ),
          _bubble(const [196, 132]),
          _bubble(const [168], you: true),
          _bubble(const [220, 204, 96]),
          _bubble(const [150, 112], you: true),
        ],
      ),
    );
  }
}

/// The file waiting to go with the next message, over the composer: its
/// picture (or a video's first frame), what it is and how far it is up,
/// why it cannot go, and Remove.
class _Staged extends StatelessWidget {
  const _Staged({
    required this.upload,
    required this.onRemove,
    required this.onRetry,
  });

  final HelpUploadState upload;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  static const double _thumb = 48;

  @override
  Widget build(BuildContext context) {
    final file = upload.file;
    final kind = attachmentOnlyBody(file.kind);
    final failure = upload.failure;
    final going = upload.done == null && !upload.failed;
    final text = upload.failed
        ? upload.refused
              ? helpRefusalWords(failure!, file.kind).title ??
                    (file.kind == HelpAttachmentKind.video
                        ? 'Videos go up to 60 s and 50 MB: MP4, MOV, WebM or '
                              '3GP.'
                        : 'That file can’t be sent')
              : helpFailureText(failure)
        : going
        ? '${file.kind == HelpAttachmentKind.file ? file.name : kind} · '
              '${(upload.progress * 100).round()}%'
        : [
            file.kind == HelpAttachmentKind.file ? file.name : kind,
            ?file.lengthLabel,
            file.sizeLabel,
          ].join(' · ');
    final source = file.source;
    final Widget thumb = switch (file.kind) {
      HelpAttachmentKind.image =>
        localPicture(context, file, width: _thumb, height: _thumb) ??
            const ColoredBox(color: IqColors.secondary),
      HelpAttachmentKind.video => Stack(
        fit: StackFit.expand,
        children: [
          if (source != null)
            IqRecordingPoster(
              source: source,
              placeholder: const ColoredBox(color: IqColors.brandDark),
            )
          else
            const ColoredBox(color: IqColors.brandDark),
          const Center(
            child: IqIcon(IqIcons.play, size: 18, color: IqColors.primaryFg),
          ),
        ],
      ),
      HelpAttachmentKind.audio || HelpAttachmentKind.file => const ColoredBox(
        color: IqColors.secondary,
        child: Center(
          child: IqIcon(IqIcons.document, size: 20, color: IqColors.brand),
        ),
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s3,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(IqRadius.sm),
            child: SizedBox.square(dimension: _thumb, child: thumb),
          ),
          const SizedBox(width: IqSpace.s2p5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.small.copyWith(
                    color: upload.failed ? IqColors.err : IqColors.fg2,
                  ),
                ),
                if (going) ...[
                  const SizedBox(height: IqSpace.s1p5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(IqRadius.full),
                    child: LinearProgressIndicator(
                      value: upload.progress.clamp(0.02, 1),
                      minHeight: 3,
                      color: IqColors.brand,
                      backgroundColor: IqColors.line,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (upload.failed && !upload.refused) ...[
            const SizedBox(width: IqSpace.s2),
            IqChatRoundButton(
              icon: IqIcons.refresh,
              semanticLabel: 'Try again',
              onTap: onRetry,
            ),
          ],
          const SizedBox(width: IqSpace.s2),
          IqChatRoundButton(
            icon: IqIcons.close,
            semanticLabel: 'Remove',
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Under a message that did not go: why, and Try again (or Remove, for a
/// file the API will not take).
class _NotSent extends StatelessWidget {
  const _NotSent({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: IqSpace.s1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IqIcon(IqIcons.error, size: 14, color: IqColors.err),
          const SizedBox(width: IqSpace.s1),
          Flexible(
            child: Text(
              text,
              style: IqText.small.copyWith(color: IqColors.err),
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          IqPressable(
            semanticLabel: action,
            onTap: onAction,
            builder: (context, pressed) => PressDim(
              pressed: pressed,
              child: Text(
                action,
                style: IqText.smallStrong.copyWith(color: IqColors.brand),
              ),
            ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: 'Couldn’t load. Check your connection.',
            action: 'Try again',
            onAction: onRetry,
          ),
        ],
      ),
    );
  }
}
