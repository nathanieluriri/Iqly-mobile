import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderClipRect;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/illustration.dart';

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
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

/// The sheet focuses AMOUNT once it has risen.
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// The B5 withdraw with the ledger held until the test answers, so the
/// pending moment starts on a frame the test picks.
class _HeldRequestedRepository extends RequestedWalletRepository {
  final answer = Completer<void>();

  @override
  Future<List<LedgerEntry>> ledger() async {
    await answer.future;
    return super.ledger();
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('B5 wallet', () {
    testWidgets('wallet (37:24)', (tester) async {
      await _golden(tester, 'wallet_wallet', Routes.wallet);
    });

    testWidgets('withdraw sheet (40:9785)', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sheet',
        withdrawLocation(amountKobo: 500000),
        act: _settleSheet,
      );
    });

    testWidgets('select bank (38:20)', (tester) async {
      await _golden(tester, 'wallet_select_bank', Routes.selectBank);
    });

    testWidgets('withdrawal pending (38:147)', (tester) async {
      await _golden(
        tester,
        'wallet_withdrawal_pending',
        withdrawalPendingPath('w4'),
        repository: RequestedWalletRepository(),
      );
    });

    testWidgets('withdrawal pending mid-sweep: the ink whole, the strap '
        'alone half across (spec 5.29)', (tester) async {
      final repository = _HeldRequestedRepository();
      await pumpApp(
        tester,
        withdrawalPendingPath('w4'),
        repository: repository,
        reducedMotion: false,
        overrides: walletOverrides(),
      );
      repository.answer.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(Arrive), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 242));

      final art = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                IqIllustrations.wallet.asset,
      );
      final ink = find.descendant(of: find.byType(Arrive), matching: art);
      final strap = find.descendant(of: find.byType(Wipe), matching: art);
      Color fill(Finder layer, String? id, Color color) =>
          (tester.widget<SvgPicture>(layer).bytesLoader as SvgAssetLoader)
              .colorMapper!
              .substitute(id, 'path', 'fill', color);

      expect(fill(strap, 'accent', IqColors.accent), IqColors.accent);
      expect(fill(strap, 'ink', IqColors.brand).a, 0);
      expect(fill(strap, null, IqColors.brand).a, 0);
      expect(fill(ink, 'ink', IqColors.brand), IqColors.brand);
      expect(fill(ink, null, IqColors.brand), IqColors.brand);
      expect(fill(ink, 'accent', IqColors.accent).a, 0);

      final inkFade = tester.widget<FadeTransition>(
        find.ancestor(of: ink, matching: find.byType(FadeTransition)).first,
      );
      expect(inkFade.opacity.value, greaterThan(0.9));
      final sweep = tester.renderObject<RenderClipRect>(
        find.ancestor(of: strap, matching: find.byType(ClipRect)).first,
      );
      expect(
        sweep.clipper!.getClip(sweep.size).width / sweep.size.width,
        closeTo(0.5, 0.01),
      );

      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/wallet_withdrawal_pending_mid_sweep.png',
      );

      await tester.pump(const Duration(seconds: 1));
      await expectMatchesGolden(
        find.byType(MaterialApp),
        'goldens/wallet_withdrawal_pending.png',
      );
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

    testWidgets('loading: the failed frame without its banner', (tester) async {
      await _golden(
        tester,
        'wallet_loading',
        Routes.wallet,
        repository: PendingWalletRepository(),
        act: (tester) => tester.pump(const Duration(milliseconds: 400)),
      );
    });

    testWidgets('withdraw sheet: the keyboard is up', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sheet_keyboard',
        withdrawLocation(amountKobo: 500000),
        act: (tester) async {
          await _settleSheet(tester);
          tester.view.padding = const FakeViewPadding(top: 54);
          tester.view.viewInsets = const FakeViewPadding(bottom: 336);
        },
      );
    });

    testWidgets('withdraw sheet: more than is available', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sheet_over',
        withdrawLocation(amountKobo: 1500000),
        act: _settleSheet,
      );
    });

    testWidgets('withdraw sheet: another bank, verified', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sheet_verified',
        withdrawLocation(amountKobo: 500000, bankCode: '50211'),
        act: (tester) async {
          await _settleSheet(tester);
          await tester.enterText(find.byType(EditableText).last, '0123456789');
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('withdraw sheet: another bank, not verified', (tester) async {
      await _golden(
        tester,
        'wallet_withdraw_sheet_unverified',
        withdrawLocation(amountKobo: 500000, bankCode: '50211'),
        act: (tester) async {
          await _settleSheet(tester);
          await tester.enterText(
            find.byType(EditableText).last,
            DemoWalletService.unverifiableAccountNumber,
          );
          await tester.pumpAndSettle();
        },
      );
    });
  });

  group('B14 withdrawals', () {
    testWidgets('tracker (194:9752)', (tester) async {
      await _golden(tester, 'withdrawals_tracker', withdrawalPath('w3'));
    });

    testWidgets('failed (194:9835)', (tester) async {
      await _golden(tester, 'withdrawals_failed', withdrawalPath('w1'));
    });

    testWidgets('tracker once the payout arrived', (tester) async {
      await _golden(
        tester,
        'withdrawals_tracker_arrived',
        withdrawalPath('w3'),
        repository: PaidOutWalletRepository(),
      );
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
