import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/more/more_state.dart';

void main() {
  test('names the build, as the frame does', () {
    expect(BuildInfo.sample.footer(ios: true), 'IQLY FOR IOS 1.4.2 (310)');
  });

  test('adds the running patch', () {
    const info = BuildInfo(version: '0.2.0', build: '2', patch: 2);
    expect(info.footer(ios: false), 'IQLY FOR ANDROID 0.2.0 (2) · PATCH 2');
  });
}
