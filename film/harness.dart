/// Preview mode: films a flow of the real app on a phone, on a dark stage,
/// one frame per 1/60 s of fake time, streamed into ffmpeg.
library;

// film/ sits outside test/ so CI skips it; the analyzer then does not count
// it as test code for the test-only APIs it drives.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/app.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/media_service.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/golden/golden.dart';

const _fps = 60;
const _outputWidth = 1080.0;
const _outputHeight = 1920.0;
const _pixelRatio = 2.0;
const _screenWidth = 390.0;
const _screenHeight = 844.0;
const _rim = 12.0;
const _screenRadius = 47.0;
const _outerRadius = 55.0;
const _statusBarHeight = 54.0;
const _homeIndicatorHeight = 34.0;
const _phone = Size(_screenWidth + 2 * _rim, _screenHeight + 2 * _rim);

/// Where the phone's screen sits on the stage, in logical pixels.
const _screenOrigin = Offset(
  (_outputWidth / _pixelRatio - _screenWidth) / 2,
  (_outputHeight / _pixelRatio - _screenHeight) / 2,
);

const _stageColor = Color(0xFF1E1E1E);
const _bezelColor = Color(0xFF000000);
const _bezelEdge = Color(0xFF3A3A3C);
const _islandColor = Color(0xFF000000);
const _darkInk = Color(0xFF0A0A0A);
const _lightInk = Color(0xFFFFFFFF);
const _touchFill = Color(0x59000000);
const _touchRing = Color(0x8CFFFFFF);

typedef FilmScript = Future<void> Function(Director d);

/// The drawn status bar's 9:41, on a weekday (Friday 2 October 2026). The
/// clock stands still for the whole film.
final _filmNow = DateTime(2026, 10, 2, 9, 41);

/// The app's clock and every demo source that dates things, at [_filmNow],
/// so deadlines, ages and greetings agree with the status bar. Each mirrors
/// the app's own provider with the clock passed in.
List<Override> _pinnedClock(_Sources sources) {
  DateTime now() => _filmNow;
  return [
    clockProvider.overrideWithValue(now),
    repositoryProvider.overrideWithValue(
      DemoRepository(DemoData(now: _filmNow), latency: DemoLatency.prototype),
    ),
    pollsServiceProvider.overrideWith((ref) => DemoPollsService(clock: now)),
    walletServiceProvider.overrideWith((ref) => DemoWalletService(clock: now)),
    helpServiceProvider.overrideWith((ref) => DemoHelpService(clock: now)),
    notificationsServiceProvider.overrideWith(
      (ref) =>
          DemoNotificationsService(ref.watch(repositoryProvider), clock: now),
    ),
    activationsServiceProvider.overrideWith((ref) {
      final service =
          sources.activations?.call(now) ?? DemoActivationsService(clock: now);
      ref.onDispose(service.dispose);
      return service;
    }),
    // The phone's own pickers cannot open here; their demo stand-ins answer
    // as a person picking would.
    mediaServiceProvider.overrideWithValue(
      sources.media ?? DemoMediaService(access: MediaAccess.allowed),
    ),
    attachmentPickerProvider.overrideWithValue(DemoAttachmentPicker()),
    if (sources.link case final link?)
      routerProvider.overrideWith((ref) => buildRouter(initialLocation: link)),
  ];
}

/// Demo sources a film swaps in to reach a state, such as an upload that
/// fails; each is built at the film's clock.
class _Sources {
  const _Sources({this.activations, this.media, this.link});

  final DemoActivationsService Function(DateTime Function() now)? activations;
  final MediaService? media;
  final String? link;
}

/// Registers one film. [prefs] seeds SharedPreferences as the device holds
/// them when the app opens; empty is a fresh install. Errors the app reports
/// are logged to `film/out/<name>.errors` instead of stopping the film.
/// [activations] and [media] replace those demo sources for a film that
/// needs a failure or another starting state. [link] opens the app from
/// that link instead of the splash.
void film(
  String name,
  FilmScript script, {
  Map<String, Object> prefs = const {},
  DemoActivationsService Function(DateTime Function() now)? activations,
  MediaService? media,
  String? link,
}) {
  setUpAll(loadAppFonts);
  testWidgets(name, (tester) async {
    final d = Director._(tester, name);
    final onError = FlutterError.onError;
    FlutterError.onError = d._report;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // flutter_test draws every shadow unblurred for steady goldens; films
    // need the real falloff. The binding checks the flag as soon as the body
    // ends, before any tear-down, so it is restored here.
    debugDisableShadows = false;
    try {
      await d._open(
        prefs,
        _Sources(activations: activations, media: media, link: link),
      );
      await script(d);
      await d._close();
    } catch (_) {
      await d._abort();
      rethrow;
    } finally {
      debugDisableShadows = true;
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = onError;
    }
  }, timeout: Timeout.none);
}

/// Drives the app like a person would, one captured frame at a time. Every
/// call advances the clock in real time, so the film runs at the speed the
/// script reads.
class Director {
  Director._(this.tester, this.name);

  final WidgetTester tester;
  final String name;

  final _chrome = _Chrome();
  final _inset = ValueNotifier<double>(0);
  final _stageKey = GlobalKey();
  final _taps = <String>[];
  final _haptics = <String>[];
  final _errors = <String, _Error>{};
  final _watch = Stopwatch();

  Process? _ffmpeg;
  Future<void>? _flushing;
  final _ffmpegLog = StringBuffer();
  int _frame = 0;
  Duration _clock = Duration.zero;

  double? _backdrop;
  double _indicatorTarget = 0;

  double _kbFrom = 0;
  double _kbTarget = 0;
  int _kbStart = 0;
  int _kbLostFor = 0;
  Map<String, dynamic>? _kbArgs;
  double _kbHeight = _Board.strip + _Board.keysHeight;
  double _kbHeightFrom = _Board.strip + _Board.keysHeight;
  double _kbHeightGoal = _Board.strip + _Board.keysHeight;
  int _kbHeightStart = 0;

