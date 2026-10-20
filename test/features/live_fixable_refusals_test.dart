import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/profile/edit_detail_screen.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/features/settings/restore_account_screen.dart';
import 'package:iqly_mobile/features/submit/submit_field.dart';
import 'package:iqly_mobile/features/wallet/withdraw_sheet.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../data/live/live_data_fixtures.dart';
import '../golden/screens/app_harness.dart';
import '../golden/screens/submit_harness.dart';
import '../support/live_launch.dart';

/// One person's wallet, and [born] as the profile's date of birth; a
/// withdrawal answers [status] [code].
ApiClient _wallet(
  int status,
  String code,
  List<http.Request> posts, {
  String? born,
}) => ApiClient(
  tokens: MemoryTokenStore('t'),
  baseUrl: 'https://api.test',
  client: MockClient((r) async {
    http.Response json(int status, Object body) =>
        http.Response(jsonEncode(body), status);
    return switch ('${r.method} ${r.url.path}') {
      'POST /wallet/withdrawals' => () {
        posts.add(r);
        return json(status, {
          'success': false,
          'error': {
            'code': code,
            'message': 'Refused.',
            if (code == 'PROFILE_INCOMPLETE')
              'details': {
                'missing': ['dateOfBirth'],
              },
          },
        });
      }(),
      'GET /wallet' => json(200, {'success': true, 'data': walletJson()}),
      'GET /profiles/contributors/me' => json(200, {
        'success': true,
        'data': {'dateOfBirth': born},
      }),
      'GET /wallet/bank-account' => json(200, {
        'success': true,
        'data': bankAccountJson(),
      }),
      'GET /me' => json(200, {
        'success': true,
        'data': {
          'id': 'u_1',
          'name': 'Ada Obi',
          'email': 'ada@example.com',
          'status': code == 'ACCOUNT_CLOSING' ? 'closing' : 'active',
          'closesAt': code == 'ACCOUNT_CLOSING'
              ? '2026-11-16T09:00:00.000Z'
              : null,
        },
      }),
      _ => json(200, {'success': true, 'data': page([])}),
    };
  }),
);

Future<void> _withdraw(WidgetTester tester) async {
  await tester.tap(find.text('Withdraw').first);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byWidgetPredicate((w) => w is IqField && w.label == 'Amount'),
      matching: find.byType(EditableText),
    ),
    '5000',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Withdraw').last);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Submit, refused with [failure] whatever is sent.
class _Refusing extends DemoSubmitService {
  _Refusing(super.data, this.failure) : super(delay: Duration.zero);

  final SubmitFailure failure;

  @override
  Future<SubmitResult> submit(SubmitRequest request) async =>
      SubmitResult.failure(failure);
}

void main() {
  group('withdraw', () {
    for (final (status, code, born, shows) in [
      (409, 'PROFILE_INCOMPLETE', null, 'Pick a date'),
      (403, 'UNDER_AGE', '2010-01-01', 'You must be 18 or over to be paid.'),
    ]) {
      testWidgets('$code opens Date of birth; Back returns to the sheet', (
        tester,
      ) async {
        final posts = <http.Request>[];
        await pumpLiveLaunch(
          tester,
          Routes.wallet,
          api: _wallet(status, code, posts, born: born),
        );
        await tester.pumpAndSettle();
        await _withdraw(tester);
        expect(posts, hasLength(1));
        expect(find.byType(EditDetailScreen), findsOneWidget);
        expect(
          tester.widget<EditDetailScreen>(find.byType(EditDetailScreen)).field,
          DetailField.dateOfBirth,
        );
        expect(find.text(shows), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(WithdrawSheet), findsOneWidget);
        expect(find.text('Couldn’t send. Nothing was sent.'), findsOneWidget);
      });
    }

    testWidgets('ACCOUNT_CLOSING goes to Restore, with the close date', (
      tester,
    ) async {
      final posts = <http.Request>[];
      await pumpLiveLaunch(
        tester,
        Routes.wallet,
        api: _wallet(403, 'ACCOUNT_CLOSING', posts),
      );
      await tester.pumpAndSettle();
      await _withdraw(tester);
      expect(find.byType(RestoreAccountScreen), findsOneWidget);
      expect(find.textContaining('closes on 16 November'), findsOneWidget);
    });
  });

  group('submit', () {
    Future<void> send(WidgetTester tester, SubmitFailure failure) async {
      await pumpApp(
        tester,
        Routes.submitTo('c9'),
        overrides: [
          submitServiceProvider.overrideWith(
            (ref) => _Refusing(
              (ref.watch(repositoryProvider) as DemoRepository).data,
              failure,
            ),
          ),
          attachmentPickerProvider.overrideWithValue(DemoAttachmentPicker()),
          attachmentUploaderProvider.overrideWithValue(ScriptedUploader()),
        ],
      );
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is SubmitField && w.label == 'Title',
          ),
          matching: find.byType(EditableText),
        ),
        'Show the IMEI check',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is SubmitField && w.label == 'Your answer',
          ),
          matching: find.byType(EditableText),
        ),
        'A free IMEI and theft check on every phone.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
    }

    testWidgets('UNDER_AGE opens Date of birth; the draft waits', (
      tester,
    ) async {
      await send(tester, SubmitFailure.underAge);
      expect(
        tester.widget<EditDetailScreen>(find.byType(EditDetailScreen)).field,
        DetailField.dateOfBirth,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t send. Your draft is saved on this phone.'),
        findsOneWidget,
      );
    });

    testWidgets('ACCOUNT_CLOSING goes to Restore', (tester) async {
      await send(tester, SubmitFailure.closing);
      expect(find.byType(RestoreAccountScreen), findsOneWidget);
    });

    testWidgets('any other refusal stays on the banner', (tester) async {
      await send(tester, SubmitFailure.unknown);
      expect(find.byType(EditDetailScreen), findsNothing);
      expect(find.byType(RestoreAccountScreen), findsNothing);
      expect(
        find.text('Couldn’t send. Your draft is saved on this phone.'),
        findsOneWidget,
      );
    });
  });
}
