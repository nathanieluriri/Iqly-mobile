import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/local/local_rows.dart';
import '../../router.dart';
import '../../core/responsive.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/empty_state.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../../ui/skeleton.dart';
import '../more/more_widgets.dart';
import '../settings/restore_account_screen.dart';
import 'help_routes.dart';
import 'help_state.dart';

/// "Sat, 3:06 pm" within the week, then the date: "12 Oct, 3:06 pm", so a
/// weekday never stands for two days.
String supportTime(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final old =
      (today.difference(day).inHours / Duration.hoursPerDay).round() > 6;
  return DateFormat(old ? 'd MMM, h:mm a' : 'EEE, h:mm a')
      .format(at)
      .replaceAll('AM', 'am')
      .replaceAll('PM', 'pm');
}

/// What an inbox row says under the subject. With [names] a reply from a
/// business says so by name: "Kudi Box replied".
String conversationLine(HelpTicket ticket, DateTime now, {bool names = false}) {
  final reply = ticket.lastReply;
  final status = switch (ticket.status) {
    HelpTicketStatus.replied when !ticket.unread => 'Replied',
    HelpTicketStatus.replied
        when names && reply != null && reply.fromBusiness =>
      '${reply.authorName} replied',
    HelpTicketStatus.replied => 'Support replied',
    HelpTicketStatus.open => 'Sent',
    HelpTicketStatus.resolved => 'Resolved',
  };
  return '$status · ${supportTime(ticket.updatedAt, now)}';
}

/// B21 · Support · conversations (485:39190): the one support inbox
/// (designer answer 21), past conversations newest first, the activation
/// thread among them; Start a new conversation opens 485:39308.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(conversationsProvider);
    final tickets = loaded.value;
    final now = ref.watch(clockProvider)();
    final names = ref.watch(helpAuthorNamesProvider);
    final failed = tickets == null && loaded.hasError && !loaded.isLoading;
    return SubPage(
      title: 'Support',
      body: LoadingGate(
        loading: tickets == null && !failed,
        skeleton: const _InboxSkeleton(),
        child: failed
            ? _InboxFailed(onRetry: () => ref.invalidate(conversationsProvider))
            : tickets == null
            ? const SizedBox.shrink()
            : tickets.isEmpty
            ? const IqEmptyFill(
                child: IqEmptyState(
                  figure: IqFigures.caller,
                  title: 'No conversations yet',
                  body: 'Start one and the replies land here.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                children: [
                  const _InboxTitle(),
                  for (final ticket in tickets)
                    Padding(
                      padding: const EdgeInsets.only(top: IqSpace.s3),
                      child: IqListRow(
                        label: ticket.subject,
                        description: conversationLine(
                          ticket,
                          now,
                          names: names,
                        ),
                        icon: IqIcons.chat,
                        onTap: () => context.open(helpThreadPath(ticket.id)),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        IqButton(
          label: 'Start a new conversation',
          // Beside a thread's Send reply on a tablet, the one primary is
          // that reply (T14).
          kind: Layout.isTablet(context)
              ? IqButtonKind.secondary
              : IqButtonKind.primary,
          showIcon: false,
          width: double.infinity,
          onTap: () => context.open(Routes.newConversation),
        ),
      ],
    );
  }
}

class _InboxTitle extends StatelessWidget {
  const _InboxTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
      child: Text(
        'Your conversations',
        style: IqText.title.copyWith(color: IqColors.fg),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      children: [
        const _InboxTitle(),
        for (var i = 0; i < 3; i++) ...[
          const SizedBox(height: IqSpace.s3),
          const IqSkeleton(kind: IqSkeletonKind.row),
        ],
      ],
    );
  }
}

class _InboxFailed extends StatelessWidget {
  const _InboxFailed({required this.onRetry});

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
        const SizedBox(height: IqSpace.s6),
        Text(
          'Nothing to show yet',
          textAlign: TextAlign.center,
          style: IqText.cardTitle.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(
          'They will show here once they load.',
          textAlign: TextAlign.center,
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
      ],
    );
  }
}

/// B21 · Chat · new conversation (485:39308): the first message to
/// support. Send opens the thread in this page's place.
class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});

  static const subject = 'Chat with iQLY support';

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final _message = TextEditingController();
  bool _sending = false;
  bool _failed = false;
  HelpFailure? _failure;

  /// The open's Idempotency-Key, kept until the API answers it for sure.
  String _key = LocalRows.newId();

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    final HelpTicket ticket;
    try {
      ticket = await ref
          .read(helpTicketsProvider.notifier)
          .open(
            HelpRequest(
              subject: NewConversationScreen.subject,
              message: body,
              idempotencyKey: _key,
            ),
          );
    } catch (error) {
      if (!mounted) return;
      final failure = error is HelpRefused ? error.failure : null;
      setState(() {
        _sending = false;
        _failed = true;
        _failure = failure;
        if (failure != null && failure != HelpFailure.offline) {
          _key = LocalRows.newId();
        }
      });
      await errorHaptic();
      if (failure == HelpFailure.closing && Flags.deleteAccount && mounted) {
        await showClosingAccount(context, ref);
      }
      return;
    }
    if (!mounted) return;
    context.pushReplacement(
      helpThreadPath(ticket.id),
      extra: HelpThreadEntry.sent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Support',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: helpFailureText(_failure),
            showAction: false,
            visible: _failed,
            margin: const EdgeInsets.only(top: IqSpace.s2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
            child: Text(
              'New conversation',
              style: IqText.title.copyWith(color: IqColors.fg),
            ),
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            DemoHelp.replyLine,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          IqField(
            label: 'Reply',
            value: 'Write to support',
            controller: _message,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
      actions: [
        IqButton(
          label: 'Send',
          showIcon: false,
          width: double.infinity,
          disabled: _message.text.trim().isEmpty,
          loading: _sending,
          onTap: _send,
        ),
      ],
    );
  }
}
