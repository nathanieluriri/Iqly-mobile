import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/responsive.dart';
import 'package:iqly_mobile/data/outcomes_data.dart';
import 'package:iqly_mobile/data/outcomes_service.dart';
import 'package:iqly_mobile/data/share_service.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/outcomes/leaderboard_screen.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_routes.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/outcomes/share_sheet.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/leaderboard_row.dart';
import 'package:iqly_mobile/ui/share_card.dart';

import '../golden/golden.dart';
import '../golden/screens/app_harness.dart';

const _success = 'HapticFeedbackType.successNotification';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Keeps every image it is handed, so a test can read its size.
class _Share extends DemoShareService {
  final images = <Uint8List>[];

  @override
  Future<void> shareImage(
    Uint8List png, {
    required String name,
    String? text,
  }) async {
    images.add(png);
    await super.shareImage(png, name: name, text: text);
  }

  @override
  Future<void> shareImageTo(
    ShareApp app,
    Uint8List png, {
    required String name,
    String? text,
  }) async {
    images.add(png);
    await super.shareImageTo(app, png, name: name, text: text);
  }
}

class _FailingOutcomes implements OutcomesService {
  bool fail = true;
  int calls = 0;

  @override
  Future<Outcome?> outcome(String submissionId) async {
    calls++;
    if (fail) throw Exception('offline');
    return OutcomesDemo.of(submissionId, figmaNow);
  }
}

/// Haptics and clipboard writes the app asks the platform for.
({List<String> haptics, List<String> clipboard}) _platform(
  WidgetTester tester,
) {
  final haptics = <String>[];
  final clipboard = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      haptics.add(call.arguments as String);
    }
    if (call.method == 'Clipboard.setData') {
      clipboard.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return (haptics: haptics, clipboard: clipboard);
}

