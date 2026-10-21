import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/support_files.dart';
import 'package:iqly_mobile/features/help/chat_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_attachment_screen.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/help/help_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_header.dart';
import 'package:iqly_mobile/ui/chat_media.dart';
import 'package:iqly_mobile/ui/chat_pill.dart';
import 'package:iqly_mobile/ui/chat_ticks.dart';
import 'package:iqly_mobile/ui/search_box.dart';
import 'package:iqly_mobile/ui/skeleton.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/chat_harness.dart';
import '../golden/screens/support_chat_screens_test.dart' show chatNow;
import '../support/chat_fakes.dart';

IqChatMedia _media(WidgetTester tester) =>
    tester.widget<IqChatMedia>(find.byType(IqChatMedia).first);

Iterable<IqChatTicks> _ticks(WidgetTester tester, IqChatTicksState state) =>
    tester
        .widgetList<IqChatTicks>(find.byType(IqChatTicks))
        .where((t) => t.state == state);

void main() {
  setUpAll(loadAppFonts);

  group('the thread starts at the top', () {
    testWidgets('a short thread sits under its day at the top', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(tester, helpThreadPath('t_short'), help);
      final canvas = chatCanvas(tester);
      final day = tester.getRect(find.text('Yesterday'));
      final bubble = tester.getRect(find.text('can’t remember'));
      expect(day.top - canvas.top, lessThan(IqSpace.s6));
      expect(bubble.top, greaterThan(day.bottom));
      expect(canvas.bottom - bubble.bottom, greaterThan(200));
    });

    testWidgets('a long thread opens at its newest message', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [longThread()]);
      await openChat(tester, helpThreadPath('withdrawal'), help);
      final canvas = chatCanvas(tester);
      final newest = tester.getRect(
        find.textContaining('The reference on the receipt'),
      );
      expect(newest.bottom, lessThanOrEqualTo(canvas.bottom));
      expect(canvas.bottom - newest.bottom, lessThan(IqSpace.s10));
      final oldest = tester.getRect(
        find.textContaining('has said pending since Monday'),
      );
      expect(oldest.bottom, lessThan(canvas.top));
    });

    testWidgets('while it scrolls, the day on screen rides pinned at the '
        'top, gone a moment after it stops', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [longThread()]);
      await openChat(tester, helpThreadPath('withdrawal'), help);
      expect(find.byKey(chatPinnedDayKey), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(chatThreadKey)),
      );
      await gesture.moveBy(const Offset(0, 120));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 200));
      final pinned = find.byKey(chatPinnedDayKey);
      expect(pinned, findsOneWidget);
      final canvas = chatCanvas(tester);
      expect(tester.getRect(pinned).top - canvas.top, lessThan(IqSpace.s4));
      final label = tester.widget<IqChatPill>(pinned).label;
      final inline = find.byWidgetPredicate(
        (w) => w is IqChatPill && w.label == label && w.key != chatPinnedDayKey,
      );
      expect(tester.getRect(inline).bottom, lessThan(canvas.top + IqSpace.s4));
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: pinned, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(opacity(), 1);
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(opacity(), 0);
    });

    testWidgets('new messages land at the end without moving what is read; '
        'at the end they show', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [longThread()]);
      final container = await openChat(
        tester,
        helpThreadPath('withdrawal'),
        help,
      );
      await tester.drag(find.byKey(chatThreadKey), const Offset(0, 300));
      await tester.pumpAndSettle();
      final read = find.text('I still can’t see it in my bank app.');
      final before = tester.getRect(read);
      void lands(String body) {
        final ticket = help.tickets['withdrawal']!;
        help.tickets['withdrawal'] = ticket.copyWith(
          messages: [...ticket.messages, supportReply(body)],
        );
        container
            .read(helpTicketsProvider.notifier)
            .follow('withdrawal', quiet: true);
      }

      lands('It has landed now.');
      await tester.pumpAndSettle();
      expect(tester.getRect(read), before);

      await tester.drag(find.byKey(chatThreadKey), const Offset(0, -3000));
      await tester.pumpAndSettle();
      lands('Anything else we can help with?');
      await tester.pumpAndSettle();
      final canvas = chatCanvas(tester);
      final newest = tester.getRect(
        find.text('Anything else we can help with?'),
      );
      expect(newest.bottom, lessThanOrEqualTo(canvas.bottom));
      expect(canvas.bottom - newest.bottom, lessThan(IqSpace.s10));
    });
  });

  group('loading', () {
    testWidgets('skeleton bubbles hold the canvas until the thread arrives, '
        'and the header never reads a bare About:', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()])
        ..holdThreads = true;
      await openChat(tester, helpThreadPath('t_short'), help);
      expect(find.text('About:'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(IqChatHeader),
          matching: find.byType(IqSkeleton),
        ),
        findsOneWidget,
      );
      await tester.pump(IqDurations.skeletonDelay);
      await tester.pump();
      expect(find.byKey(chatSkeletonKey), findsOneWidget);
      expect(find.text('can’t remember'), findsNothing);

      help.answer('t_short');
      await tester.pump(IqDurations.skeletonMin);
      await tester.pumpAndSettle();
      expect(find.byKey(chatSkeletonKey), findsNothing);
      expect(find.text('About: Payments'), findsOneWidget);
      expect(find.text('can’t remember'), findsOneWidget);
    });
  });

  group('reopening', () {
    testWidgets('a thread the phone kept shows at once with Updating, and '
        'the answer lands in place', (tester) async {
      final help =
          ScriptedHelp(
              clock: () => chatNow,
              tickets: [
                shortThread(
                  more: [supportReply('Which bank did you send it to?')],
                ),
              ],
            )
            ..kept['t_short'] = shortThread()
            ..holdThreads = true;
      await openChat(tester, helpThreadPath('t_short'), help);
      expect(find.byKey(chatSkeletonKey), findsNothing);
      expect(find.text('can’t remember'), findsOneWidget);
      expect(find.text('About: Payments'), findsOneWidget);
      expect(find.text('Updating'), findsOneWidget);
      expect(find.text('Usually replies within a day'), findsNothing);
      final before = tester.getRect(find.text('can’t remember'));

      help.answer('t_short');
      await tester.pumpAndSettle();
      expect(find.text('Updating'), findsNothing);
      expect(find.text('Usually replies within a day'), findsOneWidget);
      expect(find.text('Which bank did you send it to?'), findsOneWidget);
      expect(tester.getRect(find.text('can’t remember')), before);
    });

    testWidgets('a read that fails says Couldn’t update over the kept '
        'thread, and Try again reads again', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()])
        ..kept['t_short'] = shortThread()
        ..holdThreads = true;
      await openChat(tester, helpThreadPath('t_short'), help);
      help.fail('t_short');
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t update'), findsOneWidget);
      expect(find.text('can’t remember'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(IqChatHeader),
          matching: find.text('Try again'),
        ),
      );
      await tester.pump();
      expect(find.text('Updating'), findsOneWidget);
      expect(help.watches, ['t_short', 't_short']);
      help.answer('t_short');
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t update'), findsNothing);
      expect(find.text('Updating'), findsNothing);
    });

    testWidgets('the inbox shows what the phone kept at once, then reads it '
        'again: Updating, Couldn’t update with Try again, then nothing', (
      tester,
    ) async {
      final help =
          ScriptedHelp(
              clock: () => chatNow,
              tickets: [shortThread(), longThread()],
            )
            ..keptInbox = [shortThread()]
            ..holdInbox = true;
      await openChat(tester, Routes.support, help);
      expect(find.text('Updating'), findsOneWidget);
      expect(find.text('You: can’t remember'), findsOneWidget);

      final search = tester.getRect(find.byType(IqSearchBox));
      help.failInbox();
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t update'), findsOneWidget);
      expect(find.text('You: can’t remember'), findsOneWidget);
      expect(tester.getRect(find.byType(IqSearchBox)), search);

      await tester.tap(find.text('Couldn’t update'));
      await tester.pump();
      expect(find.text('Updating'), findsOneWidget);
      help.answerInbox();
      await tester.pumpAndSettle();
      expect(find.text('Updating'), findsNothing);
      expect(find.text('Couldn’t update'), findsNothing);
      expect(find.text('Open · 2'), findsOneWidget);
    });
  });

  group('pictures', () {
    testWidgets('a picture loads with its progress, offers Try again when '
        'it fails, then shows; the viewer shares it', (tester) async {
      final files = ScriptedFiles();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(tester, helpThreadPath('t_short'), help, files: files);
      expect(_media(tester).state, IqChatMediaState.loading);
      expect(_media(tester).progress, isNull);
      files.progress('up_9', 0.4);
      await tester.pump();
      expect(_media(tester).progress, 0.4);

      files.refuse('up_9');
      await tester.pumpAndSettle();
      expect(_media(tester).state, IqChatMediaState.failed);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.byType(IqChatMedia));
      await tester.pump();
      expect(_media(tester).state, IqChatMediaState.loading);
      files.land('up_9', chatScreenshot);
      await tester.pumpAndSettle();
      expect(_media(tester).state, IqChatMediaState.ready);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(IqChatMedia),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as ResizeImage).imageProvider, isA<FileImage>());

      await tester.tap(find.byType(IqChatMedia));
      await tester.pumpAndSettle();
      expect(find.byType(HelpAttachmentScreen), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(files.fetches, ['up_9', 'up_9']);
    });

    testWidgets('the viewer shows the picture coming, Try again when it '
        'did not, then the picture', (tester) async {
      final files = ScriptedFiles();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(tester, helpThreadPath('t_short'), help, files: files);
      await tester.tap(find.byType(IqChatMedia));
      await tester.pumpAndSettle();
      expect(find.byType(HelpAttachmentScreen), findsOneWidget);
      expect(
        tester.widget<IqChatMedia>(find.byType(IqChatMedia).last).state,
        IqChatMediaState.loading,
      );

      files.refuse('up_9');
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t load. Check your connection.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again').last);
      await tester.pump();
      files.land('up_9', chatScreenshot);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Couldn’t load. Check your connection.'), findsNothing);
    });
  });

  group('the composer', () {
    testWidgets('+ offers photos and videos, a photo or a video, never '
        'audio, and the picked file waits as a preview', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(tester, helpThreadPath('t_short'), help);
      await tester.tap(find.bySemanticsLabel('Attach'));
      await tester.pumpAndSettle();
      expect(find.text('Photos and videos'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Record a video'), findsOneWidget);
      expect(
        find.textContaining(RegExp('voice|audio', caseSensitive: false)),
        findsNothing,
      );
      expect(help.sources, isEmpty);

      help.picked = HelpAttachment(
        name: 'IMG_0001.jpg',
        bytes: 1200000,
        kind: HelpAttachmentKind.image,
        read: () async => chatPng,
      );
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(help.sources, [SupportSource.camera]);
      expect(find.text('Photo · 1 MB'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove'), findsOneWidget);
      expect(find.bySemanticsLabel('Send'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Photo · 1 MB'), findsNothing);
      expect(find.bySemanticsLabel('Voice note'), findsOneWidget);
    });

    testWidgets('a picture sent shows at once from the phone while it goes '
        'up, then lands saved without downloading', (tester) async {
      final files = ScriptedFiles()..keptFiles['up_9'] = chatScreenshot;
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()])
        ..holdUploads = true
        ..picked = HelpAttachment(
          name: 'IMG_0002.jpg',
          bytes: 300000,
          kind: HelpAttachmentKind.image,
          read: () async => chatPng,
        );
      await openChat(tester, helpThreadPath('t_short'), help, files: files);
      await tester.tap(find.bySemanticsLabel('Attach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photos and videos'));
      await tester.pumpAndSettle();
      expect(help.sources, [SupportSource.photos]);
      expect(find.text('Photo · 0%'), findsOneWidget);
      help.step(0.3);
      await tester.pumpAndSettle();
      expect(find.text('Photo · 30%'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Photo · 30%'), findsNothing);
      expect(_ticks(tester, IqChatTicksState.sending), hasLength(1));
      final going = tester
          .widgetList<IqChatMedia>(find.byType(IqChatMedia))
          .last;
      expect(going.state, IqChatMediaState.loading);
      expect(going.progress, 0.3);
      expect(going.image, isNotNull);
      expect(help.replies, isEmpty);

      help.step(1);
      await tester.pumpAndSettle();
      expect(help.replies.single.body, 'Photo');
      expect(help.replies.single.files.single.id, 'up_1');
      expect(files.keptSent, ['up_1']);
      expect(_ticks(tester, IqChatTicksState.sending), isEmpty);
      expect(
        tester.widgetList<IqChatMedia>(find.byType(IqChatMedia)).last.state,
        IqChatMediaState.ready,
      );
      expect(files.fetches, isEmpty);
    });

    testWidgets('the mic says voice notes are coming and opens no picker', (
      tester,
    ) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(tester, helpThreadPath('t_short'), help);
      await tester.tap(find.bySemanticsLabel('Voice note'));
      await tester.pump();
      expect(find.text(voiceNotesComing), findsOneWidget);
      expect(find.text('Photos and videos'), findsNothing);
      expect(help.sources, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
