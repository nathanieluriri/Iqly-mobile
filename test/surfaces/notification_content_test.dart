import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/features/settings/notification_preferences_screen.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/surfaces/notification_content.dart';
import 'package:iqly_mobile/surfaces/notification_sounds.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);
  final data = DemoData(now: now);
  final inputs = SurfaceInputs.demo(now);
  Brief brief(String id) => data.briefs.firstWhere((b) => b.id == id);

  test('payout on its way (350:17527, 350:17909)', () {
    final w3 = data.withdrawals.firstWhere((w) => w.id == 'w3');
    final note = payoutNotification(
      w3,
      notificationId: inputs.feedIdFor('w3'),
    )!;
    expect(note.title, '₦10,000.00 on its way');
    expect(
      note.body,
      'To Access Bank ••6789 · usually within minutes, up to 24h',
    );
    expect(note.subtext, 'Payout');
    expect(note.channel, SurfaceChannel.payouts);
    expect(note.progress, 1);
    expect(note.progressMax, 3);
    expect(note.ongoing, isTrue);
    expect(note.route, '/wallet/withdrawals/w3');
    expect(
      SurfaceNotification.routeFor(note.payload),
      '/wallet/withdrawals/w3',
    );
  });

  test('a sent payout fills two of three steps', () {
    final w3 = data.withdrawals.firstWhere((w) => w.id == 'w3');
    final sent = w3.copyWith(sentAt: now);
    expect(payoutNotification(sent, notificationId: 'n1')!.progress, 2);
  });

  test('a failed payout has no progress notification', () {
    final w1 = data.withdrawals.firstWhere((w) => w.id == 'w1');
    expect(payoutNotification(w1, notificationId: 'n6'), isNull);
  });

  test('result (347:16090 second banner)', () {
    final award = data.ledger.firstWhere((l) => l.id == 'l3');
    final submission = data.submissions.firstWhere((s) => s.id == 's2');
    final note = resultNotification(
      award,
      submission,
      brief('c3'),
      notificationId: inputs.feedIdFor('l3')!,
    );
    expect(note.title, 'You won ₦12,500.00');
    expect(note.body, '"Sunday is data day" was picked. It is in your wallet.');
    expect(note.route, '/notifications/n4');
    expect(note.channel, SurfaceChannel.results);
  });

  test('draft waiting (347:16090 third banner)', () {
    final note = draftNotification(brief('c5'), now, notificationId: 'n2')!;
    expect(note.title, 'Your Sunline draft is waiting');
    expect(note.body, '6 hours left to send it. Pick up where you stopped.');
    expect(note.channel, SurfaceChannel.closingSoon);
    expect(draftNotification(brief('c3'), now, notificationId: 'x'), isNull);
  });

  test('new poll with actions (350:17527 Expanded)', () {
    final orchid = demoPolls(now).first;
    final note = pollNotification(orchid)!;
    expect(note.title, 'New poll from Orchid Foods');
    expect(
      note.body,
      'Which flavour should we launch first? Takes 10 seconds.',
    );
    expect(
      [for (final a in note.actions) a.label],
      ['Vote now', 'Remind me later'],
    );
    expect(note.thumb, 'orchid-foods');
    expect(
      SurfaceNotification.routeFor(note.payload, actionId: 'vote'),
      '/polls/orchid-foods',
    );
    expect(
      SurfaceNotification.routeFor(note.payload, actionId: 'later'),
      isNull,
    );
    final sunline = demoPolls(now).last;
    expect(pollNotification(sunline), isNull);
  });

  test('ids are stable and payload parsing is forgiving', () {
    expect(stableId('payout:w3'), stableId('payout:w3'));
    expect(stableId('payout:w3'), isNot(stableId('payout:w2')));
    expect(stableId('payout:w3'), lessThan(1 << 31));
    expect(SurfaceNotification.routeFor('not json'), isNull);
    expect(SurfaceNotification.routeFor(null), isNull);
  });

  test('channels match Notification preferences, and their sounds ship', () {
    final topics = {
      SurfaceChannel.closingSoon: NotificationTopic.closingSoon,
      SurfaceChannel.results: NotificationTopic.results,
      SurfaceChannel.payouts: NotificationTopic.payouts,
      SurfaceChannel.newBriefs: NotificationTopic.newBriefs,
      SurfaceChannel.polls: NotificationTopic.polls,
    };
    for (final channel in SurfaceChannel.values) {
      final (title, description) = notificationCopy[topics[channel]]!;
      expect(channel.title, title);
      expect(channel.description, description);
      expect(NotificationTopic.values.byName(channel.name), topics[channel]);
      expect(SurfaceChannel.retired, isNot(contains(channel.id)));
    }
    final keep = File('android/app/src/main/res/raw/keep.xml')
        .readAsStringSync();
    final xcode = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(keep, contains('@raw/iqly_*'));
    expect(keep, contains('@drawable/ic_stat_iqly'));
    for (final sound in IqSound.values) {
      expect(sound.resource, startsWith('iqly_'));
      expect(
        File('android/app/src/main/res/raw/${sound.resource}.ogg').existsSync(),
        isTrue,
      );
      expect(File('ios/Runner/Sounds/${sound.iosFile}').existsSync(), isTrue);
      expect(xcode, contains('${sound.iosFile} in Resources'));
    }
  });

  test('the small icon is the cut-out logomark tile, also on the summaries '
      'OneSignal builds; shortcuts are fg glyphs on a tint disc that read the '
      'same on any launcher and theme', () {
    String read(String path) => File(path).readAsStringSync();
    const res = 'android/app/src/main/res';
    final icon = read('$res/drawable/ic_stat_iqly.xml');
    expect(icon, contains('tool/gen_status_icon.py'));
    expect('<path'.allMatches(icon), hasLength(1));
    expect(icon, contains('#FFFFFFFF'));

    for (final name in ['polls', 'forward', 'submissions']) {
      final adaptive = read('$res/drawable-anydpi-v26/ic_shortcut_$name.xml');
      expect(
        adaptive,
        contains('<background android:drawable="@color/iq_tint"'),
      );
      expect(adaptive, contains('@drawable/ic_shortcut_${name}_foreground'));
      for (final glyph in [
        read('$res/drawable/ic_shortcut_$name.xml'),
        read('$res/drawable/ic_shortcut_${name}_foreground.xml'),
      ]) {
        expect(glyph, contains('@color/iq_fg'));
        expect(glyph, isNot(contains('#2D0048')));
      }
    }
    expect(
      Directory('$res/values-night').listSync().map((f) => f.path),
      isNot(contains(endsWith('surface_colors.xml'))),
    );
    final accent = RegExp(r'name="iq_accent">#([0-9A-F]{8})<')
        .firstMatch(read('$res/values/iq_colors.xml'))![1];
    final oneSignal = read('$res/values/onesignal.xml');
    expect(oneSignal, contains('>@drawable/ic_stat_iqly<'));
    expect(oneSignal, contains('ic_stat_onesignal_default'));
    expect(
      oneSignal,
      contains(
        '"onesignal_notification_accent_color" translatable="false">$accent<',
      ),
    );
    final push = read(
      'android/app/src/main/kotlin/net/iqly/app/IqlyPushExtension.kt',
    );
    expect(push, contains('R.color.iq_accent'));
    expect(
      push,
      matches(RegExp(r'setProgress\([^)]*\)\s*\.setShowWhen\(false\)')),
    );
    expect(push, isNot(contains('R.color.iq_brand')));
  });
}
