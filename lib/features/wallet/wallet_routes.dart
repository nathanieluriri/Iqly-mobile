import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../shell/tablet_sheet.dart';
import '../../router.dart';
import '../../ui/wallet_card.dart';
import '../withdrawals/withdrawal_screen.dart';
import 'activity_screen.dart';
import 'add_bank_screen.dart';
import 'bank_account_sheet.dart';
import 'select_bank_screen.dart';
import 'wallet_balance_screen.dart';
import 'wallet_screen.dart';
import 'withdraw_sheet.dart';
import 'withdrawal_pending_screen.dart';

/// The tracker, arrived, failed and reversed states of one withdrawal. The
/// payout notification links here; keep the path stable.
String withdrawalPath(String id) => '/wallet/withdrawals/$id';

String withdrawalPendingPath(String id) => '/wallet/withdrawals/$id/pending';

const walletOnItsWayPath = '/wallet/on-its-way';
const walletEarnedPath = '/wallet/earned';
const bankAccountPath = '/wallet/bank-account';

enum ActivityTab { all, rewards, withdrawals }

String activityPath([ActivityTab tab = ActivityTab.all]) =>
    tab == ActivityTab.all
    ? '/wallet/activity'
    : '/wallet/activity?tab=${tab.name}';

String addBankPath(String bankCode) => '/wallet/add-bank?bank=$bankCode';

/// The Withdraw sheet, prefilled for a retry: [amountKobo] in the amount
/// field and the saved account [account] names (its id, or its key in the
/// demo) as the destination.
String withdrawLocation({int? amountKobo, String? account}) => Uri(
  path: Routes.withdraw,
  queryParameters: {
    if (amountKobo != null) 'amount': '$amountKobo',
    'account': ?account,
  },
).toString();

/// The Wallet tab. Everything under it is a sub page or a sheet over the
/// shell (Page bar, Back, no dock): pages push 300 / 240, sheets rise 300
/// and drop 200 on the .5 scrim.
GoRoute walletTabRoute(GlobalKey<NavigatorState> rootKey) => GoRoute(
  path: Routes.wallet,
  pageBuilder: (context, state) => pushPage(state, const WalletScreen()),
  routes: [
    GoRoute(
      path: 'withdraw',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) {
        final query = state.uri.queryParameters;
        final sheet = WithdrawSheet(
          amountKobo: int.tryParse(query['amount'] ?? ''),
          account: query['account'],
        );
        if (Layout.isTablet(context)) {
          return TabletDialogPage(
            key: state.pageKey,
            name: state.name ?? state.path,
            width: 480,
            child: sheet,
          );
        }
        return sheetPage(state, sheet, scrim: IqScrim.sheet);
      },
    ),
    GoRoute(
      path: 'bank-account',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => Layout.isTablet(context)
          ? TabletDialogPage(
              key: state.pageKey,
              name: state.name ?? state.path,
              width: 480,
              child: const BankAccountSheet(),
            )
          : sheetPage(state, const BankAccountSheet(), scrim: IqScrim.sheet),
    ),
    GoRoute(
      path: 'on-its-way',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => pushPage(
        state,
        const WalletBalanceScreen(balance: IqWalletCardBalance.onItsWay),
      ),
    ),
    GoRoute(
      path: 'earned',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => pushPage(
        state,
        const WalletBalanceScreen(balance: IqWalletCardBalance.earned),
      ),
    ),
    GoRoute(
      path: 'activity',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => pushPage(
        state,
        ActivityScreen(
          initial:
              ActivityTab.values
                  .where((t) => t.name == state.uri.queryParameters['tab'])
                  .firstOrNull ??
              ActivityTab.all,
        ),
      ),
    ),
    GoRoute(
      path: 'select-bank',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) =>
          pushPage<bool>(state, const SelectBankScreen()),
    ),
    GoRoute(
      path: 'add-bank',
      parentNavigatorKey: rootKey,
      pageBuilder: (context, state) => pushPage<bool>(
        state,
        AddBankScreen(bankCode: state.uri.queryParameters['bank'] ?? ''),
      ),
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

/// Back to the opener; with nothing to go back to, the Wallet.
void leaveWallet(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.wallet, extra: NavDirection.back);
  }
}
