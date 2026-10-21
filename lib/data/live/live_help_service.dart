import 'dart:async';

import '../../core/backend.dart';
import '../api_client.dart';
import '../help_data.dart';
import '../help_service.dart';
import '../local/local_rows.dart';
import '../local/local_store.dart';
import '../models.dart';
import '../support_files.dart';
import 'live_account.dart';

/// Report an issue's topics as the API names them (contract 12.1).
const helpTopics = {
  'Payments': 'payments',
  'A brief': 'a_brief',
  'The app': 'the_app',
  'Something else': 'something_else',
};

/// What a support refusal means for the person (contract 12.1).
HelpFailure helpFailureOf(int status, String? code) => switch (code) {
  'RATE_LIMITED' => HelpFailure.tooManyTries,
  'ACCOUNT_CLOSING' => HelpFailure.closing,
  'FILE_TOO_LARGE' => HelpFailure.tooLarge,
  'VIDEO_TOO_LONG' || 'AUDIO_TOO_LONG' => HelpFailure.tooLong,
  'FILE_TYPE_NOT_ALLOWED' => HelpFailure.fileType,
  'SUPPORT_UPLOAD_NOT_FOUND' ||
  'SUPPORT_UPLOAD_IN_USE' ||
  'SUPPORT_TICKET_NOT_FOUND' ||
  'ACTIVATION_NOT_FOUND' => HelpFailure.gone,
  _ when status == 429 => HelpFailure.tooManyTries,
  _ when status == 404 => HelpFailure.gone,
  _ when status == 413 => HelpFailure.tooLarge,
  _ when status == 415 => HelpFailure.fileType,
  _ when status == 408 || status >= 500 => HelpFailure.offline,
  _ => HelpFailure.unknown,
};

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

HelpAttachment? helpAttachmentFromJson(Object? json) {
  final j = _map(json);
  final id = apiText(j['id']);
  if (id == null) return null;
  final seconds = apiInt(j['lengthSeconds']);
  final url = apiText(j['url']);
  return HelpAttachment(
    id: id,
    name: apiText(j['name']) ?? '',
    bytes: apiInt(j['bytes']) ?? 0,
    length: seconds == null ? null : Duration(seconds: seconds),
    kind: switch (j['kind']) {
      'image' => HelpAttachmentKind.image,
      'audio' => HelpAttachmentKind.audio,
      _ => HelpAttachmentKind.video,
    },
    mime: apiText(j['mime']),
    url: url == null ? null : Uri.tryParse(url),
  );
}

/// Only the person's own messages read as theirs: any other author, one
/// this build does not know included, writes from the other side.
HelpMessage? _message(Object? json) {
  final j = _map(json);
  final at = apiTime(j['at']);
  if (at == null) return null;
  final files = [
    if (j['attachments'] case final List<Object?> list)
      for (final item in list) ?helpAttachmentFromJson(item),
  ];
  final you = j['author'] == 'you';
  return HelpMessage(
    author: you ? HelpAuthor.you : HelpAuthor.support,
    body: apiText(j['body']) ?? '',
    at: at,
    attachment: files.firstOrNull,
    more: files.skip(1).toList(),
    authorName: you ? null : apiText(j['authorName']),
    side: you
        ? null
        : switch (j['authorKind']) {
            'iqly' => HelpSide.iqly,
            'business' => HelpSide.business,
            _ => null,
          },
  );
}

/// A `TicketThread`, or an inbox row of `GET /support/tickets`, which has
/// only its last message. The credit is the activation's own ledger row.
HelpTicket? helpTicketFromJson(Map<String, dynamic> json) {
  final id = apiText(json['id']);
  if (id == null) return null;
  final credit = _map(json['credit']);
  final ledgerId = apiText(credit['ledgerId']);
  final amount = apiInt(credit['amountKobo']);
  final creditedAt = apiTime(credit['at']);
  final other = _map(json['with']);
  final readBy = _map(json['readBy']);
  final business =
      json['channel'] == 'contributor_business' || other['kind'] == 'business';
  return HelpTicket(
    channel: business ? HelpChannel.business : HelpChannel.iqly,
    withName: business ? apiText(other['name']) : null,
    withLogo: business ? apiText(other['logoUrl']) : null,
    readByIqly: apiTime(readBy['iqly']),
    readByBusiness: apiTime(readBy['business']),
    topic: apiText(json['topic']),
    id: id,
    reference: apiText(json['reference']),
    subject: apiText(json['subject']) ?? '',
    status: switch (json['status']) {
      'replied' => HelpTicketStatus.replied,
      'resolved' => HelpTicketStatus.resolved,
      _ => HelpTicketStatus.open,
    },
    activationId: apiText(json['activationId']),
    unread: json['unread'] == true,
    lastAt: apiTime(json['updatedAt']),
    messages: [
      if (json['messages'] case final List<Object?> messages)
        for (final message in messages) ?_message(message)
      else
        ?_message(json['lastMessage']),
    ],
    credit: ledgerId == null || amount == null || creditedAt == null
        ? null
        : LedgerEntry(
            id: ledgerId,
            type: LedgerType.award,
            amountKobo: amount,
            createdAt: creditedAt,
          ),
  );
}

