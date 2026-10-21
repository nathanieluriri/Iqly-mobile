import 'activations_data.dart';
import 'media_service.dart';
import 'models.dart';

enum HelpTicketStatus { open, replied, resolved }

/// Who wrote a message: the person, or the other side (iQLY support or,
/// about an activation, the business behind it).
enum HelpAuthor { you, support }

/// How iQLY's staff sign their replies.
const iqlySupport = 'iQLY support';

/// A [file] is a document: a PDF, Word, Excel or PowerPoint file, a text
/// or a CSV (the API's `document`, while health says `supportDocuments`).
enum HelpAttachmentKind { image, video, audio, file }

/// Who a thread is with and answered by (contract 12.1 `channel`): iQLY
/// support, or the business behind the activation it asks about.
enum HelpChannel { iqly, business }

/// Which side wrote a reply, or resolved a thread.
enum HelpSide { you, iqly, business }

/// A recording's length or time as files and voice notes show it: "0:31".
String helpLength(Duration length) =>
    '${length.inMinutes}:${(length.inSeconds % 60).toString().padLeft(2, '0')}';

/// The body a message carries when the person sends a file alone, since a
/// message needs words: the thread shows the file without them.
String attachmentOnlyBody(HelpAttachmentKind kind) => switch (kind) {
  HelpAttachmentKind.audio => 'Voice note',
  HelpAttachmentKind.image => 'Photo',
  HelpAttachmentKind.video => 'Video',
  HelpAttachmentKind.file => 'Document',
};

/// A file sent with a message: a screen recording in the frames, and on the
/// live API also a picture or a voice note. [source] is where it plays from
/// (the demo's recordings have none); [id] is the API's upload, [url] where
/// the API serves it (with the bearer token) and [read] the picked file's
/// bytes until it is uploaded.
class HelpAttachment {
  const HelpAttachment({
    required this.name,
    required this.bytes,
    this.length,
    this.source,
    this.id,
    this.kind = HelpAttachmentKind.video,
    this.mime,
    this.url,
    this.read,
    this.preview,
    this.pages,
  });

  final String name;

  /// A picture the app ships (the demo's screenshot), drawn in the thread.
  final String? preview;

  /// A document's pages, where known.
  final int? pages;
  final Duration? length;
  final int bytes;
  final Uri? source;
  final String? id;
  final HelpAttachmentKind kind;
  final String? mime;
  final Uri? url;
  final Future<List<int>> Function()? read;

  /// "0:31", null for a picture or an unknown length.
  String? get lengthLabel {
    final length = this.length;
    return length == null ? null : helpLength(length);
  }

  /// "12 MB", or "68 KB" under a megabyte.
  String get sizeLabel => bytes >= 1000000
      ? '${(bytes / 1000000).round()} MB'
      : '${(bytes / 1000).ceil()} KB';

  /// Uploaded as [id], as the API answered it.
  HelpAttachment uploaded({
    required String id,
    String? name,
    int? bytes,
    Duration? length,
    HelpAttachmentKind? kind,
    String? mime,
  }) => HelpAttachment(
    name: name ?? this.name,
    bytes: bytes ?? this.bytes,
    length: length ?? this.length,
    source: source,
    id: id,
    kind: kind ?? this.kind,
    mime: mime ?? this.mime,
  );
}

class HelpMessage {
  const HelpMessage({
    required this.author,
    required this.body,
    required this.at,
    this.attachment,
    this.more = const [],
    this.authorName,
    this.side,
  });

  /// Who wrote it as the API says (`authorKind`): null on the person's own
  /// and on an API that does not say.
  final HelpSide? side;

  final HelpAuthor author;
  final String body;
  final DateTime at;
  final HelpAttachment? attachment;

  /// What else the API says was sent with it (up to three in all).
  final List<HelpAttachment> more;

  /// Who signed a reply, as the API names them: the business's name, or
  /// [iqlySupport]; null for the person's own and on an API that does not
  /// say.
  final String? authorName;

  /// A reply the business wrote.
  bool get fromBusiness =>
      author == HelpAuthor.support &&
      (side == HelpSide.business ||
          (side == null && authorName != null && authorName != iqlySupport));

