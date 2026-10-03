import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../withdrawals/withdrawal_screen.dart';
import 'select_bank_screen.dart';
import 'wallet_screen.dart';
import 'withdraw_sheet.dart';
import 'withdrawal_pending_screen.dart';

String withdrawalPath(String id) => '/wallet/withdrawals/$id';

String withdrawalPendingPath(String id) => '/wallet/withdrawals/$id/pending';

/// The Withdraw sheet, prefilled for a retry: [amountKobo] in the amount
/// field and [bankCode] as the destination.
String withdrawLocation({int? amountKobo, String? bankCode}) => Uri(
  path: Routes.withdraw,
  queryParameters: {
    if (amountKobo != null) 'amount': '$amountKobo',
    'bank': ?bankCode,
  },
).toString();

/// The Wallet tab. Its other screens open over the shell (their frames have
/// no dock) but sit under /wallet, so a direct `go` draws the Wallet below
/// them, as the Withdraw sheet frame does. Select bank and the withdrawal
/// screens push; Withdraw rises as a sheet on the .5 scrim (spec 3.1, 3.3).
GoRoute walletTabRoute(GlobalKey<NavigatorState> rootKey) => GoRoute(
  path: Routes.wallet,
  pageBuilder: (context, state) => pushPage(state, const WalletScreen()),
  routes: [
    GoRoute(
      path: 'withdraw',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) {
        final query = state.uri.queryParameters;
        return sheetPage(
          state,
          WithdrawSheet(
            amountKobo: int.tryParse(query['amount'] ?? ''),
            bankCode: query['bank'],
          ),
          scrim: IqScrim.sheet,
        );
      },
    ),
    GoRoute(
      path: 'select-bank',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) =>
          pushPage<Bank>(state, const SelectBankScreen()),
    ),
    GoRoute(
      path: 'withdrawals/:id/pending',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => pushPage(
        state,
        WithdrawalPendingScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: 'withdrawals/:id',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) =>
          pushPage(state, WithdrawalScreen(id: state.pathParameters['id']!)),
    ),
  ],
);