  static const _kbSlideFrames = 15;
  static const _kbHideDebounce = 2;
  static const _frameTime = Duration(microseconds: 16667);

  String get _out => 'film/out/$name';

  /// Seconds since the film started.
  double get time => _frame / _fps;

  /// Advances [n] frames.
  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      await _step();
    }
  }

  Future<void> hold(double seconds) => frames((seconds * _fps).round());

  /// Advances frames until [finder] finds something.
  Future<void> waitFor(Finder finder, {double timeout = 10}) =>
      _until(() => finder.evaluate().isNotEmpty, '$finder', timeout);

  /// Advances frames until [finder] finds nothing.
  Future<void> gone(Finder finder, {double timeout = 10}) =>
      _until(() => finder.evaluate().isEmpty, '$finder to go', timeout);

  /// Waits for the screen [finder] marks, lets its route transition and the
  /// keyboard come to rest, then holds so a viewer can read it.
  Future<void> arrive(Finder finder, {double hold = 1.5}) async {
    await waitFor(finder);
    await settle(on: finder);
    await this.hold(hold);
  }

  /// Advances frames until the route holding [on] has finished animating
  /// and the keyboard is still.
  Future<void> settle({Finder? on, double timeout = 5}) async {
    var quiet = 0;
    await _until(
      () {
        quiet = _routeIdle(on) && _keyboardIdle ? quiet + 1 : 0;
        return quiet >= 3;
      },
      'the screen to settle',
      timeout,
    );
  }

  /// Taps the centre of the one hit-testable widget [finder] matches, with the
  /// touch indicator showing where.
  Future<void> tap(Finder finder, {String? label}) async {
    final point = _centreOf(finder);
    if (_underKeyboard(point)) {
      throw TestFailure('$name: $finder is under the keyboard at ${_t()}');
    }
    final gesture = await tester.createGesture();
    await _touch(
      point,
      _slug(label ?? finder.describeMatch(Plurality.one)),
      press: () => gesture.down(point, timeStamp: _clock),
      release: () => gesture.up(timeStamp: _clock),
    );
  }

  /// Holds a finger on the one hit-testable widget [finder] matches for
  /// [seconds], past the long-press deadline, then lifts.
  Future<void> longPress(
    Finder finder, {
    String? label,
    double seconds = 0.7,
  }) async {
    final point = _centreOf(finder);
    final gesture = await tester.createGesture();
    await _touch(
      point,
      _slug('long-${label ?? finder.describeMatch(Plurality.one)}'),
      press: () async {
        await gesture.down(point, timeStamp: _clock);
        await hold(seconds);
      },
      release: () => gesture.up(timeStamp: _clock),
    );
  }

  /// The round back button of the top bar.
  Future<void> back() => tap(find.bySemanticsLabel('Back'), label: 'back');

  /// The iOS back swipe: a thumb from the left edge across most of the
  /// screen, lifting while it moves.
  Future<void> swipeBack({double seconds = 0.4}) {
    final index = '${_taps.length + 1}'.padLeft(2, '0');
    _taps.add('${time.toStringAsFixed(3)}\t$index-swipe-back');
    return _drag(
      _screenOrigin + const Offset(6, _screenHeight * 0.55),
      const Offset(_screenWidth * 0.62, 0),
      seconds,
      fling: true,
    );
  }

  /// Types [text] into the focused field, character by character, on the
  /// drawn keyboard. Like iOS, each character lands as its key is released.
  Future<void> type(String text, {double cps = 12}) async {
    await _keyboardUp();
    final per = math.max(3, (_fps / cps).round());
    for (final char in text.split('')) {
      final plan = _chrome.board.plan(char);
      if (plan == null) {
        throw TestFailure('$name: no "$char" key on the keyboard at ${_t()}');
      }
      for (final key in plan.prelude) {
        await _pressKey(key, per, () => _chrome.board.apply(key));
      }
      await _pressKey(plan.key, per, () {
        _insert(char);
        _chrome.board.typed(char);
      }, label: char);
    }
  }

  /// Presses the keyboard's return key (next, done, go and so on).
  Future<void> submit() async {
    await _keyboardUp();
    final key = _chrome.board.key('enter');
    if (key == null) {
      throw TestFailure('$name: this keypad has no return key at ${_t()}');
    }
    final action = _inputAction();
    final board = _chrome.board;
    await _touch(
      _screenOrigin +
          Offset(0, _screenHeight - _chrome.board.height) +
          key.rect.center,
      'keyboard-${key.label}',
      press: () async => board.pressed = key.id,
      release: () async {
        board.pressed = null;
        await tester.testTextInput.receiveAction(action);
      },
    );
  }

  /// Drags from [from] within [finder] by [dy] (negative scrolls content
  /// up). A plain drag rests before lifting so nothing flings; with [fling]
  /// the finger moves at an even speed and lifts while moving, so the list
  /// carries on as iOS would.
  Future<void> scroll(
    Finder finder,
    double dy, {
    double seconds = 0.45,
    Alignment from = Alignment.center,
    bool fling = false,
  }) {
    final matches = finder.evaluate();
    if (matches.length != 1) {
      throw TestFailure(
        '$name: expected one match for $finder at ${_t()}, '
        'found ${matches.length}',
      );
    }
    final box = matches.single.renderObject! as RenderBox;
    final start = box.localToGlobal(from.alongSize(box.size));
    return _drag(start, Offset(0, dy), seconds, fling: fling);
  }

  /// Presses delete [count] times, or until the focused field is empty.
  Future<void> erase([int? count, double cps = 14]) async {
    await _keyboardUp();
    final per = math.max(3, (_fps / cps).round());
    final key = _chrome.board.key('delete')!;
    final n = count ?? _focusedValue().text.length;
    for (var i = 0; i < n; i++) {
      await _pressKey(key, per, _deleteBackward);
    }
  }

  /// Drags [list] until [item] is in full view and clear of the keyboard.
  Future<void> reveal(Finder item, Finder list) async {
    await settle(on: list);
    for (var attempt = 0; !_inView(item, list); attempt++) {
      if (attempt == 8) {
        throw TestFailure('$name: $item never came into view at ${_t()}');
      }
      final view = tester.getRect(list);
      final from = Offset(view.center.dx, view.top + view.height * 0.8);
      var dy = -view.height * 0.55;
      if (item.evaluate().isNotEmpty) {
        dy = view.top + view.height * 0.45 - tester.getCenter(item).dy;
      }
      await _drag(from, Offset(0, dy), 0.5);
      await hold(0.3);
    }
  }

  /// Scrolls the open sheet's list until [label] is in full view, then taps
  /// it. The sheet is the top route; its first vertical list is the one.
  Future<void> pickFromSheet(String label) async {
    final list = find
        .byElementPredicate(
          (e) =>
              e.widget is Scrollable &&
              (e.widget as Scrollable).axisDirection == AxisDirection.down &&
              (ModalRoute.of(e)?.isCurrent ?? false),
        )
        .first;
    final item = find.descendant(of: list, matching: find.text(label));
    await reveal(item, list);
    await tap(item, label: label);
  }

  Future<void> _until(bool Function() done, String what, double timeout) async {
    final limit = (timeout * _fps).round();
    for (var i = 0; !done(); i++) {
      if (i >= limit) {
        throw TestFailure('$name: waited ${timeout}s for $what at ${_t()}');
      }
      await _step();
    }
  }

  Future<void> _open(Map<String, Object> prefs, _Sources sources) async {
    final view = tester.view;
    view.physicalSize = const Size(_outputWidth, _outputHeight);
    view.devicePixelRatio = _pixelRatio;
    // RenderView takes the status bar style from the annotated region under
    // (centre, padding.top / 2) in physical pixels: aim that at the phone's
    // status bar so SystemChrome.latestStyle follows the app.
    final probe = (_screenOrigin.dy + _statusBarHeight / 2) * _pixelRatio;
    view.padding = FakeViewPadding(top: probe * 2);
    addTearDown(view.reset);
    // A device answers platform calls such as the error haptic; the test
    // engine has no handler for them.
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        final kind = '${call.arguments}'.split('.').last;
        _haptics.add('${time.toStringAsFixed(3)}\t$kind\t${_screenName()}');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    SharedPreferences.setMockInitialValues(prefs);
    final shared = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _Stage(
        stageKey: _stageKey,
        chrome: _chrome,
        inset: _inset,
        statusBar: File('film/assets/status-bar.svg').readAsStringSync(),
        homeIndicator: File('film/assets/home-indicator.svg')
            .readAsStringSync(),
        app: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(shared),
            ..._pinnedClock(sources),
          ],
          child: const IqlyApp(),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    _syncStatusBar();
    _indicatorTarget = _chrome.indicator = _chrome.lightContent ? 1 : 0;
    await tester.pump(Duration.zero);

    Directory('film/out').createSync(recursive: true);
    _watch.start();
    await tester.runAsync(() async {
      final ffmpeg = await Process.start('ffmpeg', [
        ...['-y', '-hide_banner', '-loglevel', 'error'],
        ...['-f', 'rawvideo', '-pix_fmt', 'rgba'],
        ...['-s', '${_outputWidth.toInt()}x${_outputHeight.toInt()}'],
        ...['-r', '$_fps', '-i', '-'],
        ...['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18'],
        ...['-movflags', '+faststart', '$_out.mp4'],
      ]);
      ffmpeg.stdout.drain<void>();
      ffmpeg.stderr.transform(utf8.decoder).listen(_ffmpegLog.write);
      _ffmpeg = ffmpeg;
    });
    await _capture();
  }

  Future<void> _close() async {
    final code = await tester.runAsync(() async {
      final ffmpeg = _ffmpeg!;
      await _flushing;
      await ffmpeg.stdin.close();
      return ffmpeg.exitCode;
    });
    _watch.stop();
    if (code != 0) {
      throw TestFailure('$name: ffmpeg exited with $code\n$_ffmpegLog');
    }
    File('$_out.taps').writeAsStringSync(_taps.map((t) => '$t\n').join());
    File('$_out.haptics').writeAsStringSync(_haptics.map((h) => '$h\n').join());
    File('$_out.errors')
        .writeAsStringSync(_errors.values.map((e) => '$e\n').join());
    final wall = _watch.elapsed;
    debugPrint(
      '$name: $_frame frames, ${time.toStringAsFixed(2)} s of film, '
      'rendered in ${wall.inMinutes}m ${wall.inSeconds % 60}s '
      '(${(wall.inMilliseconds / math.max(1, _frame)).round()} ms a frame), '
      '${_errors.length} app errors, to $_out.mp4',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  /// Ends the encode so the frames so far still make a playable film. ffmpeg
  /// ignores SIGTERM while it waits on an open pipe, hence the closed stdin
  /// and the SIGKILL fallback.
  Future<void> _abort() async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return;
    await tester.runAsync(() async {
      try {
        await _flushing;
        await ffmpeg.stdin.close();
        await ffmpeg.exitCode.timeout(const Duration(seconds: 30));
      } catch (_) {
        ffmpeg.kill(ProcessSignal.sigkill);
      }
    });
  }

  void _report(FlutterErrorDetails details) {
    final message = details.exceptionAsString().split('\n').first.trim();
    final context = details.context?.toDescription();
    final key = '$message${context == null ? '' : ' ($context)'}';
    _errors.putIfAbsent(key, () => _Error(time, key)).count++;
  }

  Future<void> _step() async {
    _driveKeyboard();
    _adaptIndicator();
    _frame++;
    final next = Duration(microseconds: (_frame * 1e6 / _fps).round());
    await tester.pump(next - _clock);
    _clock = next;
    if (_syncStatusBar()) await tester.pump(Duration.zero);
    for (final error in _errors.values) {
      error.screen ??= _screenName();
    }
    await _capture();
  }

  Future<void> _capture() async {
    final boundary =
        _stageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      final pixels = bytes!.buffer.asUint8List();
      _backdrop = _backdropLuma(pixels);
      await _flushing;
      final stdin = _ffmpeg!.stdin;
      stdin.add(pixels);
      _flushing = stdin.flush();
    });
  }

  /// Mean luma of the app just above the home indicator pill, in the frame
  /// just captured.
  static double _backdropLuma(Uint8List rgba) {
    const scale = _pixelRatio;
    final top = _screenOrigin.dy + _screenHeight - _homeIndicatorHeight + 6;
    final x0 = ((_screenOrigin.dx + 95) * scale).round();
    final x1 = ((_screenOrigin.dx + 295) * scale).round();
    final y0 = (top * scale).round();
    final y1 = ((top + 12) * scale).round();
    final width = _outputWidth.round();
    var sum = 0.0;
    var n = 0;
    for (var y = y0; y < y1; y += 3) {
      for (var x = x0; x < x1; x += 3) {
        final i = (y * width + x) * 4;
        sum += 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
        n++;
      }
    }
    return sum / n / 255;
  }

  /// Like iOS, the home indicator takes the opposite of the luma behind it,
  /// easing over 150 ms.
  void _adaptIndicator() {
    final luma = _backdrop;
    if (luma == null) return;
    if (luma < 0.45) _indicatorTarget = 1;
    if (luma > 0.55) _indicatorTarget = 0;
    final now = _chrome.indicator;
    final next = now < _indicatorTarget
        ? math.min(_indicatorTarget, now + 1 / 9)
        : math.max(_indicatorTarget, now - 1 / 9);
    if (next == now) return;
    _chrome
      ..indicator = next
      ..changed();
  }

  bool _syncStatusBar() {
    final style = SystemChrome.latestStyle;
    if (style == null || style == _chrome.style) return false;
    _chrome
      ..style = style
      ..changed();
    return true;
  }

  /// The keyboard follows the text input connection: up while a field holds
  /// it, down a few frames after it closes (a focus hop between fields closes
  /// and reopens it within a frame or two, which iOS does not animate).
  void _driveKeyboard() {
    final input = tester.testTextInput;
    final shown = input.isVisible;
    _kbLostFor = shown ? 0 : _kbLostFor + 1;
    final target = shown || (_kbTarget == 1 && _kbLostFor < _kbHideDebounce)
        ? 1.0
        : 0.0;
    if (shown && !identical(input.setClientArgs, _kbArgs)) {
      _kbArgs = input.setClientArgs;
      _chrome.board.configure(_kbArgs);
      _chrome.changed();
    }
    // A keypad is shorter than the letters; iOS eases between the two.
    final goal = _chrome.board.height;
    if (goal != _kbHeightGoal) {
      _kbHeightFrom = _chrome.keyboard == 0 ? goal : _kbHeight;
      _kbHeightGoal = goal;
      _kbHeightStart = _frame;
    }
    if (target != _kbTarget) {
      _kbFrom = _chrome.keyboard;
      _kbTarget = target;
      _kbStart = _frame;
    }
    final t = ((_frame + 1 - _kbStart) / _kbSlideFrames).clamp(0.0, 1.0);
    final v = _kbFrom + (_kbTarget - _kbFrom) * Curves.easeOut.transform(t);
    final th = ((_frame + 1 - _kbHeightStart) / _kbSlideFrames).clamp(0.0, 1.0);
    _kbHeight =
        _kbHeightFrom +
        (_kbHeightGoal - _kbHeightFrom) * Curves.easeOut.transform(th);
    final inset = (v * _kbHeight * _pixelRatio).round() / _pixelRatio;
    if (v != _chrome.keyboard || inset != _chrome.inset) {
      _chrome
        ..keyboard = v
        ..inset = inset
        ..changed();
      _inset.value = inset;
      // A focused field keeps its caret above a rising keyboard only when the
      // view's own insets grow (EditableText.didChangeMetrics), as on iOS.
      tester.view.viewInsets = FakeViewPadding(bottom: inset * _pixelRatio);
    }
  }

  bool get _keyboardIdle =>
      _chrome.keyboard == _kbTarget &&
      _kbHeight == _kbHeightGoal &&
      (tester.testTextInput.isVisible ? 1.0 : 0.0) == _kbTarget;

  Future<void> _keyboardUp() =>
      _until(() => _keyboardIdle && _chrome.keyboard == 1, 'the keyboard', 3);

  bool _underKeyboard(Offset point) =>
      point.dy - _screenOrigin.dy > _screenHeight - _chrome.inset;

  bool _routeIdle(Finder? on) {
    final found = on?.evaluate();
    if (found == null || found.isEmpty) return true;
    final route = ModalRoute.of(found.first);
    if (route == null) return true;
    final enter = route.animation?.status ?? AnimationStatus.completed;
    final cover = route.secondaryAnimation?.status ?? AnimationStatus.dismissed;
    return enter == AnimationStatus.completed &&
        cover == AnimationStatus.dismissed;
  }

  /// The innermost screen on top, to place an error in the film.
  String _screenName() {
    final screens = find
        .byWidgetPredicate((w) => w.runtimeType.toString().endsWith('Screen'))
        .evaluate();
    return screens.isEmpty ? '' : screens.last.widget.runtimeType.toString();
  }

  Offset _centreOf(Finder finder, {bool hitTest = true}) {
    final matches = (hitTest ? finder.hitTestable() : finder).evaluate();
    if (matches.length != 1) {
      throw TestFailure(
        '$name: expected one ${hitTest ? 'tappable ' : ''}match for '
        '$finder at ${_t()}, found ${matches.length}',
      );
    }
    final box = matches.single.renderObject! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  bool _inView(Finder item, Finder list) {
    if (item.evaluate().isEmpty) return false;
    final view = tester.getRect(list).deflate(8);
    final rect = tester.getRect(item);
    return rect.top >= view.top &&
        rect.bottom <= view.bottom &&
        !_underKeyboard(rect.bottomCenter);
  }

  /// A tap as the viewer sees it: the dot fades in, presses for 120 ms with
  /// [press] at its start, lifts with [release], and fades out. The tap's
  /// time is logged for the transition frames.
  Future<void> _touch(
    Offset point,
    String label, {
    required Future<void> Function() press,
    required Future<void> Function() release,
  }) async {
    final touch = _chrome.touch = _Touch(point - _screenOrigin);
    for (var i = 1; i <= 6; i++) {
      touch.opacity = i / 6;
      _chrome.changed();
      await _step();
    }
    await frames(3);
    await press();
    for (var i = 1; i <= 7; i++) {
      touch.scale = 1 - 0.15 * Curves.easeOut.transform(i / 7);
      _chrome.changed();
      await _step();
    }
    await frames(3);
    final index = '${_taps.length + 1}'.padLeft(2, '0');
    _taps.add('${time.toStringAsFixed(3)}\t$index-$label');
    await release();
    for (var i = 1; i <= 12; i++) {
      final t = i / 12;
      touch
        ..opacity = 1 - t
        ..scale = 0.85 + 0.15 * Curves.easeOut.transform(t);
      _chrome.changed();
      await _step();
    }
    _chrome
      ..touch = null
      ..changed();
  }

  Future<void> _drag(
    Offset from,
    Offset by,
    double seconds, {
    bool fling = false,
  }) async {
    if (_underKeyboard(from)) {
      throw TestFailure('$name: drag starts under the keyboard at ${_t()}');
    }
    final touch = _chrome.touch = _Touch(from - _screenOrigin);
    for (var i = 1; i <= 5; i++) {
      touch.opacity = i / 5;
      _chrome.changed();
      await _step();
    }
    final gesture = await tester.createGesture();
    await gesture.down(from, timeStamp: _clock);
    final n = math.max(2, (seconds * _fps).round());
    final curve = fling ? Curves.linear : Curves.easeInOut;
    for (var i = 1; i <= n; i++) {
      final at = from + by * curve.transform(i / n);
      await gesture.moveTo(at, timeStamp: _clock + _frameTime);
      // A lifting finger's last move and its up land in the same frame. Lifted
      // a frame later, the fling's first tick (elapsed zero) holds the list
      // still for a frame.
      if (fling && i == n) await gesture.up(timeStamp: _clock + _frameTime);
      touch.at = at - _screenOrigin;
      _chrome.changed();
      await _step();
    }
    if (!fling) {
      await frames(4);
      await gesture.up(timeStamp: _clock);
    }
    for (var i = 1; i <= 8; i++) {
      touch.opacity = 1 - i / 8;
      _chrome.changed();
      await _step();
    }
    _chrome
      ..touch = null
      ..changed();
  }

  Future<void> _pressKey(
    _Key key,
    int length,
    void Function() onRelease, {
    String? label,
  }) async {
    // Held for most of the stroke with a couple of frames up, so a key
    // pressed twice running lifts visibly in between.
    final down = math.max(1, math.min(4, length - 2));
    _chrome.board
      ..pressed = key.id
      ..pressedLabel = label;
    _chrome.changed();
    await frames(down);
    onRelease();
    _chrome.board
      ..pressed = null
      ..pressedLabel = null;
    _chrome.changed();
    await frames(length - down);
  }

  TextEditingValue _focusedValue() {
    final focused = find.byWidgetPredicate(
      (w) => w is EditableText && w.focusNode.hasFocus,
    );
    if (focused.evaluate().length != 1) {
      throw TestFailure('$name: no focused field to type into at ${_t()}');
    }
    final value = tester.state<EditableTextState>(focused).textEditingValue;
    return value.selection.isValid
        ? value
        : value.copyWith(
            selection: TextSelection.collapsed(offset: value.text.length),
          );
  }

  /// Sends the new editing state the way the iOS keyboard does: the whole
  /// value, with [char] replacing the selection.
  void _insert(String char) {
    final value = _focusedValue();
    final selection = value.selection;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: value.text.replaceRange(selection.start, selection.end, char),
        selection: TextSelection.collapsed(
          offset: selection.start + char.length,
        ),
      ),
    );
  }

  void _deleteBackward() {
    final value = _focusedValue();
    final selection = value.selection;
    final start = selection.isCollapsed
        ? math.max(0, selection.start - 1)
        : selection.start;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: value.text.replaceRange(start, selection.end, ''),
        selection: TextSelection.collapsed(offset: start),
      ),
    );
  }

  TextInputAction _inputAction() {
    final name = (_kbArgs?['inputAction'] as String?)?.split('.').last;
    return TextInputAction.values.firstWhere(
      (a) => a.name == name,
      orElse: () => TextInputAction.done,
    );
  }

  String _t() => '${time.toStringAsFixed(2)}s';

  static String _slug(String text) {
    final slug = text
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .replaceFirst(RegExp(r'^widget-with-(text|type)-'), '');
    return slug.length > 40 ? slug.substring(0, 40) : slug;
  }
}

