import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/biometric_service.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/live/brief_marks_sync.dart';
import 'package:iqly_mobile/data/live/submit_queue.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/edit_detail_screen.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/features/submit/submit_sent.dart';
import 'package:iqly_mobile/features/splash/patch_dialog.dart';
import 'package:iqly_mobile/features/wallet/pin_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/features/wallet/withdrawal_pin_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

/// The API as these tests script it: each `METHOD /path` answers from
/// [routes], every other read an empty page.
class _Server {
  _Server([Map<String, http.Response Function(http.Request)>? routes])
    : routes = {...?routes};

  final Map<String, http.Response Function(http.Request)> routes;
  final requests = <http.Request>[];

  /// Requests to these routes fail as a dropped connection does.
  final offline = <String>{};

  late final api = ApiClient(
    tokens: MemoryTokenStore('t'),
    baseUrl: 'https://api.test',
    client: MockClient((r) async {
      requests.add(r);
      final route = '${r.method} ${r.url.path}';
      if (offline.contains(route)) {
        throw http.ClientException('offline', r.url);
      }
      return routes[route]?.call(r) ?? ok(page([]));
    }),
  );

  List<http.Request> to(String route) => [
    for (final r in requests)
      if ('${r.method} ${r.url.path}' == route) r,
  ];
}

/// [wait] after the launch's clock, as the API writes a time.
String _after(Duration wait) => launchNow.add(wait).toUtc().toIso8601String();

Map<String, Object?> _body(http.Request r) =>
    (jsonDecode(r.body) as Map).cast<String, Object?>();

http.Response _refused(
  int status,
  String code, [
  Map<String, Object?> details = const {},
  Map<String, String> headers = const {},
]) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'No.', 'details': details},
  }),
  status,
  headers: {'content-type': 'application/json', ...headers},
);

Map<String, Object?> _pin({
  bool set = true,
  bool locked = false,
  bool resetRequired = false,
}) => {
  'set': set,
  'updatedAt': '2026-10-01T10:00:00Z',
  'locked': locked,
  'lockedUntil': null,
  'resetRequired': resetRequired,
  'attemptsLeft': set ? 5 : null,
};

/// A wallet with ₦15,000.00 to withdraw to Access Bank ••6789; a
/// withdrawal is made only with the PIN 2580 once [pinAsked].
_Server _wallet({
  Map<String, Object?>? pin,
  bool pinAsked = true,
  http.Response Function(http.Request)? verify,
}) => _Server({
  'GET /wallet': (_) => ok(walletJson()),
  'GET /wallet/bank-account': (_) => ok(bankAccountJson()),
  'GET /banks': (_) => ok(banksJson),
  'GET /wallet/pin': (_) => ok(pin ?? _pin()),
  'POST /wallet/pin/verify':
      verify ??
      (r) => _body(r)['pin'] == '2580'
          ? ok({'verified': true})
          : _refused(403, 'PIN_INCORRECT', {'attemptsLeft': 4}),
  'POST /wallet/withdrawals': (r) {
    final given = _body(r)['pin'];
    if (pinAsked && given == null) return _refused(403, 'PIN_REQUIRED');
    if (pinAsked && given != '2580') {
      return _refused(403, 'PIN_INCORRECT', {'attemptsLeft': 3});
    }
    return ok(withdrawalJson({'id': 'w_2', 'amount': 500000}), status: 201);
  },
});

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is IqField && w.label == label),
  matching: find.byType(EditableText),
);

/// Runs [work] while the frames and the fake clock move on.
Future<T> settled<T>(WidgetTester tester, Future<T> work) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
  return work;
}

