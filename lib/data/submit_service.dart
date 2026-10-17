import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/deadline.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'demo_data.dart';
import 'live/live_repository.dart';
import 'live/live_submit_service.dart';
import 'models.dart';
import 'repository.dart';
import 'submit_data.dart';

/// Why a brief cannot take a submission now (iqly.net "Can't submit right
/// now"), in the order the product checks them.
enum SubmitBlock { full, deadlinePassed, closed, alreadySubmitted }

/// A brief as the submit flow opens it: its form, or why it is blocked.
class SubmitOpening {
  const SubmitOpening.open(Brief this.brief, SubmitForm this.form)
    : block = null,
      submissionId = null;

  const SubmitOpening.blocked(
    SubmitBlock this.block, {
    this.brief,
    this.submissionId,
  }) : form = null;

  final Brief? brief;
  final SubmitForm? form;
  final SubmitBlock? block;

  /// The one already sent, when [block] is [SubmitBlock.alreadySubmitted].
  final String? submissionId;
}

enum SubmitFailure {
  blocked,
  offline,
  unknown,

  /// The profile's date of birth is under 18 (403 UNDER_AGE).
  underAge,

  /// The account is closing, so it takes no writes (403 ACCOUNT_CLOSING).
  closing,

  /// A file of a kind the brief does not take (415 FILE_TYPE_NOT_ALLOWED):
  /// sending it again can only be refused again.
  fileType,
}

class SubmitResult {
  const SubmitResult.sent(SubmitReceipt this.receipt)
    : failure = null,
      block = null;

  const SubmitResult.failure(SubmitFailure this.failure, {this.block})
    : receipt = null;

  final SubmitReceipt? receipt;
  final SubmitFailure? failure;
  final SubmitBlock? block;

  bool get ok => receipt != null;
}

/// Sending a response. The live API answers the challenge detail, the
/// contributor's submission for it and the POST; the demo writes into the
/// sample dataset after a short delay, so My submissions reads the new row
/// back as the API would.
abstract class SubmitService {
  Future<SubmitOpening> open(String briefId);

  Future<SubmitResult> submit(SubmitRequest request);
}

/// The phone's own file picker.
abstract class AttachmentPicker {
  /// The files picked, or none when the person cancels. [only] narrows the
  /// kinds offered, by extension, to what the brief takes.
  Future<List<AttachmentFile>> pick({List<String>? only});
}

/// Sends one attachment up, reporting progress from 0 to 1. True once it
/// is stored.
abstract class AttachmentUploader {
  Future<bool> upload(AttachmentFile file, void Function(double) progress);
}

