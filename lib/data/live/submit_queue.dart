import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend.dart';
import '../../core/session.dart';
import '../api_client.dart';
import '../local/local_store.dart';
import '../local/outbox.dart';
import '../submit_data.dart';
import '../submit_service.dart';
import 'live_account.dart';
import 'live_repository.dart';
import 'live_submit_service.dart' show LiveSubmitService;
import 'mappers.dart';

/// A file uploaded ahead of the send (contract 13.4).
class SubmissionUpload {
  const SubmissionUpload({required this.id, this.expiresAt});

  final String id;

  /// Unsent uploads go after 24 hours.
  final DateTime? expiresAt;
}

enum UploadProblem {
  /// 415 FILE_TYPE_NOT_ALLOWED: not an image or PDF, not what it says it
  /// is, or not a kind the brief takes.
  fileType,

  /// 413 FILE_TOO_LARGE.
  tooLarge,

  /// 409 SUBMISSION_UPLOADS_LIMIT: 20 unsent uploads or 200 MB of them.
  limit,
  rateLimited,
  closing,
  offline,
  unknown,
}

class UploadRefused implements Exception {
  const UploadRefused(this.problem);

  final UploadProblem problem;

  /// Sending it again as it is cannot help.
  bool get settled =>
      problem == UploadProblem.fileType ||
      problem == UploadProblem.tooLarge ||
      problem == UploadProblem.limit;

  @override
  String toString() => 'UploadRefused(${problem.name})';
}

/// Submission files on their own step: each goes up as it is picked, with
/// its progress, and the send names them by id.
class SubmissionUploads {
  SubmissionUploads(this.api, {AccountScope? scope})
    : scope = scope ?? AccountScope.always();

  final ApiClient api;
  final AccountScope scope;

  Future<SubmissionUpload> upload(
    AttachmentFile file, {
    String? briefId,
    void Function(double progress)? onProgress,
  }) async {
    final read = file.read;
    if (read == null) throw const UploadRefused(UploadProblem.unknown);
    final ApiResponse res;
    try {
      res = await scope.guard(
        api.multipart(
          '/submissions/uploads',
          fields: {'challengeId': ?briefId},
          files: [
            ApiFile(
              field: 'file',
              filename: file.name,
              bytes: await read(),
              contentType: LiveSubmitService.mediaTypeOf(file.name),
            ),
          ],
          onProgress: onProgress,
        ),
      );
    } on ApiUnreachable {
      throw const UploadRefused(UploadProblem.offline);
    }
    final id = res.ok ? res.data['id'] : null;
    if (id is String && id.isNotEmpty) {
      return SubmissionUpload(
        id: id,
        expiresAt: apiTime(res.data['expiresAt']),
      );
    }
    throw UploadRefused(switch (res.code) {
      'FILE_TYPE_NOT_ALLOWED' => UploadProblem.fileType,
      'FILE_TOO_LARGE' => UploadProblem.tooLarge,
      'SUBMISSION_UPLOADS_LIMIT' => UploadProblem.limit,
      'ACCOUNT_CLOSING' => UploadProblem.closing,
      _ when res.status == 415 => UploadProblem.fileType,
      _ when res.status == 413 => UploadProblem.tooLarge,
      _ when res.status == 429 => UploadProblem.rateLimited,
      _ => UploadProblem.unknown,
    });
  }

  /// A file taken off the entry before it is sent. Best effort: one left
  /// behind expires by itself.
  Future<void> drop(String id) async {
    try {
      await api.delete('/submissions/uploads/${Uri.encodeComponent(id)}');
    } on Object {
      // Expires within 24 hours anyway.
    }
  }
}

/// Uploads while `uploads` runs live, else null: the files then ride in
/// the send, as before.
final submissionUploadsProvider = Provider<SubmissionUploads?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null || !ref.watch(liveModeProvider).isLive(LiveFeature.uploads)) {
    return null;
  }
  return SubmissionUploads(api, scope: ref.watch(accountScopeProvider));
});

/// The outbox kind of a queued send.
const submitKind = 'submissions.submit';

/// Where a queued send's answer waits for the screen that queued it.
String submitAnswerKey(String itemId) => 'submit/$itemId';

/// What a refused send's code means to the flow.
SubmitResult submitResultFor(String? code, int status) {
  final block = switch (code) {
    'SUBMISSION_DEADLINE_PASSED' => SubmitBlock.deadlinePassed,
    'SUBMISSION_CHALLENGE_NOT_OPEN' => SubmitBlock.closed,
    'SUBMISSION_CAP_REACHED' => SubmitBlock.full,
    'SUBMISSION_DUPLICATE' => SubmitBlock.alreadySubmitted,
    'SUBMISSION_NOT_IN_AUDIENCE' => SubmitBlock.notInAudience,
    _ => null,
  };
  if (block != null) {
    return SubmitResult.failure(SubmitFailure.blocked, block: block);
  }
  return SubmitResult.failure(switch (code) {
    'UNDER_AGE' => SubmitFailure.underAge,
    'ACCOUNT_CLOSING' => SubmitFailure.closing,
    'FILE_TYPE_NOT_ALLOWED' => SubmitFailure.fileType,
    'SUBMISSION_UPLOAD_NOT_FOUND' ||
    'SUBMISSION_UPLOAD_IN_USE' => SubmitFailure.uploadsGone,
    _ when status == 415 => SubmitFailure.fileType,
    _ => SubmitFailure.unknown,
  });
}

