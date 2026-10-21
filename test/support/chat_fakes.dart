import 'dart:async';
import 'dart:io';

import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/signed_in_files.dart';
import 'package:iqly_mobile/data/support_files.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/data/voice_recorder.dart';

/// Support as a test drives it: [tickets] is what the API has, [kept] and
/// [keptInbox] what the phone kept. With [holdThreads] a thread's read
/// waits for [answer] or [fail]; [holdInbox] does the same for the inbox.
/// The next pick is [picked], and with [holdUploads] its upload moves only
/// as [step] says.
class ScriptedHelp implements HelpService {
  ScriptedHelp({required this.clock, Iterable<HelpTicket> tickets = const []})
    : tickets = {for (final t in tickets) t.id: t};

  final DateTime Function() clock;
  final Map<String, HelpTicket> tickets;
  final kept = <String, HelpTicket>{};
  List<HelpTicket>? keptInbox;

  bool holdThreads = false;
  bool holdInbox = false;
  bool holdUploads = false;
  HelpAttachment? picked;

  final watches = <String>[];
  final sources = <SupportSource>[];
  final replies = <({String body, List<HelpAttachment> files, String? key})>[];
  int inboxReads = 0;

  final _threads = <String, List<StreamController<HelpTicket>>>{};
  Completer<List<HelpTicket>>? _inbox;
  StreamController<HelpUpload>? _upload;
  HelpAttachment? _going;
  int _uploads = 0;

  /// Answers every held read of [id] with the thread as [tickets] has it.
  void answer(String id) {
    for (final read in _threads.remove(id) ?? const []) {
      read
        ..add(tickets[id]!)
        ..close();
    }
  }

  /// Fails every held read of [id].
  void fail(
    String id, [
    Object error = const HelpRefused(HelpFailure.offline),
  ]) {
    for (final read in _threads.remove(id) ?? const []) {
      read
        ..addError(error)
        ..close();
    }
  }

  void answerInbox() {
    _inbox?.complete(_list());
    _inbox = null;
  }

  void failInbox() {
    _inbox?.completeError(const HelpRefused(HelpFailure.offline));
    _inbox = null;
  }

  /// Moves the held upload to [progress]; at 1 it is up as `up_1`.
  void step(double progress) {
    final file = _going!;
    _upload!.add(
      progress >= 1
          ? HelpUpload(file.uploaded(id: 'up_${++_uploads}'), 1)
          : HelpUpload(file, progress),
    );
    if (progress >= 1) _upload!.close();
  }

  List<HelpTicket> _list() =>
      tickets.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<HelpUpload> addRecording({
    String? about,
    SupportSource source = SupportSource.photos,
  }) {
    sources.add(source);
    final file = picked;
    return file == null ? const Stream.empty() : upload(file);
  }

  @override
  Stream<HelpUpload> upload(HelpAttachment file) {
    if (holdUploads) {
      _going = file;
      final steps = _upload = StreamController<HelpUpload>();
      steps.add(HelpUpload(file, 0));
      return steps.stream;
    }
    return Stream.fromIterable([
      HelpUpload(file, 0),
      HelpUpload(file.uploaded(id: 'up_${++_uploads}'), 1),
    ]);
  }

  @override
  Future<void> discard(HelpAttachment file) async {}

  @override
  Future<int> unread() async => 0;

  @override
  Future<HelpTicket> send(HelpRequest request) async {
    final ticket = HelpTicket(
      id: 't${tickets.length + 1}',
      subject: request.subject,
      status: HelpTicketStatus.open,
      messages: [
        HelpMessage(
          author: HelpAuthor.you,
          body: request.message,
          at: clock(),
          attachment: request.attachment,
        ),
      ],
    );
    return tickets[ticket.id] = ticket;
  }

  @override
  Stream<HelpTicket> watch(String ticketId) {
    watches.add(ticketId);
    if (holdThreads) {
      final read = StreamController<HelpTicket>();
      (_threads[ticketId] ??= []).add(read);
      return read.stream;
    }
    final ticket = tickets[ticketId];
    return ticket == null
        ? Stream.error(const HelpRefused(HelpFailure.gone))
        : Stream.value(ticket);
  }

