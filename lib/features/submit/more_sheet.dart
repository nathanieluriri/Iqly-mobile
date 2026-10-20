import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/flags.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/device.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../discover/discover_state.dart' show closeRemindersProvider;
import '../discover/discover_widgets.dart' show businessLabel;
import 'submit_header.dart';
import 'submit_parts.dart';
import 'submit_state.dart';
import 'submit_steps.dart' show pickAttachments;

/// B3 · Submit · More (481:21544), from the cover header's More: what sits
/// beside the answer without crowding it. View the brief, the files when
/// the brief takes them, Drafts and Remind me while the brief is open.
Future<void> showSubmitMore(
  BuildContext context, {
  required Brief brief,
  required SubmitForm form,
  required VoidCallback onViewBrief,
  required VoidCallback onDrafts,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showIqSheet<void>(
    Navigator.of(context, rootNavigator: true).context,
    (context) => SubmitMoreSheet(
      brief: brief,
      form: form,
      onViewBrief: () {
        Navigator.of(context).pop();
        onViewBrief();
      },
      onDrafts: () {
        Navigator.of(context).pop();
        onDrafts();
      },
    ),
    scrim: IqScrim.sheet,
  );
}

class SubmitMoreSheet extends ConsumerWidget {
  const SubmitMoreSheet({
    super.key,
    required this.brief,
    required this.form,
    required this.onViewBrief,
    required this.onDrafts,
  });

  final Brief brief;
  final SubmitForm form;
  final VoidCallback onViewBrief;
  final VoidCallback onDrafts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(submitFlowProvider(brief.id));
    final notifier = ref.read(submitFlowProvider(brief.id).notifier);
    final now = ref.watch(clockProvider)();
    final left = timeLeft(brief.deadline, now);
    final canRemind =
        Flags.closeReminders &&
        brief.isLive &&
        left != null &&
        left > Duration.zero;
    final reminded =
        ref.watch(closeRemindersProvider).value?.contains(brief.id) ?? false;
    final media = MediaQuery.of(context);
    final attach = form.acceptsFiles;

    return CenteredContent(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height - media.padding.top,
        ),
        child: Material(
          color: IqColors.card,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(IqConfirmSheet.radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: IqSpace.s2p5),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: IqColors.line2,
                      borderRadius: BorderRadius.circular(IqRadius.full),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  IqSpace.s4,
                  IqSpace.s1 + IqSpace.s2,
                  IqSpace.s4,
                  IqSpace.s2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'More',
                          style: IqText.cardTitle.copyWith(color: IqColors.fg),
                        ),
                      ),
                    ),
                    RoundIconButton(
                      icon: IqIcons.close,
                      label: 'Close',
                      color: IqColors.brand,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s1,
                    IqSpace.s4,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IqListRow(
                        label: 'View the brief',
                        description: 'What ${businessLabel(brief)} asked for',
                        icon: IqIcons.document,
                        divider: false,
                        onTap: onViewBrief,
                      ),
                      if (attach) ...[
                        const SizedBox(height: IqSpace.s1),
                        AttachmentsPanel(
                          files: flow.files,
                          error: flow.fileError,
                          onAdd: () =>
                              pickAttachments(context, ref, brief.id, form),
                          onRetry: notifier.retry,
                        ),
                      ],
                      const SizedBox(height: IqSpace.s1),
                      IqListRow(
                        label: 'Drafts',
                        description: 'Saved on this phone as you type',
                        icon: IqIcons.clock,
                        divider: false,
                        onTap: onDrafts,
                      ),
                      if (canRemind) ...[
                        const SizedBox(height: IqSpace.s1),
                        IqListRow(
                          label: 'Remind me',
                          description: reminded
                              ? 'An hour before close'
                              : 'Before the brief closes',
                          icon: IqIcons.bell,
                          divider: false,
                          onTap: () async {
                            IqHaptics.select.play();
                            await ref
                                .read(closeRemindersProvider.notifier)
                                .setReminder(brief.id, !reminded);
                            if (!reminded) {
                              await ref
                                  .read(deviceServiceProvider)
                                  .requestNotificationPermission();
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: math.max(
                  media.viewPadding.bottom,
                  IqConfirmSheet.homeIndicator,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