  List<HelpAttachment> get attachments => [?attachment, ...more];
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
    this.reference,
    this.lastAt,
    this.channel = HelpChannel.iqly,
    this.withName,
    this.withLogo,
    this.readByIqly,
    this.readByBusiness,
    this.topic,
    this.resolvedBy,
  });

  final String id;

  /// Who the thread is with ([withName] and [withLogo] name the business on
  /// [HelpChannel.business]), from an API with `supportChannels`.
  final HelpChannel channel;
  final String? withName;
  final String? withLogo;

  /// When the other side last opened the thread (`readBy`), so a message
  /// sent before reads as read.
  final DateTime? readByIqly;
  final DateTime? readByBusiness;

  /// Report an issue's topic as the API names it (`payments`).
  final String? topic;

  /// Who marked it resolved, where the app knows.
  final HelpSide? resolvedBy;

  /// The latest time the side that answers opened the thread.
  DateTime? get readAt => switch ((readByIqly, readByBusiness)) {
    (final a?, final b?) => a.isAfter(b) ? a : b,
    (final a, final b) => a ?? b,
  };
  final String subject;
  final HelpTicketStatus status;

  /// Oldest first. An inbox row from the API holds only its last message.
  final List<HelpMessage> messages;

  /// "IQ-HELP-2041", from the API.
  final String? reference;

  /// When the API says the thread last moved, for a row with no messages.
  final DateTime? lastAt;

  /// The activation the ticket is about, if any.
  final String? activationId;
  final bool supportTyping;

  /// The award support put on the ledger when it replied, if any.
  final LedgerEntry? credit;

  /// Support replied and the person has not opened the thread since.
  final bool unread;

  /// The last message.
  DateTime get updatedAt =>
      messages.isEmpty ? lastAt ?? DateTime(2000) : messages.last.at;

  /// Support has answered.
  bool get answered => messages.any((m) => m.author == HelpAuthor.support);

  /// The latest reply from the other side.
  HelpMessage? get lastReply => messages.reversed
      .where((m) => m.author == HelpAuthor.support)
      .firstOrNull;

  /// The business that has answered here, by its latest reply.
  String? get business =>
      messages.reversed.where((m) => m.fromBusiness).firstOrNull?.authorName;

  HelpTicket copyWith({
    HelpTicketStatus? status,
    List<HelpMessage>? messages,
    bool? supportTyping,
    LedgerEntry? credit,
    bool? unread,
    DateTime? readByIqly,
    HelpSide? Function()? resolvedBy,
  }) => HelpTicket(
    id: id,
    subject: subject,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    activationId: activationId,
    supportTyping: supportTyping ?? this.supportTyping,
    credit: credit ?? this.credit,
    unread: unread ?? this.unread,
    reference: reference,
    lastAt: lastAt,
    channel: channel,
    withName: withName,
    withLogo: withLogo,
    readByIqly: readByIqly ?? this.readByIqly,
    readByBusiness: readByBusiness,
    topic: topic,
    resolvedBy: resolvedBy == null ? this.resolvedBy : resolvedBy(),
  );
}

class HelpRequest {
  const HelpRequest({
    required this.subject,
    required this.message,
    this.attachment,
    this.activation,
    this.topic,
    this.idempotencyKey,
  });

  final String subject;
  final String message;
  final HelpAttachment? attachment;

  /// The key the screen keeps for this request until the API has answered
  /// it for sure, so a send whose answer was lost opens one thread.
  final String? idempotencyKey;

  /// A report's topic as the API names it (`the_app`); a report's subject
  /// is the topic as Report an issue lists it.
  final String? topic;

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

  /// iQLY support's one reply promise (20 Oct); a business makes none.
  static const replyLine = 'Usually replies within a day';