class _Error {
  _Error(this.time, this.message);

  final double time;
  final String message;
  String? screen;
  int count = 0;

  @override
  String toString() =>
      '${time.toStringAsFixed(2)}s\t${screen ?? ''}\t$message'
      '${count > 1 ? ' (x$count)' : ''}';
}

class _Touch {
  _Touch(this.at);

  Offset at;
  double opacity = 0;
  double scale = 1;
}

/// Everything the device chrome draws, changed by the director between frames.
class _Chrome extends ChangeNotifier {
  SystemUiOverlayStyle style = SystemUiOverlayStyle.dark;
  double keyboard = 0;
  double inset = 0;

  /// The home indicator's ink, 0 dark to 1 light.
  double indicator = 0;
  final board = _Board();
  _Touch? touch;

  /// iOS reads statusBarBrightness: a dark bar behind means light content.
  bool get lightContent =>
      style.statusBarBrightness == Brightness.dark ||
      (style.statusBarBrightness == null &&
          style.statusBarIconBrightness == Brightness.light);

  void changed() => notifyListeners();
}

enum _KeyKind { char, digit, pad, shift, delete, mode, symbols, space, enter }

/// The iOS numeric keypads: no suggestion strip and no return key.
enum _Pad { number, decimal, phone }

class _Key {
  const _Key(this.id, this.rect, this.kind, [this.label = '']);

