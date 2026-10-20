import 'dart:convert';

import '../api_client.dart';
import '../local/local_rows.dart';
import '../models.dart';
import '../submit_data.dart';
import '../submit_service.dart';
import 'mappers.dart';
import 'submit_queue.dart';

/// The answer as the API stores it: each paragraph (split on blank lines)
/// escaped and wrapped in `<p>`, a single line break inside it as `<br>`.
/// HTML reads a bare newline as a space, so without the `<br>` a typed list
/// would reach the business, and come back, as one line.
String answerHtml(String answer) => [
  for (final paragraph in answer.replaceAll('\r\n', '\n').split(_blankLine))
    if (paragraph.trim().isNotEmpty) '<p>${_lines(paragraph)}</p>',
].join();

final _blankLine = RegExp(r'\n\s*\n');

String _lines(String paragraph) =>
    [for (final line in paragraph.trim().split('\n')) _escape(line.trim())]
        .join('<br>');

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Opens briefs and sends responses on the iQLY API (contract 5). A send
/// goes online with its files; nothing is queued, so the draft stays until
/// the API confirms. While `uploads` runs live the files go up first and a
/// send naming them queues in the outbox ([SubmitQueue]), so it can wait
/// for the network and goes once. Retries of a send whose answer never came back carry
/// the same Idempotency-Key, so the API can never take it twice.
class LiveSubmitService implements SubmitService {
  LiveSubmitService(
    this.api, {
    DateTime Function()? clock,
    this.queue,
    this.audience = false,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient api;

  /// Health's `briefAudience`: a brief that says the person is outside its
  /// audience opens blocked, before anything is written.
  final bool audience;

  /// While `uploads` runs live: a send naming its uploads queues here, so
  /// it can wait for the network (contract 13.4).
  final SubmitQueue? queue;
  final DateTime Function() _clock;

  /// What the API takes besides the answer: images and PDFs.
  static const fileExtensions = [...SubmitForm.imageExtensions, 'pdf'];

  final _forms = <String, SubmitForm>{};

  /// By brief: the key of the send still waiting for an answer.
  final _keys = <String, String>{};

  /// The blocks as the demo checks them: already sent first, then full,
  /// past the server's deadline, not live, and outside its audience.
  @override
  Future<SubmitOpening> open(String briefId) async {
    final id = Uri.encodeComponent(briefId);
    final [challenge, mine] = await Future.wait([
      api.get('/challenges/$id'),
      api.get('/submissions/mine/by-challenge/$id'),
    ]);
    if (challenge.status == 404) {
      return const SubmitOpening.blocked(SubmitBlock.closed);
    }
    if (!challenge.ok) throw ApiRefused(challenge.status, challenge.code);
    final brief = briefFromJson(challenge.data);
    if (brief == null) return const SubmitOpening.blocked(SubmitBlock.closed);
    final sent = _sentId(mine);
    if (sent != null) {
      return SubmitOpening.blocked(
        SubmitBlock.alreadySubmitted,
        brief: brief,
        submissionId: sent,
      );
    }
    final block = _block(brief);
    if (block != null) return SubmitOpening.blocked(block, brief: brief);
    if (audience && challenge.data['inAudience'] == false) {
      return SubmitOpening.blocked(SubmitBlock.notInAudience, brief: brief);
    }
    final form = submitFormFromJson(challenge.data);
    _forms[briefId] = form;
    return SubmitOpening.open(brief, form);
  }

  static String? _sentId(ApiResponse res) {
    if (res.status == 404) return null;
    if (!res.ok) throw ApiRefused(res.status, res.code);
    final data = res.body['data'];
    return data is Map && data['id'] is String ? data['id'] as String : null;
  }

  SubmitBlock? _block(Brief brief) {
    final deadline = brief.deadline;
    if (brief.spotsLeft == 0) return SubmitBlock.full;
    if (deadline != null && !deadline.isAfter(_clock())) {
      return SubmitBlock.deadlinePassed;
    }
    if (!brief.isLive) return SubmitBlock.closed;
    return null;
  }

  @override
  Future<SubmitResult> submit(SubmitRequest request) async {
    final queue = this.queue;
    final uploadIds = request.uploadIds;
    if (queue != null && uploadIds != null) {
      final SubmitForm form;
      try {
        form = _forms[request.briefId] ?? await _formOf(request.briefId);
      } on ApiUnreachable {
        return const SubmitResult.failure(SubmitFailure.offline);
      } on Exception {
        return const SubmitResult.failure(SubmitFailure.unknown);
      }
      return queue.send(request.briefId, {
        'title': request.title,
        'body': answerHtml(request.answer),
        'surveyAnswers': _survey(form, request.answers),
        'uploadIds': uploadIds,
      });
    }
    final SubmitForm form;
    final List<ApiFile>? files;
    try {
      form = _forms[request.briefId] ?? await _formOf(request.briefId);
      files = await _files(request.files);
    } on ApiUnreachable {
      return const SubmitResult.failure(SubmitFailure.offline);
    } on Exception {
      return const SubmitResult.failure(SubmitFailure.unknown);
    }
    if (files == null) return const SubmitResult.failure(SubmitFailure.unknown);
    final survey = _survey(form, request.answers);
    final key = _keys[request.briefId] ??= LocalRows.newId();
    final ApiResponse res;
    try {
      res = await api.multipart(
        '/submissions/challenges/${Uri.encodeComponent(request.briefId)}',
        fields: {
          'title': request.title,
          'body': answerHtml(request.answer),
          if (survey.isNotEmpty) 'surveyAnswers': jsonEncode(survey),
        },
        files: files,
        onProgress: request.onProgress,
        idempotencyKey: key,
      );
    } on ApiUnreachable {
      return const SubmitResult.failure(SubmitFailure.offline);
    }
    if (!_mayHaveLanded(res.status)) _keys.remove(request.briefId);
    if (res.ok) {
      final submission = submissionFromJson(res.body['data']);
      if (submission == null) {
        return const SubmitResult.failure(SubmitFailure.unknown);
      }
      final entries = res.data['entries'];
      return SubmitResult.sent(
        SubmitReceipt(
          submission: submission,
          entries: entries is int ? entries : null,
        ),
      );
    }
    return submitResultFor(res.code, res.status);
  }

  /// A timeout, a throttle or a server fault says nothing of whether the
  /// send was stored, so its key stays for the retry.
  static bool _mayHaveLanded(int status) =>
      status == 408 || status == 429 || status >= 500;

  Future<SubmitForm> _formOf(String briefId) async {
    final res = await api.get('/challenges/${Uri.encodeComponent(briefId)}');
    if (!res.ok) throw ApiRefused(res.status, res.code);
    return _forms[briefId] = submitFormFromJson(res.data);
  }

  /// A single choice and free text answer with a string, a multiple choice
  /// with the list picked.
  static Map<String, Object> _survey(
    SubmitForm form,
    Map<String, List<String>> answers,
  ) => {
    for (final question in form.questions)
      if (answers[question.id] case final given? when given.isNotEmpty)
        question.id: question.multi ? given : given.first,
  };

  /// Null when a file cannot be read.
  static Future<List<ApiFile>?> _files(List<AttachmentFile> picked) async {
    final files = <ApiFile>[];
    for (final file in picked) {
      final read = file.read;
      if (read == null) return null;
      files.add(
        ApiFile(
          field: 'file',
          filename: file.name,
          bytes: await read(),
          contentType: mediaTypeOf(file.name),
        ),
      );
    }
    return files;
  }

  /// The media type the API classifies a file by, from its extension.
  static String mediaTypeOf(String name) {
    final dot = name.lastIndexOf('.');
    return switch (dot < 0 ? '' : name.substring(dot + 1).toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}

/// A live send carries its files, so each one is in as soon as it is
/// picked and goes up with the send.
class LiveAttachmentUploader implements AttachmentUploader {
  const LiveAttachmentUploader();

  @override
  Future<bool> upload(
    AttachmentFile file,
    void Function(double progress) progress,
  ) async {
    progress(1);
    return true;
  }
}
