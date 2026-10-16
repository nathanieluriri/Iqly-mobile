import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/transitions.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';

/// These frames lay the sheet on fg at 50%, not the brand scrim.
final _scrim = IqColors.fg.withValues(alpha: IqOpacity.sheetScrim);

/// An Exp/ConfirmSheet with the Primary button these frames use, rising 300
/// and dropping 200. True for the button, false for the ghost link, null
/// when the scrim or a drag closes it.
Future<bool?> showDraftSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showIqSheet<bool>(
    context,
    (context) => Material(
      type: MaterialType.transparency,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: IqConfirmSheet(
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          confirmKind: IqButtonKind.primary,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      ),
    ),
    scrim: _scrim,
  );
}

/// 499:27019.
Future<bool?> showDiscardOneSheet(BuildContext context) => showDraftSheet(
  context,
  title: 'Discard this draft?',
  body: 'It only lives on this phone. This cannot be undone.',
  confirmLabel: 'Discard',
  cancelLabel: 'Keep draft',
);

/// 499:27256.
Future<bool?> showDiscardManySheet(BuildContext context, int count) =>
    showDraftSheet(
      context,
      title: 'Discard $count drafts?',
      body: 'They only live on this phone. This cannot be undone.',
      confirmLabel: 'Discard $count drafts',
      cancelLabel: 'Keep them',
    );