  final String id;
  final Rect rect;
  final _KeyKind kind;
  final String label;
}

class _Plan {
  const _Plan(this.key, [this.prelude = const []]);

  final _Key key;
  final List<_Key> prelude;
}

/// An iOS-style light keyboard: a 45 suggestion strip over 291 of keys.
class _Board {
  static const width = 390.0;
  static const strip = 45.0;
  static const keysHeight = 291.0;
  static const keyHeight = 42.0;
  static const _rowPitch = 54.0;
  static const _firstRow = strip + 8;

  bool email = false;
  _Pad? pad;
  String enter = 'return';
  bool numbers = false;
  bool shift = false;
  String? pressed;
  String? pressedLabel;

  double get height => pad == null ? strip + keysHeight : keysHeight;

  bool get enterIsAction =>
      const {'go', 'search', 'send', 'done'}.contains(enter);

  List<_Key> get keys => _layout(numbers);

  void configure(Map<String, dynamic>? args) {
    final input = args?['inputType'] as Map?;
    final type = input?['name'] as String?;
    final action = (args?['inputAction'] as String?)?.split('.').last;
    email = type == 'TextInputType.emailAddress';
    pad = switch (type) {
      'TextInputType.phone' => _Pad.phone,
      'TextInputType.number' when input?['signed'] != true =>
        input?['decimal'] == true ? _Pad.decimal : _Pad.number,
      _ => null,
    };
    enter = switch (action) {
      'go' || 'next' || 'done' || 'search' || 'send' => action!,
      _ => 'return',
    };
    numbers = false;
    shift = false;
  }

