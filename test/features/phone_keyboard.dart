import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The system keyboard as an iPhone moves it, for tests that pump 60 Hz
/// frames: it rises while a field holds the text input and goes down two
/// frames after the input closes, sliding 336 pt over 15 frames ease-out,
/// and while it is up it covers the home indicator, so the bottom padding
/// shrinks as it rises (the 34 pt view padding stays).
class PhoneKeyboard {
  PhoneKeyboard(this.tester) {
    _apply();
  }

  final WidgetTester tester;

  static const double height = 336;
  static const double homeIndicator = 34;
  static const double statusBar = 54;
  static const frameTime = Duration(microseconds: 16667);
  static const _slide = 15;
  static const _hideAfter = 2;

  double _inset = 0;
  double _from = 0;
  double _target = 0;
  int _since = 0;
  int _closedFor = 0;

  /// How far the keyboard is up, in points.
  double get inset => _inset;

  /// Pumps one frame, the keyboard moving toward where the input says.
  Future<void> frame() async {
    final shown = tester.testTextInput.isVisible;
    _closedFor = shown ? 0 : _closedFor + 1;
    final target = shown || (_target == 1 && _closedFor < _hideAfter)
        ? 1.0
        : 0.0;
    if (target != _target) {
      _from = _inset / height;
      _target = target;
      _since = 0;
    }
    _since++;
    final t = (_since / _slide).clamp(0.0, 1.0);
    final at = _from + (_target - _from) * Curves.easeOut.transform(t);
    _inset = at * height;
    _apply();
    await tester.pump(frameTime);
  }

  /// Pumps [count] frames.
  Future<void> frames(int count) async {
    for (var i = 0; i < count; i++) {
      await frame();
    }
  }

  /// Pumps frames until [done], at most [limit] of them.
  Future<void> until(bool Function() done, {int limit = 120}) async {
    for (var i = 0; i < limit && !done(); i++) {
      await frame();
    }
    expect(done(), isTrue);
  }

  void _apply() {
    final view = tester.view;
    view.viewInsets = FakeViewPadding(bottom: _inset);
    view.padding = FakeViewPadding(
      top: statusBar,
      bottom: math.max(0, homeIndicator - _inset),
    );
    view.viewPadding = const FakeViewPadding(
      top: statusBar,
      bottom: homeIndicator,
    );
  }
}