/// A send that names its files by upload id goes through the outbox under
/// its own Idempotency-Key, so it can wait on the phone without a
/// connection and goes once when the network is back (contract 13.4). The
/// screen waits for its first answer; with none it says the entry is
/// queued.
class SubmitQueue {
  SubmitQueue(this.link, {this.wait = const Duration(seconds: 30)});

  final AccountLink link;

  /// The queued sends a screen is waiting on; it says itself how they went.
  static final waiting = <String>{};

  /// How long the screen waits for the outbox's first answer.
  final Duration wait;

  Future<SubmitResult> send(
    String briefId,
    Map<String, Object?> payload,
  ) async {
    if (!link.scope.open) throw const AccountChanged();
    final user = link.userId();
    if (user == null) return const SubmitResult.failure(SubmitFailure.unknown);
    final item = await link.outbox.enqueue(
      user,
      kind: submitKind,
      payload: {'challengeId': briefId, ...payload},
      coalesceKey: 'submit:$briefId',
    );
    return _settled(user, item.id);
  }

  Future<SubmitResult> _settled(String user, String id) async {
    final done = Completer<SubmitResult>();
    Future<void> check() async {
      if (done.isCompleted) return;
      final item = await link.store.outboxItem(id);
      if (done.isCompleted) return;
      final result = switch (item?.status) {
        null || OutboxStatus.done => await _answer(user, id),
        OutboxStatus.failed => submitResultFor(item!.lastErrorCode, 0),
        OutboxStatus.pending when item!.lastErrorCode == 'ACCOUNT_CLOSING' =>
          await _closing(id),
        OutboxStatus.pending when item!.attempts > 0 =>
          const SubmitResult.queued(),
        _ => null,
      };
      if (result != null && !done.isCompleted) done.complete(result);
    }

    waiting.add(id);
    final changes = link.outbox.watch().listen((_) => unawaited(check()));
    try {
      return await done.future.timeout(
        wait,
        onTimeout: () => const SubmitResult.queued(),
      );
    } finally {
      waiting.remove(id);
      await changes.cancel();
    }
  }

  /// A closing account takes no entry: the send leaves the queue rather
  /// than go out after a restore.
  Future<SubmitResult> _closing(String id) async {
    await link.outbox.discard(id);
    return const SubmitResult.failure(SubmitFailure.closing);
  }

  Future<SubmitResult> _answer(String user, String id) async {
    final kept = (await link.store.readCache(user, submitAnswerKey(id)))?.json;
    if (kept is Map) {
      final json = kept.cast<String, dynamic>();
      final duplicate = json['duplicate'];
      if (duplicate is String) {
        return const SubmitResult.failure(
          SubmitFailure.blocked,
          block: SubmitBlock.alreadySubmitted,
        );
      }
      final submission = submissionFromJson(json);
      if (submission != null) {
        final entries = json['entries'];
        return SubmitResult.sent(
          SubmitReceipt(
            submission: submission,
            entries: entries is int ? entries : null,
          ),
        );
      }
    }
    return const SubmitResult.queued();
  }
}

/// The queue while `uploads` runs live and the session knows the account.
final submitQueueProvider = Provider<SubmitQueue?>((ref) {
  final link = ref.watch(liveLinkProvider(LiveFeature.uploads));
  return link == null ? null : SubmitQueue(link);
});

/// Sends queued entries while `uploads` runs live. Each answer is kept for
/// the screen that may be waiting for it, and [onSent] hears an entry the
/// API took, for the account it was queued under.
void registerSubmitWrites(
  Outbox outbox,
  ApiClient api,
  LocalStore store, {
  required bool live,
  void Function(String userId, String briefId)? onSent,
  void Function(String userId, String briefId, String code)? onRefused,
}) {
  if (!live) {
    outbox.unregister(submitKind);
    return;
  }
  outbox.register(submitKind, (item) async {
    final payload = item.payload;
    final briefId = payload['challengeId'];
    if (briefId is! String) return const OutboxResult.fail('VALIDATION_ERROR');
    final uploadIds = payload['uploadIds'];
    final survey = payload['surveyAnswers'];
    final ApiResponse res;
    try {
      res = await api.multipart(
        '/submissions/challenges/${Uri.encodeComponent(briefId)}',
        fields: {
          'title': '${payload['title'] ?? ''}',
          'body': '${payload['body'] ?? ''}',
          if (survey is Map && survey.isNotEmpty)
            'surveyAnswers': jsonEncode(survey),
          if (uploadIds is List && uploadIds.isNotEmpty)
            'uploadIds': jsonEncode(uploadIds),
        },
        idempotencyKey: item.id,
      );
    } on ApiUnreachable {
      return outboxResultFor(status: 0, networkError: true);
    }
    String? submissionId;
    if (res.ok) {
      submissionId = apiText(res.data['id']);
      await store.writeCache(item.userId, submitAnswerKey(item.id), res.data);
    } else if (res.code == 'SUBMISSION_DUPLICATE') {
      final error = res.body['error'];
      final details = error is Map ? error['details'] : null;
      submissionId = details is Map ? apiText(details['submissionId']) : null;
      await store.writeCache(item.userId, submitAnswerKey(item.id), {
        'duplicate': submissionId ?? '',
      });
    }
    final result = outboxResultFor(
      status: res.status,
      code: res.code,
      message: res.message,
      retryAfter: res.retryAfter,
      serverRef: submissionId,
    );
    if (result is OutboxDone) onSent?.call(item.userId, briefId);
    if (result case OutboxFail(:final code)
        when !SubmitQueue.waiting.contains(item.id)) {
      onRefused?.call(item.userId, briefId, code);
    }
    return result;
  });
}