  _Key? key(String id) => _find(keys, id);

  /// The keys a typist presses for [char]: a layout or shift key first when
  /// needed, then the key itself. Null when the keyboard has no such key.
  _Plan? plan(String char) {
    if (pad != null) {
      final key = this.key(char);
      return key == null ? null : _Plan(key);
    }
    final lower = char.toLowerCase();
    final upper = char != lower;
    final here = _find(_layout(numbers), lower);
    if (here != null) {
      final shiftKey = _find(_layout(numbers), 'shift');
      return _Plan(here, [if (upper && !shift && shiftKey != null) shiftKey]);
    }
    final there = _find(_layout(!numbers), lower);
    if (there == null) return null;
    final shiftKey = _find(_layout(!numbers), 'shift');
    return _Plan(there, [
      key(numbers ? 'ABC' : '123')!,
      if (upper && shiftKey != null) shiftKey,
    ]);
  }

  void apply(_Key key) {
    switch (key.kind) {
      case _KeyKind.mode:
        numbers = !numbers;
        shift = false;
      case _KeyKind.shift:
        shift = !shift;
      default:
        break;
    }
  }

  void typed(String char) {
    if (char != char.toLowerCase()) shift = false;
  }

  _Key? _find(List<_Key> keys, String id) =>
      keys.where((k) => k.id == id).firstOrNull;

