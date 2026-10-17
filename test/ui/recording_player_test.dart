import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/activations/activations_widgets.dart';
import 'package:iqly_mobile/ui/recording_player.dart';
import 'package:video_player/video_player.dart';

class _FakeRecording extends VideoPlayerController {
  _FakeRecording(super.url) : super.networkUrl();

  int initialized = 0;
  bool disposed = false;
  final seeks = <Duration>[];

  @override
  Future<void> initialize() async {
    initialized++;
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 42),
      size: const Size(1080, 1920),
    );
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> setVolume(double volume) async =>
      value = value.copyWith(volume: volume);

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

void main() {
  final source = Uri.parse('file:///proof/recording.mp4');
  late List<_FakeRecording> opened;

  setUp(() {
    opened = [];
    Recordings.open = (uri) {
      final fake = _FakeRecording(uri);
      opened.add(fake);
      return fake;
    };
  });

  tearDown(() => Recordings.open = openRecording);

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(width: 358, height: 600, child: child)),
    ),
  );

  testWidgets('the player loads the recording, plays, pauses, scrubs and '
      'mutes', (tester) async {
    await pump(
      tester,
      IqRecordingPlayer(source: source, placeholder: const Text('frame')),
    );
    await tester.pump();
    expect(opened, hasLength(1));
    final video = opened.single;
    expect(video.initialized, 1);
    expect(find.text('frame'), findsNothing);
    expect(find.text('0:00 / 0:42'), findsOneWidget);
    expect(find.bySemanticsLabel('Mute'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Play').first);
    await tester.pump();
    expect(video.value.isPlaying, isTrue);
    expect(find.bySemanticsLabel('Pause'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Mute'));
    await tester.pump();
    expect(video.value.volume, 0);
    expect(find.bySemanticsLabel('Sound on'), findsOneWidget);

    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(video.seeks.single, const Duration(seconds: 21));
    expect(find.text('0:21 / 0:42'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pause').first);
    await tester.pump();
    expect(video.value.isPlaying, isFalse);
  });

  testWidgets('the player pauses when its page is covered and the app goes '
      'to the background, and lets go of the recording when it leaves', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: IqRecordingPlayer(source: source)),
      ),
    );
    await tester.pump();
    final video = opened.single;
    await video.play();
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(video.value.isPlaying, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    await video.play();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(video.value.isPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpWidget(const SizedBox());
    expect(video.disposed, isTrue);
  });

  testWidgets('the player waits for its page to arrive before it loads', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox()),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => IqRecordingPlayer(source: source),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(opened, isEmpty);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
  });

  testWidgets('posters of one recording share its first frame and free it '
      'with the last one', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          Expanded(child: ProofFrame(source: source)),
          Expanded(child: ProofFrame(source: source)),
        ],
      ),
    );
    await tester.pump();
    expect(opened, hasLength(1));
    expect(Recordings.posters, 1);
    expect(find.byType(VideoPlayer), findsNWidgets(2));

    await pump(tester, const ProofFrame());
    await tester.pump();
    expect(find.byType(VideoPlayer), findsNothing);
    expect(Recordings.posters, 0);
    expect(opened.single.disposed, isTrue);
  });
}
