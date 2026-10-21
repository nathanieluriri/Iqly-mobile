import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/help_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/chat_header.dart';
import '../../ui/chip.dart';
import '../../ui/empty_state.dart';
import '../../ui/illustration.dart';
import '../../ui/search_box.dart';
import '../../ui/skeleton.dart';
import '../../ui/support_sticker.dart';
import '../../ui/thread_row.dart';
import '../discover/business_art.dart';
import '../more/more_widgets.dart';
import 'chat_state.dart';
import 'help_routes.dart';
import 'help_state.dart';

/// "9:13 am" today, "Yesterday", the weekday within the week, then the
/// date ("8 Oct"), as the inbox rows read.
String threadTime(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final back = (today.difference(day).inHours / Duration.hoursPerDay).round();
  if (back <= 0) {
    return DateFormat('h:mm a')
        .format(at)
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');
  }
  if (back == 1) return 'Yesterday';
  if (back < 7) return DateFormat('EEEE').format(at);
  return DateFormat('d MMM').format(at);
}

/// Who a thread is with, by name.
String threadWith(HelpTicket ticket) => ticket.channel == HelpChannel.business
    ? ticket.withName ?? ticket.business ?? 'The business'
    : iqlySupport;

/// The thread's avatar: iQLY's sticker, or the business's logo.
Widget threadAvatar(HelpTicket ticket, {String? logo}) =>
    ticket.channel == HelpChannel.business
    ? ClipOval(child: businessLogo(logo ?? ticket.withLogo, size: 40))
    : const IqSupportSticker();

/// What the last message says on its row: "You: " before the person's own,
/// a file sent alone by its kind and length ("Voice note · 0:42").
String threadPreview(HelpTicket ticket) {
  final last = ticket.messages.lastOrNull;
  if (last == null) return '';
  final file = last.attachment;
  final words = file != null && last.body == attachmentOnlyBody(file.kind)
      ? [last.body, ?file.lengthLabel].join(' · ')
      : last.body;
  return last.author == HelpAuthor.you ? 'You: $words' : words;
}

/// The replies after the person's last message, for the unread badge.
int unreadReplies(HelpTicket ticket) {
  if (!ticket.unread) return 0;
  var count = 0;
  for (final message in ticket.messages.reversed) {
    if (message.author == HelpAuthor.you) break;
    count++;
  }
  return count;
}

/// B21 · Support inbox (1589:118540, empty 1589:118626), with health's
/// `supportChannels`: every thread with iQLY support and with businesses,
/// latest first, searched by who, what about or what was said, and split
/// into Open and Resolved. Start a new conversation writes to iQLY support.
/// It opens at once on the threads the phone kept, reading them again
/// beside the title (Updating, or Couldn't update with Try again).
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  final _search = TextEditingController();
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    final inbox = ref.read(helpInboxProvider.notifier);
    Future.microtask(inbox.refresh);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _about(HelpTicket ticket) {
    if (ticket.channel != HelpChannel.business) return ticket.subject;
    final id = ticket.activationId;
    final title = id == null
        ? null
        : ref.watch(helpActivationTitleProvider(id));
    return 'About: ${title ?? ticket.subject}';
  }

  bool _matches(HelpTicket ticket, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return [
      threadWith(ticket),
      _about(ticket),
      threadPreview(ticket),
    ].any((text) => text.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(helpInboxProvider);
    final tickets = ref.watch(helpInboxTicketsProvider);
    final now = ref.watch(clockProvider)();
    final failed = tickets == null && inbox.failed;
    void retry() => ref.read(helpInboxProvider.notifier).refresh();
    final open = [
      for (final t in tickets ?? const <HelpTicket>[])
        if (t.status != HelpTicketStatus.resolved) t,
    ];
    final resolved = [
      for (final t in tickets ?? const <HelpTicket>[])
        if (t.status == HelpTicketStatus.resolved) t,
    ];
    final query = _search.text.trim();
    final shown = [
      for (final t in _resolved ? resolved : open)
        if (_matches(t, query)) t,
    ];
    return SubPage(
      title: 'Support',
      body: LoadingGate(
        loading: tickets == null && !failed,
        skeleton: const _Skeleton(),
        child: failed
            ? _Failed(onRetry: retry)
            : tickets == null
            ? const SizedBox.shrink()
            : tickets.isEmpty
            ? const IqEmptyFill(
                child: IqEmptyState(
                  figure: IqFigures.sender,
                  title: 'No conversations yet',
                  body: 'Start one and the replies land here.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  IqSpace.s4,
                  IqSpace.s2,
                  IqSpace.s4,
                  IqSpace.s4,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(child: _Title()),
                      IqChatSyncLine(
                        sync: switch (inbox.sync) {
                          HelpSync.idle => IqChatSync.none,
                          HelpSync.updating => IqChatSync.updating,
                          HelpSync.failed => IqChatSync.failed,
                        },
                        onRetry: retry,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: IqSpace.s3),
                  IqSearchBox(
                    placeholder: 'Search conversations',
                    value: '',
                    controller: _search,
                  ),
                  const SizedBox(height: IqSpace.s3),
                  Wrap(
                    spacing: IqSpace.s2,
                    runSpacing: IqSpace.s2,
                    children: [
                      IqChip(
                        label: 'Open · ${open.length}',
                        state: _resolved
                            ? IqChipState.standard
                            : IqChipState.selected,
                        onChanged: (_) => setState(() => _resolved = false),
                      ),
                      IqChip(
                        label: 'Resolved · ${resolved.length}',
                        state: _resolved
                            ? IqChipState.selected
                            : IqChipState.standard,
                        onChanged: (_) => setState(() => _resolved = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: IqSpace.s3),
                  if (shown.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(IqRadius.xl2),
                      child: Column(
                        children: [
                          for (final (i, ticket) in shown.indexed)
                            IqThreadRow(
                              withWhom: ticket.channel == HelpChannel.business
                                  ? IqThreadRowWith.business
                                  : IqThreadRowWith.iqly,
                              state: ticket.status == HelpTicketStatus.resolved
                                  ? IqThreadRowState.resolved
                                  : ticket.unread
                                  ? IqThreadRowState.unread
                                  : IqThreadRowState.read,
                              avatar: threadAvatar(ticket),
                              name: threadWith(ticket),
                              time: threadTime(ticket.updatedAt, now),
                              about: _about(ticket),
                              preview: threadPreview(ticket),
                              count: unreadReplies(ticket),
                              showDivider: i < shown.length - 1,
                              onTap: () =>
                                  context.open(helpThreadPath(ticket.id)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        IqButton(
          label: 'Start a new conversation',
          showIcon: false,
          width: double.infinity,
          onTap: () => context.open(Routes.newConversation),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Text(
    'Your conversations',
    style: IqText.title.copyWith(color: IqColors.fg),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s2, IqSpace.s4, 0),
      children: [
        const _Title(),
        for (var i = 0; i < 3; i++) ...[
          const SizedBox(height: IqSpace.s3),
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      children: [
        IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: onRetry,
          margin: const EdgeInsets.only(top: IqSpace.s2),
        ),
      ],
    );
  }
}
