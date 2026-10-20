import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/transitions.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/signed_in_files.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/toast.dart';
import '../../ui/top_bar.dart';
import '../more/more_widgets.dart' show RowGroup;
import 'submissions_routes.dart';
import 'submissions_state.dart';

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

/// Why a file sent with an entry could not be read: gone from the API
/// (404), or no answer.
String submissionFileError(Object error) =>
    error is ApiRefused && error.status == 404
    ? 'This file is no longer available.'
    : 'Couldn’t load. Check your connection.';

/// The name a PDF sent with an entry is saved under: the brief's title
/// without the characters file names cannot hold, numbered when the entry
/// has more than one PDF; the file's id when there is no title.
String submissionPdfName(
  String? briefTitle,
  SubmissionFile file,
  List<SubmissionFile> files,
) {
  var stem = (briefTitle ?? '')
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (stem.length > 80) stem = stem.substring(0, 80).trim();
  if (stem.isEmpty) stem = file.id;
  final pdfs = [
    for (final f in files)
      if (!f.image) f.id,
  ];
  return pdfs.length > 1
      ? '$stem ${pdfs.indexOf(file.id) + 1}.pdf'
      : '$stem.pdf';
}

/// What the person sent with their entry, drawn as the submit flow's
/// attachments group (481:21544): the Attachments row with the count, then
/// a row per file in iqly.net's words. A picture opens in the app; a PDF,
/// which the app cannot show, goes to the phone's save dialog under the
/// brief's title, and a toast says whether it was saved (nothing when the
/// person cancels), or that the file is no longer there.
class SubmissionFiles extends ConsumerWidget {
  const SubmissionFiles({
    super.key,
    required this.submissionId,
    required this.files,
    this.briefTitle,
  });

  final String submissionId;
  final List<SubmissionFile> files;
  final String? briefTitle;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    SubmissionFile file,
  ) async {
    final File downloaded;
    try {
      downloaded = await fetchSubmissionFile(ref, file);
    } on Exception catch (error) {
      if (context.mounted) {
        IqToast.show(
          context,
          submissionFileError(error),
          kind: IqToastKind.error,
        );
      }
      return;
    }
    final saved = await ref
        .read(fileSaverProvider)
        .save(
          downloaded,
          name: submissionPdfName(briefTitle, file, files),
          mime: 'application/pdf',
        );
    if (!context.mounted) return;
    switch (saved) {
      case FileSave.saved:
        IqToast.show(context, 'PDF saved');
      case FileSave.failed:
        IqToast.show(
          context,
          'PDF not saved. Try again.',
          kind: IqToastKind.error,
        );
      case FileSave.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = files.length == 1 ? '1 file' : '${files.length} files';
    return RowGroup(
      outlined: true,
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
                    submissionFilePath(submissionId, file.id),
                    extra: file,
                  )
                : () => _save(context, ref, file),
          ),
      ],
    );
  }
}

/// A picture sent with an entry, to pinch and zoom, read from the account's
/// folder. No Figma frame draws it: the page keeps the help attachment's
/// layout under the file's name. Opened without the file (a link, or the
/// page restored after the app was closed), it reads the entry by id and
/// finds the file there; an entry without that picture goes back to the
/// submission.
class SubmissionFileScreen extends ConsumerStatefulWidget {
  const SubmissionFileScreen({
    super.key,
    required this.submissionId,
    required this.fileId,
    this.file,
  });

  final String submissionId;
  final String fileId;
  final SubmissionFile? file;

  @override
  ConsumerState<SubmissionFileScreen> createState() =>
      _SubmissionFileScreenState();
}

class _SubmissionFileScreenState extends ConsumerState<SubmissionFileScreen> {
  late SubmissionFile? _file = widget.file;
  File? _downloaded;

  /// Why the picture is not showing, once reading it failed.
  Object? _failed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = null);
    try {
      final file = _file ??= await _find();
      if (file == null || !file.image) {
        if (mounted) _toSubmission();
        return;
      }
      final downloaded = await fetchSubmissionFile(ref, file);
      if (mounted) setState(() => _downloaded = downloaded);
    } on Exception catch (error) {
      if (mounted) setState(() => _failed = error);
    }
  }

  Future<SubmissionFile?> _find() async {
    final entry = submissionItemProvider(widget.submissionId);
    final kept = ref.listenManual(entry, (_, _) {});
    try {
      final item = await ref.read(entry.future);
      return item?.submission.files
          .where((f) => f.id == widget.fileId)
          .firstOrNull;
    } finally {
      kept.close();
    }
  }

  void _toSubmission() =>
      context.go(submissionPath(widget.submissionId), extra: NavDirection.back);

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      _toSubmission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = _downloaded;
    final Widget body;
    if (_failed case final failed?) {
      final gone = failed is ApiRefused && failed.status == 404;
      body = Align(
        alignment: Alignment.topCenter,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: submissionFileError(failed),
          action: 'Try again',
          showAction: !gone,
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
                  title: _file?.label ?? 'Image attachment',
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