  static Rect _at(int row, double x, double w) =>
      Rect.fromLTWH(x, _firstRow + row * _rowPitch, w, keyHeight);

  List<_Key> _layout(bool numbers) {
    if (pad != null) return _padLayout(pad!);
    final keys = <_Key>[];
    void row(int r, String chars, double x0, double w) {
      for (var i = 0; i < chars.length; i++) {
        keys.add(
          _Key(chars[i], _at(r, x0 + i * (w + 6), w), _KeyKind.char, chars[i]),
        );
      }
    }

    if (email) {
      keys
        ..add(_Key('@', _at(3, 204, 42), _KeyKind.char, '@'))
        ..add(_Key('.', _at(3, 252, 42), _KeyKind.char, '.'));
    }
    if (numbers) {
      row(0, '1234567890', 3, 33);
      row(1, '-/:;()\$&@"', 3, 33);
      keys.add(_Key('#+=', _at(2, 3, 42), _KeyKind.symbols, '#+='));
      row(2, ".,?!'", 65.5, 47);
    } else {
      row(0, 'qwertyuiop', 3, 33);
      row(1, 'asdfghjkl', 22.5, 33);
      keys.add(_Key('shift', _at(2, 3, 42), _KeyKind.shift));
      row(2, 'zxcvbnm', 61.5, 33);
    }
    final mode = numbers ? 'ABC' : '123';
    keys
      ..add(_Key('delete', _at(2, 345, 42), _KeyKind.delete))
      ..add(_Key(mode, _at(3, 3, 87), _KeyKind.mode, mode))
      ..add(_Key(' ', _at(3, 96, email ? 102 : 198), _KeyKind.space, 'space'))
      ..add(_Key('enter', _at(3, 300, 87), _KeyKind.enter, enter));
    return keys;
  }
}