/// A thread's conditional read (contract 13.5), its tag kept with the copy
/// the thread opens on, so the two never disagree.
class _KeptTag implements EtagCache {
  _KeptTag(this.store, this.userId, this.key);

  final LocalStore store;
  final String userId;
  final String key;

  @override
  Future<TaggedAnswer?> read(String path) async {
    final kept = await store.readCache(userId, key);
    final etag = kept?.etag;
    final json = kept?.json;
    if (etag == null || json is! Map) return null;
    return (etag: etag, body: <String, dynamic>{'data': json});
  }

  @override
  Future<void> write(String path, TaggedAnswer answer) async {
    final data = answer.body['data'];
    if (data is Map) {
      await store.writeCache(userId, key, data, etag: answer.etag);
    }
  }
}

/// Support on the iQLY API (contract 12.1). Files go up as they are picked
/// (`POST /support/uploads`) and a thread opens with their ids. Opening a
/// thread carries an Idempotency-Key kept for the same request until the
/// API has answered it for sure, so a retry after a lost answer opens it
/// once. Nothing is queued: a send that does not go stays on screen. The
/// inbox and every thread the API answers are kept on the phone, so they
/// open at once next time while they read again; a thread's read goes
/// conditional once the API tags it.
class LiveHelpService implements HelpService {
  LiveHelpService(this.link, {required this.files});

  final AccountLink link;
  final SupportFiles files;

  ApiClient get _api => link.api;

  /// The inbox reads at most this many threads.
  static const cap = 200;

  /// How often an open thread asks again for support's reply.
  static const pollEvery = Duration(seconds: 30);

  /// By request: the key of an open still waiting for a sure answer, for
  /// a request whose screen keeps none.
  final _keys = <String, String>{};

  /// What each picked file went up as, so sending again never uploads it
  /// twice.
  final _uploaded = Expando<HelpAttachment>();

  Future<ApiResponse> _call(Future<ApiResponse> request) async {
    final ApiResponse res;
    try {
      res = await link.scope.guard(request);
    } on ApiUnreachable {
      throw const HelpRefused(HelpFailure.offline);
    }
    if (!res.ok) {
      throw HelpRefused(helpFailureOf(res.status, res.code), res.code);
    }
    return res;
  }

  HelpTicket _ticket(ApiResponse res) {
    final ticket = helpTicketFromJson(res.data);
    if (ticket == null) throw const HelpRefused(HelpFailure.unknown);
    return ticket;
  }

  String _path(String ticketId) =>
      '/support/tickets/${Uri.encodeComponent(ticketId)}';

  /// Where the phone keeps the inbox and each thread as last read.
  static const inboxKey = 'support:tickets';
  static String threadKey(String ticketId) => 'support:ticket:$ticketId';

  /// A copy that cannot be kept never fails what the API answered.
  Future<void> _keep(String key, Map<String, dynamic> json) async {
    try {
      await link.keep(key, json);
    } on Object {
      return;
    }
  }

  /// [res]'s thread, kept for the next time it opens.
  Future<HelpTicket> _kept(ApiResponse res) async {
    final ticket = _ticket(res);
    await _keep(threadKey(ticket.id), res.data);
    return ticket;
  }

  EtagCache? _tags(String ticketId) {
    final user = link.userId();
    return link.etags && user != null
        ? _KeptTag(link.store, user, threadKey(ticketId))
        : null;
  }

  @override
  Stream<HelpUpload> addRecording({
    String? about,
    SupportSource source = SupportSource.photos,
  }) async* {
    final picked = await files.pickAttachment(source);
    if (picked == null) return;
    yield* upload(picked);
  }

