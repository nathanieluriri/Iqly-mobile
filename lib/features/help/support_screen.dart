import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../more/more_widgets.dart';
import '../settings/restore_account_screen.dart';
import 'help_routes.dart';
import 'help_state.dart';

/// "Sat, 3:06 pm".
String supportTime(DateTime at) =>
    DateFormat('EEE, h:mm a')
        .format(at)
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');

/// What an inbox row says under the subject.
String conversationLine(HelpTicket ticket) {
  final status = switch (ticket.status) {
    HelpTicketStatus.replied => ticket.unread ? 'Support replied' : 'Replied',
    HelpTicketStatus.open => 'Sent',
    HelpTicketStatus.resolved => 'Resolved',
  };
  return '$status · ${supportTime(ticket.updatedAt)}';
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
    return SubPage(
      title: 'Support',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          if (tickets == null && loaded.hasError && !loaded.isLoading)
            IqBanner(
              kind: IqBannerKind.error,
              title: 'Couldn’t load. Check your connection.',
              action: 'Try again',
              onAction: () => ref.invalidate(conversationsProvider),
              margin: const EdgeInsets.only(top: IqSpace.s2),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
            child: Text(
              'Your conversations',
              style: IqText.title.copyWith(color: IqColors.fg),
            ),
          ),
          for (final ticket in tickets ?? const <HelpTicket>[])
            Padding(
              padding: const EdgeInsets.only(top: IqSpace.s3),
              child: IqListRow(
                label: ticket.subject,
                description: conversationLine(ticket),
                icon: IqIcons.chat,
                onTap: () => context.open(helpThreadPath(ticket.id)),
              ),
            ),
        ],
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
            HelpRequest(subject: NewConversationScreen.subject, message: body),
          );
    } catch (error) {
      if (!mounted) return;
      final failure = error is HelpRefused ? error.failure : null;
      setState(() {
        _sending = false;
        _failed = true;
        _failure = failure;
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
