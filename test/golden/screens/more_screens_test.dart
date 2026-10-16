import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/data/device.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/features/profile/profile_routes.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/features/referrals/referrals_state.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'more_harness.dart';
import 'polls_notifications_help_harness.dart';

Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText).first, text);
  await tester.pumpAndSettle();
}

Future<void> _invite(WidgetTester tester, String code) async {
  await pumpMore(tester, Routes.inviteCode);
  await _type(tester, code);
  await tester.tap(find.text('Apply code'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  group('B7 More', () {
    testWidgets('428:18424 More', (tester) async {
      await pumpMore(tester, Routes.more);
      await moreGolden(tester, 'more');
    }, variant: ios);

    testWidgets('428:18663 More, scrolled', (tester) async {
      await pumpMore(tester, Routes.more);
      await _scrollToEnd(tester);
      await moreGolden(tester, 'more_scrolled');
    }, variant: ios);

    testWidgets('429:19063 Clear cache sheet', (tester) async {
      await pumpMore(tester, Routes.more);
      await _scrollToEnd(tester);
      await tester.tap(find.text('Clear cache'));
      await tester.pumpAndSettle();
      await moreGolden(tester, 'clear_cache');
    }, variant: ios);

    testWidgets('484:23036 Sign out?', (tester) async {
      await pumpMore(tester, Routes.more);
      await _scrollToEnd(tester);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await moreGolden(tester, 'sign_out');
    }, variant: ios);

    testWidgets('485:39490 Saved briefs', (tester) async {
      await pumpMore(tester, Routes.moreSavedBriefs);
      await moreGolden(tester, 'saved_briefs');
    });

    testWidgets('Saved briefs, offline', (tester) async {
      await pumpMore(
        tester,
        Routes.moreSavedBriefs,
        repository: ScriptedRepository([BriefsCall.fail]),
      );
      await moreGolden(tester, 'saved_briefs_offline');
    });

    testWidgets('Saved briefs, empty', (tester) async {
      await pumpMore(
        tester,
        Routes.moreSavedBriefs,
        prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
      );
      await moreGolden(tester, 'saved_briefs_empty');
    });
  });

  group('B7 Profile', () {
    testWidgets('40:24 Your profile', (tester) async {
      await pumpMore(tester, Routes.profile);
      await moreGolden(tester, 'your_profile');
    });

    testWidgets('40:141 Your details', (tester) async {
      await pumpMore(tester, Routes.yourDetails);
      await moreGolden(tester, 'your_details');
    });

    for (final (field, frame) in [
      (DetailField.phone, '429:18775'),
      (DetailField.dateOfBirth, '429:18828'),
      (DetailField.state, '429:18881'),
      (DetailField.university, '484:22641'),
      (DetailField.interests, '429:18966'),
      (DetailField.occupation, '484:22898'),
      (DetailField.city, '484:22728'),
      (DetailField.education, '484:22815'),
    ]) {
      testWidgets('$frame Edit · ${field.label}', (tester) async {
        await pumpMore(tester, editDetailPath(field));
        await moreGolden(tester, 'edit_${field.slug.replaceAll('-', '_')}');
      });
    }

    testWidgets('484:22583 Confirm your number', (tester) async {
      await pumpMore(tester, editDetailPath(DetailField.phone));
      await _type(tester, '+234 803 555 4410');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await _type(tester, '4821');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await moreGolden(tester, 'edit_phone_code');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    });
  });

  group('B20 Referrals', () {
    testWidgets('430:19109 Referrals', (tester) async {
      await pumpMore(
        tester,
        Routes.referrals,
        overrides: [inviteCodeOpenProvider.overrideWith((ref) async => true)],
      );
      await moreGolden(tester, 'referrals');
    });

    testWidgets('Referrals after the first win', (tester) async {
      await pumpMore(tester, Routes.referrals);
      await moreGolden(tester, 'referrals_code_closed');
    });

    testWidgets('433:19672 Invite share sheet', (tester) async {
      await pumpMore(
        tester,
        Routes.referrals,
        overrides: [inviteCodeOpenProvider.overrideWith((ref) async => true)],
      );
      await tester.tap(find.text('Invite friends'));
      await tester.pumpAndSettle();
      await moreGolden(tester, 'invite_sheet');
    });

    testWidgets('430:19186 Enter invite code', (tester) async {
      await pumpMore(tester, Routes.inviteCode);
      await _type(tester, 'TUNDE07');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await moreGolden(tester, 'invite_code');
    });

    for (final (code, name) in [
      ('BOLA99', 'invalid'),
      ('EMEKA15', 'expired'),
      ('ADAEZE24', 'own_code'),
      ('TUNDE07', 'success'),
    ]) {
      testWidgets('Enter invite code · $name', (tester) async {
        await _invite(tester, code);
        await moreGolden(tester, 'invite_code_$name');
      });
    }

    testWidgets('430:19331 Referral history, empty', (tester) async {
      await pumpMore(
        tester,
        Routes.referralHistory,
        overrides: [referralsServiceProvider.overrideWithValue(_NoInvites())],
      );
      await moreGolden(tester, 'referral_history_empty');
    });

    testWidgets('430:19239 Referral history', (tester) async {
      await pumpMore(tester, Routes.referralHistory);
      await moreGolden(tester, 'referral_history');
    });
  });

  group('B21 Help centre', () {
    testWidgets('431:19394 Help centre', (tester) async {
      await pumpMore(tester, Routes.helpCentre);
      await moreGolden(tester, 'help_centre');
    });

    testWidgets('436:19729 searching', (tester) async {
      await pumpMore(tester, '${Routes.helpCentre}?q=withdraw');
      await moreGolden(tester, 'help_searching');
    });

    testWidgets('485:39411 no results', (tester) async {
      await pumpMore(tester, '${Routes.helpCentre}?q=visa');
      await moreGolden(tester, 'help_no_results');
    });

    testWidgets('436:19673 answer sheet', (tester) async {
      await pumpMore(tester, Routes.helpCentre);
      await tester.tap(find.text('When do I get paid after a brief closes?'));
      await tester.pumpAndSettle();
      await moreGolden(tester, 'help_answer');
    });

    testWidgets('485:39190 Support conversations', (tester) async {
      await pumpMore(tester, Routes.support);
      await moreGolden(tester, 'support');
    });

    testWidgets('431:19583 Chat with support', (tester) async {
      await pumpMore(tester, Routes.support);
      await tester.tap(find.text('Withdrawal to Access Bank'));
      await tester.pumpAndSettle();
      await moreGolden(tester, 'support_chat');
    });

    testWidgets('485:39308 New conversation', (tester) async {
      await pumpMore(tester, Routes.newConversation);
      await moreGolden(tester, 'support_new');
    });

    testWidgets('431:19647 Report an issue', (tester) async {
      await pumpMore(tester, Routes.reportIssue);
      await _type(
        tester,
        'My withdrawal of ₦10,000.00 has been pending since Monday. Access '
        'Bank says nothing has arrived.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await moreGolden(tester, 'report');
    });

    testWidgets('431:19726 Report sent', (tester) async {
      await pumpMore(tester, Routes.reportIssue);
      await _type(tester, 'Pending since Monday.');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      await moreGolden(tester, 'report_sent');
    });

    testWidgets('431:19781 Terms and conditions', (tester) async {
      await pumpMore(tester, Routes.terms);
      await moreGolden(tester, 'terms');
    });

    testWidgets('431:19828 Privacy policy', (tester) async {
      await pumpMore(tester, Routes.privacy);
      await moreGolden(tester, 'privacy');
    });
  });

  group('B14 Settings', () {
    testWidgets('194:9932 Notification preferences', (tester) async {
      await pumpMore(tester, Routes.notificationPreferences);
      await moreGolden(tester, 'notification_preferences');
    });

    testWidgets('484:23502 phone permission off', (tester) async {
      await pumpMore(
        tester,
        Routes.notificationPreferences,
        device: DemoDeviceService(delay: Duration.zero)
          ..notificationsOn = false,
      );
      await moreGolden(tester, 'notification_preferences_off');
    });

    testWidgets('1336:28442 Try notifications', (tester) async {
      await pumpMore(tester, Routes.tryNotifications);
      await moreGolden(tester, 'try_notifications');
    }, variant: ios);

    testWidgets('194:9964 Delete account', (tester) async {
      await pumpMore(tester, Routes.deleteAccount);
      await moreGolden(tester, 'delete_account');
    });

    testWidgets('194:10046 Delete account, typed', (tester) async {
      await pumpMore(tester, Routes.deleteAccount);
      await _type(tester, 'delete');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await moreGolden(tester, 'delete_account_typed');
    });

    testWidgets('484:23450 Delete account, typed, at ₦0.00', (tester) async {
      await pumpMore(
        tester,
        Routes.deleteAccount,
        repository: EmptyWalletRepository(),
      );
      await _type(tester, 'delete');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await moreGolden(tester, 'delete_account_zero');
    });

    testWidgets('225:10830 Account closing', (tester) async {
      await pumpMore(tester, Routes.accountClosing);
      await moreGolden(tester, 'account_closing');
    });

    testWidgets('484:23398 Restore your account?', (tester) async {
      await pumpMore(tester, Routes.accountClosing);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go(Routes.restoreAccount, extra: DateTime(2026, 11, 4));
      await tester.pumpAndSettle();
      await moreGolden(tester, 'restore_account');
    });
  });

  group('B6 Notifications', () {
    testWidgets('39:24 Notifications', (tester) async {
      await pumpMore(tester, Routes.notifications);
      await moreGolden(tester, 'notifications');
    });

    testWidgets('39:180 Notifications, empty', (tester) async {
      await pumpMore(
        tester,
        Routes.notifications,
        notifications: EmptyNotificationsService(),
      );
      await moreGolden(tester, 'notifications_empty');
    });

    for (final (text, name) in [
      ('₦40,000.00 paid out', 'payout'),
      ('You won ₦12,500.00', 'result'),
      ('Kudi Box closes tomorrow', 'deadline'),
    ]) {
      testWidgets('Notification · $name', (tester) async {
        await pumpMore(tester, Routes.notifications);
        await tester.tap(find.text(text, findRichText: true));
        await tester.pumpAndSettle();
        await moreGolden(tester, 'notification_$name');
      });
    }
  });
}

/// An account that has invited nobody yet.
class _NoInvites extends DemoReferralsService {
  _NoInvites() : super(now: figmaNow);

  @override
  Future<Referrals> referrals() async {
    final all = await super.referrals();
    return Referrals(
      code: all.code,
      invites: const [],
      memberSince: all.memberSince,
    );
  }
}
