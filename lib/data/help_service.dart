import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/money.dart';
import '../core/session.dart';
import 'activations_data.dart';
import 'demo_data.dart';
import 'help_data.dart';
import 'live/live_repository.dart' show liveModeProvider;
import 'models.dart';

/// One step of a recording upload: the picked [file] and how far it is.
class HelpUpload {
  const HelpUpload(this.file, this.progress);

  final HelpAttachment file;

  /// 0 to 1; at 1 the file is uploaded and ready to send.
  final double progress;

  bool get done => progress >= 1;
}

/// Asking support for help. The live version picks the recording with
/// image_picker (a screen recording from the gallery) and uploads it to the
/// API; the thread updates come from the API by push or polling.
abstract class HelpService {
  /// Picks a screen recording on the device and uploads it, reporting
  /// progress until it is done. Ends with nothing when the person cancels
  /// the picker. [about] names the business the request is about; the demo
  /// names its file after it.
  Stream<HelpUpload> addRecording({String? about});

  /// Sends [request] to support and opens its ticket.
  Future<HelpTicket> send(HelpRequest request);

  /// [ticketId] now and as support answers it: typing, then the reply.
  Stream<HelpTicket> watch(String ticketId);

  /// Adds the person's [body] to [ticketId].
  Future<HelpTicket> reply(String ticketId, String body);

  /// The person marks [ticketId] as resolved.
  Future<HelpTicket> resolve(String ticketId);

  /// The one support inbox: every conversation, latest message first.
  Future<List<HelpTicket>> conversations();

  /// The person opened [ticketId].
  Future<void> markRead(String ticketId);

  /// Sends a report (B21 · Report an issue) and returns its ticket number.
  Future<String> report({
    required String topic,
    required String details,
    String? screenshot,
  });
}

/// Picks the frame's recording and uploads it in four steps, answers sends
/// after [delay], and has support start typing [typingAfter] a ticket is
/// watched and reply [replyAfter] later. Support answers a request about an
/// activation that was started: it confirms the steps and credits the
/// reward, unless the activation was already paid when the request went,
/// then the reward is in the wallet already and nothing more is credited.
/// Other requests wait for the live API. A null [replyAfter] leaves tickets
/// waiting.
class DemoHelpService implements HelpService {
  DemoHelpService({
    this.delay = const Duration(milliseconds: 700),
    this.uploadStep = const Duration(milliseconds: 300),
    this.typingAfter = const Duration(seconds: 1),
    this.replyAfter = const Duration(milliseconds: 2400),
    String? firstName,
    DateTime Function()? clock,
  }) : firstName = firstName ?? DemoData.user.firstName,
       _clock = clock ?? DateTime.now {
    for (final ticket in DemoHelp.conversations(this.firstName)) {
      _save(ticket);
    }
  }

  final Duration delay;
  final Duration uploadStep;
  final Duration typingAfter;
  final Duration? replyAfter;
  final String firstName;
  final DateTime Function() _clock;

  final requests = <HelpRequest>[];
  final reports = <({String topic, String details, String? screenshot})>[];
  final _tickets = <String, HelpTicket>{};
  final _about = <String, Activation>{};
  int _next = 1;

  Future<void> _wait(Duration duration) => duration == Duration.zero
      ? Future.value()
      : Future<void>.delayed(duration);

  HelpTicket _ticket(String id) {
    final ticket = _tickets[id];
    if (ticket == null) throw StateError('No ticket $id');
    return ticket;
  }

  HelpTicket _save(HelpTicket ticket) => _tickets[ticket.id] = ticket;

  @override
  Stream<HelpUpload> addRecording({String? about}) async* {
    final file = DemoHelp.recordingFor(about);
    for (final progress in const [0.0, 0.25, 0.5, 0.75]) {
      yield HelpUpload(file, progress);
      await _wait(uploadStep);
    }
    yield HelpUpload(file, 1);
  }

  @override
  Future<HelpTicket> send(HelpRequest request) async {
    await _wait(delay);
    requests.add(request);
    final ticket = HelpTicket(
      id: 't${_next++}',
      subject: request.subject,
      status: HelpTicketStatus.open,
      activationId: request.activation?.id,
      messages: [
        HelpMessage(
          author: HelpAuthor.you,
          body: request.message,
          at: _clock(),
          attachment: request.attachment,
        ),
      ],
    );
    if (request.activation case final about?) _about[ticket.id] = about;
    return _save(ticket);
  }

  @override
  Stream<HelpTicket> watch(String ticketId) async* {
    final ticket = _tickets[ticketId];
    if (ticket == null) return;
    yield ticket;
    final after = replyAfter;
    final about = _about[ticketId];
    if (after == null || ticket.answered || about == null || !about.started) {
      return;
    }
    await _wait(typingAfter);
    yield _save(_ticket(ticketId).copyWith(supportTyping: true));
    await _wait(after);
    final at = _clock();
    final current = _ticket(ticketId);
    yield _save(
      current.copyWith(
        supportTyping: false,
        status: current.status == HelpTicketStatus.resolved
            ? HelpTicketStatus.resolved
            : HelpTicketStatus.replied,
        credit: about.credited
            ? null
            : LedgerEntry(
                id: about.creditId,
                type: LedgerType.award,
                amountKobo: about.rewardKobo,
                createdAt: at,
              ),
        messages: [
          ...current.messages,
          HelpMessage(
            author: HelpAuthor.support,
            body: DemoHelp.reply(
              firstName,
              steps: about.steps.length,
              amount: naira(about.rewardKobo),
            ),
            at: at,
          ),
        ],
      ),
    );
  }

  @override
  Future<HelpTicket> reply(String ticketId, String body) async {
    await _wait(delay);
    final ticket = _ticket(ticketId);
    return _save(
      ticket.copyWith(
        status: HelpTicketStatus.open,
        messages: [
          ...ticket.messages,
          HelpMessage(author: HelpAuthor.you, body: body, at: _clock()),
        ],
      ),
    );
  }

  @override
  Future<List<HelpTicket>> conversations() async =>
      _tickets.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> markRead(String ticketId) async {
    final ticket = _tickets[ticketId];
    if (ticket != null && ticket.unread) _save(ticket.copyWith(unread: false));
  }

  /// B21 · Report sent (431:19726) numbers the first report IQ-HELP-2041.
  @override
  Future<String> report({
    required String topic,
    required String details,
    String? screenshot,
  }) async {
    await _wait(delay);
    reports.add((topic: topic, details: details, screenshot: screenshot));
    return 'IQ-HELP-${2040 + reports.length}';
  }

  @override
  Future<HelpTicket> resolve(String ticketId) async {
    await _wait(delay);
    return _save(_ticket(ticketId).copyWith(status: HelpTicketStatus.resolved));
  }
}

final helpServiceProvider = Provider<HelpService>((ref) {
  ref.watch(accountProvider);
  return DemoHelpService();
});

/// Whether the ways to reach support show this launch: always in the
/// preview, and in a live launch only while the API runs support.
final supportShownProvider = Provider<bool>((ref) {
  final mode = ref.watch(liveModeProvider);
  return mode.isPreview || mode.isLive(LiveFeature.support);
});
