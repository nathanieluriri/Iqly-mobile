import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/voice_recorder.dart';
import 'package:iqly_mobile/features/help/chat_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/ui/chat_composer.dart';
import 'package:iqly_mobile/ui/chat_media.dart';
import 'package:iqly_mobile/ui/chat_ticks.dart';
import 'package:iqly_mobile/ui/recording_player.dart';
import 'package:video_player/video_player.dart';

import '../golden/golden.dart' show loadAppFonts;
import '../golden/screens/chat_harness.dart';
import '../golden/screens/support_chat_screens_test.dart' show chatNow;
import '../support/chat_fakes.dart';

class _FakePlayer extends VideoPlayerController {
  _FakePlayer(super.uri) : super.networkUrl();

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);

  void playedTo(Duration position) =>
      value = value.copyWith(position: position);
}

IqChatComposer _composer(WidgetTester tester) =>
    tester.widget<IqChatComposer>(find.byType(IqChatComposer));

Future<TestGesture> _hold(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.bySemanticsLabel('Voice note')),
  );
  await tester.pump(IqDurations.holdToRecord);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  return gesture;
}

HelpTicket _withNote({Uri? url}) => shortThread(
  more: [
    HelpMessage(
      author: HelpAuthor.support,
      side: HelpSide.iqly,
      authorName: iqlySupport,
      body: attachmentOnlyBody(HelpAttachmentKind.audio),
      at: chatAt(0, 9, 12),
      attachment: HelpAttachment(
        id: 'up_7',
        name: 'voice-note.m4a',
        bytes: 160000,
        length: const Duration(seconds: 20),
        kind: HelpAttachmentKind.audio,
        url: url ?? Uri.parse('https://api.test/support/attachments/up_7'),
      ),
    ),
  ],
);

void main() {
  setUpAll(loadAppFonts);

  late List<_FakePlayer> players;
  setUp(() {
    players = [];
    Recordings.open = (uri) {
      final player = _FakePlayer(uri);
      players.add(player);
      return player;
    };
  });
  tearDown(() => Recordings.open = openRecording);

  group('recording', () {
    testWidgets('held, the mic records with the time running; let go, the '
        'note shows at once and goes', (tester) async {
      final recorder = ScriptedRecorder();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()])
        ..holdUploads = true;
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      expect(recorder.starts, 1);
      expect(_composer(tester).state, IqChatComposerState.recording);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Slide to cancel'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('0:03'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(recorder.stops, 1);
      expect(_composer(tester).state, IqChatComposerState.empty);
      final going = tester
          .widgetList<IqChatMedia>(find.byType(IqChatMedia))
          .first;
      expect(going.kind, IqChatMediaKind.voice);
      expect(going.state, IqChatMediaState.loading);
      expect(
        tester.widgetList<IqChatTicks>(find.byType(IqChatTicks)).first.state,
        IqChatTicksState.sending,
      );

      help.step(1);
      await tester.pumpAndSettle();
      final sent = help.replies.single;
      expect(sent.body, 'Voice note');
      expect(sent.files.single.kind, HelpAttachmentKind.audio);
      expect(sent.files.single.length, const Duration(seconds: 3));
      expect(
        tester.widgetList<IqChatTicks>(find.byType(IqChatTicks)).first.state,
        IqChatTicksState.saved,
      );
    });

    testWidgets('slid left, the note is thrown away', (tester) async {
      final recorder = ScriptedRecorder();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(_composer(tester).slide, closeTo(0.5, 0.01));
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      expect(recorder.cancels, 1);
      expect(_composer(tester).state, IqChatComposerState.empty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(recorder.stops, 0);
      expect(help.replies, isEmpty);
    });

    testWidgets('a hold under a second sends nothing and says to hold', (
      tester,
    ) async {
      final recorder = ScriptedRecorder()
        ..length = const Duration(milliseconds: 400);
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(find.text(holdToRecord), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(help.replies, isEmpty);
    });

    testWidgets('without the microphone it says so and records nothing', (
      tester,
    ) async {
      final recorder = ScriptedRecorder()..answer = VoiceStart.refused;
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      expect(find.text(micRefused), findsOneWidget);
      expect(_composer(tester).state, IqChatComposerState.empty);
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(recorder.stops, 0);
      expect(help.replies, isEmpty);
    });

    testWidgets('at 5 minutes the note sends itself', (tester) async {
      final recorder = ScriptedRecorder()..length = const Duration(minutes: 5);
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      await tester.pump(const Duration(minutes: 4, seconds: 59));
      await tester.pump();
      expect(find.text('4:59'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(recorder.stops, 1);
      expect(
        help.replies.single.files.single.length,
        const Duration(minutes: 5),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(recorder.stops, 1);
    });
  });

  group('playing', () {
    testWidgets('a voice note plays in its bubble: it comes down once, then '
        'plays and pauses, the bars and the time following it', (tester) async {
      final files = ScriptedFiles();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [_withNote()]);
      await openChat(tester, helpThreadPath('t_short'), help, files: files);
      final voice = find.byWidgetPredicate(
        (w) => w is IqChatMedia && w.kind == IqChatMediaKind.voice,
      );
      IqChatMedia note() => tester.widget<IqChatMedia>(voice);
      expect(note().duration, '0:20');
      expect(note().played, 0);
      expect(files.fetches, isNot(contains('up_7')));

      await tester.tap(voice);
      await tester.pump();
      expect(note().state, IqChatMediaState.loading);
      expect(files.fetches.where((id) => id == 'up_7'), hasLength(1));
      files.land('up_7', chatScreenshot.absolute);
      await tester.pumpAndSettle();
      expect(players.single.dataSource, startsWith('file:'));
      expect(note().playing, isTrue);

      players.single.playedTo(const Duration(seconds: 10));
      await tester.pump();
      expect(note().duration, '0:10');
      expect(note().played, IqChatMedia.bars.length ~/ 2);

      await tester.tap(voice);
      await tester.pumpAndSettle();
      expect(note().playing, isFalse);
      expect(note().duration, '0:10');
    });
  });
}