  /// Over what the API takes of its kind: refused before a byte goes up.
  static HelpFailure? _overLimit(HelpAttachment file) {
    if (file.bytes > SupportLimits.bytes(file.kind)) {
      return HelpFailure.tooLarge;
    }
    final most = SupportLimits.length(file.kind);
    final length = file.length;
    if (most != null && length != null && length > most) {
      return HelpFailure.tooLong;
    }
    return null;
  }

  /// Progress follows the bytes sent, held short of done until the API
  /// answers with the upload's id.
  @override
  Stream<HelpUpload> upload(HelpAttachment file) {
    final steps = StreamController<HelpUpload>();
    Future<void> run() async {
      if (_uploaded[file] case final done?) {
        steps.add(HelpUpload(done, 1));
        return;
      }
      steps.add(HelpUpload(file, 0));
      if (_overLimit(file) case final failure?) throw HelpRefused(failure);
      final read = file.read;
      if (read == null) throw const HelpRefused(HelpFailure.unknown);
      final bytes = await read();
      final type = supportTypeOf(file.name);
      final length = file.length;
      final res = await _call(
        _api.multipart(
          '/support/uploads',
          fields: {
            if (length != null && file.kind != HelpAttachmentKind.image)
              'lengthSeconds': '${length.inSeconds}',
          },
          files: [
            ApiFile(
              field: 'file',
              filename: file.name,
              bytes: bytes,
              contentType:
                  file.mime ?? type?.mime ?? 'application/octet-stream',
            ),
          ],
          onProgress: (progress) {
            if (!steps.isClosed) {
              steps.add(HelpUpload(file, progress.clamp(0, 0.99)));
            }
          },
        ),
      );
      final answer = helpAttachmentFromJson(res.data);
      if (answer == null) throw const HelpRefused(HelpFailure.unknown);
      final done = file.uploaded(
        id: answer.id!,
        name: answer.name.isEmpty ? null : answer.name,
        bytes: answer.bytes == 0 ? null : answer.bytes,
        length: answer.length,
        kind: answer.kind,
        mime: answer.mime,
      );
      _uploaded[file] = done;
      steps.add(HelpUpload(done, 1));
    }

    run().then(
      (_) => steps.close(),
      onError: (Object error, StackTrace stack) {
        steps.addError(error, stack);
        steps.close();
      },
    );
    return steps.stream;
  }

  /// An upload already gone or sent leaves nothing to drop.
  @override
  Future<void> discard(HelpAttachment file) async {
    final id = file.id;
    if (id == null) return;
    try {
      await link.scope.guard(
        _api.delete('/support/uploads/${Uri.encodeComponent(id)}'),
      );
    } on Exception {
      return;
    }
  }

  @override
  Future<HelpTicket> send(HelpRequest request) async {
    final uploadIds = [?request.attachment?.id];
    final body = <String, Object?>{
      'subject': request.subject,
      'message': request.message,
      'topic': ?request.topic,
      'activationId': ?request.activation?.id,
      if (uploadIds.isNotEmpty) 'uploadIds': uploadIds,
    };
    final fingerprint = [
      request.subject,
      request.message,
      request.topic,
      request.activation?.id,
      ...uploadIds,
    ].join('\u0000');
    final key =
        request.idempotencyKey ?? (_keys[fingerprint] ??= LocalRows.newId());
    try {
      final res = await _call(
        _api.send('POST', '/support/tickets', body: body, idempotencyKey: key),
      );
      _keys.remove(fingerprint);
      return await _kept(res);
    } on HelpRefused catch (refused) {
      if (refused.failure != HelpFailure.offline) _keys.remove(fingerprint);
      rethrow;
    }
  }

  /// The thread as the API has it now. Reading it does not mark it read.
  /// An answer the conditional read already kept with its tag is not kept
  /// again, which would drop the tag.
  @override
  Stream<HelpTicket> watch(String ticketId) async* {
    final tags = _tags(ticketId);
    final res = await _call(_api.get(_path(ticketId), etags: tags));
    final ticket = _ticket(res);
    if (tags == null || res.headers['etag'] == null) {
      await _keep(threadKey(ticketId), res.data);
    }
    yield ticket;
  }

  @override
  Future<HelpTicket?> keptThread(String ticketId) async {
    try {
      final json = await link.kept(threadKey(ticketId));
      return json == null ? null : helpTicketFromJson(json);
    } on Object {
      return null;
    }
  }

  @override
  Future<List<HelpTicket>?> keptConversations() async {
    try {
      final items = (await link.kept(inboxKey))?['items'];
      if (items is! List) return null;
      return [
        for (final item in items)
          if (item is Map) ?helpTicketFromJson(item.cast<String, dynamic>()),
      ];
    } on Object {
      return null;
    }
  }