  @override
  Future<HelpTicket> reply(
    String ticketId,
    String body, {
    String? idempotencyKey,
    List<HelpAttachment> attachments = const [],
  }) async {
    replies.add((body: body, files: attachments, key: idempotencyKey));
    final ticket = tickets[ticketId]!;
    final served = [
      for (final file in attachments)
        HelpAttachment(
          id: file.id,
          name: file.name,
          bytes: file.bytes,
          kind: file.kind,
          length: file.length,
          url: Uri.parse('https://api.test/support/attachments/${file.id}'),
        ),
    ];
    return tickets[ticketId] = ticket.copyWith(
      status: HelpTicketStatus.open,
      messages: [
        ...ticket.messages,
        HelpMessage(
          author: HelpAuthor.you,
          body: body,
          at: clock(),
          attachment: served.firstOrNull,
          more: served.skip(1).toList(),
        ),
      ],
    );
  }

  @override
  Future<HelpTicket> resolve(String ticketId) async =>
      tickets[ticketId] = tickets[ticketId]!.copyWith(
        status: HelpTicketStatus.resolved,
        resolvedBy: () => HelpSide.you,
      );

  @override
  Future<List<HelpTicket>> conversations() {
    inboxReads++;
    if (!holdInbox) return Future.value(_list());
    return (_inbox = Completer<List<HelpTicket>>()).future;
  }

  @override
  Future<HelpTicket?> keptThread(String ticketId) async => kept[ticketId];

  @override
  Future<List<HelpTicket>?> keptConversations() async => keptInbox;

  @override
  Future<void> markRead(String ticketId) async {}

  @override
  Future<String> report({
    required String topic,
    required String details,
    HelpAttachment? screenshot,
    String? idempotencyKey,
  }) async => 'IQ-HELP-2041';
}

/// The account's files as a test serves them: [keptFiles] are on the phone
/// already; a fetch waits until [land] or [refuse], reporting [progress].
class ScriptedFiles extends SignedInFiles {
  ScriptedFiles()
    : super(
        api: ApiClient(
          tokens: MemoryTokenStore('signed.token'),
          baseUrl: 'https://api.test',
        ),
        root: Directory('${Directory.systemTemp.path}/iqly-test-files'),
      );

  final keptFiles = <String, File>{};
  final fetches = <String>[];
  final keptSent = <String>[];
  final _waiting = <String, Completer<File>>{};
  final _progress = <String, void Function(double)?>{};

  void progress(String id, double value) => _progress[id]?.call(value);

  void land(String id, File file) => _waiting.remove(id)?.complete(file);

  void refuse(String id) =>
      _waiting.remove(id)?.completeError(const ApiUnreachable());

  @override
  File? kept({required String userId, required String id, String name = ''}) =>
      keptFiles[id];

  @override
  Future<File> fetch({
    required String userId,
    required String id,
    required String url,
    String name = '',
    void Function(double progress)? onProgress,
  }) {
    fetches.add(id);
    final kept = keptFiles[id];
    if (kept != null) return Future.value(kept);
    _progress[id] = onProgress;
    return (_waiting[id] = Completer<File>()).future;
  }

  @override
  Future<void> keep({
    required String userId,
    required String id,
    required List<int> bytes,
    String name = '',
  }) async {
    keptSent.add(id);
    keptFiles[id] = File('assets/samples/support/withdrawals-screenshot.jpg');
  }
}

/// The microphone as a test drives it: [answer] is how starting goes, and
/// a stop answers a note as long as [length] (null for nothing recorded).
class ScriptedRecorder implements VoiceRecorder {
  VoiceStart answer = VoiceStart.recording;
  Duration? length = const Duration(seconds: 3);
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  Future<VoiceStart> start() async {
    starts++;
    return answer;
  }

  @override
  Future<VoiceNote?> stop() async {
    stops++;
    final length = this.length;
    return length == null
        ? null
        : VoiceNote(path: '/voice/note.m4a', length: length, bytes: 24000);
  }

  @override
  Future<void> cancel() async => cancels++;
}
