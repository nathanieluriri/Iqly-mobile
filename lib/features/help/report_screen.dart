import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../data/help_data.dart';
import '../../data/help_service.dart';
import '../../data/local/local_rows.dart';
import '../../data/support_files.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/chip.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/list_row.dart';
import '../more/more_widgets.dart';
import '../settings/restore_account_screen.dart';
import 'help_state.dart';

/// B21 · Report an issue (431:19647): what it is about, what happened and
/// an optional screenshot from the phone's own picker; Send report opens
/// Report sent (431:19726) in its place with the ticket number.
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  static const topics = ['Payments', 'A brief', 'The app', 'Something else'];

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _details = TextEditingController();
  String _topic = ReportIssueScreen.topics.first;
  HelpAttachment? _screenshot;
  bool _sending = false;
  bool _failed = false;
  HelpFailure? _failure;
  HelpAttachmentKind? _refused;

  /// The report's Idempotency-Key, kept until the API answers it for sure;
  /// the screenshot goes up once whatever the retries.
  String _key = LocalRows.newId();

  @override
  void initState() {
    super.initState();
    _details.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ref.read(supportFilesProvider).pickScreenshot();
    if (picked != null && mounted) setState(() => _screenshot = picked);
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    final String ticket;
    try {
      ticket = await ref
          .read(helpServiceProvider)
          .report(
            topic: _topic,
            details: _details.text.trim(),
            screenshot: _screenshot,
            idempotencyKey: _key,
          );
    } on Exception catch (error) {
      if (!mounted) return;
      final failure = error is HelpRefused ? error.failure : null;
      final upload =
          error is HelpRefused &&
          (error.refusesFile ||
              error.code == 'SUPPORT_UPLOAD_NOT_FOUND' ||
              error.code == 'SUPPORT_UPLOAD_IN_USE');
      setState(() {
        _sending = false;
        _failed = true;
        _failure = failure;
        _refused = error is HelpRefused && error.refusesFile
            ? HelpAttachmentKind.image
            : null;
        if (upload) _screenshot = null;
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
    context.pushReplacement(Routes.reportSent, extra: ticket);
  }

  @override
  Widget build(BuildContext context) {
    final screenshot = _screenshot;
    return SubPage(
      title: 'Report an issue',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          IqBanner(
            kind: IqBannerKind.error,
            title: switch ((_failure, _refused)) {
              (final failure?, final kind?) => () {
                final words = helpRefusalWords(failure, kind);
                return '${words.title}. ${words.hint}';
              }(),
              (final failure, _) => helpFailureText(
                failure,
                offline: 'Not sent. Check your connection.',
              ),
            },
            showAction: false,
            visible: _failed,
            margin: const EdgeInsets.only(bottom: IqSpace.s3),
          ),
          Text(
            'What is it about?',
            style: IqText.body.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Wrap(
            spacing: IqSpace.s2,
            runSpacing: IqSpace.s2,
            children: [
              for (final topic in ReportIssueScreen.topics)
                IqChip(
                  label: topic,
                  state: topic == _topic
                      ? IqChipState.selected
                      : IqChipState.standard,
                  onChanged: (_) => setState(() => _topic = topic),
                ),
            ],
          ),
          const SizedBox(height: IqSpace.s2),
          IqField(
            label: 'Tell us what happened',
            value: '',
            controller: _details,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: IqSpace.s2),
          IqListRow(
            label: screenshot?.name ?? 'Add a screenshot',
            description: screenshot == null
                ? 'Optional · PNG or JPG'
                : 'Attached · tap to change',
            icon: IqIcons.upload,
            divider: false,
            onTap: _pick,
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'We reply here and by email. ${DemoHelp.replyLine}',
            style: IqText.small.copyWith(color: IqColors.fg3),
          ),
        ],
      ),
      actions: [
        IqButton(
          label: 'Send report',
          showIcon: false,
          width: double.infinity,
          disabled: _details.text.trim().isEmpty,
          loading: _sending,
          onTap: _send,
        ),
      ],
    );
  }
}

/// B21 · Report sent (431:19726): the ticket number and when support
/// replies; Back to Help returns to the Help centre.
class ReportSentScreen extends StatelessWidget {
  const ReportSentScreen({super.key, required this.ticket});

  final String ticket;

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Report an issue',
      hasFields: false,
      body: Align(
        alignment: Alignment.topCenter,
        child: FigureState(
          bodyInset: 45,
          figure: const Padding(
            padding: EdgeInsets.only(top: IqSpace.s10),
            child: IqFigure(IqFigures.sender, width: 180),
          ),
          title: 'Report sent',
          body:
              'Ticket $ticket. We reply here and by email. '
              '${DemoHelp.replyLine}',
        ),
      ),
      actions: [
        IqButton(
          label: 'Back to Help',
          kind: IqButtonKind.ghost,
          showIcon: false,
          width: double.infinity,
          onTap: () => goBack(context),
        ),
      ],
    );
  }
}
