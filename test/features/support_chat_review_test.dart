import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/support_files.dart';
import 'package:iqly_mobile/features/help/chat_files.dart';
import 'package:iqly_mobile/features/help/chat_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/help/help_state.dart';
import 'package:iqly_mobile/features/more/more_widgets.dart' show RowGroup;
import 'package:iqly_mobile/ui/chat_composer.dart';
import 'package:iqly_mobile/ui/chat_header.dart';
import 'package:iqly_mobile/ui/chat_media.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/chat_harness.dart';
import '../golden/screens/support_chat_screens_test.dart' show chatNow;
import '../support/chat_fakes.dart';

HelpTicket _pictures(int n) => HelpTicket(
  id: 't_pics',
  subject: 'Payments',
  topic: 'payments',
  status: HelpTicketStatus.open,
  messages: [
    for (var i = 0; i < n; i++)
      HelpMessage(
        author: i.isEven ? HelpAuthor.you : HelpAuthor.support,
        side: i.isEven ? null : HelpSide.iqly,
        body: 'Picture $i',
        at: chatAt(1, 8 + i ~/ 60, i % 60),
        attachment: HelpAttachment(
          id: 'pic_$i',
          name: 'pic_$i.jpg',
          bytes: 240000,
          kind: HelpAttachmentKind.image,
          url: Uri.parse('https://api.test/support/attachments/pic_$i'),
        ),
      ),
  ],
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a long thread builds and downloads only what is near the '
      'screen', (tester) async {
    final files = ScriptedFiles();
    final help = ScriptedHelp(clock: () => chatNow, tickets: [_pictures(40)]);
    await openChat(tester, helpThreadPath('t_pics'), help, files: files);
    expect(find.byType(ChatPicture).evaluate().length, lessThan(10));
    expect(files.fetches.toSet().length, lessThan(10));
    expect(files.fetches, contains('pic_39'));
    expect(files.fetches, isNot(contains('pic_0')));
  });

  testWidgets('the + sheet hugs its rows over the home indicator', (
    tester,
  ) async {
    final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
    await openChat(tester, helpThreadPath('t_short'), help);
    await tester.tap(find.bySemanticsLabel('Attach'));
    await tester.pumpAndSettle();
    final rows = tester.getRect(find.byType(RowGroup).last);
    expect(rows.top, greaterThan(844 / 2));
    expect(rows.bottom, greaterThan(844 - 34 - 2 * 24));
  });

  testWidgets('with the microphone declared, iOS records videos too', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
    await openChat(tester, helpThreadPath('t_short'), help);
    await tester.tap(find.bySemanticsLabel('Attach'));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Record a video'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  test('a recorded video is held to 20 s, under the API\'s 50 MB', () {
    expect(DeviceSupportFiles.videoLength, const Duration(seconds: 20));
  });

  testWidgets('a business name holds still while the thread updates', (
    tester,
  ) async {
    Future<Rect> name(IqChatSync sync) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: IqChatHeader(
                withWhom: IqChatHeaderWith.business,
                avatar: const SizedBox(),
                title: 'Orchid Foods',
                about: 'About: Rate 3 recipes',
                sync: sync,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      return tester.getRect(find.text('Orchid Foods'));
    }

    final idle = await name(IqChatSync.none);
    expect((await name(IqChatSync.updating)).top, idle.top);
    expect((await name(IqChatSync.failed)).top, idle.top);
  });

  testWidgets('after a failed load nothing can be sent, so no new thread '
      'opens', (tester) async {
    final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()])
      ..holdThreads = true;
    await openChat(tester, helpThreadPath('t_short'), help);
    help.fail('t_short');
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    expect(
      tester.widget<IqChatComposer>(find.byType(IqChatComposer)).sending,
      isTrue,
    );
    await tester.enterText(find.byType(EditableText), 'Any news?');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(help.tickets.keys, ['t_short']);
    expect(help.replies, isEmpty);
  });

  testWidgets('scrolled up, a reply waits below behind the down arrow and '
      'its count; the arrow takes the thread to it', (tester) async {
    final help = ScriptedHelp(clock: () => chatNow, tickets: [longThread()]);
    final container = await openChat(
      tester,
      helpThreadPath('withdrawal'),
      help,
    );
    expect(find.bySemanticsLabel('Newest messages'), findsNothing);
    await tester.drag(find.byKey(chatThreadKey), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Newest messages'), findsOneWidget);
    final read = find.text('Access Bank confirmed it on Tuesday.');
    final before = tester.getRect(read);

    final ticket = help.tickets['withdrawal']!;
    help.tickets['withdrawal'] = ticket.copyWith(
      messages: [...ticket.messages, supportReply('It has landed now.')],
    );
    container
        .read(helpTicketsProvider.notifier)
        .follow('withdrawal', quiet: true);
    await tester.pumpAndSettle();
    expect(tester.getRect(read), before);
    expect(find.text('It has landed now.'), findsNothing);
    expect(find.bySemanticsLabel('1 new message'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('1 new message'));
    await tester.pumpAndSettle();
    final canvas = chatCanvas(tester);
    final newest = tester.getRect(find.text('It has landed now.'));
    expect(canvas.bottom - newest.bottom, lessThan(40));
    expect(find.bySemanticsLabel('1 new message'), findsNothing);
  });

  testWidgets('a picture already on the phone shows in the first frame', (
    tester,
  ) async {
    final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
    final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
    await openChat(tester, helpThreadPath('t_short'), help, files: files);
    final states = <IqChatMediaState>[];
    for (var i = 0; i < 3; i++) {
      states.add(
        tester.widget<IqChatMedia>(find.byType(IqChatMedia).first).state,
      );
      await tester.pump();
    }
    expect(states, everyElement(IqChatMediaState.ready));
    expect(files.fetches, isEmpty);
  });

  test('a picture decodes big enough to cover its frame, whatever its '
      'shape', () {
    const frame = Size(906, 516);
    ui.TargetImageSize cover(int w, int h) => CoverImage.coverSize(frame, w, h);
    final wide = cover(4000, 1000);
    expect(wide.height, greaterThanOrEqualTo(516));
    expect(wide.width, greaterThanOrEqualTo(906));
    final tall = cover(1000, 2170);
    expect(tall.width, greaterThanOrEqualTo(906));
    expect(tall.height, greaterThanOrEqualTo(516));
    expect(cover(600, 400).width, isNull);
  });
}
