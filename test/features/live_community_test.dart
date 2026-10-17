import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/avatar_service.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/referrals/referrals_state.dart';
import 'package:iqly_mobile/ui/share_target.dart';
import 'package:iqly_mobile/data/invite.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/features/avatar/avatar_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/wallet/bank_account_sheet.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/gift_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

const _moon = {'kind': 'buddy', 'buddy': 'Moon'};

Map<String, Object?> _avatarJson({
  Object? spec = _moon,
  Object? look,
  bool isDefault = false,
}) => {
  'spec': spec,
  'look': look ?? IqAvatarPresets.person2.toJson(),
  'preset': isDefault ? 'person4' : null,
  'isDefault': isDefault,
  'updatedAt': isDefault ? null : '2026-10-01T10:00:00.000Z',
};

/// Ada's API: the account reads every live screen makes, plus whatever
/// a test adds.
FakeApi _api() {
  final api = FakeApi();
  api.data('GET', '/me', {
    'id': 'u_1',
    'name': 'Ada Obi',
    'email': 'ada@example.com',
    'status': 'active',
  });
  api.data('GET', '/profiles/contributors/me', {'gender': 'female'});
  api.data('GET', '/me/notification-preferences', const {});
  api.data('GET', '/notifications', {
    'items': <Object>[],
    'nextCursor': null,
    'unseen': 0,
  });
  api.data('GET', '/submissions/mine', page([]));
  api.data('GET', '/challenges/browse', {'items': <Object>[], 'pageCount': 1});
  return api;
}

Backend _with(Set<LiveFeature> more) => Backend.of({...firstFeatures, ...more});

