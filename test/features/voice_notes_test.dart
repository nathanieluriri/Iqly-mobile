import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/voice_recorder.dart';
import 'package:iqly_mobile/features/help/chat_state.dart';
import 'package:iqly_mobile/features/help/chat_thread_screen.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/ui/chat_composer.dart';
import 'package:iqly_mobile/ui/chat_media.dart';
import 'package:iqly_mobile/ui/chat_ticks.dart';
import 'package:iqly_mobile/ui/recording_player.dart';
import 'package:iqly_mobile/ui/toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

IqToast _toast(WidgetTester tester) =>
    tester.widget<IqToast>(find.byType(IqToast));

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
      expect(_toast(tester).kind, IqToastKind.hint);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(help.replies, isEmpty);
    });

    testWidgets('a tap on the mic says to hold, as a hint', (tester) async {
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [
          voiceRecorderProvider.overrideWithValue(ScriptedRecorder()),
        ],
      );
      await tester.tap(find.bySemanticsLabel('Voice note'));
      await tester.pump();
      await tester.pump();
      expect(find.text(holdToRecord), findsOneWidget);
      expect(_toast(tester).kind, IqToastKind.hint);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('without the microphone on Android it gives the steps and '
        'records nothing', (tester) async {
      final recorder = ScriptedRecorder()..answer = VoiceStart.refused;
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      expect(find.text(micRefusedSteps), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(micRefusedSteps), findsOneWidget);
      expect(_composer(tester).state, IqChatComposerState.empty);
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(recorder.stops, 0);
      expect(help.replies, isEmpty);
    });

    testWidgets('without the microphone on iOS it offers Settings', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final recorder = ScriptedRecorder()..answer = VoiceStart.refused;
        final device = DemoDeviceService(delay: Duration.zero);
        final help = ScriptedHelp(
          clock: () => chatNow,
          tickets: [shortThread()],
        );
        await openChat(
          tester,
          helpThreadPath('t_short'),
          help,
          overrides: [
            voiceRecorderProvider.overrideWithValue(recorder),
            deviceServiceProvider.overrideWithValue(device),
          ],
        );
        final gesture = await _hold(tester);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text(micRefused), findsOneWidget);
        expect(find.text(micRefusedIos), findsOneWidget);
        await tester.tap(find.text(micSettings));
        await tester.pumpAndSettle();
        expect(device.opened, [Uri.parse('app-settings:')]);
        expect(recorder.stops, 0);
        expect(help.replies, isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
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

  group('with a screen reader', () {
    // After the app is up: its harness sets reduced motion.
    Future<void> screenReader(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
          );
      await tester.pump();
    }

    testWidgets('the mic is tapped to record and tapped again to send', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final recorder = ScriptedRecorder();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      await screenReader(tester);
      final record = find.bySemanticsLabel('Record voice note');
      expect(
        tester.getSemantics(record),
        isSemantics(
          label: 'Record voice note',
          hint: 'Tap again to send',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: false,
        ),
      );
      await tester.tap(record);
      await tester.pump();
      await tester.pump();
      expect(recorder.starts, 1);
      expect(_composer(tester).state, IqChatComposerState.recording);
      expect(find.text('Slide to cancel'), findsNothing);
      final stop = find.bySemanticsLabel('Stop and send');
      expect(
        tester.getSemantics(stop),
        isSemantics(hint: 'Sends the voice note', hasTapAction: true),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(recorder.stops, 1);
      expect(recorder.cancels, 0);
      expect(help.replies.single.files.single.kind, HelpAttachmentKind.audio);
      semantics.dispose();
    });

    testWidgets('Cancel throws the note away', (tester) async {
      final recorder = ScriptedRecorder();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      await screenReader(tester);
      await tester.tap(find.bySemanticsLabel('Record voice note'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(recorder.cancels, 1);
      expect(recorder.stops, 0);
      expect(_composer(tester).state, IqChatComposerState.empty);
      expect(help.replies, isEmpty);
    });
  });

  testWidgets('without a screen reader the disc says to hold, and offers no '
      'long press a screen reader would end at once', (tester) async {
    final semantics = tester.ensureSemantics();
    final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()]);
    await openChat(
      tester,
      helpThreadPath('t_short'),
      help,
      overrides: [voiceRecorderProvider.overrideWithValue(ScriptedRecorder())],
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Voice note')),
      isSemantics(
        label: 'Voice note',
        hint: 'Hold to record',
        hasLongPressAction: false,
      ),
    );
    semantics.dispose();
  });

  group('recordings on the phone', () {
    late Directory folder;
    late Directory was;
    var made = 0;
    setUp(() {
      was = VoiceNotes.folder;
      folder = Directory.systemTemp.createTempSync('voice-notes-test');
      VoiceNotes.folder = folder;
    });
    tearDown(() {
      VoiceNotes.folder = was;
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });
    File recorded() =>
        File('${folder.path}/${made++}.m4a')..writeAsBytesSync([0, 1, 2]);

    testWidgets('a hold too short to send deletes its recording', (
      tester,
    ) async {
      final file = recorded();
      final recorder = ScriptedRecorder()
        ..length = const Duration(milliseconds: 400)
        ..path = file.path;
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
      expect(file.existsSync(), isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('a note is deleted once it has gone', (tester) async {
      final file = recorded();
      final recorder = ScriptedRecorder()..path = file.path;
      final help = ScriptedHelp(clock: () => chatNow, tickets: [shortThread()])
        ..holdUploads = true;
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final gesture = await _hold(tester);
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(file.existsSync(), isTrue);
      help.step(1);
      await tester.pumpAndSettle();
      expect(help.replies, hasLength(1));
      expect(file.existsSync(), isFalse);
    });

    test('a note cancelled or replaced before it goes is deleted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final help = ScriptedHelp(clock: () => chatNow)..holdUploads = true;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          helpServiceProvider.overrideWithValue(help),
        ],
      );
      addTearDown(container.dispose);
      final uploads = container.read(helpUploadsProvider.notifier);
      final file = recorded();
      final key = uploads.start(
        VoiceNote(
          path: file.path,
          length: const Duration(seconds: 2),
          bytes: 3,
        ).toAttachment(),
      );
      uploads.cancel(key);
      expect(file.existsSync(), isFalse);
    });

    test('sign-out deletes every recording left', () async {
      SharedPreferences.setMockInitialValues({
        'session.signedIn': true,
        'session.userId': 'u_1',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final file = recorded();
      await forgetSession(container.read);
      expect(file.existsSync(), isFalse);
      expect(folder.existsSync(), isFalse);
    });

    test('app start clears what a killed app left', () async {
      final file = recorded();
      await VoiceNotes.clear();
      expect(file.existsSync(), isFalse);
      await VoiceNotes.clear();
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

    testWidgets('recording pauses a note that is playing', (tester) async {
      final files = ScriptedFiles();
      final recorder = ScriptedRecorder();
      final help = ScriptedHelp(clock: () => chatNow, tickets: [_withNote()]);
      await openChat(
        tester,
        helpThreadPath('t_short'),
        help,
        files: files,
        overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
      );
      final voice = find.byWidgetPredicate(
        (w) => w is IqChatMedia && w.kind == IqChatMediaKind.voice,
      );
      await tester.tap(voice);
      await tester.pump();
      files.land('up_7', chatScreenshot.absolute);
      await tester.pumpAndSettle();
      expect(players.single.value.isPlaying, isTrue);

      final gesture = await _hold(tester);
      expect(recorder.starts, 1);
      expect(players.single.value.isPlaying, isFalse);
      await gesture.moveBy(const Offset(-140, 0));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