List<_Key> _padLayout(_Pad pad) {
  Rect at(int row, int column) =>
      Rect.fromLTWH(6.0 + column * 128, 6.0 + row * 53, 122, 46);
  const letters = [
    '',
    'ABC',
    'DEF',
    'GHI',
    'JKL',
    'MNO',
    'PQRS',
    'TUV',
    'WXYZ',
  ];
  final keys = [
    for (var i = 1; i <= 9; i++)
      _Key('$i', at((i - 1) ~/ 3, (i - 1) % 3), _KeyKind.digit, letters[i - 1]),
  ];
  switch (pad) {
    case _Pad.decimal:
      keys.add(_Key('.', at(3, 0), _KeyKind.pad, '.'));
    case _Pad.phone:
      keys.add(_Key('+', at(3, 0), _KeyKind.pad, '+*#'));
    case _Pad.number:
      break;
  }
  return keys
    ..add(_Key('0', at(3, 1), _KeyKind.digit, pad == _Pad.phone ? '+' : ''))
    ..add(_Key('delete', at(3, 2), _KeyKind.delete));
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.stageKey,
    required this.chrome,
    required this.inset,
    required this.statusBar,
    required this.homeIndicator,
    required this.app,
  });

  final GlobalKey stageKey;
  final _Chrome chrome;
  final ValueListenable<double> inset;
  final String statusBar;
  final String homeIndicator;
  final Widget app;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: stageKey,
        child: ColoredBox(
          color: _stageColor,
          child: Center(
            child: SizedBox.fromSize(
              size: _phone,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _bezelColor,
                        borderRadius: BorderRadius.circular(_outerRadius),
                        border: Border.all(color: _bezelEdge, width: 1.5),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _rim,
                    top: _rim,
                    width: _screenWidth,
                    height: _screenHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_screenRadius),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _AppHost(
                              inset: inset,
                              child: RepaintBoundary(child: app),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ListenableBuilder(
                                listenable: chrome,
                                builder: (context, _) => _Overlays(
                                  chrome: chrome,
                                  statusBar: statusBar,
                                  homeIndicator: homeIndicator,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gives the app the phone's metrics: the Figma insets, and the keyboard as
/// a bottom view inset while it is up.
class _AppHost extends StatelessWidget {
  const _AppHost({required this.inset, required this.child});

  final ValueListenable<double> inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: inset,
      child: child,
      builder: (context, keyboard, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(_screenWidth, _screenHeight),
          padding: EdgeInsets.only(
            top: _statusBarHeight,
            bottom: math.max(0, _homeIndicatorHeight - keyboard),
          ),
          viewPadding: const EdgeInsets.only(
            top: _statusBarHeight,
            bottom: _homeIndicatorHeight,
          ),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
    );
  }
}

class _Overlays extends StatelessWidget {
  const _Overlays({
    required this.chrome,
    required this.statusBar,
    required this.homeIndicator,
  });

  final _Chrome chrome;
  final String statusBar;
  final String homeIndicator;

  @override
  Widget build(BuildContext context) {
    final ink = chrome.lightContent ? _lightInk : _darkInk;
    final touch = chrome.touch;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: _screenWidth,
          height: _statusBarHeight,
          child: SvgPicture.string(
            statusBar,
            colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
          ),
        ),
        const Positioned(
          left: (_screenWidth - 126) / 2,
          top: 11,
          width: 126,
          height: 37,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: _islandColor,
              shape: StadiumBorder(),
            ),
          ),
        ),
        if (chrome.inset > 0)
          Positioned(
            left: 0,
            top: _screenHeight - chrome.inset,
            width: _Board.width,
            height: chrome.board.height,
            child: CustomPaint(painter: _BoardPainter(chrome.board)),
          ),
        Positioned(
          left: 0,
          bottom: 0,
          width: _screenWidth,
          height: _homeIndicatorHeight,
          child: SvgPicture.string(
            homeIndicator,
            colorFilter: ColorFilter.mode(
              Color.lerp(_darkInk, _lightInk, chrome.indicator)!,
              BlendMode.srcIn,
            ),
          ),
        ),
        if (touch != null)
          Positioned.fill(child: CustomPaint(painter: _TouchPainter(touch))),
      ],
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(_Touch touch)
    : _at = touch.at,
      _opacity = touch.opacity,
      _scale = touch.scale;

  final Offset _at;
  final double _opacity;
  final double _scale;

  static const _radius = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = _radius * _scale;
    canvas
      ..drawCircle(
        _at,
        r,
        Paint()..color = _touchFill.withValues(alpha: _touchFill.a * _opacity),
      )
      ..drawCircle(
        _at,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _touchRing.withValues(alpha: _touchRing.a * _opacity),
      );
  }

  @override
  bool shouldRepaint(_TouchPainter old) =>
      old._at != _at || old._opacity != _opacity || old._scale != _scale;
}