  /// [idempotencyKey] rides along so the API answers a reply sent again
  /// after its answer was lost with the first (an API without the key
  /// support ignores it).
  @override
  Future<HelpTicket> reply(
    String ticketId,
    String body, {
    String? idempotencyKey,
    List<HelpAttachment> attachments = const [],
  }) async => _kept(
    await _call(
      _api.send(
        'POST',
        '${_path(ticketId)}/messages',
        body: {
          'message': body,
          if (attachments.isNotEmpty)
            'uploadIds': [for (final file in attachments) ?file.id],
        },
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  @override
  Future<HelpTicket> resolve(String ticketId) async =>
      _kept(await _call(_api.post('${_path(ticketId)}/resolve')));

  @override
  Future<List<HelpTicket>> conversations() async {
    final tickets = <HelpTicket>[];
    final rows = <Map<String, dynamic>>[];
    String? cursor;
    do {
      final query = Uri(queryParameters: {'limit': '100', 'cursor': ?cursor})
          .query;
      final res = await _call(_api.get('/support/tickets?$query'));
      final items = res.data['items'];
      if (items is! List || items.isEmpty) break;
      for (final item in items) {
        if (item is Map) {
          final row = item.cast<String, dynamic>();
          if (helpTicketFromJson(row) case final ticket?) {
            tickets.add(ticket);
            rows.add(row);
          }
        }
      }
      cursor = apiText(res.data['nextCursor']);
    } while (cursor != null && tickets.length < cap);
    await _keep(inboxKey, {'items': rows});
    return tickets;
  }

  /// The kept thread reads as opened too, so it opens without the count.
  @override
  Future<void> markRead(String ticketId) async {
    await _call(_api.post('${_path(ticketId)}/read'));
    try {
      final kept = await link.kept(threadKey(ticketId));
      if (kept != null && kept['unread'] == true) {
        await link.keep(threadKey(ticketId), {...kept, 'unread': false});
      }
    } on Object {
      return;
    }
  }

  @override
  Future<int> unread() async =>
      apiInt((await _call(_api.get('/support/unread'))).data['unread']) ?? 0;

  /// The screenshot goes up first (once, however often the report is
  /// sent), then the report opens with it.
  @override
  Future<String> report({
    required String topic,
    required String details,
    HelpAttachment? screenshot,
    String? idempotencyKey,
  }) async {
    var attachment = screenshot;
    if (attachment != null && attachment.id == null) {
      attachment = (await upload(attachment).last).file;
    }
    final ticket = await send(
      HelpRequest(
        subject: topic,
        message: details,
        topic: helpTopics[topic] ?? 'something_else',
        attachment: attachment,
        idempotencyKey: idempotencyKey,
      ),
    );
    return ticket.reference ?? '';
  }
}

/// Support in a live launch that does not run it: nothing is read or sent,
/// so no sample thread shows as the person's.
class PausedHelpService implements HelpService {
  const PausedHelpService();

  static Future<Never> _paused() =>
      Future.error(const FeaturePaused(LiveFeature.support));

  @override
  Stream<HelpUpload> addRecording({
    String? about,
    SupportSource source = SupportSource.photos,
  }) => const Stream.empty();

  @override
  Stream<HelpUpload> upload(HelpAttachment file) =>
      Stream.error(const FeaturePaused(LiveFeature.support));

  @override
  Future<void> discard(HelpAttachment file) async {}

  @override
  Future<int> unread() async => 0;

  @override
  Future<HelpTicket> send(HelpRequest request) => _paused();

  @override
  Stream<HelpTicket> watch(String ticketId) => const Stream.empty();

  @override
  Future<HelpTicket> reply(
    String ticketId,
    String body, {
    String? idempotencyKey,
    List<HelpAttachment> attachments = const [],
  }) => _paused();

  @override
  Future<HelpTicket> resolve(String ticketId) => _paused();

  @override
  Future<List<HelpTicket>> conversations() async => const [];

  @override
  Future<HelpTicket?> keptThread(String ticketId) async => null;

  @override
  Future<List<HelpTicket>?> keptConversations() async => null;

  @override
  Future<void> markRead(String ticketId) async {}

  @override
  Future<String> report({
    required String topic,
    required String details,
    HelpAttachment? screenshot,
    String? idempotencyKey,
  }) => _paused();
}