/// Taps [target] on the share sheet and lets the card render to an image.
Future<void> _shareTo(WidgetTester tester, String target, _Share share) async {
  final before = share.images.length;
  await tester.runAsync(() async {
    await tester.tap(find.text(target));
    for (var i = 0; i < 40 && share.images.length == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}

(int, int) _pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  // The share image is the card at 3x: real type keeps it 358 x 418.
  setUpAll(loadAppFonts);

  testWidgets(
    'B13: the Winner shares its card, opens the leaderboard, the brief and '
    'the wallet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final platform = _platform(tester);
      final share = _Share();
      await pumpApp(
        tester,
        Routes.submissions,
        overrides: [shareServiceProvider.overrideWithValue(share)],
      );
      await _tap(tester, find.text('Sunday is data day'));
      expect(find.byType(WinnerView), findsOneWidget);
      expect(find.text('Your result'), findsOneWidget);
      expect(find.text('You did it.'), findsOneWidget);
      final card = tester.widget<IqShareCard>(find.byType(IqShareCard));
      expect(card.brand.toUpperCase(), 'WINNER · 5TH OF 48');
      expect(card.title, 'Sunday is data day');
      expect(card.amount, '₦12,500');
      expect(card.brief, 'Why do Lagosians skip mobile banking on Sundays?');
      expect(card.name.toUpperCase(), 'ADAEZE OKAFOR');
      expect(find.text('See the leaderboard'), findsOneWidget);
      expect(platform.haptics, [_success]);

      await _tap(tester, find.text('Share your win'));
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(find.text('Share your win'), findsNWidgets(2));
      expect(find.text('SHARE TO'), findsOneWidget);
      for (final target in ['WhatsApp', 'Instagram', 'X', 'Telegram']) {
        expect(find.text(target), findsOneWidget);
      }
      expect(find.text('More…'), findsOneWidget);

      await _shareTo(tester, 'WhatsApp', share);
      expect(find.byType(ShareSheet), findsNothing);
      final sent = share.sharedTo.single;
      expect(sent.app, ShareApp.whatsapp);
      expect(sent.name, 'iqly-win-s2.png');
      expect(sent.text, 'https://iqly.net/challenges/c3');
      expect(_pngSize(share.images.single), (1074, 1254));

      await _tap(tester, find.text('Share your win'));
      await _shareTo(tester, 'More…', share);
      expect(share.shared.single.name, 'iqly-win-s2.png');
      expect(find.byType(ShareSheet), findsNothing);

      await _tap(tester, find.text('Share your win'));
      await _tap(tester, find.text('Copy link'));
      expect(platform.clipboard, ['https://iqly.net/challenges/c3']);
      expect(platform.haptics.last, _success);
      expect(find.byType(ShareSheet), findsNothing);

      await _tap(tester, find.text('Share your win'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Save image'));
        for (var i = 0; i < 40 && share.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(share.saved.single.name, 'iqly-win-s2.png');
      expect(find.byType(ShareSheet), findsNothing);

      await _tap(tester, find.text('Share your win'));
      await _tap(
        tester,
        find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.close),
      );
      expect(find.byType(ShareSheet), findsNothing);

      await _tap(tester, find.text('Share your win'));
      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsNothing);

      await _tap(tester, find.text('See the leaderboard'));
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      expect(find.text('Top 5 of 48 entries'), findsOneWidget);
      expect(find.text('₦400,000 SPLIT'), findsOneWidget);
      final you = tester.widget<IqLeaderboardRow>(
        find.byWidgetPredicate(
          (w) => w is IqLeaderboardRow && w.state == IqLeaderboardRowState.you,
        ),
      );
      expect(
        (you.rank, you.name, you.entry, you.amount),
        ('5', 'You', 'Sunday is data day', '₦12,500'),
      );

      await _tap(tester, find.text('Open the brief'));
      expect(find.byType(BriefDetailScreen), findsOneWidget);
      expect(
        find.text('Why do Lagosians skip mobile banking on Sundays?'),
        findsOneWidget,
      );
      await _tap(tester, find.bySemanticsLabel('Back'));
      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.byType(WinnerView), findsOneWidget);

      await _tap(tester, find.byType(IqShareCard));
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Back'));

      await _tap(tester, find.text('View wallet'));
      expect(find.byType(WalletScreen), findsOneWidget);
      expect(platform.haptics.where((h) => h == _success), hasLength(3));
      semantics.dispose();
    },
  );

  testWidgets(
    'B13: Not selected reads the note, opens what won, the next brief and '
    'the For you feed',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final platform = _platform(tester);
      final container = await pumpApp(tester, Routes.submissions);
      await tester.scrollUntilVisible(
        find.text('One counter for quick jobs'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, find.text('One counter for quick jobs'));
      expect(find.byType(NotSelectedView), findsOneWidget);
      expect(find.text('ONE COUNTER FOR QUICK JOBS'), findsOneWidget);
      expect(find.text('Not this time'), findsOneWidget);
      expect(find.text('9th of 36'), findsOneWidget);
      expect(find.text('A note from the business'), findsOneWidget);
      expect(find.text('H'), findsNWidgets(2));
      expect(find.text('Harbour Microfinance'), findsNWidgets(2));
      expect(
        find.text('Good idea. The winners put every quick job on one counter.'),
        findsOneWidget,
      );
      expect(find.text('FRI, 11:20 AM'), findsOneWidget);
      expect(find.text('For you'), findsOneWidget);
      expect(find.text('Rename our youth current account'), findsOneWidget);
      expect(platform.haptics, isEmpty);

      await _tap(tester, find.text('See what won'));
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      expect(
        find.text('CUT QUEUE TIME AT OUR BRANCH COUNTERS'),
        findsOneWidget,
      );
      expect(find.text('Top 4 of 36 entries'), findsOneWidget);
      expect(find.text('₦350,000 SPLIT'), findsOneWidget);
      expect(find.text('· · ·'), findsOneWidget);
      expect(find.text('One counter for quick jobs'), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.byType(NotSelectedView), findsOneWidget);

      await _tap(tester, find.text('Rename our youth current account'));
      expect(find.byType(BriefDetailScreen), findsOneWidget);
      expect(find.text('₦80k'), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Back'));

      container.read(discoverFiltersProvider.notifier).showAll();
      await _tap(tester, find.text('Find your next brief'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(discoverFiltersProvider).forYou, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('B13: the Winner celebrates with a haptic once per device', (
    tester,
  ) async {
    final platform = _platform(tester);
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Sunday is data day'));
    expect(platform.haptics, [_success]);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
    await _tap(tester, find.text('Sunday is data day'));
    expect(find.byType(WinnerView), findsOneWidget);
    expect(platform.haptics, [_success]);
  });

  testWidgets('B13: a Winner whose board is not out names the business', (
    tester,
  ) async {
    await pumpApp(tester, resultPath('s3'));
    expect(find.text('Winner · Volt Riders'), findsOneWidget);
    expect(find.text('₦50,000'), findsOneWidget);
    expect(find.text('See the leaderboard'), findsNothing);
    await tester.tap(find.byType(IqShareCard));
    await tester.pumpAndSettle();
    expect(find.byType(LeaderboardScreen), findsNothing);
  });

  testWidgets('B13: a row still under review opens its submission', (
    tester,
  ) async {
    await pumpApp(tester, resultPath('s1'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(find.text('Fizzo: short, loud, easy to say'), findsOneWidget);
  });

  testWidgets('B13: a result that fails to load offers Try again', (
    tester,
  ) async {
    final outcomes = _FailingOutcomes();
    await pumpApp(
      tester,
      resultPath('s2'),
      overrides: [outcomesServiceProvider.overrideWithValue(outcomes)],
    );
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    expect(find.text('You did it.'), findsNothing);

    outcomes.fail = false;
    await _tap(tester, find.text('Try again'));
    expect(find.text('You did it.'), findsOneWidget);
    expect(outcomes.calls, 2);
  });

  testWidgets(
    'B13: back from a result opened directly goes to My submissions',
    (tester) async {
      await pumpApp(tester, leaderboardPath('s5'));
      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.byType(NotSelectedView), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.byType(MySubmissionsScreen), findsOneWidget);
    },
  );

  for (final (name, location) in [
    ('winner', resultPath('s2')),
    ('share sheet', sharePath('s2')),
    ('not selected', resultPath('s5')),
    ('leaderboard', leaderboardPath('s2')),
    ('leaderboard not selected', leaderboardPath('s5')),
  ]) {
    testWidgets('B13 $name: 44 pt targets, all labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, location);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  for (final (name, location) in [
    ('winner', resultPath('s2')),
    ('not selected', resultPath('s5')),
    ('leaderboard', leaderboardPath('s2')),
  ]) {
    testWidgets('B13 $name holds its layout while a keyboard leaves', (
      tester,
    ) async {
      await pumpApp(tester, location);
      final content = find.byType(CenteredContent).first;
      final height = tester.getSize(content).height;
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();
      expect(tester.getSize(content).height, height);
    });
  }
}
