import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/signed_in_files.dart';
import 'package:iqly_mobile/features/help/chat_files.dart' show CoverImage;
import 'package:iqly_mobile/ui/chat_canvas.dart';
import 'package:iqly_mobile/ui/chat_media.dart';

import '../../support/chat_fakes.dart';
import 'app_harness.dart';
import 'help_harness.dart';
import 'polls_notifications_help_harness.dart';
import 'support_chat_screens_test.dart' show chatNow;

final chatPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP49eYSAAWcArlITY1UAAAAAElFTkSuQmCC',
);

/// The support sample screenshot, as a file on disk.
final chatScreenshot = File(
  'assets/samples/support/withdrawals-screenshot.jpg',
);

DateTime chatAt(int daysBack, int hour, int minute) =>
    DateTime(chatNow.year, chatNow.month, chatNow.day - daysBack, hour, minute);

/// The owner's thread (21 Oct): one picture sent yesterday, about Payments.
HelpTicket shortThread({List<HelpMessage> more = const []}) => HelpTicket(
  id: 't_short',
  subject: 'Payments',
  topic: 'payments',
  status: HelpTicketStatus.open,
  messages: [
    HelpMessage(
      author: HelpAuthor.you,
      body: 'can’t remember',
      at: chatAt(1, 17, 36),
      attachment: HelpAttachment(
        id: 'up_9',
        name: '12437.jpg',
        bytes: 240000,
        kind: HelpAttachmentKind.image,
        url: Uri.parse('https://api.test/support/attachments/up_9'),
      ),
    ),
    ...more,
  ],
);

HelpMessage supportReply(String body, {int daysBack = 0}) => HelpMessage(
  author: HelpAuthor.support,
  side: HelpSide.iqly,
  authorName: iqlySupport,
  body: body,
  at: chatAt(daysBack, 9, 20),
);

/// The B21 withdrawal thread, already read.
HelpTicket longThread() => DemoHelp.conversations(
  'Adaeze',
  chatNow,
).firstWhere((t) => t.id == 'withdrawal').copyWith(unread: false);

/// The chat at [location] on [help], the account's files from [files].
Future<ProviderContainer> openChat(
  WidgetTester tester,
  String location,
  ScriptedHelp help, {
  ScriptedFiles? files,
  List<Override> overrides = const [],
}) => pumpApp(
  tester,
  location,
  clock: () => chatNow,
  supportChannels: true,
  overrides: [
    ...laneOverrides(help: help),
    ...helpActivations(),
    if (files != null) signedInFilesProvider.overrideWithValue(files),
    ...overrides,
  ],
);

Rect chatCanvas(WidgetTester tester) =>
    tester.getRect(find.byType(IqChatCanvas));

/// Decodes [file] as the chat draws it (bubbles, the waiting thumbnail
/// and the viewer) off the fake clock before a screen draws it there: a
/// picture first loaded on the fake clock never finishes for a golden.
Future<void> warmPicture(WidgetTester tester, File file) async {
  final providers = <ImageProvider<Object>>[
    for (final size in const [
      Size(302, IqChatMedia.frameHeight),
      Size(210, IqChatMedia.frameHeight),
      Size(48, 48),
      Size(390, 390),
    ])
      CoverImage(FileImage(file), size),
    ResizeImage(FileImage(file), width: 780),
  ];
  await tester.runAsync(() async {
    for (final provider in providers) {
      final stream = provider.resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) {
          if (!done.isCompleted) done.complete();
        },
        onError: (_, _) {
          if (!done.isCompleted) done.complete();
        },
      );
      stream.addListener(listener);
      await done.future;
      stream.removeListener(listener);
    }
  });
}