const _kbBackground = Color(0xFFD1D3D9);
const _kbKey = Color(0xFFFFFFFF);
const _kbFunction = Color(0xFFABB0BA);
const _kbShadow = Color(0xFF898A8D);
const _kbAction = Color(0xFF007AFF);
const _kbActionPressed = Color(0xFF66AFFF);
const _kbLabel = Color(0xFF000000);
const _kbGlyph = Color(0xFF3C3C43);
const _kbDivider = Color(0xFFB4B7BD);

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.board)
    : _snapshot = (
        board.numbers,
        board.shift,
        board.pressed,
        board.pressedLabel,
        board.email,
        board.enter,
        board.pad,
      );

  final _Board board;
  final Object _snapshot;

  static const _radius = Radius.circular(5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _kbBackground);
    final letters = board.pad == null;
    if (letters) {
      final divider = Paint()
        ..color = _kbDivider
        ..strokeWidth = 1;
      for (final x in [size.width / 3, size.width * 2 / 3]) {
        canvas.drawLine(Offset(x, 12), Offset(x, _Board.strip - 12), divider);
      }
    }
    _Key? popup;
    for (final key in board.keys) {
      final pressed = board.pressed == key.id;
      if (pressed && key.kind == _KeyKind.char) popup = key;
      _drawKey(canvas, key, pressed);
    }
    if (letters) {
      _globe(canvas, Offset(33, size.height - 46));
      _mic(canvas, Offset(size.width - 33, size.height - 46));
    }
    if (popup != null) _drawPopup(canvas, popup, size);
  }

  void _drawKey(Canvas canvas, _Key key, bool pressed) {
    // A keypad's corner keys sit on the background until pressed.
    final bare = board.pad != null && !pressed;
    final fill = switch (key.kind) {
      _KeyKind.char ||
      _KeyKind.space ||
      _KeyKind.digit => pressed ? _kbFunction : _kbKey,
      _KeyKind.pad || _KeyKind.delete when bare => null,
      _KeyKind.shift => board.shift || pressed ? _kbKey : _kbFunction,
      _KeyKind.enter when board.enterIsAction =>
        pressed ? _kbActionPressed : _kbAction,
      _ => pressed ? _kbKey : _kbFunction,
    };
    final rect = RRect.fromRectAndRadius(key.rect, _radius);
    if (fill != null) {
      canvas
        ..drawRRect(rect.shift(const Offset(0, 1)), Paint()..color = _kbShadow)
        ..drawRRect(rect, Paint()..color = fill);
    }
    final centre = key.rect.center;
    switch (key.kind) {
      case _KeyKind.digit:
        final lettered = key.label.isNotEmpty;
        _label(
          canvas,
          key.id,
          lettered ? centre - const Offset(0, 6) : centre,
          25,
        );
        if (lettered) {
          _label(
            canvas,
            key.label,
            centre + const Offset(0, 12),
            10,
            weight: FontWeight.w700,
            spacing: 2,
          );
        }
      case _KeyKind.pad:
        _label(canvas, key.label, centre, key.label.length > 1 ? 20 : 25);
      case _KeyKind.shift:
        _shiftGlyph(canvas, centre, filled: board.shift || pressed);
      case _KeyKind.delete:
        _deleteGlyph(canvas, centre);
      case _KeyKind.char:
        final upper = !board.numbers && board.shift;
        _label(
          canvas,
          upper ? key.label.toUpperCase() : key.label,
          centre,
          22.5,
        );
      case _KeyKind.enter:
        _label(
          canvas,
          key.label,
          centre,
          16,
          color: board.enterIsAction ? _kbKey : _kbLabel,
        );
      default:
        _label(canvas, key.label, centre, 16);
    }
  }

  /// The iOS key preview: a wider cap above the key, joined by a neck.
  void _drawPopup(Canvas canvas, _Key key, Size size) {
    final r = key.rect;
    final w = r.width + 22;
    final left = (r.center.dx - w / 2).clamp(1.0, size.width - w - 1);
    final cap = RRect.fromLTRBR(
      left,
      r.top - 54,
      left + w,
      r.top - 6,
      const Radius.circular(9),
    );
    final neck = Path()
      ..moveTo(cap.left, cap.bottom - 9)
      ..cubicTo(cap.left, cap.bottom + 4, r.left, r.top - 2, r.left, r.top + 8)
      ..lineTo(r.left, r.bottom - 5)
      ..arcToPoint(
        Offset(r.left + 5, r.bottom),
        radius: _radius,
        clockwise: false,
      )
      ..lineTo(r.right - 5, r.bottom)
      ..arcToPoint(
        Offset(r.right, r.bottom - 5),
        radius: _radius,
        clockwise: false,
      )
      ..lineTo(r.right, r.top + 8)
      ..cubicTo(
        r.right,
        r.top - 2,
        cap.right,
        cap.bottom + 4,
        cap.right,
        cap.bottom - 9,
      )
      ..close();
    final shadow = Paint()..color = _kbShadow.withValues(alpha: 0.6);
    final fill = Paint()..color = _kbKey;
    canvas
      ..drawRRect(cap.shift(const Offset(0, 1)), shadow)
      ..drawPath(neck.shift(const Offset(0, 1)), shadow)
      ..drawRRect(cap, fill)
      ..drawPath(neck, fill);
    final char = board.pressedLabel ?? key.label;
    _label(canvas, char, cap.outerRect.center, 32);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset centre,
    double size, {
    Color color = _kbLabel,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: IqFonts.jakarta,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter
      ..paint(canvas, centre - Offset(painter.width / 2, painter.height / 2))
      ..dispose();
  }

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _kbLabel;

  void _shiftGlyph(Canvas canvas, Offset c, {required bool filled}) {
    final path = Path()
      ..moveTo(c.dx, c.dy - 9)
      ..lineTo(c.dx + 9, c.dy + 0.5)
      ..lineTo(c.dx + 4.5, c.dy + 0.5)
      ..lineTo(c.dx + 4.5, c.dy + 8)
      ..lineTo(c.dx - 4.5, c.dy + 8)
      ..lineTo(c.dx - 4.5, c.dy + 0.5)
      ..lineTo(c.dx - 9, c.dy + 0.5)
      ..close();
    canvas.drawPath(path, filled ? (Paint()..color = _kbLabel) : _stroke);
  }

  void _deleteGlyph(Canvas canvas, Offset c) {
    final path = Path()
      ..moveTo(c.dx - 12, c.dy)
      ..lineTo(c.dx - 5, c.dy - 7.5)
      ..lineTo(c.dx + 11, c.dy - 7.5)
      ..lineTo(c.dx + 11, c.dy + 7.5)
      ..lineTo(c.dx - 5, c.dy + 7.5)
      ..close();
    final stroke = _stroke;
    canvas
      ..drawPath(path, stroke)
      ..drawLine(
        c + const Offset(-0.5, -3.5),
        c + const Offset(6.5, 3.5),
        stroke,
      )
      ..drawLine(
        c + const Offset(6.5, -3.5),
        c + const Offset(-0.5, 3.5),
        stroke,
      );
  }

  void _globe(Canvas canvas, Offset c) {
    final paint = _stroke
      ..color = _kbGlyph
      ..strokeWidth = 1.5;
    canvas
      ..drawCircle(c, 11, paint)
      ..drawOval(Rect.fromCenter(center: c, width: 10, height: 22), paint)
      ..drawLine(c - const Offset(11, 0), c + const Offset(11, 0), paint)
      ..drawLine(
        c + const Offset(-9.5, -5.5),
        c + const Offset(9.5, -5.5),
        paint,
      )
      ..drawLine(
        c + const Offset(-9.5, 5.5),
        c + const Offset(9.5, 5.5),
        paint,
      );
  }

  void _mic(Canvas canvas, Offset c) {
    final paint = _stroke
      ..color = _kbGlyph
      ..strokeWidth = 1.5;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c - const Offset(0, 4), width: 8, height: 14),
          const Radius.circular(4),
        ),
        paint,
      )
      ..drawArc(
        Rect.fromCenter(center: c - const Offset(0, 3), width: 16, height: 16),
        0,
        math.pi,
        false,
        paint,
      )
      ..drawLine(c + const Offset(0, 5), c + const Offset(0, 10), paint);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old._snapshot != _snapshot;
}
