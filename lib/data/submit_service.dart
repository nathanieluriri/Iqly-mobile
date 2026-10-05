import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deadline.dart';
import 'demo_data.dart';
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

enum SubmitFailure { blocked, offline, unknown }

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
  /// The files picked, or none when the person cancels.
  Future<List<AttachmentFile>> pick();
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
  DeviceAttachmentPicker({AttachmentPicker? fallback})
    : fallback = fallback ?? DemoAttachmentPicker();

  final AttachmentPicker fallback;

  @override
  Future<List<AttachmentFile>> pick() async {
    try {
      final files = await FilePicker.pickFiles();
      return [
        for (final file in files)
          AttachmentFile(
            name: file.name,
            bytes: file.lengthSync() ?? await file.length() ?? 0,
          ),
      ];
    } on MissingPluginException {
      return fallback.pick();
    }
  }
}

class DemoAttachmentPicker implements AttachmentPicker {
  final picks = <List<AttachmentFile>>[];

  /// What the next pick returns.
  List<AttachmentFile> next = SubmitDemo.picked;

  @override
  Future<List<AttachmentFile>> pick() async {
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

/// The demo writes into the same dataset the repository reads.
final submitServiceProvider = Provider<SubmitService>((ref) {
  final repository = ref.watch(repositoryProvider);
  return DemoSubmitService(
    repository is DemoRepository ? repository.data : DemoData(),
    clock: ref.watch(clockProvider),
  );
});

final attachmentPickerProvider = Provider<AttachmentPicker>(
  (ref) => DeviceAttachmentPicker(),
);

final attachmentUploaderProvider = Provider<AttachmentUploader>(
  (ref) => DemoAttachmentUploader(),
);
