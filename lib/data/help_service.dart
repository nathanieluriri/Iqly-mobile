import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import 'demo_data.dart';
import 'help_data.dart';
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
  /// the picker.
  Stream<HelpUpload> addRecording();

  /// Sends [request] to support and opens its ticket.
  Future<HelpTicket> send(HelpRequest request);

  /// [ticketId] now and as support answers it: typing, then the reply.
  Stream<HelpTicket> watch(String ticketId);

  /// Adds the person's [body] to [ticketId].
  Future<HelpTicket> reply(String ticketId, String body);

  /// The person marks [ticketId] as resolved.
  Future<HelpTicket> resolve(String ticketId);
}

/// Picks [DemoHelp.recording] and uploads it in four steps, answers sends
/// after [delay], and has support start typing [typingAfter] a ticket is
/// watched and reply [replyAfter] later with the activation reward credited.
/// A null [replyAfter] leaves tickets waiting.
class DemoHelpService implements HelpService {
  DemoHelpService({
    this.delay = const Duration(milliseconds: 700),
    this.uploadStep = const Duration(milliseconds: 300),
    this.typingAfter = const Duration(seconds: 1),
    this.replyAfter = const Duration(milliseconds: 2400),
    String? firstName,
    DateTime Function()? clock,
  }) : firstName = firstName ?? DemoData.user.firstName,
       _clock = clock ?? DateTime.now;

  final Duration delay;
  final Duration uploadStep;
  final Duration typingAfter;
  final Duration? replyAfter;
  final String firstName;
  final DateTime Function() _clock;

  final requests = <HelpRequest>[];
  final _tickets = <String, HelpTicket>{};
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
  Stream<HelpUpload> addRecording() async* {
    for (final progress in const [0.0, 0.25, 0.5, 0.75]) {
      yield HelpUpload(DemoHelp.recording, progress);
      await _wait(uploadStep);
    }
    yield const HelpUpload(DemoHelp.recording, 1);
  }

  @override
  Future<HelpTicket> send(HelpRequest request) async {
    await _wait(delay);
    requests.add(request);
    return _save(
      HelpTicket(
        id: 't${_next++}',
        subject: request.subject,
        status: HelpTicketStatus.open,
        messages: [
          HelpMessage(
            author: HelpAuthor.you,
            body: request.message,
            at: _clock(),
            attachment: request.attachment,
          ),
        ],
      ),
    );
  }

  @override
  Stream<HelpTicket> watch(String ticketId) async* {
    final ticket = _tickets[ticketId];
    if (ticket == null) return;
    yield ticket;
    final after = replyAfter;
    final answered = ticket.messages.any((m) => m.author == HelpAuthor.support);
    if (after == null || answered) return;
    await _wait(typingAfter);
    yield _save(_ticket(ticketId).copyWith(supportTyping: true));
    await _wait(after);
    final at = _clock();
    final credit = LedgerEntry(
      id: DemoHelp.creditId,
      type: LedgerType.award,
      amountKobo: DemoHelp.rewardKobo,
      createdAt: at,
    );
    final current = _ticket(ticketId);
    yield _save(
      current.copyWith(
        supportTyping: false,
        status: current.status == HelpTicketStatus.resolved
            ? HelpTicketStatus.resolved
            : HelpTicketStatus.replied,
        credit: credit,
        messages: [
          ...current.messages,
          HelpMessage(
            author: HelpAuthor.support,
            body: DemoHelp.reply(firstName, naira(credit.amountKobo)),
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
  Future<HelpTicket> resolve(String ticketId) async {
    await _wait(delay);
    return _save(_ticket(ticketId).copyWith(status: HelpTicketStatus.resolved));
  }
}

final helpServiceProvider = Provider<HelpService>((ref) => DemoHelpService());
