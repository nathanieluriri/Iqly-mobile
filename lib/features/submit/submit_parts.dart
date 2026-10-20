import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/models.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/sample_logo.dart';

/// The sample set's mark for a brief's business; an anonymous brief gets
/// the private one.
IqSampleLogoBrand sampleBrandOf(Brief? brief) {
  final name = brief?.businessName;
  if (name == null) return IqSampleLogoBrand.private;
  for (final brand in IqSampleLogoBrand.values) {
    if (name == brand.label || name.startsWith('${brand.label} ')) {
      return brand;
    }
  }
  return IqSampleLogoBrand.private;
}

/// A pool the way the cards write it: "₦150k", "₦500" (no decimals).
String poolShort(int kobo) {
  final naira = kobo ~/ 100;
  if (naira < 1000) return '₦$naira';
  if (naira < 1000000) return '₦${_trim(naira / 1000)}k';
  return '₦${_trim(naira / 1000000)}m';
}

String _trim(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String _length(Duration length) {
  final seconds = length.inSeconds % 60;
  return '${length.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}

/// "Up to 5 files · 10 MB each", then "3 files · 4.1 MB" (481:21544).
String attachmentsDescription(List<Attachment> files) {
  if (files.isEmpty) {
    return 'Up to ${SubmitLimits.files} files · '
        '${SubmitLimits.fileBytes ~/ (1024 * 1024)} MB each';
  }
  final bytes = files.fold(0, (sum, a) => sum + a.file.bytes);
  final count = files.length == 1 ? '1 file' : '${files.length} files';
  return '$count · ${_mb(bytes)}';
}

String attachmentStatus(Attachment attachment) {
  final length = attachment.file.length;
  return switch (attachment.status) {
    AttachmentStatus.uploading =>
      'Uploading · ${(attachment.progress * 100).round()}%',
    AttachmentStatus.failed => 'Failed · tap to retry',
    AttachmentStatus.done =>
      'Added · ${length != null ? _length(length) : _mb(attachment.file.bytes)}',
  };
}

/// The attachments group (481:21544): the Attachments row that opens the
/// phone's picker, then one row per file. A failed row retries on tap.
class AttachmentsGroup extends StatelessWidget {
  const AttachmentsGroup({
    super.key,
    required this.files,
    required this.onAdd,
    required this.onRetry,
  });

  final List<Attachment> files;
  final VoidCallback onAdd;
  final ValueChanged<AttachmentFile> onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IqColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IqListRow(
            label: 'Attachments',
            description: attachmentsDescription(files),
            icon: IqIcons.plus,
            divider: files.isNotEmpty,
            onTap: onAdd,
          ),
          for (final (i, attachment) in files.indexed)
            IqListRow(
              key: ObjectKey(attachment.file),
              label: attachment.file.name,
              description: attachmentStatus(attachment),
              icon: IqIcons.document,
              divider: i < files.length - 1,
              onTap: attachment.status == AttachmentStatus.failed
                  ? () => onRetry(attachment.file)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// [AttachmentsGroup] with iqly.net's words for a file it turns away.
class AttachmentsPanel extends StatelessWidget {
  const AttachmentsPanel({
    super.key,
    required this.files,
    required this.error,
    required this.onAdd,
    required this.onRetry,
  });

  final List<Attachment> files;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<AttachmentFile> onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttachmentsGroup(files: files, onAdd: onAdd, onRetry: onRetry),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s1p5),
            child: Reveal(
              key: ValueKey(error),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: IqText.small.copyWith(color: IqColors.errStrong),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