  /// The B21 inbox (1589:118540) as of [now]: the iQLY thread about the
  /// withdrawal (1589:118774, 1589:119167) with two replies unread, the
  /// Orchid Foods activation thread (1589:122097) and the resolved Kudi Box
  /// one (1589:122537). The frames read on Tuesday 20 October, so each time
  /// is that many days before [now]'s day: 8 Oct is 12 days back.
  static List<HelpTicket> conversations(String firstName, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int daysBack, int hour, int minute) => today
        .subtract(Duration(days: daysBack))
        .add(Duration(hours: hour, minutes: minute));
    return [
      HelpTicket(
        id: 'withdrawal',
        subject: 'Withdrawal to Access Bank',
        topic: 'payments',
        status: HelpTicketStatus.replied,
        unread: true,
        readByIqly: at(0, 9, 13),
        messages: [
          HelpMessage(
            author: HelpAuthor.you,
            body:
                'Hi, my withdrawal of ₦10,000.00 has said pending since '
                'Monday.',
            at: at(12, 14, 20),
            attachment: const HelpAttachment(
              name: 'withdrawals.jpg',
              bytes: 19000,
              kind: HelpAttachmentKind.image,
              preview: 'assets/samples/support/withdrawals-screenshot.jpg',
            ),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.iqly,
            authorName: iqlySupport,
            body:
                'Hi $firstName, Access Bank is still confirming it. It should '
                'land by tomorrow. We will message you here when it does.',
            at: at(12, 15, 6),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.iqly,
            authorName: iqlySupport,
            body: 'Access Bank confirmed it on Tuesday.',
            at: at(3, 10, 5),
            attachment: const HelpAttachment(
              name: 'Withdrawal receipt.pdf',
              bytes: 64000,
              kind: HelpAttachmentKind.file,
              mime: 'application/pdf',
              pages: 1,
            ),
          ),
          HelpMessage(
            author: HelpAuthor.you,
            body: attachmentOnlyBody(HelpAttachmentKind.audio),
            at: at(1, 18, 48),
            attachment: const HelpAttachment(
              name: 'voice-note.m4a',
              bytes: 190000,
              length: Duration(seconds: 24),
              kind: HelpAttachmentKind.audio,
            ),
          ),
          HelpMessage(
            author: HelpAuthor.you,
            body: 'I still can’t see it in my bank app.',
            at: at(1, 18, 49),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.iqly,
            authorName: iqlySupport,
            body: 'Thanks for the voice note, $firstName.',
            at: at(0, 9, 12),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.iqly,
            authorName: iqlySupport,
            body:
                'The reference on the receipt is the one Access Bank needs. '
                'Show it to them and they can trace the transfer.',
            at: at(0, 9, 13),
          ),
        ],
      ),
      HelpTicket(
        id: 'orchid-foods',
        subject: 'Orchid Foods activation',
        status: HelpTicketStatus.open,
        activationId: 'a1',
        channel: HelpChannel.business,
        withName: 'Orchid Foods',
        withLogo: 'assets/samples/logos/orchid-foods.svg',
        readByBusiness: at(1, 18, 10),
        readByIqly: at(1, 9, 5),
        messages: [
          HelpMessage(
            author: HelpAuthor.you,
            body:
                'Rated all 3 recipes on Thursday and sent my recording. It '
                'still says Checking.',
            at: at(4, 14, 20),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.iqly,
            authorName: iqlySupport,
            body:
                'Hi $firstName, we’ve asked Orchid Foods to check your '
                'recording.',
            at: at(1, 9, 5),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.business,
            authorName: 'Orchid Foods',
            body: 'Please send a clearer recording.',
            at: at(1, 16, 40),
          ),
          HelpMessage(
            author: HelpAuthor.you,
            body: attachmentOnlyBody(HelpAttachmentKind.audio),
            at: at(1, 18, 2),
            attachment: const HelpAttachment(
              name: 'voice-note.m4a',
              bytes: 330000,
              length: Duration(seconds: 42),
              kind: HelpAttachmentKind.audio,
            ),
          ),
        ],
      ),
      HelpTicket(
        id: 'kudi-box',
        subject: 'Kudi Box activation',
        status: HelpTicketStatus.resolved,
        activationId: 'a2',
        channel: HelpChannel.business,
        withName: 'Kudi Box',
        withLogo: 'assets/samples/logos/kudi-box.svg',
        readByBusiness: at(18, 14, 14),
        resolvedBy: HelpSide.business,
        messages: [
          HelpMessage(
            author: HelpAuthor.you,
            body:
                'Did all three steps on Thursday. Sent proof of step 2 '
                'yesterday, still says Checking.',
            at: at(18, 13, 28),
          ),
          HelpMessage(
            author: HelpAuthor.support,
            side: HelpSide.business,
            authorName: 'Kudi Box',
            body: reply(firstName, steps: 3, amount: '₦1,500.00'),
            at: at(18, 14, 14),
          ),
        ],
      ),
    ];
  }

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