class DemoSubmitService implements SubmitService {
  DemoSubmitService(
    this.data, {
    this.delay = const Duration(milliseconds: 700),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DemoData data;
  final Duration delay;
  final DateTime Function() _clock;

  final requests = <SubmitRequest>[];

  /// Set to make the next sends fail as if offline.
  bool offline = false;

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future<void>.delayed(delay);

  @override
  Future<SubmitOpening> open(String briefId) async {
    final brief = data.briefs.where((b) => b.id == briefId).firstOrNull;
    if (brief == null) return const SubmitOpening.blocked(SubmitBlock.closed);
    final sent = data.submissions.where((s) => s.briefId == briefId);
    if (sent.isNotEmpty) {
      return SubmitOpening.blocked(
        SubmitBlock.alreadySubmitted,
        brief: brief,
        submissionId: sent.first.id,
      );
    }
    final block = _block(brief);
    if (block != null) return SubmitOpening.blocked(block, brief: brief);
    return SubmitOpening.open(
      brief,
      SubmitDemo.forms[briefId] ?? const SubmitForm(),
    );
  }

  SubmitBlock? _block(Brief brief) {
    final deadline = brief.deadline;
    final passed = deadline != null && !deadline.isAfter(_clock());
    final full = brief.spotsLeft == 0;
    if (!full && !passed && brief.isLive) return null;
    if (full) return SubmitBlock.full;
    if (passed) return SubmitBlock.deadlinePassed;
    return SubmitBlock.closed;
  }

  @override
  Future<SubmitResult> submit(SubmitRequest request) async {
    await _wait();
    if (offline) return const SubmitResult.failure(SubmitFailure.offline);
    final opening = await open(request.briefId);
    final brief = opening.brief;
    if (opening.block != null || brief == null) {
      return SubmitResult.failure(SubmitFailure.blocked, block: opening.block);
    }
    requests.add(request);
    final submission = Submission(
      id: 's${_nextId()}',
      briefId: brief.id,
      title: request.title,
      body: request.answer,
      status: SubmissionStatus.pending,
      createdAt: _clock(),
    );
    data.submissions.insert(0, submission);
    return SubmitResult.sent(
      SubmitReceipt(submission: submission, entries: _takeSpot(brief)),
    );
  }

  int _nextId() {
    final ids = data.submissions.map((s) => int.tryParse(s.id.substring(1)));
    return ids.fold(0, (top, id) => id != null && id > top ? id : top) + 1;
  }

  /// The new entry takes one of the brief's spots; with a known capacity the
  /// entries so far are the spots taken.
  int? _takeSpot(Brief brief) {
    final left = brief.spotsLeft;
    if (left == null) return null;
    final i = data.briefs.indexOf(brief);
    data.briefs[i] = Brief(
      id: brief.id,
      title: brief.title,
      body: brief.body,
      tier: brief.tier,
      category: brief.category,
      rewardPoolKobo: brief.rewardPoolKobo,
      status: brief.status,
      deadline: brief.deadline,
      businessName: brief.businessName,
      createdAt: brief.createdAt,
      interest: brief.interest,
      spotsLeft: left - 1,
      spotsTotal: brief.spotsTotal,
      winnerRule: brief.winnerRule,
    );
    final total = brief.spotsTotal;
    return total == null ? null : total - (left - 1);
  }
}

/// The system picker (file_picker). Without the plugin, as in tests and
/// on a desktop build without it, it falls back to [fallback].
class DeviceAttachmentPicker implements AttachmentPicker {
  DeviceAttachmentPicker({AttachmentPicker? fallback, this.extensions})
    : fallback = fallback ?? DemoAttachmentPicker();

  final AttachmentPicker fallback;

  /// The kinds of file offered, by extension; null offers any file.
  final List<String>? extensions;

  /// What [pick] offers: the picker's own kinds, narrowed to [only].
  List<String>? offered(List<String>? only) {
    final own = extensions;
    if (only == null) return own;
    if (own == null) return only;
    return [
      for (final kind in own)
        if (only.contains(kind)) kind,
    ];
  }

  @override
  Future<List<AttachmentFile>> pick({List<String>? only}) async {
    try {
      final kinds = offered(only);
      final files = await FilePicker.pickFiles(
        type: kinds == null ? FileType.any : FileType.custom,
        allowedExtensions: kinds,
      );
      return [
        for (final file in files)
          AttachmentFile(
            name: file.name,
            bytes: file.lengthSync() ?? await file.length() ?? 0,
            read: file.readAsBytes,
          ),
      ];
    } on MissingPluginException {
      return fallback.pick(only: only);
    }
  }
}

class DemoAttachmentPicker implements AttachmentPicker {
  final picks = <List<AttachmentFile>>[];

  /// What the next pick returns.
  List<AttachmentFile> next = SubmitDemo.picked;

  /// What each pick was narrowed to.
  final offers = <List<String>?>[];

  @override
  Future<List<AttachmentFile>> pick({List<String>? only}) async {
    offers.add(only);
    picks.add(next);
    return next;
  }
}

/// Uploads in five steps over [duration]; names in [failing] fail once.
class DemoAttachmentUploader implements AttachmentUploader {
  DemoAttachmentUploader({
    this.duration = const Duration(milliseconds: 1500),
    Set<String>? failing,
  }) : failing = failing ?? {};

  final Duration duration;
  final Set<String> failing;

  @override
  Future<bool> upload(
    AttachmentFile file,
    void Function(double) progress,
  ) async {
    const steps = 5;
    for (var i = 1; i <= steps; i++) {
      if (duration > Duration.zero) {
        await Future<void>.delayed(duration ~/ steps);
      }
      if (failing.remove(file.name)) return false;
      progress(i / steps);
    }
    return true;
  }
}

/// Submit in a live launch that pauses it: a brief does not open and a
/// send fails, before anything is sent or written into the sample data.
class PausedSubmitService implements SubmitService {
  const PausedSubmitService();

  @override
  Future<SubmitOpening> open(String briefId) =>
      Future.error(const FeaturePaused(LiveFeature.submit));

  @override
  Future<SubmitResult> submit(SubmitRequest request) async =>
      const SubmitResult.failure(SubmitFailure.unknown);
}

/// The API when submit is live, and a refusal while a live launch pauses
/// it. The demo writes into the dataset the preview's repository reads.
final submitServiceProvider = Provider<SubmitService>((ref) {
  ref.watch(accountProvider);
  final api = ref.watch(apiClientProvider);
  final mode = ref.watch(liveModeProvider);
  if (api != null && mode.isLive(LiveFeature.submit)) {
    return LiveSubmitService(api, clock: ref.watch(clockProvider));
  }
  if (!mode.isPreview) return const PausedSubmitService();
  final repository = ref.watch(repositoryProvider);
  return DemoSubmitService(
    repository is DemoRepository
        ? repository.data
        : ref.watch(demoRepositoryProvider).data,
    clock: ref.watch(clockProvider),
  );
});

/// A live send takes images and PDFs only: the API refuses anything else.
final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => ref.watch(liveModeProvider).isPreview
      ? DeviceAttachmentPicker()
      : DeviceAttachmentPicker(extensions: LiveSubmitService.fileExtensions),
);

/// A live launch never runs the demo's upload.
final attachmentUploaderProvider = Provider<AttachmentUploader>(
  (ref) => ref.watch(liveModeProvider).isPreview
      ? DemoAttachmentUploader()
      : const LiveAttachmentUploader(),
);
