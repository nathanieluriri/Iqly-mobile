import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/biometric_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/pressable.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'wallet_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  IqlyRepository? repository,
  DemoWalletService? wallet,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(
    tester,
    location,
    repository: repository ?? WalletRepository(),
    overrides: walletOverrides(wallet: wallet),
  );
  if (act != null) await act(tester);
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

/// The Withdraw sheet with ₦5,000.00, through the PIN sheet.
Future<void> _toPin(WidgetTester tester) async {
  await _settle(tester);
  await _tap(tester, find.text('Withdraw').last);
}

Future<void> _confirmPin(WidgetTester tester) async {
  await _toPin(tester);
  await tester.enterText(find.byType(EditableText).last, '1234');
  await tester.pump();
  await tester.tap(find.text('Confirm withdrawal'));
}

void main() {
  setUpAll(loadAppFonts);

  group('B5 wallet', () {
    testWidgets('wallet (37:24)', (tester) async {
      await _golden(tester, 'wallet_wallet', Routes.wallet);
    });

    testWidgets('balance hidden (331:15080)', (tester) async {
      await _golden(
        tester,
        'wallet_balance_hidden',
        Routes.wallet,
        act: (tester) => _tap(
          tester,
          find.byWidgetPredicate(
            (w) => w is IqPressable && w.semanticLabel == 'Hide balance',
          ),
        ),
      );
    });

    testWidgets('On its way lens of the tab root', (tester) async {
      await _golden(
        tester,
        'wallet_lens_on_its_way',
        Routes.wallet,
        act: (tester) => _tap(tester, find.text('On its way')),
      );
    });

    testWidgets('Earned lens of the tab root', (tester) async {
      await _golden(
        tester,
        'wallet_lens_earned',
        Routes.wallet,
        act: (tester) => _tap(tester, find.text('Earned')),
      );
    });

    testWidgets('On its way (331:15089)', (tester) async {
      await _golden(tester, 'wallet_on_its_way', walletOnItsWayPath);
    });

    testWidgets('Earned so far (331:15098)', (tester) async {
      await _golden(tester, 'wallet_earned', walletEarnedPath);
    });

    testWidgets('failed to load (165:8792)', (tester) async {
      await _golden(
        tester,
        'wallet_failed',
        Routes.wallet,
        repository: FailingWalletRepository(),
      );
    });

    testWidgets('no activity (165:8921)', (tester) async {
      await _golden(
        tester,
        'wallet_no_activity',
        Routes.wallet,
        repository: EmptyWalletRepository(),
      );
    });

    testWidgets('loading, first visit only', (tester) async {
      await _golden(
        tester,
        'wallet_loading',
        Routes.wallet,
        repository: PendingWalletRepository(),
        act: (tester) => tester.pump(const Duration(milliseconds: 400)),
      );
    });
  });

  group('B5 activity', () {
    testWidgets('All (343:16290)', (tester) async {
      await _golden(tester, 'wallet_activity_all', activityPath());
    });

    testWidgets('Rewards (331:15107)', (tester) async {
      await _golden(
        tester,
        'wallet_activity_rewards',
        activityPath(ActivityTab.rewards),
      );
    });

    testWidgets('Withdrawals (343:16311)', (tester) async {
      await _golden(
        tester,
        'wallet_activity_withdrawals',
        activityPath(ActivityTab.withdrawals),
      );
    });

    testWidgets('Filter activity sheet (332:15891)', (tester) async {
      await _golden(
        tester,
        'wallet_filter_sheet',
        activityPath(),
        act: (tester) => _tap(tester, find.text('Filter')),
      );
    });
  });

  group('B5 bank accounts', () {
    testWidgets('Bank account sheet (332:15657)', (tester) async {
      await _golden(
        tester,
        'wallet_bank_account_sheet',
        bankAccountPath,
        act: _settle,
      );
    });

    testWidgets('select bank (38:20)', (tester) async {
      await _golden(tester, 'wallet_select_bank', Routes.selectBank);
    });

    testWidgets('add bank, account number (483:22323)', (tester) async {
      await _golden(
        tester,
        'wallet_add_bank',
        addBankPath('044'),
        act: (tester) async {
          await _settle(tester);
          await tester.enterText(find.byType(EditableText), '0123456789');
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('add bank, name verified (483:22389)', (tester) async {
      await _golden(
        tester,
        'wallet_add_bank_verified',
        addBankPath('044'),
        act: (tester) async {
          await _settle(tester);
          await tester.enterText(find.byType(EditableText), '0123456789');
          await _tap(tester, find.text('Check the name'));
        },
      );
    });
  });

  group('B5 withdraw', () {
    testWidgets('withdraw sheet (40:9785)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sheet',
        withdrawLocation(amountKobo: 500000),
        act: _settle,
      );
    });

    testWidgets('above available (483:21751)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_above_available',
        withdrawLocation(amountKobo: 2000000),
        act: _settle,
      );
    });

    testWidgets('below minimum (483:21872)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_below_minimum',
        withdrawLocation(amountKobo: 50000),
        act: (tester) async {
          await _settle(tester);
          await _tap(tester, find.text('Withdraw').last);
        },
      );
    });

    testWidgets('confirm with PIN (483:22222)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_pin',
        withdrawLocation(amountKobo: 500000),
        act: (tester) async {
          await _toPin(tester);
          await tester.enterText(find.byType(EditableText).last, '1234');
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('confirm with PIN, Face ID offered (483:22222)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        withdrawLocation(amountKobo: 500000),
        repository: WalletRepository(),
        overrides: [
          ...walletOverrides(),
          biometricServiceProvider.overrideWithValue(const _CancelledFaceId()),
        ],
      );
      await _toPin(tester);
      await tester.enterText(find.byType(EditableText).last, '1234');
      await tester.pumpAndSettle();
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/wallet_withdraw_pin_face_id.png',
      );
    });

    testWidgets('sending (483:21992)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sending',
        withdrawLocation(amountKobo: 500000),
        wallet: HangingWalletService(),
        act: (tester) async {
          await _confirmPin(tester);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    });

    testWidgets('no connection (483:22107)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_no_connection',
        withdrawLocation(amountKobo: 500000),
        wallet: instantWallet()..failWith = WalletFailure.offline,
        act: (tester) async {
          await _confirmPin(tester);
          await _settle(tester);
        },
      );
    });

    testWidgets('withdrawal pending (38:147)', (tester) async {
      await _golden(
        tester,
        'wallet_withdrawal_pending',
        withdrawalPendingPath('w4'),
        repository: RequestedWalletRepository(),
      );
    });
  });

  group('B14 withdrawals', () {
    testWidgets('tracker (194:9752)', (tester) async {
      await _golden(tester, 'withdrawals_tracker', withdrawalPath('w3'));
    });

    testWidgets('arrived (485:39669)', (tester) async {
      await _golden(
        tester,
        'withdrawals_arrived',
        withdrawalPath('w3'),
        repository: ArrivedWalletRepository(),
      );
    });

    testWidgets('failed (194:9835)', (tester) async {
      await _golden(tester, 'withdrawals_failed', withdrawalPath('w1'));
    });

    testWidgets('reversed (no frame, built on 194:9835)', (tester) async {
      await _golden(tester, 'withdrawals_reversed', withdrawalPath('w0'));
    });

    testWidgets('home after payout (194:10143)', (tester) async {
      await _golden(
        tester,
        'withdrawals_home_after_payout',
        Routes.home,
        repository: PaidOutWalletRepository(),
      );
    });
  });
}

/// A phone with Face ID where the person cancels the system check, so the
/// PIN sheet opens and offers Face ID again.
class _CancelledFaceId implements BiometricService {
  const _CancelledFaceId();

  @override
  Future<BiometricKind?> available() async => BiometricKind.face;

  @override
  Future<bool> confirm(String reason) async => false;
}