/// [work] once it lands, with the fake clock moving a second at a time.
Future<T> _await<T>(WidgetTester tester, Future<T> work) async {
  var landed = false;
  work.whenComplete(() => landed = true).ignore();
  for (var i = 0; i < 60 && !landed; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
  return work;
}

/// Types into the field labelled [label], with nothing else focused first.
Future<void> _type(WidgetTester tester, String label, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _openWithdraw(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Withdraw').first);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await _type(tester, 'Amount', '5000');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Withdraw').last);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

IqButton _button(WidgetTester tester, String label) => tester.widget<IqButton>(
  find.byWidgetPredicate((w) => w is IqButton && w.label == label),
);

Backend _with(Set<LiveFeature> more) => Backend.of({...firstFeatures, ...more});

/// No value the phone keeps holds [secret].
void _neverKept(String secret) {
  final prefs = SharedPreferences.getInstance();
  prefs.then((p) {
    for (final key in p.getKeys()) {
      expect('${p.get(key)}', isNot(contains(secret)), reason: key);
    }
  });
}

/// Surfaces that keep each set of briefs the phone schedules reminders
/// for.
class _Scheduling extends Surfaces {
  _Scheduling(GoRouter router, this.scheduled)
    : super(router: router, signedIn: () => true, tabRoots: const {'/'});

  final List<Set<String>> scheduled;

  @override
  Future<void> syncCloseReminders(
    Iterable<Brief> briefs, {
    Set<String> keep = const {},
  }) async => scheduled.add({for (final b in briefs) b.id, ...keep});
}

/// A fingerprint sensor that passes while [pass] holds.
class _Finger implements BiometricService {
  bool pass = true;
  final asked = <String>[];

  @override
  Future<BiometricKind?> available() async => BiometricKind.fingerprint;

  @override
  Future<bool> confirm(String reason) async {
    asked.add(reason);
    return pass;
  }
}

void main() {
  group('withdrawing with the fingerprint', () {
    Future<(_Finger, MemoryPinVault)> launch(
      WidgetTester tester,
      _Server server,
      String location,
    ) async {
      final finger = _Finger();
      final vault = MemoryPinVault();
      await pumpLiveLaunch(
        tester,
        location,
        api: server.api,
        mode: _with({LiveFeature.withdrawalPin}),
        overrides: [
          biometricServiceProvider.overrideWithValue(finger),
          pinVaultProvider.overrideWithValue(vault),
        ],
      );
      await tester.pumpAndSettle();
      return (finger, vault);
    }

    testWidgets('More turns it on with the PIN, checked by the API, then '
        'the fingerprint, and off again', (tester) async {
      final server = _wallet();
      final (finger, vault) = await launch(tester, server, Routes.more);
      expect(find.text('Withdraw with fingerprint'), findsOneWidget);

      await tester.tap(find.text('Withdraw with fingerprint'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byType(PinSheet), findsOneWidget);
      expect(find.textContaining('instead'), findsNothing);
      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(_body(server.to('POST /wallet/pin/verify').single)['pin'], '2580');
      expect(finger.asked, ['Turn on fingerprint for withdrawals']);
      expect(await vault.read('u_1'), '2580');

      await tester.tap(find.text('Withdraw with fingerprint'));
      await tester.pumpAndSettle();
      expect(await vault.read('u_1'), isNull);
      _neverKept('2580');
    });

    testWidgets('a refused fingerprint at setup keeps nothing', (tester) async {
      final server = _wallet();
      final (finger, vault) = await launch(tester, server, Routes.more);
      finger.pass = false;
      await tester.tap(find.text('Withdraw with fingerprint'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(await vault.read('u_1'), isNull);
    });

    testWidgets('once on, a withdrawal asks for the fingerprint, not the '
        'PIN, and carries the kept PIN', (tester) async {
      final server = _wallet();
      final (finger, vault) = await launch(tester, server, Routes.wallet);
      await vault.write('u_1', '2580');
      await _openWithdraw(tester);
      expect(finger.asked, ['Confirm withdrawal']);
      expect(find.byType(PinSheet), findsNothing);
      expect(
        _body(server.to('POST /wallet/withdrawals').single)['pin'],
        '2580',
      );
    });

    testWidgets('a cancelled fingerprint falls back to the PIN sheet, which '
        'offers the fingerprint again', (tester) async {
      final server = _wallet();
      final (finger, vault) = await launch(tester, server, Routes.wallet);
      await vault.write('u_1', '2580');
      finger.pass = false;
      await _openWithdraw(tester);
      expect(find.byType(PinSheet), findsOneWidget);
      expect(find.text('Use fingerprint instead'), findsOneWidget);
      finger.pass = true;
      await tester.tap(find.text('Use fingerprint instead'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(
        _body(server.to('POST /wallet/withdrawals').single)['pin'],
        '2580',
      );
    });

    testWidgets('a kept PIN the API refuses (changed elsewhere) is dropped '
        'and the PIN sheet asks', (tester) async {
      final server = _wallet();
      final (_, vault) = await launch(tester, server, Routes.wallet);
      await vault.write('u_1', '1111');
      await _openWithdraw(tester);
      expect(find.byType(PinSheet), findsOneWidget);
      expect(await vault.read('u_1'), isNull);
      expect(find.textContaining('instead'), findsNothing);
      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Confirm withdrawal'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(
        [
          for (final r in server.to('POST /wallet/withdrawals'))
            _body(r)['pin'],
        ],
        ['1111', '2580'],
      );
    });
  });

  group('the withdrawal PIN', () {
    testWidgets('live with a PIN set: the API checks it on the sheet, a '
        'wrong one says the tries left, and the withdrawal carries it', (
      tester,
    ) async {
      final server = _wallet();
      await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: server.api,
        mode: _with({LiveFeature.withdrawalPin}),
      );
      await _openWithdraw(tester);
      expect(find.byType(PinSheet), findsOneWidget);
      expect(find.textContaining('instead'), findsNothing);

      await _type(tester, 'iQLY PIN', '1111');
      await tester.tap(find.text('Confirm withdrawal'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Wrong PIN, 4 tries left. Forgot it? Reset it by email from More.',
        ),
        findsOneWidget,
      );
      expect(server.to('POST /wallet/withdrawals'), isEmpty);

      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Confirm withdrawal'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      final sent = server.to('POST /wallet/withdrawals').single;
      expect(_body(sent)['pin'], '2580');
      expect(sent.headers.values.join(), isNot(contains('2580')));
      expect(find.byType(WithdrawSheet), findsNothing);
      _neverKept('2580');
    });

    testWidgets('Try again after a lost answer resends with the PIN under '
        'the same key: one withdrawal', (tester) async {
      final server = _wallet();
      final made = <String, Map<String, Object?>>{};
      server.routes['POST /wallet/withdrawals'] = (r) {
        final key = r.headers['idempotency-key']!;
        if (made.isEmpty) {
          made[key] = withdrawalJson({'id': 'w_2', 'amount': 500000});
          return _refused(503, 'SERVICE_UNAVAILABLE');
        }
        if (_body(r)['pin'] != '2580') return _refused(403, 'PIN_REQUIRED');
        return ok(made[key] ??= withdrawalJson({'id': 'w_${made.length + 2}'}));
      };
      await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: server.api,
        mode: _with({LiveFeature.withdrawalPin}),
      );
      await _openWithdraw(tester);
      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Confirm withdrawal'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t send.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      final sends = server.to('POST /wallet/withdrawals');
      expect(sends, hasLength(2));
      expect({
        for (final r in sends) r.headers['idempotency-key'],
      }, hasLength(1));
      expect(_body(sends.last)['pin'], '2580');
      expect(made, hasLength(1));
      expect(find.byType(WithdrawSheet), findsNothing);
    });

    testWidgets('a lock says how long it holds', (tester) async {
      final server = _wallet(
        verify: (_) => _refused(
          423,
          'PIN_LOCKED',
          {'retryAfterSeconds': 1800},
          {'retry-after': '1800'},
        ),
      );
      await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: server.api,
        mode: _with({LiveFeature.withdrawalPin}),
      );
      await _openWithdraw(tester);
      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Confirm withdrawal'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Locked after 5 wrong PINs. Try again in 30 min, or reset it by '
          'email from More.',
        ),
        findsOneWidget,
      );
      expect(server.to('POST /wallet/withdrawals'), isEmpty);
    });

    testWidgets('a lock only a reset opens leads to the reset, which sends '
        'the emailed code with the new PIN', (tester) async {
      final server = _wallet(
        verify: (_) => _refused(423, 'PIN_RESET_REQUIRED'),
      );
      server.routes['POST /wallet/pin/code'] = (_) => ok({
        'sentTo': 'a•••@example.com',
        'expiresAt': _after(const Duration(minutes: 10)),
        'resendAt': _after(const Duration(minutes: 1)),
      });
      server.routes['POST /wallet/pin/reset'] = (_) => ok(_pin());
      await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: server.api,
        mode: _with({LiveFeature.withdrawalPin}),
      );
      await _openWithdraw(tester);
      await _type(tester, 'iQLY PIN', '2580');
      await tester.tap(find.text('Confirm withdrawal'));
      await tester.pumpAndSettle();
      expect(find.text(PinSheet.lockedForReset), findsOneWidget);
      await tester.tap(find.text('Reset it by email'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byType(WithdrawalPinScreen), findsOneWidget);
      expect(
        find.text('We email you a code. It sets a new PIN and unlocks it.'),
        findsOneWidget,
      );

      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('New PIN'), findsNothing);
      expect(find.text('6-digit code'), findsNothing);
      await tester.tap(find.text('Email me a code'));
      await tester.pump();
      await tester.pump();
      expect(server.to('POST /wallet/pin/code'), hasLength(1));
      expect(
        find.text('Sent to a•••@example.com. Resend in 1:00.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(
        find.text('Sent to a•••@example.com. Didn’t get it? Resend the code.'),
        findsOneWidget,
      );
      expect(_button(tester, 'Continue').disabled, isTrue);
      await _type(tester, '6-digit code', '48215');
      expect(_button(tester, 'Continue').disabled, isTrue);
      await _type(tester, '6-digit code', '482152');
      expect(_button(tester, 'Continue').disabled, isFalse);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(_button(tester, 'Save PIN').disabled, isTrue);
      await _type(tester, 'New PIN', '4321');
      await _type(tester, 'New PIN again', '4321');
      expect(_button(tester, 'Save PIN').disabled, isFalse);
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();
      expect(_body(server.to('POST /wallet/pin/reset').single), {
        'code': '482152',
        'pin': '4321',
      });
      _neverKept('4321');
    });

    testWidgets(
      'withdrawalPin off: no PIN asked, nothing sent to /wallet/pin',
      (tester) async {
        final server = _wallet(pinAsked: false);
        await pumpLiveLaunch(tester, Routes.wallet, api: server.api);
        await _openWithdraw(tester);
        expect(find.byType(PinSheet), findsNothing);
        final sent = server.to('POST /wallet/withdrawals').single;
        expect(_body(sent).containsKey('pin'), isFalse);
        expect(
          server.requests.where((r) => r.url.path.startsWith('/wallet/pin')),
          isEmpty,
        );
      },
    );

    testWidgets('More offers the PIN only while it runs live; setting one '
        'with the password sends it with the new PIN', (tester) async {
      final server = _wallet(pin: _pin(set: false));
      server.routes['POST /wallet/pin'] = (_) => ok(_pin(), status: 201);
      await pumpLiveLaunch(
        tester,
        Routes.more,
        api: server.api,
        mode: _with({LiveFeature.withdrawalPin}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('iQLY PIN'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(
        find.text('Your 4-digit iQLY PIN confirms every withdrawal.'),
        findsOneWidget,
      );
      expect(_button(tester, 'Email me a code').disabled, isFalse);
      await tester.tap(find.text('Use your password instead'));
      await tester.pumpAndSettle();
      expect(_button(tester, 'Continue').disabled, isTrue);
      await _type(tester, 'Password', 'iqly-local-123');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _type(tester, 'New PIN', '1357');
      await _type(tester, 'New PIN again', '1375');
      expect(find.text('The PINs don’t match.'), findsOneWidget);
      expect(_button(tester, 'Save PIN').disabled, isTrue);
      expect(server.to('POST /wallet/pin'), isEmpty);
      await _type(tester, 'New PIN again', '1357');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();
      expect(_body(server.to('POST /wallet/pin').single), {
        'pin': '1357',
        'password': 'iqly-local-123',
      });
    });

    testWidgets('the PIN page shows the filling mark while it loads', (
      tester,
    ) async {
      final server = _wallet();
      final status = Completer<http.Response>();
      final api = ApiClient(
        tokens: MemoryTokenStore('t'),
        baseUrl: 'https://api.test',
        client: MockClient((r) async {
          if (r.url.path == '/wallet/pin') return status.future;
          return server.routes['${r.method} ${r.url.path}']?.call(r) ??
              ok(page([]));
        }),
      );
      await pumpLiveLaunch(
        tester,
        Routes.withdrawalPin,
        api: api,
        mode: _with({LiveFeature.withdrawalPin}),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(IqPageLoading), findsOneWidget);
      expect(find.text('Save PIN'), findsNothing);
      status.complete(ok(_pin()));
      await tester.pumpAndSettle();
      expect(find.byType(IqPageLoading), findsNothing);
      expect(find.text('Current PIN'), findsOneWidget);
      expect(_button(tester, 'Save PIN').disabled, isTrue);
    });

    testWidgets('More has no PIN row while withdrawalPin is off', (
      tester,
    ) async {
      final (container, router) = await pumpLiveLaunch(
        tester,
        Routes.more,
        api: _wallet().api,
      );
      await tester.pumpAndSettle();
      expect(find.text('iQLY PIN'), findsNothing);
      expect(hiddenRoute(container.read, Routes.withdrawalPin), isTrue);
    });
  });

  group('phone codes', () {
    _Server phoneServer({
      http.Response Function(http.Request)? code,
      bool verified = false,
    }) => _Server({
      'GET /profiles/contributors/me': (_) => ok({
        'phone': '+2348012345678',
        'phoneVerified': verified,
        'dateOfBirth': '2001-04-09',
      }),
      'POST /me/phone/code':
          code ??
          (_) => ok({
            'to': '+2348035550101',
            'expiresAt': _after(const Duration(minutes: 10)),
            'resendAt': _after(const Duration(seconds: 45)),
          }),
      'POST /me/phone/verify': (r) => _body(r)['code'] == '123456'
          ? ok({
              'phone': '+2348035550101',
              'verified': true,
              'verifiedAt': '2026-10-17T10:01:00Z',
              'pending': null,
              'resendAt': null,
            })
          : _refused(400, 'CODE_INVALID', {'attemptsLeft': 4}),
    });

    Future<void> typeNumber(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phone number').first);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await _type(tester, 'Phone number', '0803 555 0101');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }

    testWidgets('live: the code goes by SMS, a wrong one says the tries '
        'left, the right one confirms the number and Your details says so', (
      tester,
    ) async {
      final server = phoneServer();
      final store = MemoryLocalStore(clock: () => launchNow);
      await pumpLiveLaunch(
        tester,
        Routes.yourDetails,
        api: server.api,
        store: store,
        mode: _with({LiveFeature.phoneVerification}),
      );
      await typeNumber(tester);
      expect(_body(server.to('POST /me/phone/code').single), {
        'phone': '0803 555 0101',
      });
      expect(find.byType(PhoneCodeScreen), findsOneWidget);
      expect(find.textContaining('Resend in 0:45'), findsOneWidget);

      await _type(tester, '6-digit code', '000000');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('That code isn’t right. 4 tries left.'), findsOneWidget);

      await _type(tester, '6-digit code', '123456');
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byType(YourDetailsScreen), findsOneWidget);
      expect(find.text('+2348035550101 · Verified'), findsOneWidget);
      expect(
        await _await(tester, store.outbox('u_1')),
        isEmpty,
        reason: 'the API saved the number with the code',
      );
    });

    testWidgets('an API without SMS (503) saves the number with no code '
        'step', (tester) async {
      final server = phoneServer(
        code: (_) => _refused(503, 'SMS_NOT_CONFIGURED'),
      );
      final store = MemoryLocalStore(clock: () => launchNow);
      await pumpLiveLaunch(
        tester,
        Routes.yourDetails,
        api: server.api,
        store: store,
        mode: _with({LiveFeature.phoneVerification}),
      );
      await typeNumber(tester);
      expect(find.byType(PhoneCodeScreen), findsNothing);
      expect(find.byType(YourDetailsScreen), findsOneWidget);
      expect(find.text('0803 555 0101'), findsOneWidget);
      final queued = await _await(tester, store.outbox('u_1'));
      expect(queued.single.payload, {'phone': '0803 555 0101'});
    });

    testWidgets('too many codes says how long to wait', (tester) async {
      final server = phoneServer(
        code: (_) => _refused(
          429,
          'RATE_LIMITED',
          {'retryAfterSeconds': 45},
          {'retry-after': '45'},
        ),
      );
      await pumpLiveLaunch(
        tester,
        Routes.yourDetails,
        api: server.api,
        mode: _with({LiveFeature.phoneVerification}),
      );
      await typeNumber(tester);
      expect(find.byType(PhoneCodeScreen), findsNothing);
      expect(find.text('Too many codes. Try again in 0:45.'), findsOneWidget);
    });

    testWidgets('phoneVerification off: the code page as before, and no '
        '/me/phone call', (tester) async {
      final server = phoneServer(verified: true);
      await pumpLiveLaunch(tester, Routes.yourDetails, api: server.api);
      await tester.pumpAndSettle();
      expect(find.textContaining('Verified'), findsNothing);
      await typeNumber(tester);
      expect(find.byType(PhoneCodeScreen), findsOneWidget);
      await _type(tester, '6-digit code', '999999');
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(
        server.requests.where((r) => r.url.path.startsWith('/me/phone')),
        isEmpty,
      );
    });
  });

  group('saved briefs and reminders', () {
    Future<(ProviderContainer, LocalStore)> launch(
      WidgetTester tester,
      _Server server, {
      required Backend mode,
      Map<String, Object> prefs = const {},
      Surfaces Function(GoRouter router)? surfaces,
    }) async {
      final store = MemoryLocalStore(clock: () => launchNow);
      final (container, _) = await pumpLiveLaunch(
        tester,
        Routes.more,
        api: server.api,
        store: store,
        mode: mode,
        prefs: signedInLive(prefs),
        overrides: [
          if (surfaces != null)
            surfacesProvider.overrideWith(
              (ref) => surfaces(ref.watch(routerProvider)),
            ),
        ],
      );
      startAccountSync(container);
      container
        ..listen(savedBriefsProvider, (_, _) {})
        ..listen(closeRemindersProvider, (_, _) {});
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      return (container, store);
    }

    _Server marks() => _Server({
      'GET /challenges/browse': (_) => ok({
        ...page([challengeJson()]),
        'pageCount': 1,
      }),
      'GET /challenges/c_1': (_) => ok(challengeJson()),
      'GET /challenges/c_2': (_) => ok(challengeJson({'id': 'c_2'})),
      'GET /me/saved-briefs': (_) => ok({
        'items': [
          {'challengeId': 'c_2', 'savedAt': '2026-10-16T10:00:00Z'},
        ],
      }),
      'GET /me/close-reminders': (_) => ok({
        'items': [
          {
            'challengeId': 'c_1',
            'offsetsMinutes': [60, 1440],
            'closesAt': '2026-10-25T17:00:00Z',
          },
        ],
      }),
      'PUT /me/saved-briefs/c_1': (_) => ok({'challengeId': 'c_1'}),
      'PUT /me/close-reminders/c_2': (r) => ok({'challengeId': 'c_2'}),
    });

    final saved = jsonEncode([
      Brief.fromJson({
        ...DemoData(now: launchNow).briefs.first.toJson(),
        'id': 'c_1',
      }).toJson(),
    ]);

    testWidgets('live: pulled at launch (a removal made elsewhere wins), '
        'and each change queues for the API', (tester) async {
      final server = marks();
      final (c, store) = await launch(
        tester,
        server,
        mode: _with({
          LiveFeature.savedBriefsSync,
          LiveFeature.closeRemindersSync,
        }),
        prefs: {
          SavedBriefsNotifier.key: saved,
          CloseRemindersNotifier.key: ['c_9'],
          'sync.saved.adopted.u_1': true,
          'sync.reminder.adopted.u_1': true,
        },
      );
      expect(
        [for (final b in c.read(savedBriefsProvider).value!) b.id],
        ['c_2'],
      );
      expect(c.read(closeRemindersProvider).value, {'c_1'});

      final brief = (await settled(
        tester,
        c.read(repositoryProvider).brief('c_1'),
      ))!;
      await settled(
        tester,
        c.read(savedBriefsProvider.notifier).setSaved(brief, true),
      );
      await settled(
        tester,
        c.read(closeRemindersProvider.notifier).setReminder('c_2', true),
      );
      await settled(tester, Future<void>.value());
      expect(server.to('PUT /me/saved-briefs/c_1'), hasLength(1));
      expect(_body(server.to('PUT /me/close-reminders/c_2').single), {
        'offsetsMinutes': [60],
      });
      expect(await _await(tester, store.outbox('u_1')), isEmpty);
    });

    testWidgets('the first sync on a phone keeps the marks kept only on it: '
        'they go to the API, stay listed, and the reminder stays '
        'scheduled', (tester) async {
      final server = marks();
      server.routes['PUT /me/close-reminders/c_2'] = (r) =>
          ok({'challengeId': 'c_2', ..._body(r)});
      final scheduled = <Set<String>>[];
      final (c, store) = await launch(
        tester,
        server,
        mode: _with({
          LiveFeature.savedBriefsSync,
          LiveFeature.closeRemindersSync,
        }),
        prefs: {
          SavedBriefsNotifier.key: saved,
          CloseRemindersNotifier.key: ['c_2'],
        },
        surfaces: (router) => _Scheduling(router, scheduled),
      );
      expect(
        [for (final b in c.read(savedBriefsProvider).value!) b.id],
        ['c_1', 'c_2'],
      );
      expect(c.read(closeRemindersProvider).value, {'c_2', 'c_1'});
      expect(server.to('PUT /me/saved-briefs/c_1'), hasLength(1));
      expect(_body(server.to('PUT /me/close-reminders/c_2').single), {
        'offsetsMinutes': [60],
      });
      expect(scheduled.last, {'c_2', 'c_1'});
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getBool('sync.saved.adopted.u_1'), isTrue);
      expect(prefs.getBool('sync.reminder.adopted.u_1'), isTrue);
      await c.read(outboxProvider).stop();
    });

    testWidgets('a change not yet sent wins over the pull until it goes', (
      tester,
    ) async {
      final server = marks()..offline.add('PUT /me/saved-briefs/c_1');
      final (c, store) = await launch(
        tester,
        server,
        mode: _with({LiveFeature.savedBriefsSync}),
      );
      final brief = (await settled(
        tester,
        c.read(repositoryProvider).brief('c_1'),
      ))!;
      await settled(
        tester,
        c.read(savedBriefsProvider.notifier).setSaved(brief, true),
      );
      await settled(tester, Future<void>.value());
      expect(await _await(tester, store.outbox('u_1')), hasLength(1));
      await settled(tester, c.read(savedBriefsProvider.notifier).pull());
      expect(
        [for (final b in c.read(savedBriefsProvider).value!) b.id],
        ['c_1', 'c_2'],
      );
      await c.read(outboxProvider).stop();
    });

    testWidgets('off: the lists stay on the phone and the API is never '
        'asked', (tester) async {
      final server = marks();
      final (c, store) = await launch(
        tester,
        server,
        mode: allLive,
        prefs: {SavedBriefsNotifier.key: saved},
      );
      expect(
        [for (final b in c.read(savedBriefsProvider).value!) b.id],
        ['c_1'],
      );
      await settled(
        tester,
        c.read(closeRemindersProvider.notifier).setReminder('c_1', true),
      );
      expect(
        server.requests.where(
          (r) =>
              r.url.path.startsWith('/me/saved-briefs') ||
              r.url.path.startsWith('/me/close-reminders'),
        ),
        isEmpty,
      );
      expect(await _await(tester, store.outbox('u_1')), isEmpty);
      expect(c.read(briefMarksSyncProvider(BriefMark.saved)), isNull);
    });
  });

  group('uploads and a send queued offline', () {
    testWidgets('the queued moment offers Discover only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SentMoment(receipt: null, onView: null, onDiscover: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved to send.'), findsOneWidget);
      expect(find.text('View submission'), findsNothing);
      expect(find.text('Back to Discover'), findsOneWidget);
    });
  });

  testWidgets('preview: no PIN row and nothing asked of the API', (
    tester,
  ) async {
    final server = _wallet();
    final (c, _) = await pumpLiveLaunch(
      tester,
      Routes.more,
      api: server.api,
      mode: Backend.preview,
    );
    await tester.pumpAndSettle();
    expect(find.text('iQLY PIN'), findsNothing);
    expect(c.read(briefMarksSyncProvider(BriefMark.saved)), isNull);
    expect(c.read(submissionUploadsProvider), isNull);
    expect(server.requests, isEmpty);
    expect(c.read(sessionProvider).signedIn, isTrue);
  });
}
