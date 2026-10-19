import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/signed_in_files.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import 'submissions_routes.dart';

/// [file] from the account's folder, downloaded with the session token
/// first ([SignedInFiles]).
Future<File> fetchSubmissionFile(WidgetRef ref, SubmissionFile file) {
  final files = ref.read(signedInFilesProvider);
  if (files == null) {
    return Future.error(const ApiUnreachable(nothingSent: true));
  }
  return files.fetch(
    userId: ref.read(sessionProvider).userId ?? '',
    id: 'submission-${file.id}',
    url: file.url,
    name: file.image ? 'image' : 'attachment.pdf',
  );
}

/// What the person sent with their entry, drawn as the submit flow's
/// attachments group (481:21544): the Attachments row with the count, then
/// a row per file in iqly.net's words. A picture opens in the app; a PDF,
/// which the app cannot show, goes to the phone's save dialog.
class SubmissionFiles extends ConsumerWidget {
  const SubmissionFiles({
    super.key,
    required this.submissionId,
    required this.files,
  });

  final String submissionId;
  final List<SubmissionFile> files;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    SubmissionFile file,
  ) async {
    final File downloaded;
    try {
      downloaded = await fetchSubmissionFile(ref, file);
    } on Exception {
      if (context.mounted) {
        IqToast.show(
          context,
          'Couldn’t load. Check your connection.',
          kind: IqToastKind.error,
        );
      }
      return;
    }
    await ref
        .read(fileSaverProvider)
        .save(downloaded, name: 'attachment.pdf', mime: 'application/pdf');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = files.length == 1 ? '1 file' : '${files.length} files';
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
            description: count,
            icon: IqIcons.document,
            showChevron: false,
          ),
          for (final (i, file) in files.indexed)
            IqListRow(
              key: ValueKey(file.id),
              label: file.label,
              showDescription: false,
              icon: file.image ? IqIcons.background : IqIcons.download,
              divider: i < files.length - 1,
              onTap: file.image
                  ? () => context.open(
                      submissionFilePath(submissionId),
                      extra: file,
                    )
                  : () => _save(context, ref, file),
            ),
        ],
      ),
    );
  }
}

/// A picture sent with an entry, to pinch and zoom, read from the account's
/// folder. No Figma frame draws it: the page keeps the help attachment's
/// layout under the file's name.
class SubmissionFileScreen extends ConsumerStatefulWidget {
  const SubmissionFileScreen({
    super.key,
    required this.submissionId,
    required this.file,
  });

  final String submissionId;
  final SubmissionFile? file;

  @override
  ConsumerState<SubmissionFileScreen> createState() =>
      _SubmissionFileScreenState();
}

class _SubmissionFileScreenState extends ConsumerState<SubmissionFileScreen> {
  File? _downloaded;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final file = widget.file;
    if (file == null) return;
    setState(() => _failed = false);
    try {
      final downloaded = await fetchSubmissionFile(ref, file);
      if (mounted) setState(() => _downloaded = downloaded);
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(submissionPath(widget.submissionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = _downloaded;
    final Widget body;
    if (_failed) {
      body = Align(
        alignment: Alignment.topCenter,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: 'Couldn’t load. Check your connection.',
          action: 'Try again',
          onAction: _load,
        ),
      );
    } else if (downloaded == null) {
      body = const SizedBox.shrink();
    } else {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(IqRadius.xl2),
        child: ColoredBox(
          color: IqColors.panel,
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(child: Image.file(downloaded, fit: BoxFit.contain)),
          ),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: widget.file?.label ?? '',
                  onBack: _back,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      IqSpace.s4,
                      0,
                      IqSpace.s4,
                      IqSpace.s4,
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
