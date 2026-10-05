import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/surfaces/biometric_copy.dart';
import 'package:iqly_mobile/surfaces/shortcuts.dart';
import 'package:iqly_mobile/surfaces/surface_launch.dart';

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);

  test('icon menu entries in frame order (347:16322, 350:17788)', () {
    final items = appShortcuts(polls: demoPolls(now), draftBriefId: 'c5');
    expect(
      [for (final s in items) s.label],
      ['Answer a quick poll', 'Continue my draft', 'My submissions'],
    );
    expect(
      [for (final s in items) s.type],
      [
        'iqly://app/polls/orchid-foods',
        'iqly://app/briefs/c5/submit',
        'iqly://app/submissions',
      ],
    );
    expect(
      [for (final s in items) s.icon],
      ['ic_shortcut_polls', 'ic_shortcut_forward', 'ic_shortcut_submissions'],
    );
  });

  test('entries with nothing behind them are left out', () {
    final items = appShortcuts(
      polls: demoPolls(now),
      draftBriefId: null,
      showPolls: false,
    );
    expect([for (final s in items) s.label], ['My submissions']);
  });

  test('biometric prompt words (350:17937)', () {
    final copy = BiometricCopy.withdraw(
      amountKobo: 500000,
      destination: 'Access Bank ••6789',
    );
    expect(copy.title, 'Confirm it is you');
    expect(copy.subtitle, 'Withdraw ₦5,000.00 to Access Bank ••6789');
    expect(copy.hint, 'Touch the fingerprint sensor');
    expect(copy.cancel, 'Cancel');
    expect(copy.fallback, 'Use PIN');
  });

  test('a tap waits for sign in and a tab root', () {
    final queue = SurfaceLaunchQueue(readyRoots: {'/home', '/wallet'});
    expect(
      queue.offer('/polls/orchid-foods', location: '/splash', signedIn: true),
      isNull,
    );
    expect(queue.onLocation('/landing', signedIn: false), isNull);
    expect(queue.onLocation('/home', signedIn: false), isNull);
    expect(queue.onLocation('/home', signedIn: true), '/polls/orchid-foods');
    expect(queue.onLocation('/home', signedIn: true), isNull);
    expect(
      queue.offer('/submissions', location: '/wallet', signedIn: true),
      '/submissions',
    );
    expect(queue.pending, isNull);
  });
}