Future<ProviderContainer> _launch(
  WidgetTester tester,
  FakeApi api,
  String location, {
  Backend? mode,
  Map<String, Object> prefs = const {},
}) async {
  final (container, _) = await pumpLiveLaunch(
    tester,
    location,
    api: api.api(),
    mode: mode,
    prefs: signedInLive(prefs),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('avatar', () {
    test('the default mirrors the API: the same id and gender always give '
        'the same preset, from the gender\'s three', () {
      expect(defaultAvatarLook('u_1', 'female'), IqAvatarPresets.person4);
      expect(defaultAvatarLook('u_1', 'male'), IqAvatarPresets.person3);
      expect(defaultAvatarLook('u_1', null), IqAvatarPresets.person5);
      expect(
        defaultAvatarLook('u_1', 'prefer_not_to_say'),
        IqAvatarPresets.person5,
      );
      for (var i = 0; i < 40; i++) {
        final id = 'user_$i';
        expect([
          IqAvatarPresets.person1,
          IqAvatarPresets.person4,
          IqAvatarPresets.person5,
        ], contains(defaultAvatarLook(id, 'female')));
        expect([
          IqAvatarPresets.person2,
          IqAvatarPresets.person3,
          IqAvatarPresets.person6,
        ], contains(defaultAvatarLook(id, 'male')));
        expect(defaultAvatarLook(id, 'male'), defaultAvatarLook(id, 'male'));
      }
    });

    testWidgets('live with the avatar on: the account\'s avatar shows, and '
        'it comes back after a sign out wipes the phone\'s copy', (
      tester,
    ) async {
      final api = _api()..data('GET', '/me/avatar', _avatarJson());
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
      );
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
      expect(c.read(avatarProvider).look, IqAvatarPresets.person2);

      await c.read(avatarProvider.notifier).forget();
      await tester.pumpAndSettle();
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
        reason: 'the account still has it',
      );
      expect(api.to('/me/avatar', method: 'GET').length, greaterThan(1));
    });

    testWidgets('a new phone with nothing kept shows the account\'s avatar, '
        'never a random one', (tester) async {
      final api = _api()
        ..data(
          'GET',
          '/me/avatar',
          _avatarJson(
            spec: IqPersonAvatar(IqAvatarPresets.person6).toJson(),
            look: IqAvatarPresets.person6.toJson(),
          ),
        );
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
      );
      expect(
        c.read(avatarProvider).spec,
        const IqPersonAvatar(IqAvatarPresets.person6),
      );
    });

    testWidgets('a pick goes to the account through the outbox, spec and '
        'look', (tester) async {
      final api = _api()
        ..data('GET', '/me/avatar', _avatarJson(isDefault: true))
        ..on('PUT', '/me/avatar', (_) => ok(_avatarJson()));
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
      );
      c.read(accountSyncProvider);
      await c
          .read(avatarProvider.notifier)
          .choose(const IqEmojiAvatar('😎', bg: 3));
      await c.read(outboxProvider).kick();
      await tester.pumpAndSettle();
      final put = api.to('/me/avatar', method: 'PUT');
      expect(put, hasLength(1));
      expect(put.single.body, contains('"kind":"emoji"'));
      expect(put.single.body, contains('"look"'));
      expect(c.read(avatarProvider).spec, const IqEmojiAvatar('😎', bg: 3));
    });

    testWidgets('a pick made before the account kept avatars goes up once '
        'the account only has its default', (tester) async {
      final api = _api()
        ..data('GET', '/me/avatar', _avatarJson(isDefault: true))
        ..on('PUT', '/me/avatar', (_) => ok(_avatarJson()));
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
        prefs: {'avatar.spec': '{"kind":"buddy","buddy":"Moon"}'},
      );
      c.read(accountSyncProvider);
      await c.read(outboxProvider).kick();
      await tester.pumpAndSettle();
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
      expect(api.to('/me/avatar', method: 'PUT'), hasLength(1));
    });

    testWidgets('live with the avatar off: nothing asked, the phone\'s avatar '
        'as today', (tester) async {
      final api = _api();
      final c = await _launch(
        tester,
        api,
        Routes.more,
        prefs: {'avatar.spec': '{"kind":"buddy","buddy":"Moon"}'},
      );
      await c
          .read(avatarProvider.notifier)
          .choose(const IqBuddyAvatar(IqAvatarBuddyKind.bean));
      expect(api.to('/me/avatar'), isEmpty);
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.bean),
      );
    });

    test('preview: a new account starts on its gender\'s preset, and a '
        'gender given later moves an unpicked one', () async {
      SharedPreferences.setMockInitialValues({'session.userId': 'u_1'});
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(c.dispose);
      final avatar = c.read(avatarProvider.notifier);
      await avatar.startNewcomer(gender: 'male');
      expect(
        c.read(avatarProvider).spec,
        const IqPersonAvatar(IqAvatarPresets.person3),
      );
      await avatar.genderKnown('female');
      expect(
        c.read(avatarProvider).spec,
        const IqPersonAvatar(IqAvatarPresets.person4),
      );
      await avatar.choose(const IqBuddyAvatar(IqAvatarBuddyKind.bean));
      await avatar.genderKnown('male');
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.bean),
        reason: 'a pick stays',
      );
      c
          .read(accountDetailsProvider.notifier)
          .edit(const AccountDetails(gender: 'female'));
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.bean),
      );
    });
    testWidgets('GET /me carries the avatar when GET /me/avatar fails', (
      tester,
    ) async {
      final api = _api()
        ..data('GET', '/me', {
          'id': 'u_1',
          'name': 'Ada Obi',
          'email': 'ada@example.com',
          'status': 'active',
          'avatar': _avatarJson(),
        })
        ..on('GET', '/me/avatar', (_) => refused(500, 'INTERNAL'));
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
      );
      c.read(meProvider);
      await tester.pumpAndSettle();
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
    });

    testWidgets('unreachable at launch: a blank circle, never a guess; the '
        'read goes again once the API answers again', (tester) async {
      final api = _api()..data('GET', '/me/avatar', _avatarJson());
      api.offline = true;
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
      );
      expect(c.read(avatarProvider).known, isFalse);
      expect(c.read(avatarProvider).spec, awaitingAvatar);
      api.offline = false;
      await c.read(apiClientProvider)!.get('/notifications');
      await tester.pumpAndSettle();
      expect(c.read(avatarProvider).known, isTrue);
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
    });

    test('without the API feature each account keeps its own avatar '
        'across a sign out; the switch and a close wipe it', () async {
      SharedPreferences.setMockInitialValues({
        'session.signedIn': true,
        'session.userId': 'u_1',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      await c
          .read(avatarProvider.notifier)
          .choose(const IqBuddyAvatar(IqAvatarBuddyKind.moon));
      await c.read(avatarProvider.notifier).forget();
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
      await c.read(sessionProvider.notifier).setUserId('u_2');
      expect(
        c.read(avatarProvider).spec,
        isNot(const IqBuddyAvatar(IqAvatarBuddyKind.moon)),
      );
      await c.read(sessionProvider.notifier).setUserId('u_1');
      expect(
        c.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
      await c.read(avatarProvider.notifier).forget();
      await c.read(avatarProvider.notifier).wipe('u_1');
      expect(
        c.read(avatarProvider).spec,
        const IqPersonAvatar(IqAvatarPresets.person1),
      );
    });
  });

  group('leaderboard', () {
    final board = {
      'month': '2026-10',
      'contributors': 2130,
      'entries': [
        for (var rank = 1; rank <= 6; rank++)
          {
            'rank': rank,
            'name': 'Person $rank.',
            'points': 4000 - rank * 100,
            'wins': 2,
            'submissions': 9,
            'you': false,
          },
        {
          'rank': 7,
          'name': 'Ada O.',
          'points': 1310,
          'wins': 1,
          'submissions': 21,
          'you': true,
        },
      ],
      'you': {'rank': 7, 'points': 1310, 'wins': 1, 'submissions': 21},
      'rules': {'pointsPerSubmission': 10, 'pointsPerWin': 100},
    };

    testWidgets('live with the leaderboard on: the pass and the board read '
        'GET /leaderboard', (tester) async {
      final api = _api()..data('GET', '/leaderboard', board);
      await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.leaderboard}),
      );
      expect(find.text('1,310'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('1,240'), findsNothing);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.textContaining('ADAEZE24'), findsNothing);

      await tester.tap(find.text('Leaderboard'));
      await tester.pumpAndSettle();
      expect(find.text('You are 7th of 2,130'), findsOneWidget);
      expect(find.text('Person 1.'), findsOneWidget);
      expect(find.text('Chinedu A.'), findsNothing);
    });

    testWidgets('no points yet: no rank, and the points read 0', (
      tester,
    ) async {
      final api = _api()
        ..data('GET', '/leaderboard', {
          'month': '2026-10',
          'contributors': 0,
          'entries': <Object>[],
          'you': {'rank': null, 'points': 0, 'wins': 0, 'submissions': 0},
        });
      await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.leaderboard}),
      );
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('live without it: /leaderboard lands on Discover and is '
        'never asked', (tester) async {
      final api = _api();
      await _launch(tester, api, Routes.pointsLeaderboard);
      expect(find.text('You are 7th of 2,130'), findsNothing);
      expect(api.to('/leaderboard'), isEmpty);
    });
  });

  group('referrals', () {
    final referrals = {
      'code': 'ADA24',
      'invites': [
        {'name': 'Tunde F.', 'status': 'joined', 'at': '2026-10-03T10:00:00Z'},
        {'name': 'Ngozi E.', 'status': 'won', 'at': '2026-10-10T10:00:00Z'},
      ],
      'memberSince': '2026-10-15T10:00:00.000Z',
      'invitedBy': null,
      'applyUntil': '2026-11-14T10:00:00.000Z',
    };

    testWidgets('live with referrals on: the code on More, the gift on '
        'Discover, no money promised', (tester) async {
      final api = _api()..data('GET', '/me/referrals', referrals);
      await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.referrals}),
      );
      expect(find.textContaining('ADA24'), findsWidgets);
      expect(find.text('Invite friends to iQLY'), findsOneWidget);
      expect(find.textContaining('₦500'), findsNothing);
      expect(find.text('1,240'), findsNothing);

      await tester.tap(find.text('Invite friends to iQLY'));
      await tester.pumpAndSettle();
      expect(find.text('Invite friends'), findsWidgets);
      expect(find.textContaining('₦500'), findsNothing);

      await tester.tap(find.text('Referral history'));
      await tester.pumpAndSettle();
      expect(find.text('Tunde F.'), findsOneWidget);
      expect(find.text('Won a first brief'), findsOneWidget);
      expect(find.text('WON'), findsOneWidget);
      expect(find.text('EARNED'), findsNothing);
    });

    testWidgets('Discover has the gift with referrals on', (tester) async {
      final api = _api()..data('GET', '/me/referrals', referrals);
      await _launch(
        tester,
        api,
        Routes.home,
        mode: _with({LiveFeature.referrals}),
      );
      expect(find.byType(IqGiftButton), findsOneWidget);
    });

    testWidgets('Enter an invite code: the inviter from the lookup, each '
        'refusal in plain words', (tester) async {
      var answer = refused(409, 'INVITE_CODE_ALREADY_APPLIED');
      final api = _api()
        ..data('GET', '/me/referrals', referrals)
        ..on('GET', '/referrals/codes/CHIDI7', (_) {
          return ok({'code': 'CHIDI7', 'inviter': 'Chidi A.'});
        })
        ..on('POST', '/me/referrals/apply', (_) => answer);
      await _launch(
        tester,
        api,
        Routes.inviteCode,
        mode: _with({LiveFeature.referrals}),
      );
      await tester.enterText(find.byType(EditableText), 'chidi7');
      await tester.pump(ReferralsService.lookupPause);
      await tester.pumpAndSettle();
      expect(find.text('Chidi A. invited you'), findsOneWidget);
      expect(api.to('/referrals/codes/CHIDI7'), hasLength(1));

      await tester.tap(find.text('Apply code'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'You’ve already added a friend’s code. Only one can be added.',
        ),
        findsOneWidget,
      );

      answer = ok({
        'code': 'CHIDI7',
        'inviter': 'Chidi A.',
        'appliedAt': '2026-10-17T10:00:00Z',
      });
      await tester.enterText(find.byType(EditableText), 'TUNDE07');
      await tester.pump(ReferralsService.lookupPause);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply code'));
      await tester.pumpAndSettle();
      expect(
        find.text('You’re in. Your friend’s code is on your account.'),
        findsOneWidget,
      );
      expect(find.textContaining('₦500'), findsNothing);
    });

    test('an invite link is looked up on the API with referrals on, and '
        'knows no sample invite without them', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final on in [true, false]) {
        final api = FakeApi()
          ..on(
            'GET',
            '/referrals/codes/CHIDI7',
            (_) => ok({'code': 'CHIDI7', 'inviter': 'Chidi A.'}),
          );
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...liveOverrides(
              api.api(),
              mode: on ? _with({LiveFeature.referrals}) : allLive,
            ),
          ],
        );
        addTearDown(c.dispose);
        final invite = await c.read(inviteServiceProvider).lookUp('chidi7');
        expect(invite?.inviterName, on ? 'Chidi A.' : null);
        expect(api.requests, hasLength(on ? 1 : 0));
      }
    });

    testWidgets('a link\'s code the account refuses after sign-up is kept '
        'and shown on Referrals, and offered again', (tester) async {
      final api = _api()
        ..data('GET', '/me/referrals', referrals)
        ..on(
          'POST',
          '/me/referrals/apply',
          (_) => refused(409, 'INVITE_CODE_EXPIRED'),
        );
      final c = await _launch(
        tester,
        api,
        Routes.referrals,
        mode: _with({LiveFeature.referrals}),
      );
      c.read(accountSyncProvider);
      final service = c.read(referralsServiceProvider) as LiveReferralsService;
      await service.queueApply('CHIDI7');
      await c.read(outboxProvider).kick();
      await tester.pumpAndSettle();
      expect(c.read(unappliedInviteProvider)?.code, 'CHIDI7');
      expect(find.textContaining('CHIDI7 wasn’t added'), findsOneWidget);
      expect(find.text('Enter an invite code'), findsOneWidget);
    });

    testWidgets('the live invite sheet offers only Copy link', (tester) async {
      final api = _api()..data('GET', '/me/referrals', referrals);
      await _launch(
        tester,
        api,
        Routes.referrals,
        mode: _with({LiveFeature.referrals}),
      );
      await tester.tap(find.text('Invite friends').last);
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Save image'), findsNothing);
      expect(find.byType(IqShareTarget), findsNothing);
    });

    test('every apply refusal has an outcome', () {
      expect(
        inviteCodeOutcome('INVITE_CODE_INVALID'),
        InviteCodeOutcome.invalid,
      );
      expect(
        inviteCodeOutcome('INVITE_CODE_EXPIRED'),
        InviteCodeOutcome.expired,
      );
      expect(inviteCodeOutcome('INVITE_CODE_OWN'), InviteCodeOutcome.ownCode);
      expect(
        inviteCodeOutcome('INVITE_CODE_ALREADY_APPLIED'),
        InviteCodeOutcome.alreadyApplied,
      );
      expect(
        inviteCodeOutcome('INVITE_CODE_CIRCULAR'),
        InviteCodeOutcome.circular,
      );
      expect(inviteCodeOutcome('RATE_LIMITED'), InviteCodeOutcome.tooManyTries);
      expect(inviteCodeOutcome('ACCOUNT_CLOSING'), InviteCodeOutcome.closing);
      expect(inviteCodeOutcome('SOMETHING_NEW'), InviteCodeOutcome.unknown);
    });

    testWidgets('live without referrals: no invite card, gift or Referrals, '
        'and nothing asked', (tester) async {
      final api = _api();
      await _launch(tester, api, Routes.referrals);
      expect(find.text('Referral history'), findsNothing);
      expect(find.byType(IqGiftButton), findsNothing);
      expect(api.to('/me/referrals'), isEmpty);
    });
  });

  group('saved bank accounts', () {
    FakeApi wallet({bool several = true}) {
      final api = _api()
        ..data('GET', '/wallet/transactions', page([]))
        ..data('GET', '/wallet/withdrawals', page([]))
        ..data('GET', '/banks', banksJson)
        ..data('GET', '/wallet', walletJson())
        ..data('GET', '/wallet/bank-account', bankAccountJson());
      if (several) {
        api.data('GET', '/wallet/bank-accounts', [
          bankAccountJson({'isDefault': true}),
          bankAccountJson({
            'id': 'ba_2',
            'bankCode': '058',
            'bankName': 'Guaranty Trust Bank',
            'accountLast4': '4321',
            'isDefault': false,
          }),
        ]);
      }
      return api;
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Bank account').first);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.byType(BankAccountSheet), findsOneWidget);
    }

    testWidgets('the list first, the default marked; Set as default and '
        'Remove go to the API, a withdrawal on its way keeps the account', (
      tester,
    ) async {
      final api = wallet()
        ..on(
          'POST',
          '/wallet/bank-accounts/ba_2/default',
          (_) => ok(bankAccountJson({'id': 'ba_2', 'isDefault': true})),
        )
        ..on(
          'DELETE',
          '/wallet/bank-accounts/ba_2',
          (_) => refused(409, 'BANK_ACCOUNT_IN_USE'),
        );
      final c = await _launch(
        tester,
        api,
        Routes.wallet,
        mode: _with({LiveFeature.bankAccounts}),
      );
      await openSheet(tester);
      expect(find.text('Access Bank ••6789'), findsOneWidget);
      expect(find.text('Guaranty Trust Bank ••4321'), findsOneWidget);
      expect(find.text('Adaeze Okafor · Default'), findsOneWidget);
      expect(find.text('Add another'), findsOneWidget);

      await tester.tap(find.text('Guaranty Trust Bank ••4321'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this account?'), findsOneWidget);
      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();
      expect(find.text(BankAccountSheet.inUse), findsOneWidget);
      expect((await c.read(walletProvider.future)).accounts, hasLength(2));

      api.on(
        'DELETE',
        '/wallet/bank-accounts/ba_2',
        (_) => ok([
          bankAccountJson({'isDefault': true}),
        ]),
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();
      expect(find.text('Guaranty Trust Bank ••4321'), findsNothing);
      expect(c.read(walletProvider).value!.accounts, hasLength(1));
      expect(
        api.to('/wallet/bank-accounts/ba_2', method: 'DELETE'),
        hasLength(2),
      );
    });

    testWidgets('Set as default asks no PIN live and posts the default', (
      tester,
    ) async {
      final api = wallet();
      api.on('POST', '/wallet/bank-accounts/ba_2/default', (_) {
        api.data('GET', '/wallet/bank-accounts', [
          bankAccountJson({
            'id': 'ba_2',
            'bankCode': '058',
            'bankName': 'Guaranty Trust Bank',
            'accountLast4': '4321',
            'isDefault': true,
          }),
          bankAccountJson({'isDefault': false}),
        ]);
        return ok(bankAccountJson({'id': 'ba_2', 'isDefault': true}));
      });
      final c = await _launch(
        tester,
        api,
        Routes.wallet,
        mode: _with({LiveFeature.bankAccounts}),
      );
      await openSheet(tester);
      await tester.tap(find.text('Guaranty Trust Bank ••4321'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();
      expect(find.byType(IqField), findsNothing, reason: 'no PIN');
      expect(
        api.to('/wallet/bank-accounts/ba_2/default', method: 'POST'),
        hasLength(1),
      );
      expect(c.read(walletProvider).value!.savedBank!.id, 'ba_2');
    });

    testWidgets('without the feature: the single account, no Remove, the '
        'old route', (tester) async {
      final api = wallet(several: false);
      await _launch(tester, api, Routes.wallet);
      await openSheet(tester);
      expect(find.text('Access Bank ••6789'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Add a bank account'), findsOneWidget);
      expect(api.to('/wallet/bank-accounts'), isEmpty);
    });

    testWidgets('an account gone elsewhere: plain words and the list again', (
      tester,
    ) async {
      final api = wallet()
        ..on(
          'DELETE',
          '/wallet/bank-accounts/ba_2',
          (_) => refused(404, 'BANK_ACCOUNT_NOT_FOUND'),
        );
      await _launch(
        tester,
        api,
        Routes.wallet,
        mode: _with({LiveFeature.bankAccounts}),
      );
      await openSheet(tester);
      final reads = api.to('/wallet/bank-accounts', method: 'GET').length;
      api.data('GET', '/wallet/bank-accounts', [
        bankAccountJson({'isDefault': true}),
      ]);
      await tester.tap(find.text('Guaranty Trust Bank ••4321'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();
      expect(find.text(BankAccountSheet.gone), findsOneWidget);
      expect(
        api.to('/wallet/bank-accounts', method: 'GET').length,
        greaterThan(reads),
      );
      expect(find.text('Guaranty Trust Bank ••4321'), findsNothing);
    });

    test('a withdrawal to an account gone elsewhere says so', () async {
      final api = FakeApi()
        ..on(
          'POST',
          '/wallet/withdrawals',
          (_) => refused(404, 'BANK_ACCOUNT_NOT_FOUND'),
        );
      final result = await LiveWalletService(api.api(), bankAccounts: true)
          .withdraw(
            amountKobo: 500000,
            account: const SavedBank(
              id: 'ba_9',
              bankCode: '058',
              bankName: 'Guaranty Trust Bank',
              accountName: 'ADAEZE OKAFOR',
              accountNumber: '4321',
            ),
          );
      expect(result.failure, WalletFailure.accountGone);
      expect(result.unsettled, isFalse);
    });

    test('a withdrawal names the picked account by id only while the API '
        'keeps several', () async {
      for (final several in [true, false]) {
        final api = FakeApi()
          ..on(
            'POST',
            '/wallet/withdrawals',
            (_) => ok(withdrawalJson(), status: 201),
          );
        final service = LiveWalletService(api.api(), bankAccounts: several);
        await service.withdraw(
          amountKobo: 500000,
          account: const SavedBank(
            id: 'ba_2',
            bankCode: '058',
            bankName: 'Guaranty Trust Bank',
            accountName: 'ADAEZE OKAFOR',
            accountNumber: '4321',
          ),
        );
        final body = api.to('/wallet/withdrawals').single.body;
        expect(body.contains('"bankAccountId":"ba_2"'), several);
      }
    });

    test('a sixth account is refused with BANK_ACCOUNT_LIMIT', () async {
      final api = FakeApi()
        ..on(
          'POST',
          '/wallet/bank-accounts',
          (_) => refused(409, 'BANK_ACCOUNT_LIMIT'),
        );
      final service = LiveWalletService(api.api(), bankAccounts: true);
      await expectLater(
        service.addAccount(
          const SavedBank(
            bankCode: '058',
            bankName: 'Guaranty Trust Bank',
            accountName: '',
            accountNumber: '0123456789',
          ),
        ),
        throwsA(
          isA<Object>().having((e) => '$e', 'refusal', contains('LIMIT')),
        ),
      );
    });
  });
}
