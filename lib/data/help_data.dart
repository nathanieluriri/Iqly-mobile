import 'activations_data.dart';
import 'media_service.dart';
import 'models.dart';

enum HelpTicketStatus { open, replied, resolved }

enum HelpAuthor { you, support }

/// A screen recording sent with a message. [source] is where it plays from;
/// the demo's recordings have none.
class HelpAttachment {
  const HelpAttachment({
    required this.name,
    required this.length,
    required this.bytes,
    this.source,
  });

  final String name;
  final Duration length;
  final int bytes;
  final Uri? source;

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
    this.unread = false,
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

  /// Support replied and the person has not opened the thread since.
  final bool unread;

  /// The last message.
  DateTime get updatedAt => messages.last.at;

  /// Support has answered.
  bool get answered => messages.any((m) => m.author == HelpAuthor.support);

  HelpTicket copyWith({
    HelpTicketStatus? status,
    List<HelpMessage>? messages,
    bool? supportTyping,
    LedgerEntry? credit,
    bool? unread,
  }) => HelpTicket(
    id: id,
    subject: subject,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    activationId: activationId,
    supportTyping: supportTyping ?? this.supportTyping,
    credit: credit ?? this.credit,
    unread: unread ?? this.unread,
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

/// One common question and its answer.
class Faq {
  const Faq(this.question, this.answer);

  final String question;
  final String answer;
}

/// The B10 thread (141:5818, 141:5876), about the activation the person
/// asked from. In the frames it is Kudi Box, whose B8 reward is ₦1,500:
/// support confirms the three steps and credits the reward on the ledger
/// row the activation's own payout uses, so it counts once whichever pays
/// it. On the DemoData wallet (available ₦15,000.00, one ₦10,000.00
/// withdrawal on hold, earned ₦65,000.00) that gives ₦16,500.00 available,
/// ₦10,000.00 on hold, ₦66,500.00 earned (the frame reads the older
/// ₦14,000.00 and ₦64,000.00).
abstract final class DemoHelp {
  /// B21 · Help centre (431:19394): the four common questions, and the one
  /// more that searching "withdraw" finds (436:19729). Only the first answer
  /// is in Figma (436:19673); the others are written from the product's own
  /// rules for the owner to sign off.
  static const faqs = [
    Faq(
      'When do I get paid after a brief closes?',
      'The business picks winners within a week of the close. Rewards land '
          'in your wallet right after, and you can withdraw them to your bank.',
    ),
    Faq(
      'Why was my submission not selected?',
      'The business picks the answers that fit its brief best. Not selected '
          'means it chose others this time; the result shows the winners.',
    ),
    Faq(
      'How long does a withdrawal take?',
      'Most withdrawals arrive the same day. Each one shows its steps in '
          'Activity: Requested, Sent to bank, Arrived.',
    ),
    Faq(
      'Can I edit a submission after sending?',
      'No. Each brief takes one submission, so check it before you send. '
          'Drafts stay yours to change until then.',
    ),
    Faq(
      'Why did my withdrawal fail?',
      'The bank turned it down, most often because the account name didn’t '
          'match. Nothing left your wallet, so you can withdraw again to an '
          'account in your name.',
    ),
  ];

  /// The questions Help centre lists before anything is typed.
  static const commonFaqs = 4;

  /// The one support reply line (designer answer 42).
  static const replyLine =
      'Usually replies within an hour on weekdays, within a day at weekends.';

  /// The two past conversations of B21 · Support (485:39190): the
  /// withdrawal chat (431:19583) and the Kudi Box activation thread.
  /// Their times are the frames' own (Saturday 3 and Friday 2 October).
  static List<HelpTicket> conversations(String firstName) => [
    HelpTicket(
      id: 'withdrawal',
      subject: 'Withdrawal to Access Bank',
      status: HelpTicketStatus.replied,
      unread: true,
      messages: [
        HelpMessage(
          author: HelpAuthor.you,
          body:
              'Hi, my withdrawal of ₦10,000.00 has said pending since Monday.',
          at: DateTime(2026, 10, 3, 14, 20),
        ),
        HelpMessage(
          author: HelpAuthor.support,
          body:
              'Hi $firstName, Access Bank is still confirming it. It should '
              'land by tomorrow. We will message you here when it does.',
          at: DateTime(2026, 10, 3, 15, 6),
        ),
      ],
    ),
    HelpTicket(
      id: 'kudi-box',
      subject: 'Kudi Box · step 2 proof',
      status: HelpTicketStatus.replied,
      activationId: 'a2',
      messages: [
        HelpMessage(
          author: HelpAuthor.you,
          body:
              'Did all three steps on Thursday. Sent proof of step 2 '
              'yesterday, still says Checking.',
          at: DateTime(2026, 10, 2, 13, 28),
          attachment: recording,
        ),
        HelpMessage(
          author: HelpAuthor.support,
          body: reply(firstName, steps: 3, amount: '₦1,500.00'),
          at: DateTime(2026, 10, 2, 14, 14),
        ),
      ],
    ),
  ];

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
