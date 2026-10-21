import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/features/help/chat_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/help/help_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/chat_media.dart';

import '../../support/chat_fakes.dart';
import '../golden.dart';
import 'chat_harness.dart';
import 'support_chat_screens_test.dart' show chatNow;

Future<void> _shot(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/chat_state_$name.png',
  );
}

ScriptedHelp _help({Iterable<HelpTicket>? tickets}) =>
    ScriptedHelp(clock: () => chatNow, tickets: tickets ?? [shortThread()]);

HelpAttachment _picked() => HelpAttachment(
  name: 'IMG_0002.jpg',
  bytes: 300000,
  kind: HelpAttachmentKind.image,
  source: Uri.file(chatScreenshot.absolute.path),
  read: () async => chatPng,
);

/// The support chat's states at 390 x 844, as the owner asked for them
/// (21 Oct): where a thread starts, its loader, reopening from the phone,
/// pictures coming and failing, the + sheet, a file waiting and going.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('a short thread starts at the top under its day', (tester) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    await openChat(tester, helpThreadPath('t_short'), _help(), files: files);
    await _shot(tester, 'short_top');
  });

  testWidgets('a long thread pins the day on screen while it scrolls', (
    tester,
  ) async {
    await openChat(
      tester,
      helpThreadPath('withdrawal'),
      _help(tickets: [longThread()]),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(chatThreadKey)),
    );
    await gesture.moveBy(const Offset(0, 160));
    await gesture.moveBy(const Offset(0, 160));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await _shot(tester, 'pinned_day');
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('a thread never kept loads on skeleton bubbles', (tester) async {
    final help = _help()..holdThreads = true;
    await openChat(tester, helpThreadPath('t_short'), help);
    await tester.pump(IqDurations.skeletonDelay);
    await tester.pump();
    await _shot(tester, 'loading');
    help.answer('t_short');
    await tester.pump(IqDurations.skeletonMin);
    await tester.pumpAndSettle();
  });

  testWidgets('a kept thread opens at once, Updating under the name', (
    tester,
  ) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    final help = _help()
      ..kept['t_short'] = shortThread()
      ..holdThreads = true;
    await openChat(tester, helpThreadPath('t_short'), help, files: files);
    await _shot(tester, 'updating');
    help.answer('t_short');
    await tester.pumpAndSettle();
  });

  testWidgets('a kept thread that could not update says so', (tester) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    final help = _help()
      ..kept['t_short'] = shortThread()
      ..holdThreads = true;
    await openChat(tester, helpThreadPath('t_short'), help, files: files);
    help.fail('t_short');
    await tester.pumpAndSettle();
    await _shot(tester, 'could_not_update');
  });

  testWidgets('the answer lands in place and the line goes', (tester) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    final help =
        _help(
            tickets: [
              shortThread(
                more: [supportReply('Which bank did you send it to?')],
              ),
            ],
          )
          ..kept['t_short'] = shortThread()
          ..holdThreads = true;
    await openChat(tester, helpThreadPath('t_short'), help, files: files);
    help.answer('t_short');
    await tester.pumpAndSettle();
    await _shot(tester, 'updated');
  });

  testWidgets('a picture coming down, and one that did not', (tester) async {
    final files = ScriptedFiles();
    await openChat(tester, helpThreadPath('t_short'), _help(), files: files);
    files.progress('up_9', 0.4);
    await tester.pumpAndSettle();
    await _shot(tester, 'picture_loading');
    files.refuse('up_9');
    await tester.pumpAndSettle();
    await _shot(tester, 'picture_failed');
  });

  testWidgets('the viewer shows the picture coming, then Try again', (
    tester,
  ) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles();
    await openChat(tester, helpThreadPath('t_short'), _help(), files: files);
    await tester.tap(find.byType(IqChatMedia));
    await tester.pumpAndSettle();
    files.progress('up_9', 0.6);
    await tester.pumpAndSettle();
    await _shot(tester, 'viewer_loading');
    files.refuse('up_9');
    await tester.pumpAndSettle();
    await _shot(tester, 'viewer_failed');
    await tester.tap(find.text('Try again').last);
    await tester.pump();
    files.land('up_9', chatScreenshot);
    await tester.pumpAndSettle();
    await _shot(tester, 'viewer_picture');
  });

  testWidgets('+ offers the kinds of file first', (tester) async {
    await openChat(tester, helpThreadPath('t_short'), _help());
    await tester.tap(find.bySemanticsLabel('Attach'));
    await tester.pumpAndSettle();
    await _shot(tester, 'attach_sheet');
  });

  testWidgets('the picked picture waits as a preview, then goes at once', (
    tester,
  ) async {
    await warmPicture(tester, chatScreenshot);
    await warmPicture(tester, chatScreenshot.absolute);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    final help = _help()
      ..holdUploads = true
      ..picked = _picked();
    await openChat(tester, helpThreadPath('t_short'), help, files: files);
    await tester.tap(find.bySemanticsLabel('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photos and videos'));
    await tester.pumpAndSettle();
    help.step(0.3);
    await tester.pumpAndSettle();
    await _shot(tester, 'staged');
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    help.step(0.6);
    await tester.pumpAndSettle();
    await _shot(tester, 'sending');
    help.step(1);
    await tester.pumpAndSettle();
    await _shot(tester, 'sent');
  });

  testWidgets('a document waits by its name, then sits as a file row', (
    tester,
  ) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    final help = _help()
      ..picked = HelpAttachment(
        name: 'Withdrawal statement.pdf',
        bytes: 64000,
        kind: HelpAttachmentKind.file,
        mime: 'application/pdf',
        read: () async => chatPng,
      );
    await openChat(tester, helpThreadPath('t_short'), help, files: files);
    await tester.tap(find.bySemanticsLabel('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();
    await _shot(tester, 'document_staged');
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    await _shot(tester, 'document_sent');
  });

  testWidgets('scrolled up, a new answer waits behind the down arrow', (
    tester,
  ) async {
    final help = _help(tickets: [longThread()]);
    final container = await openChat(
      tester,
      helpThreadPath('withdrawal'),
      help,
    );
    await tester.drag(find.byKey(chatThreadKey), const Offset(0, 400));
    await tester.pumpAndSettle();
    final ticket = help.tickets['withdrawal']!;
    help.tickets['withdrawal'] = ticket.copyWith(
      messages: [...ticket.messages, supportReply('It has landed now.')],
    );
    container
        .read(helpTicketsProvider.notifier)
        .follow('withdrawal', quiet: true);
    await tester.pumpAndSettle();
    await _shot(tester, 'new_below');
  });

  testWidgets('the mic says voice notes come next', (tester) async {
    await warmPicture(tester, chatScreenshot);
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    await openChat(tester, helpThreadPath('t_short'), _help(), files: files);
    await tester.tap(find.bySemanticsLabel('Voice note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectMatchesGolden(
      find.byType(MaterialApp),
      'goldens/chat_state_mic.png',
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('the inbox opens on what the phone kept', (tester) async {
    final help = _help(tickets: [shortThread(), longThread()])
      ..keptInbox = [shortThread(), longThread()]
      ..holdInbox = true;
    await openChat(tester, Routes.support, help);
    await _shot(tester, 'inbox_updating');
    help.failInbox();
    await tester.pumpAndSettle();
    await _shot(tester, 'inbox_could_not_update');
  });
}
