import 'activations_data.dart';
import 'media_service.dart';
import 'models.dart';

enum HelpTicketStatus { open, replied, resolved }

enum HelpAuthor { you, support }

/// A screen recording sent with a message.
class HelpAttachment {
  const HelpAttachment({
    required this.name,
    required this.length,
    required this.bytes,
  });

  final String name;
  final Duration length;
  final int bytes;

  /// "0:31".
  String get lengthLabel =>
      '${length.inMinutes}:${(length.inSeconds % 60).toString().padLeft(2, '0')}';

  /// "12 MB".
  String get sizeLabel => '${(bytes / 1000000).round()} MB';
}

class HelpMessage {
  const HelpMessage({
    required this.author,
    required this.body,
    required this.at,
    this.attachment,
  });

  final HelpAuthor author;
  final String body;
  final DateTime at;
  final HelpAttachment? attachment;
}

/// A help thread: what it is about, its messages oldest first, whether
/// support is typing, and what support credited with its reply.
class HelpTicket {
  const HelpTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.messages,
    this.activationId,
    this.supportTyping = false,
    this.credit,
  });

  final String id;
  final String subject;
  final HelpTicketStatus status;
  final List<HelpMessage> messages;

  /// The activation the ticket is about, if any.
  final String? activationId;
  final bool supportTyping;

  /// The award support put on the ledger when it replied, if any.
  final LedgerEntry? credit;

  /// Support has answered.
  bool get answered => messages.any((m) => m.author == HelpAuthor.support);

  HelpTicket copyWith({
    HelpTicketStatus? status,
    List<HelpMessage>? messages,
    bool? supportTyping,
    LedgerEntry? credit,
  }) => HelpTicket(
    id: id,
    subject: subject,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    activationId: activationId,
    supportTyping: supportTyping ?? this.supportTyping,
    credit: credit ?? this.credit,
  );
}

class HelpRequest {
  const HelpRequest({
    required this.subject,
    required this.message,
    this.attachment,
    this.activation,
  });

  final String subject;
  final String message;
  final HelpAttachment? attachment;

  /// The activation the request is about, as the app had it when the
  /// request went; the live API takes its id.
  final Activation? activation;
}

/// The B10 thread (141:5818, 141:5876), about the activation the person
/// asked from. In the frames it is Kudi Box, whose B8 reward is ₦1,500:
/// support confirms the three steps and credits the reward on the ledger
/// row the activation's own payout uses, so it counts once whichever pays
/// it. On the DemoData wallet (available ₦12,500.00, one ₦10,000.00
/// withdrawal on hold, earned ₦62,500.00) that gives the frame's updated
/// balance: ₦14,000.00 available, ₦10,000.00 on hold, ₦64,000.00 earned.
abstract final class DemoHelp {
  /// The frame's recording, "kudi-box-wallet.mp4", "0:31", "12 MB".
  static const recording = HelpAttachment(
    name: 'kudi-box-wallet.mp4',
    length: Duration(seconds: 31),
    bytes: 12000000,
  );

  /// The frame's recording, named for [business]'s activation.
  static HelpAttachment recordingFor(String? business) => business == null
      ? recording
      : HelpAttachment(
          name: DemoMediaService.recordingName(business, 'wallet'),
          length: recording.length,
          bytes: recording.bytes,
        );

  /// Support's reply on the frame, for [firstName], an activation of
  /// [steps] steps and its reward [amount].
  static String reply(
    String firstName, {
    required int steps,
    required String amount,
  }) =>
      'Thanks, $firstName. ${_confirmed(steps)} confirmed. $amount is in '
      'your wallet.';

  static String _confirmed(int steps) => switch (steps) {
    1 => 'The step',
    2 => 'Both steps',
    _ => 'All ${_words[steps] ?? '$steps'} steps',
  };

  static const _words = {3: 'three', 4: 'four', 5: 'five', 6: 'six'};
}
