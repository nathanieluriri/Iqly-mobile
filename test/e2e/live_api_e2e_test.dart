import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/app_config.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/avatar_service.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/live/brief_marks_sync.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_help_service.dart';
import 'package:iqly_mobile/data/live/live_notifications_service.dart';
import 'package:iqly_mobile/data/live/live_onboarding_service.dart';
import 'package:iqly_mobile/data/live/live_outcomes_service.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live/live_submit_service.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/live/submit_queue.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_rows.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_data.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/outcomes_service.dart';
import 'package:iqly_mobile/data/phone_service.dart';
import 'package:iqly_mobile/data/pin_service.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/signed_in_files.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/support_files.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/activations/activation_format.dart';
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/help/support_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/polls/polls_routes.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/referrals/referrals_state.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/wallet/wallet_format.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/surfaces/surfaces.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/ui/recording_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's live services against a real iQLY API, wired as main.dart wires
/// a live build: the local API from the platform repo (docs/local-api.md),
/// which this walk reseeds through its /__local tools. Plain test(), not
/// testWidgets: the widget binding would stub out real HTTP.
void main() {
  final base = Platform.environment['IQLY_E2E_API'];
  // The features the server was started without (MOBILE_FEATURES_OFF), so
  // the walk checks the app pauses them; IQLY_E2E_OFF names them the same
  // way.
  final off = {
    for (final name in (Platform.environment['IQLY_E2E_OFF'] ?? '').split(','))
      ?LiveFeature.values.asNameMap()[name.trim()],
  };
  bool on(LiveFeature feature) => !off.contains(feature);

  // Contract 11 runs only with both of its features on.
  final eleven = on(LiveFeature.polls) && on(LiveFeature.activations);

  group(
    'The live app on the API',
    skip: base == null ? 'Set IQLY_E2E_API to the local API to run' : false,
    () {
      late _LocalTools tools;
      late _Seed seed;
      late _LosingClient client;
      late MemoryTokenStore tokens;
      late ApiClient api;
      late MemoryLocalStore store;
      late ProviderContainer container;
      late Outbox outbox;
      Directory? folder;

      setUpAll(() async {
        tools = _LocalTools(base!);
        seed = _Seed(await tools.post('/__local/seed'));
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        client = _LosingClient(http.Client());
        tokens = MemoryTokenStore();
        api = ApiClient(
          tokens: tokens,
          client: client,
          baseUrl: base,
          appVersion: '0.3.0+3',
          platform: 'android',
        );
        store = MemoryLocalStore();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(api),
            localStoreProvider.overrideWithValue(store),
            healthServiceProvider.overrideWithValue(LiveHealthService(api)),
            backendProvider.overrideWith(
              () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
            ),
            authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
          ],
        );
        startAccountSync(container);
        outbox = container.read(outboxProvider);
      });

      tearDownAll(() {
        container.dispose();
        client.close();
        folder?.deleteSync(recursive: true);
      });

      /// Sends what the outbox holds and expects every write to land.
      Future<void> drain() async {
        await outbox.kick();
        expect(outbox.state.failed, isEmpty);
        expect(outbox.state.pause, isNull);
        expect(await store.outbox(seed.contributorId), isEmpty);
      }

      LiveRepository repository() =>
          container.read(repositoryProvider) as LiveRepository;

      LiveAccount account() =>
          LiveAccount(container.read(accountLinkProvider)!);

      test('health turns every feature live for contract 1', () async {
        final report = await LiveHealthService(api).check();
        final running = LiveFeature.values.toSet().difference(off);
        expect(report.ready, isTrue);
        expect(report.contract, Backend.contract);
        expect(report.features, running);
        expect(Backend.from(report).live, running);

        await container.read(backendProvider.notifier).check();
        expect(container.read(backendProvider).live, running);
        // As the splash does at its hand-off: the outbox runs from here.
        await container.read(backendProvider.notifier).lock();
      });

      test('email sign-in gives the session the account id', () async {
        final auth = container.read(authServiceProvider);
        expect(auth, isA<LiveAuthService>());
        expect((await auth.lookUpEmail(seed.email)).newAccount, isFalse);
        expect(
          (await auth.lookUpEmail('nobody@example.com')).newAccount,
          isTrue,
        );
        final result = await auth.signIn(
          email: seed.email,
          password: seed.password,
        );
        expect(result.ok, isTrue, reason: '${result.failure}');
        expect(result.userId, seed.contributorId);
        expect(result.name, 'Ada Obi');
        expect(result.newAccount, isFalse);
        expect(await tokens.read(), isNotNull);
        expect(await auth.accountName(), 'Ada Obi');

        // As completeSignIn records a returning person.
        final session = container.read(sessionProvider.notifier);
        await session.setUserId(result.userId);
        await session.setSignedIn(true);
        await session.setName(result.name);
        await session.setOnboardingDone(true);

        final me = await container.read(meProvider.future);
        expect(me!.id, seed.contributorId);
        expect(me.email, seed.email);
        expect(me.closing, isFalse);
        expect(me.memberSince, isNotNull);
        expect(container.read(sessionProvider).userId, seed.contributorId);
        final user = me.toUser();
        expect([user.firstName, user.lastName], ['Ada', 'Obi']);
        expect(user.state, 'Lagos');
        expect(user.interests, contains('Finance & fintech'));
      });

      late OnboardingProfile answers;

      test(
        'onboarding answers go through the outbox with the phone skipped',
        () async {
          final onboarding = container.read(onboardingServiceProvider);
          expect(onboarding, isA<LiveOnboardingService>());
          answers = OnboardingProfile(
            occupation: 'student',
            state: 'Lagos',
            city: 'Yaba',
            education: 'hnd_bsc',
            university: 'University of Lagos',
            // Agriculture & food keeps her in the noodles brief's audience.
            interests: const [
              'finance_fintech',
              'education',
              'agriculture_food',
            ],
            dateOfBirth: DateTime(2001, 4, 9),
          );
          expect(answers.phone, isEmpty);
          expect(
            onboardingBody(answers, today: DateTime.now())['phone'],
            isNull,
          );
          final sentAfter = DateTime.now().subtract(const Duration(seconds: 2));

          await onboarding.saveProfile(answers);
          await drain();

          final profile = (await account().me()).profile!;
          expect(profile.onboardingCompletedAt!.isAfter(sentAfter), isTrue);
          expect(profile.dateOfBirth, DateTime(2001, 4, 9));
          expect(profile.phone, '+2348031234567');
          expect(profile.city, 'Yaba');
          expect(profile.occupations, ['student']);
          expect(profile.university, 'University of Lagos');
          expect(profile.interests, [
            'finance_fintech',
            'education',
            'agriculture_food',
          ]);
          expect(profile.sector, 'tech');
        },
      );

      test('profile details: read, and a change through the outbox', () async {
        final profile = container.read(profileServiceProvider);
        expect(profile, isA<LiveProfileService>());
        final details = await profile.accountDetails();
        expect(details.phone, '+2348031234567');
        expect(details.dateOfBirth, DateTime(2001, 4, 9));
        expect(details.gender, isNull);
        expect(details.stateOfOrigin, isNull);

        await profile.saveDetails(
          details.copyWith(gender: 'female', stateOfOrigin: 'Anambra'),
          answers,
          before: details,
          answersBefore: answers,
        );
        await drain();
        final back = await LiveProfileService(
          container.read(accountLinkProvider)!,
        ).accountDetails();
        expect(back.gender, 'female');
        expect(back.stateOfOrigin, 'Anambra');
        expect(back.phone, '+2348031234567');
        expect(back.dateOfBirth, DateTime(2001, 4, 9));
      });

      test('the live briefs map to Brief', () async {
        final briefs = await repository().briefs(load: BriefsLoad.feed);
        expect(
          briefs.map((b) => b.id),
          unorderedEquals([seed.liveBriefId, seed.hiddenBriefId]),
        );

        final open = briefs.singleWhere((b) => b.id == seed.liveBriefId);
        expect(open.inAudience, isTrue);
        expect(open.title, 'Weeknight dinner: why noodles win');
        expect(open.businessName, 'Sunline Foods');
        expect(open.status, BriefStatus.live);
        expect(open.tier, Tier.advanced);
        expect(open.category, Category.customerExperience);
        expect(open.rewardPoolKobo, 10000000);
        expect(open.spotsTotal, 20);
        expect(open.spotsLeft, 19);
        expect(open.interest, 'agriculture_food');
        expect(
          open.winnerRule,
          '1st place ₦50,000 · 2nd place ₦30,000 · 3rd place ₦20,000',
        );
        expect(open.body, startsWith('We make instant noodles'));
        expect(
          open.body,
          endsWith(
            '• A short story of your last weeknight dinner\n'
            '• One change that would make you switch brands',
          ),
        );
        expect(
          open.deadline!.difference(DateTime.now()).inHours,
          inInclusiveRange(167, 168),
        );
        expect(DateTime.now().difference(open.createdAt).inHours, 24);

        final hidden = briefs.singleWhere((b) => b.id == seed.hiddenBriefId);
        expect(hidden.businessName, isNull);
        expect(hidden.logo, isNull);
        expect(hidden.spotsTotal, isNull);
        expect(hidden.spotsLeft, isNull);
        expect(hidden.category, Category.marketing);

        for (final image in [open.cover, open.logo, hidden.cover]) {
          final url = Uri.parse(image!);
          expect(url.isAbsolute, isTrue, reason: image);
          final served = await http.get(
            Uri.parse(base!).replace(path: url.path, query: url.query),
          );
          expect(served.statusCode, 200, reason: image);
          expect(served.headers['content-type'], 'image/png');
        }

        final detail = await repository().brief(seed.hiddenBriefId);
        expect(detail!.title, 'Your data plan, honestly');
        expect(detail.businessName, isNull);
      });

      late SubmitReceipt receipt;

      test('submit: the form from the survey, a PNG, one entry', () async {
        final submit = container.read(submitServiceProvider);
        expect(submit, isA<LiveSubmitService>());

        final opening = await submit.open(seed.liveBriefId);
        expect(opening.block, isNull);
        final form = opening.form!;
        expect(form.acceptsFiles, isTrue);
        expect(form.questions.map((q) => q.id), ['q1', 'q2']);
        expect(form.questions.first.text, 'Which noodle brands do you buy?');
        expect(form.questions.first.options, [
          'Indomie',
          'Golden Penny',
          'Mimee',
          'Supreme',
        ]);
        expect(form.questions.first.multi, isTrue);
        expect(form.questions.last.choice, isFalse);

        final textOnly = await submit.open(seed.hiddenBriefId);
        expect(textOnly.form!.acceptsFiles, isFalse);
        expect(textOnly.form!.questions, isEmpty);

        final progress = <double>[];
        final request = SubmitRequest(
          briefId: seed.liveBriefId,
          title: 'Noodles after a long day',
          answer: _typedAnswer,
          answers: const {
            'q1': ['Indomie', 'Supreme'],
            'q2': ['A free sample at my market.'],
          },
          files: [
            AttachmentFile(
              name: 'receipt.png',
              bytes: _png.length,
              read: () async => _png,
            ),
          ],
          onProgress: progress.add,
        );

        client.loseNextAnswer(
          'POST',
          '/submissions/challenges/${seed.liveBriefId}',
        );
        final lost = await submit.submit(request);
        expect(lost.failure, SubmitFailure.offline);

        final sent = await submit.submit(request);
        expect(sent.ok, isTrue, reason: '${sent.failure} ${sent.block}');
        receipt = sent.receipt!;
        expect(receipt.entries, 2);
        expect(receipt.submission.briefId, seed.liveBriefId);
        expect(receipt.submission.title, 'Noodles after a long day');
        expect(receipt.submission.status, SubmissionStatus.pending);
        expect(receipt.submission.body, _typedAnswer);
        expect(
          receipt.submission.brief?.title,
          'Weeknight dinner: why noodles win',
        );
        expect(progress.last, 1.0);

        final again = await submit.open(seed.liveBriefId);
        expect(again.block, SubmitBlock.alreadySubmitted);
        expect(again.submissionId, receipt.submission.id);
        final briefs = await repository().briefs(load: BriefsLoad.refresh);
        expect(
          briefs.singleWhere((b) => b.id == seed.liveBriefId).spotsLeft,
          18,
        );
      });

      late Submission hiddenEntry;

      test('a win on the brief whose business stays private', () async {
        final submit = container.read(submitServiceProvider);
        final textOnly = await submit.submit(
          SubmitRequest(
            briefId: seed.hiddenBriefId,
            title: 'Out of data on a Sunday',
            answer:
                'I run out of data every Sunday night, so I buy a daily plan '
                'at the kiosk on Monday morning.',
          ),
        );
        expect(textOnly.ok, isTrue, reason: '${textOnly.failure}');
        hiddenEntry = textOnly.receipt!.submission;
        expect(textOnly.receipt!.entries, 1);
        expect(hiddenEntry.brief!.businessName, isNull);
        expect(hiddenEntry.brief!.logo, isNull);

        final published = await tools.post(
          '/__local/challenges/${seed.hiddenBriefId}/publish',
        );
        expect(published['winners'], hasLength(1));
      });

      test('My submissions and their results', () async {
        final mine = await repository().submissions();
        expect(mine.map((s) => s.id), [
          hiddenEntry.id,
          receipt.submission.id,
          seed.wonId,
        ]);
        final [private, fresh, won] = mine;

        expect(private.status, SubmissionStatus.winner);
        expect(private.award!.amountKobo, 5000000);
        expect(private.brief!.status, BriefStatus.closed);
        expect(private.brief!.businessName, isNull);
        expect(private.brief!.logo, isNull);
        expect(private.brief!.title, 'Your data plan, honestly');

        expect(fresh.status.label, 'Under review');
        expect(fresh.body, _typedAnswer);
        expect(fresh.award, isNull);
        final brief = fresh.brief!;
        expect(brief.id, seed.liveBriefId);
        expect(brief.title, 'Weeknight dinner: why noodles win');
        expect(brief.businessName, 'Sunline Foods');
        expect(brief.status, BriefStatus.live);
        expect(brief.rewardPoolKobo, 10000000);
        expect(Uri.parse(brief.logo!).isAbsolute, isTrue);
        expect(Uri.parse(brief.cover!).isAbsolute, isTrue);
        expect(brief.deadline, isNotNull);

        expect(won.status, SubmissionStatus.winner);
        expect(won.award!.amountKobo, 3000000);
        expect(won.award!.ledgerId, isNotNull);
        expect(won.brief!.title, 'Breakfast on the go');
        expect(won.brief!.status, BriefStatus.closed);
        expect(won.brief!.businessName, 'Sunline Foods');

        final outcomes = container.read(outcomesServiceProvider);
        expect(outcomes, isA<LiveOutcomesService>());
        final result = (await outcomes.outcome(seed.wonId))!;
        expect(result.rank, 1);
        expect(result.entries, 2);
        expect(result.hasLeaderboard, isTrue);
        expect(result.link, endsWith('/challenges/breakfast-local'));
        expect(
          result.leaders.map((l) => (l.rank, l.name, l.entry, l.amountKobo)),
          [(2, 'Bob A.', '', 2000000)],
        );

        final before = (await outcomes.outcome(receipt.submission.id))!;
        expect(before.rank, isNull);
        expect(before.leaders, isEmpty);
        expect(before.entries, 2);
        expect(before.hasLeaderboard, isFalse);

        final alone = (await outcomes.outcome(hiddenEntry.id))!;
        expect(alone.rank, 1);
        expect(alone.entries, 1);
        expect(alone.leaders, isEmpty);
        expect(alone.link, endsWith('/challenges/data-plan-local'));
      });

      late SavedBank payTo;
      late Withdrawal tracked;

      test(
        'wallet: totals, ledger, banks, the account and a withdrawal',
        () async {
          final repo = repository();
          final totals = (await repo.walletTotals())!;
          expect(totals.totalEarnedKobo, 8000000);
          expect(totals.pendingWithdrawalsKobo, 0);
          expect(totals.withdrawableKobo, 7000000);

          final ledger = await repo.ledger();
          final win = ledger.singleWhere((l) => l.submissionId == seed.wonId);
          expect(win.type, LedgerType.award);
          expect(win.amountKobo, 3000000);
          expect(win.earned, isTrue);
          expect(win.source, RewardSource.submission);
          expect(win.business, 'Sunline Foods');
          final private = ledger.singleWhere(
            (l) => l.submissionId == hiddenEntry.id,
          );
          expect(private.amountKobo, 5000000);
          expect(private.source, RewardSource.submission);
          expect(private.business, isNull);
          final paidOut = ledger.singleWhere(
            (l) => l.type == LedgerType.withdrawal,
          );
          expect(paidOut.amountKobo, -1000000);
          expect(ledger, hasLength(3));

          final banks = await repo.banks();
          expect(banks.map((b) => b.code), containsAll(['044', '058']));
          final seeded = (await repo.savedBanks()).single;
          expect(seeded.label, 'Access Bank ••6789');
          expect(seeded.holder, 'Ada Obi');

          final wallet = container.read(walletServiceProvider);
          expect(wallet, isA<LiveWalletService>());
          final unknown = await wallet.verifyAccount(
            bankCode: '058',
            accountNumber: '0000000000',
          );
          expect(unknown.failure, WalletFailure.unverified);
          final verified = await wallet.verifyAccount(
            bankCode: '058',
            accountNumber: '0987654321',
          );
          expect(verified.accountName, 'ADA OBI');
          final bank = banks.singleWhere((b) => b.code == '058');
          payTo = await wallet.addAccount(
            SavedBank(
              bankCode: bank.code,
              bankName: bank.name,
              accountName: verified.accountName!,
              accountNumber: '0987654321',
            ),
          );
          expect(payTo.accountNumber, '4321');
          expect(payTo.label, 'Guaranty Trust Bank ••4321');
          expect(
            (await repo.savedBanks()).map((b) => b.accountNumber),
            containsAll(['6789', '4321']),
            reason: 'a second account is saved beside the default (10.2)',
          );

          client.loseNextAnswer('POST', '/wallet/withdrawals');
          final lost = await wallet.withdraw(
            amountKobo: 500000,
            account: payTo,
          );
          expect(lost.failure, WalletFailure.offline);
          final requested = await wallet.withdraw(
            amountKobo: 500000,
            account: payTo,
          );
          expect(requested.ok, isTrue, reason: '${requested.failure}');
          tracked = requested.withdrawal!;
          expect(tracked.amountKobo, 500000);
          expect(tracked.onHold, isTrue);
          expect(tracked.destination, 'Guaranty Trust Bank ••4321');
          expect(
            tracked.reference,
            matches(RegExp(r'^IQ-WD-\d{6}-[A-Z0-9]{4}$')),
          );
          final withdrawals = await repo.withdrawals();
          expect(withdrawals, hasLength(2));
          expect(
            withdrawals.where((w) => w.amountKobo == 500000).single.id,
            tracked.id,
          );

          final watched = <WithdrawalStatus>[];
          final last = wallet.watch(tracked).map((w) {
            watched.add(w.status);
            return w;
          }).last;
          final settled = await tools.post(
            '/__local/withdrawals/${tracked.id}/settle',
          );
          expect(settled['status'], 'completed');
          final arrived = await last.timeout(const Duration(seconds: 30));
          expect(arrived.status, WithdrawalStatus.completed);
          expect(arrived.completedAt, isNotNull);
          expect(arrived.sentAt, isNotNull);
          expect(watched.first, tracked.status);
          expect(watched.last, WithdrawalStatus.completed);

          final after = (await repo.walletTotals())!;
          expect(after.withdrawableKobo, 6500000);
          expect(after.pendingWithdrawalsKobo, 0);
          expect(after.totalEarnedKobo, 8000000);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );

      late Withdrawal refused;

      test('a payout the bank reverses, and one that fails', () async {
        final repo = repository();
        final wallet = container.read(walletServiceProvider);
        final reversed = await tools.post(
          '/__local/withdrawals/${seed.withdrawalId}/settle',
          {'event': 'transfer.reversed', 'reason': 'Account closed'},
        );
        expect(reversed['status'], 'reversed');
        final back = (await repo.withdrawals()).singleWhere(
          (w) => w.id == seed.withdrawalId,
        );
        expect(back.status, WithdrawalStatus.reversed);
        expect(back.failed, isTrue);
        expect(back.failureReason, isNull);
        final returned = (await repo.ledger()).singleWhere((l) => l.reversal);
        expect(returned.type, LedgerType.award);
        expect(returned.amountKobo, 1000000);
        expect(returned.earned, isFalse);
        final totals = (await repo.walletTotals())!;
        expect(totals.withdrawableKobo, 7500000);
        expect(totals.totalEarnedKobo, 8000000);

        final asked = await wallet.withdraw(amountKobo: 100000, account: payTo);
        expect(asked.ok, isTrue, reason: '${asked.failure}');
        refused = asked.withdrawal!;
        final last = wallet.watch(refused).last;
        final failed = await tools.post(
          '/__local/withdrawals/${refused.id}/settle',
          {'event': 'transfer.failed', 'reason': 'Account dormant'},
        );
        expect(failed['status'], 'failed');
        final ended = await last.timeout(const Duration(seconds: 30));
        expect(ended.status, WithdrawalStatus.failed);
        expect(ended.statusWord, 'failed');
        expect(ended.failureReason, isNull);
        expect((await repo.walletTotals())!.withdrawableKobo, 7500000);
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('notifications: worded from the feed, seen and read', () async {
        final service = container.read(notificationsServiceProvider);
        expect(service, isA<LiveNotificationsService>());
        final feed = await service.notifications();
        expect(feed, hasLength(11));
        expect(feed.every((n) => n.unread), isTrue);
        final now = DateTime.now();
        NotificationItem words(AppNotification note) => wordNotification(
          note,
          briefs: const {},
          awards: const {},
          withdrawals: const {},
          now: now,
        )!;

        final win = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.won &&
              n.briefId == seed.closedBriefId,
        );
        final ledger = await repository().ledger();
        expect(
          win.entryId,
          ledger.singleWhere((l) => l.submissionId == seed.wonId).id,
        );
        final winWords = words(win);
        expect(winWords.title, 'You won ₦30,000.00');
        expect(winWords.detail, 'Breakfast on the go');
        expect(
          winWords.page!.body,
          'Sunline Foods picked your answer to “Breakfast on the go”. '
          '₦30,000.00 is in your wallet now.',
        );
        expect(winWords.page!.link.location, resultPath(seed.wonId));

        final privateWin = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.won &&
              n.briefId == seed.hiddenBriefId,
        );
        expect(privateWin.facts!.brief!.businessName, isNull);
        expect(words(privateWin).title, 'You won ₦50,000.00');
        expect(
          words(privateWin).page!.body,
          'A business kept private picked your answer to “Your data plan, '
          'honestly”. ₦50,000.00 is in your wallet now.',
        );

        final requested = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.withdrawalRequested &&
              n.entryId == tracked.id,
        );
        expect(words(requested).title, '₦5,000.00 requested');
        expect(
          words(requested).detail,
          'Guaranty Trust Bank ••4321 · completed',
        );
        final paid = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.paidOut && n.entryId == tracked.id,
        );
        expect(words(paid).title, '₦5,000.00 paid out');
        expect(
          words(paid).detail,
          'Sent to Guaranty Trust Bank ••4321 · completed',
        );
        expect(
          words(paid).page!.body,
          contains('Reference ${tracked.reference}.'),
        );
        final earlier = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.paidOut && n.entryId != tracked.id,
        );
        expect(words(earlier).title, '₦10,000.00 paid out');
        expect(words(earlier).detail, 'Sent to Access Bank ••6789 · reversed');
        final reversal = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.payoutFailed &&
              n.entryId == seed.withdrawalId,
        );
        expect(words(reversal).title, '₦10,000.00 is back in your wallet');
        expect(
          words(reversal).detail,
          'Withdrawal to Access Bank ••6789 reversed',
        );
        expect(
          words(reversal).page!.body,
          '₦10,000.00 to Access Bank ••6789 reversed. '
          'It is back in your wallet.',
        );
        final failure = feed.singleWhere(
          (n) =>
              n.event == NotificationEvent.payoutFailed &&
              n.entryId == refused.id,
        );
        expect(words(failure).title, '₦1,000.00 never left your wallet');
        expect(
          words(failure).detail,
          'Withdrawal to Guaranty Trust Bank ••4321 failed',
        );
        expect(
          words(failure).page!.body,
          '₦1,000.00 to Guaranty Trust Bank ••4321 failed. '
          'Nothing left your wallet.',
        );
        final results = feed.where(
          (n) => n.event == NotificationEvent.resultsReady,
        );
        expect(results.map((n) => n.briefId), [
          seed.hiddenBriefId,
          seed.closedBriefId,
        ]);
        for (final note in results) {
          expect(words(note).title, note.facts!.title);
          expect(words(note).detail, note.facts!.body);
          expect(words(note).link!.location, Routes.brief(note.briefId!));
        }
        expect(
          results.first.facts!.body,
          startsWith('A business kept private has finished reviewing'),
        );

        expect(await service.unseen(), 11);
        await service.markSeen();
        await service.markRead(win.id);
        await drain();
        expect(await service.unseen(), 0);
        final read = await service.notifications();
        expect(read.singleWhere((n) => n.id == win.id).unread, isFalse);
        expect(read.where((n) => n.unread), hasLength(10));
      });

      test('notification preferences: read, change one, read back', () async {
        final profile = container.read(profileServiceProvider);
        expect(profile, isA<LiveProfileService>());
        expect(await profile.notificationPreferences(), {
          NotificationTopic.closingSoon: true,
          NotificationTopic.results: true,
          NotificationTopic.payouts: true,
          NotificationTopic.newBriefs: true,
          NotificationTopic.polls: false,
        });
        await profile.setNotificationPreference(
          NotificationTopic.payouts,
          false,
        );
        await drain();
        final back = await LiveProfileService(
          container.read(accountLinkProvider)!,
        ).notificationPreferences();
        expect(back[NotificationTopic.payouts], isFalse);
        expect(back[NotificationTopic.results], isTrue);
        expect(back[NotificationTopic.polls], isFalse);
      });

      // Contract 11: Tola acts for the businesses, Ada uses the app.
      late ApiClient owner;
      Directory files() =>
          folder ??= Directory.systemTemp.createTempSync('iqly-proof');
      Matcher refusedWith(String code) =>
          throwsA(isA<ApiRefused>().having((r) => r.code, 'code', code));

      /// A session of its own for [email], beside Ada's.
      Future<ApiClient> signedIn(String email, {http.Client? via}) async {
        final other = ApiClient(
          tokens: MemoryTokenStore(),
          client: via,
          baseUrl: base!,
          appVersion: '0.5.0+5',
          platform: 'android',
        );
        final res = await other.post('/auth/web/sign-in/email', {
          'email': email,
          'password': seed.password,
        });
        expect(res.ok, isTrue, reason: '$email: ${res.status} ${res.code}');
        return other;
      }

      Future<Map<String, dynamic>> asOwner(
        String method,
        String path, [
        Map<String, Object?>? body,
      ]) async {
        final res = await owner.send(
          method,
          path,
          body: body ?? (method == 'GET' ? null : const <String, Object?>{}),
        );
        expect(res.ok, isTrue, reason: '$method $path: ${res.code}');
        return res.data;
      }

      /// A Sunline Foods activation, paid for at the stand-in checkout and
      /// live now.
      Future<String> publishActivation(String title, {int slots = 10}) async {
        final made = await asOwner('POST', '/activations/owner', {
          'brandOrgId': 'org_sunline',
          'title': title,
          'minutes': 5,
          'rewardKobo': 50000,
          'slots': slots,
          'steps': [
            {'title': 'Sign up with code IQLY', 'hint': 'Enter IQLY.'},
            {'title': 'Rate a recipe', 'hint': 'Any recipe counts.'},
          ],
          'link': 'https://sunline.example/app',
          'closesAt': DateTime.now()
              .add(const Duration(days: 2))
              .toUtc()
              .toIso8601String(),
        });
        final id = made['id'] as String;
        final checkout = await asOwner(
          'POST',
          '/activations/owner/$id/payment/initiate',
          {'callbackUrl': 'http://localhost:3001/activations/paid'},
        );
        await tools.post('/__local/payments/${checkout['reference']}/pay');
        await asOwner('POST', '/activations/owner/$id/publish');
        return id;
      }

      /// Ada's run at [activation], for the business to act on.
      Future<String> runOf(String activation) async {
        final res = await api.get('/activations/$activation');
        return ((res.data['progress'] as Map)['id']) as String;
      }

      ProofVideo recording(String name, List<int> bytes, {int? seconds}) {
        // The API reads a recording's first bytes (an MP4 opens with its
        // ftyp box), so each sample recording starts with one.
        final media = name.endsWith('.mp4')
            ? [0, 0, 0, 0x18, ...'ftypmp42'.codeUnits, ...bytes]
            : bytes;
        final file = File('${files().path}/$name')..writeAsBytesSync(media);
        return ProofVideo(
          name: name,
          bytes: media.length,
          length: seconds == null ? null : Duration(seconds: seconds),
          source: file.uri,
        );
      }

      Future<String> upload(String activation, ProofVideo video) async =>
          (await container
                  .read(activationsServiceProvider)
                  .upload(activation, video)
                  .last)
              .id!;

      test('polls and activations run live; their screens show', () async {
        if (!eleven) return;
        owner = await signedIn(seed.ownerEmail);
        final mode = container.read(liveModeProvider);
        expect(mode.isLive(LiveFeature.polls), isTrue);
        expect(mode.isLive(LiveFeature.activations), isTrue);
        expect(container.read(pollsShownProvider), isTrue);
        expect(container.read(activationsShownProvider), isTrue);
        expect(
          container.read(supportShownProvider),
          mode.isLive(LiveFeature.support),
          reason: 'Ask for help on a proof shows only with support',
        );
        for (final path in [
          Routes.polls,
          pollsOf('org_sunline'),
          Routes.activations,
          activationPath(seed.recipes),
          proofPath(seed.account),
        ]) {
          expect(hiddenRoute(container.read, path), isFalse, reason: path);
        }
        expect(container.read(pollsServiceProvider), isA<LivePollsService>());
        expect(
          container.read(activationsServiceProvider),
          isA<LiveActivationsService>(),
        );
      });

      test('polls: the list, one poll, a vote, and each refusal', () async {
        if (!eleven) return;
        final service = container.read(pollsServiceProvider);
        final businesses = await service.businesses();
        expect(businesses.first.name, 'Harbour Telecom');
        final kiosk = businesses.first.polls.single;
        expect(kiosk.id, seed.kioskPoll);
        expect((kiosk.chosen, kiosk.total), (1, 176));
        final sunline = businesses.singleWhere(
          (b) => b.name == 'Sunline Foods',
        );
        expect(sunline.logo, startsWith(base!));
        Poll find(PollBusiness b, String id) =>
            b.polls.singleWhere((p) => p.id == id);
        final flavour = find(sunline, seed.flavourPoll);
        expect(flavour.voted, isFalse);
        expect(flavour.votes, [0, 0, 0]);
        expect(flavour.closedAt(DateTime.now()), isFalse);
        final noodles = find(sunline, seed.closedPoll);
        expect(noodles.closedAt(DateTime.now()), isTrue);
        expect((noodles.chosen, noodles.total), (0, 97));
        expect(noodles.shares, [63, 25, 12]);

        final alone = await service.poll(seed.flavourPoll);
        expect((alone.id, alone.name), ('org_sunline', 'Sunline Foods'));
        expect(alone.polls.single.question, flavour.question);

        final polls = container.read(pollsProvider.notifier);
        await container.read(pollsProvider.future);
        Poll shown(String id) => container
            .read(pollsProvider)
            .value!
            .expand((b) => b.polls)
            .singleWhere((p) => p.id == id);
        expect(await polls.vote(seed.flavourPoll, 0), VoteOutcome.counted);
        expect(shown(seed.flavourPoll).chosen, 0);
        expect(shown(seed.flavourPoll).total, 214);
        expect(shown(seed.flavourPoll).shares, [45, 33, 22]);
        expect(
          await polls.vote(seed.flavourPoll, 0),
          VoteOutcome.counted,
          reason: 'the same vote again is safe',
        );
        expect(shown(seed.flavourPoll).total, 214);

        await expectLater(
          service.vote(seed.flavourPoll, 1),
          refusedWith('POLL_ALREADY_VOTED'),
        );
        expect(await polls.vote(seed.flavourPoll, 2), VoteOutcome.refused);
        expect(shown(seed.flavourPoll).chosen, 0);

        await expectLater(
          service.vote(seed.canSizePoll, 3),
          refusedWith('VALIDATION_ERROR'),
        );
        expect(await polls.vote(seed.canSizePoll, 3), VoteOutcome.refused);
        expect(shown(seed.canSizePoll).voted, isFalse);

        const missing = '00000000-0000-4000-8000-000000000000';
        await expectLater(service.poll(missing), refusedWith('POLL_NOT_FOUND'));
        await expectLater(
          service.vote(missing, 0),
          refusedWith('POLL_NOT_FOUND'),
        );

        final made = await asOwner('POST', '/polls/owner', {
          'brandOrgId': 'org_sunline',
          'question': 'Which noodle flavour comes next?',
          'choices': ['Chicken', 'Pepper soup'],
          'closesAt': DateTime.now()
              .add(const Duration(hours: 2))
              .toUtc()
              .toIso8601String(),
        });
        final early = made['id'] as String;
        await asOwner('POST', '/polls/owner/$early/close');
        await expectLater(service.vote(early, 0), refusedWith('POLL_CLOSED'));
        expect(await polls.vote(early, 0), VoteOutcome.refused);
        final closed = shown(early);
        expect(closed.closedAt(DateTime.now()), isTrue);
        expect(closed.voted, isFalse);

        final inputs = await surfaceInputs(container.read, DateTime.now());
        expect(inputs.showPolls, isTrue);
        expect(inputs.polls.map((b) => b.name), contains('Sunline Foods'));
      });

      test('poll results reach the voters; the row opens the poll', () async {
        if (!eleven) return;
        final polls = container.read(pollsProvider.notifier);
        expect(await polls.vote(seed.canSizePoll, 1), VoteOutcome.counted);
        await asOwner('POST', '/polls/owner/${seed.canSizePoll}/close');
        final feed = await container
            .read(notificationsServiceProvider)
            .notifications();
        final row = feed.singleWhere((n) => n.facts?.type == 'poll_results');
        expect(row.facts!.pollId, seed.canSizePoll);
        NotificationItem words({required bool polls}) => wordNotification(
          row,
          briefs: const {},
          awards: const {},
          withdrawals: const {},
          now: DateTime.now(),
          polls: polls,
        )!;
        expect(words(polls: true).title, 'Poll results are in');
        expect(
          words(polls: true).link!.location,
          quickPollsFor(seed.canSizePoll),
        );
        expect(words(polls: false).link, isNull);
        expect(
          await polls.bring(seed.canSizePoll),
          'org_sunline',
          reason: 'the row opens the business the poll is under',
        );
        final results = await container
            .read(pollsServiceProvider)
            .poll(seed.canSizePoll);
        expect(results.polls.single.chosen, 1);
        expect(results.polls.single.closedAt(DateTime.now()), isTrue);
        expect(results.polls.single.total, 1);
      });

      test('activations: every phase the API names, mine included', () async {
        if (!eleven) return;
        final service = container.read(activationsServiceProvider);
        final all = await service.activations();
        final now = DateTime.now();
        final raw = [
          for (final item
              in (await api.get('/activations')).data['items'] as List)
            item as Map<String, dynamic>,
          for (final item
              in (await api.get('/activations/mine')).data['items'] as List)
            item as Map<String, dynamic>,
        ];
        const phases = {
          'offer': ActivationPhase.offer,
          'started': ActivationPhase.started,
          'confirming': ActivationPhase.confirming,
          'not_confirmed': ActivationPhase.notConfirmed,
          'checking': ActivationPhase.checking,
          'not_accepted': ActivationPhase.notAccepted,
          'credited': ActivationPhase.credited,
          'expired': ActivationPhase.expired,
        };
        for (final json in raw) {
          final a = all.singleWhere((a) => a.id == json['id']);
          // In proof mode the API's not_confirmed is the step to record.
          final recording =
              json['phase'] == 'not_confirmed' &&
              a.confirmationMode == ConfirmationMode.proof;
          expect(
            a.phaseAt(now),
            recording ? ActivationPhase.recording : phases[json['phase']],
            reason: a.title,
          );
          expect(a.live, isTrue);
          expect(a.imageUrl, startsWith(base!));
        }
        Activation one(String id) => all.singleWhere((a) => a.id == id);
        expect(one(seed.recipes).phaseAt(now), ActivationPhase.offer);
        expect(one(seed.recipes).spotsLeft, 38);
        expect(one(seed.account).phaseAt(now), ActivationPhase.notConfirmed);
        expect(one(seed.account).waitingStep, 1);
        expect(one(seed.order).phaseAt(now), ActivationPhase.checking);
        expect(
          one(seed.order).progress!.proof!.video.length,
          const Duration(seconds: 42),
        );
        expect(
          one(seed.closedActivation).phaseAt(now),
          ActivationPhase.expired,
        );
        expect(all.map((a) => a.id), isNot(contains(seed.paused)));

        final refreshed = await service.refresh(seed.paused);
        expect(refreshed.phaseAt(now), ActivationPhase.offer);
      });

      test('start, and each refusal Start maps', () async {
        if (!eleven) return;
        final service = container.read(activationsServiceProvider);
        final started = await service.start(seed.recipes);
        expect(started.phaseAt(DateTime.now()), ActivationPhase.started);
        expect(
          (await service.start(seed.recipes)).progress!.startedAt,
          started.progress!.startedAt,
          reason: 'starting again answers the run under way',
        );
        await expectLater(
          service.start(seed.paused),
          refusedWith('ACTIVATION_PAUSED'),
        );
        final paused = await service.refresh(seed.paused);
        expect(paused.paused, isTrue);
        expect(paused.phaseAt(DateTime.now()), ActivationPhase.offer);

        // Opened from a link: one not in the list lands; one the API has
        // not reads as gone, for good.
        final list = container.read(activationsProvider.notifier);
        await container.read(activationsProvider.future);
        expect(await list.load(seed.paused), isNull);
        expect(container.read(activationProvider(seed.paused))?.paused, isTrue);
        expect(
          await list.load('00000000-0000-4000-8000-000000000000'),
          ActivationMissing.gone,
        );
        // Resumed by the business: the next read says live again.
        await asOwner('POST', '/activations/owner/${seed.paused}/resume');
        await list.refreshOneQuietly(seed.paused);
        expect(
          container.read(activationProvider(seed.paused))?.paused,
          isFalse,
        );
        await asOwner('POST', '/activations/owner/${seed.paused}/pause');
        await expectLater(
          service.start('00000000-0000-4000-8000-000000000000'),
          refusedWith('ACTIVATION_NOT_FOUND'),
        );
        final ownersOwn = LiveActivationsService(
          AccountLink(
            api: owner,
            store: MemoryLocalStore(),
            outbox: Outbox(MemoryLocalStore()),
            userId: () => null,
          ),
        );
        await expectLater(
          ownersOwn.start(seed.recipes),
          refusedWith('ACTIVATION_OWN_BUSINESS'),
        );

        final ended = await publishActivation('Rate a recipe on day one');
        await asOwner('POST', '/activations/owner/$ended/close');
        await expectLater(
          service.start(ended),
          refusedWith('ACTIVATION_CLOSED'),
        );
        final full = await publishActivation('Be first to rate', slots: 1);
        final bob = LiveActivationsService(
          AccountLink(
            api: await signedIn(seed.otherEmail),
            store: MemoryLocalStore(),
            outbox: Outbox(MemoryLocalStore()),
            userId: () => null,
          ),
        );
        expect((await bob.start(full)).started, isTrue);
        await expectLater(service.start(full), refusedWith('ACTIVATION_FULL'));
        expect((await service.refresh(full)).full, isTrue);

        final activations = container.read(activationsProvider.notifier);
        await container.read(activationsProvider.future);
        await activations.refreshOneQuietly(full);
        expect(
          container.read(activationProvider(full))?.full,
          isTrue,
          reason: 'a refused Start reads the activation again',
        );
      });

      test(
        'proof: upload, drop, send, turned down, sent again, paid',
        () async {
          if (!eleven) return;
          final service = container.read(activationsServiceProvider);
          final clip = List<int>.filled(4096, 7);

          await expectLater(
            service.upload(seed.account, recording('notes.txt', clip)).last,
            refusedWith('FILE_TYPE_NOT_ALLOWED'),
          );
          await expectLater(
            service
                .upload(seed.account, recording('long.mp4', clip, seconds: 61))
                .last,
            refusedWith('VIDEO_TOO_LONG'),
          );
          await expectLater(
            service
                .upload(
                  seed.account,
                  recording('big.mp4', List<int>.filled(52500000, 0)),
                )
                .last,
            refusedWith('FILE_TOO_LARGE'),
          );
          for (final (activation, code) in [
            (seed.paused, 'ACTIVATION_NOT_STARTED'),
            (seed.closedActivation, 'ACTIVATION_CLOSED'),
          ]) {
            await expectLater(
              service.upload(activation, recording('p.mp4', clip)).last,
              refusedWith(code),
            );
          }

          final video = recording('harbour-signup.mp4', clip, seconds: 42);
          final dropped = await upload(seed.account, video);
          await service.discard(seed.account, dropped);
          final again = await api.delete(
            '/activations/${seed.account}/proof/uploads/$dropped',
          );
          expect(again.code, 'ACTIVATION_UPLOAD_NOT_FOUND');

          await expectLater(
            service.sendProof(
              seed.account,
              step: 1,
              uploadId: dropped,
              video: video,
            ),
            refusedWith('ACTIVATION_UPLOAD_NOT_FOUND'),
          );
          final first = await upload(seed.account, video);
          final checking = await service.sendProof(
            seed.account,
            step: 1,
            uploadId: first,
            video: video,
            phone: '0803 123 4567',
            note: 'I used my work phone',
          );
          expect(checking.phaseAt(DateTime.now()), ActivationPhase.checking);
          final sent = checking.progress!.proof!.video;
          expect(sent.length, const Duration(seconds: 42));
          final player = await http.get(
            sent.source!,
            headers: Recordings.headersFor(sent.source!),
          );
          expect(player.statusCode, 200);
          final sample = File.fromUri(video.source!).readAsBytesSync();
          expect(player.bodyBytes, sample);
          expect((await http.get(sent.source!)).statusCode, isNot(200));
          // Players open the copy downloaded once, never the stream.
          final copy = await Recordings.fetchSignedIn!(sent.source!);
          expect(copy.scheme, 'file');
          expect(File.fromUri(copy).readAsBytesSync(), sample);
          expect((await Recordings.fetchSignedIn!(sent.source!)), copy);
          final inUse = await api.delete(
            '/activations/${seed.account}/proof/uploads/$first',
          );
          expect(inUse.code, 'ACTIVATION_UPLOAD_IN_USE');
          await expectLater(
            service.sendProof(
              seed.account,
              step: 1,
              uploadId: await upload(seed.account, video),
              video: video,
            ),
            refusedWith('ACTIVATION_PROOF_PENDING'),
          );

          final run = await runOf(seed.account);
          await asOwner(
            'POST',
            '/activations/owner/${seed.account}/completions/$run/reject',
            {'reason': 'The recording ends before the Verification page.'},
          );
          final refused = await service.refresh(seed.account);
          expect(refused.phaseAt(DateTime.now()), ActivationPhase.notAccepted);
          expect(
            refused.progress!.proof!.notAccepted,
            'The recording ends before the Verification page.',
          );

          final resent = await service.sendProof(
            seed.account,
            step: 1,
            uploadId: await upload(seed.account, video),
            video: video,
          );
          expect(resent.phaseAt(DateTime.now()), ActivationPhase.checking);

          await asOwner(
            'POST',
            '/activations/owner/${seed.account}/completions/$run/approve',
          );
          final paid = await service.refresh(seed.account);
          expect(paid.phaseAt(DateTime.now()), ActivationPhase.credited);
          final ledgerId = paid.progress!.ledgerId;
          expect(ledgerId, isNotNull);
          await expectLater(
            service.upload(seed.account, recording('p.mp4', clip)).last,
            refusedWith('ACTIVATION_COMPLETION_PAID'),
          );
          expect(
            ProofRefusal.fromCode('ACTIVATION_COMPLETION_PAID'),
            ProofRefusal.paid,
            reason: 'paid meanwhile reads as the reward, not as ended',
          );

          final reward = (await repository().ledger()).singleWhere(
            (l) => l.id == ledgerId,
          );
          expect(reward.source, RewardSource.activation);
          expect(reward.activationId, seed.account);
          expect(reward.amountKobo, 150000);
          expect(reward.business, 'Harbour Telecom');
          expect(reward.note, paid.title);

          final feed = await container
              .read(notificationsServiceProvider)
              .notifications();
          NotificationItem words(AppNotification note) => wordNotification(
            note,
            briefs: const {},
            awards: const {},
            withdrawals: const {},
            now: DateTime.now(),
            activations: true,
          )!;
          final approved = feed.singleWhere(
            (n) => n.facts?.type == 'activation_approved',
          );
          expect(approved.facts!.activationId, seed.account);
          expect(approved.facts!.amountKobo, 150000);
          expect(words(approved).title, '₦1,500.00 added to your wallet');
          expect(words(approved).link!.location, activationPath(seed.account));
          final rejected = feed.singleWhere(
            (n) => n.facts?.type == 'activation_rejected',
          );
          expect(words(rejected).title, 'Proof not accepted');
          expect(words(rejected).link!.location, activationPath(seed.account));
        },
      );

      test(
        'a proof turned down after the close: nothing to record or send',
        () async {
          if (!eleven) return;
          // Bob's proof for the order was turned down (the seed); then the
          // business closes it.
          final bob = LiveActivationsService(
            AccountLink(
              api: await signedIn(seed.otherEmail),
              store: MemoryLocalStore(),
              outbox: Outbox(MemoryLocalStore()),
              userId: () => null,
            ),
          );
          final before = await bob.refresh(seed.order);
          expect(before.phaseAt(DateTime.now()), ActivationPhase.notAccepted);
          expect(before.canProveAt(DateTime.now()), isTrue);
          final kept = await bob
              .upload(
                seed.order,
                recording('bob.mp4', List<int>.filled(512, 5)),
              )
              .last;
          await asOwner('POST', '/activations/owner/${seed.order}/close');

          final after = await bob.refresh(seed.order);
          final now = DateTime.now();
          expect(after.phaseAt(now), ActivationPhase.notAccepted);
          expect(after.closedAt(now), isTrue);
          expect(after.canProveAt(now), isFalse, reason: 'no Record again');
          Matcher ended() => throwsA(
            isA<ApiRefused>()
                .having((r) => activationRunEnded(r.code), 'ended', isTrue)
                .having((r) => unanswered(r), 'retryable', isFalse),
          );
          await expectLater(
            bob.upload(seed.order, recording('late.mp4', [9, 9, 9])).last,
            ended(),
          );
          expect(
            ProofRefusal.fromCode('ACTIVATION_CLOSED'),
            ProofRefusal.ended,
          );
          await expectLater(
            bob.sendProof(
              seed.order,
              step: 1,
              uploadId: kept.id!,
              video: recording('bob.mp4', [5]),
            ),
            ended(),
          );
        },
      );

      test('throttles offer Try again; early proof is not due', () async {
        if (!eleven) return;
        final service = container.read(activationsServiceProvider);
        final video = recording('early.mp4', List<int>.filled(2048, 3));
        // Votes and starts are limited to 30 a minute each: past it, a vote
        // and a Start read as no answer, which Try again can send.
        final polls = container.read(pollsProvider.notifier);
        var vote = VoteOutcome.counted;
        for (var i = 0; i < 40 && vote == VoteOutcome.counted; i++) {
          vote = await polls.vote(seed.kioskPoll, 1);
        }
        expect(vote, VoteOutcome.offline);
        ApiRefused? held;
        for (var i = 0; i < 40 && held == null; i++) {
          try {
            await service.start(seed.recipes);
          } on ApiRefused catch (refusal) {
            held = refusal;
          }
        }
        expect(held?.code, 'RATE_LIMITED');
        expect(unanswered(held!), isTrue);
        ApiRefused? throttled;
        for (var i = 0; i < 11 && throttled == null; i++) {
          try {
            await upload(seed.recipes, video);
          } on ApiRefused catch (refusal) {
            if (refusal.code != 'RATE_LIMITED') rethrow;
            throttled = refusal;
          }
        }
        expect(throttled?.status, 429);
        expect(ProofRefusal.fromCode(throttled!.code), isNull);
        final busy = await api.multipart(
          '/activations/${seed.recipes}/proof/uploads',
          fields: const {},
          files: [
            ApiFile(
              field: 'file',
              filename: 'early.mp4',
              bytes: const [1],
              contentType: 'video/mp4',
            ),
          ],
        );
        expect(busy.code, 'RATE_LIMITED');
        await Future<void>.delayed(
          (busy.retryAfter ?? const Duration(minutes: 1)) +
              const Duration(seconds: 1),
        );

        final run = await runOf(seed.recipes);
        await asOwner(
          'POST',
          '/activations/owner/${seed.recipes}/completions/$run/confirm-step',
          {'step': 0},
        );
        final confirming = await service.refresh(seed.recipes);
        expect(confirming.phaseAt(DateTime.now()), ActivationPhase.confirming);
        await expectLater(
          service.sendProof(
            seed.recipes,
            step: 1,
            uploadId: await upload(seed.recipes, video),
            video: video,
          ),
          refusedWith('ACTIVATION_PROOF_NOT_DUE'),
        );
      }, timeout: const Timeout(Duration(minutes: 3)));

      AccountLink linkOf(ApiClient other) {
        final kept = MemoryLocalStore();
        return AccountLink(
          api: other,
          store: kept,
          outbox: Outbox(kept),
          userId: () => null,
        );
      }

      HelpAttachment file(String name, List<int> bytes, {Duration? length}) =>
          HelpAttachment(
            name: name,
            bytes: bytes.length,
            kind: supportTypeOf(name)!.kind,
            mime: supportTypeOf(name)!.mime,
            length: length,
            read: () async => bytes,
          );

      Matcher refusedFor(HelpFailure failure) => throwsA(
        isA<HelpRefused>().having((r) => r.failure, 'failure', failure),
      );

      late HelpTicket opened;

      test('support: the inbox, a thread and its files, an open whose answer '
          'was lost, a reply, support\'s answer and its feed row, read, '
          'resolved and a report', () async {
        final help = container.read(helpServiceProvider);
        expect(container.read(supportShownProvider), on(LiveFeature.support));
        if (!on(LiveFeature.support)) {
          expect(help, isA<PausedHelpService>());
          expect(await help.conversations(), isEmpty);
          expect(await help.unread(), 0);
          return;
        }
        expect(help, isA<LiveHelpService>());
        final inbox = await help.conversations();
        expect(inbox.map((t) => t.reference), ['IQ-HELP-2042', 'IQ-HELP-2041']);
        final [report, chat] = inbox;
        expect(report.status, HelpTicketStatus.open);
        expect(report.subject, 'The app');
        expect(chat.status, HelpTicketStatus.replied);
        expect(chat.unread, isTrue);
        expect(chat.messages.single.author, HelpAuthor.support);
        expect(await help.unread(), 1);

        final thread = await help.watch(chat.id).single;
        expect(thread.subject, 'Withdrawal to Access Bank');
        expect(thread.messages.map((m) => m.author), [
          HelpAuthor.you,
          HelpAuthor.support,
        ]);
        final picture =
            (await help.watch(report.id).single).messages.single.attachment!;
        expect(picture.kind, HelpAttachmentKind.image);
        expect(picture.name, 'activity.png');
        final served = await api.download(picture.url.toString());
        expect(served.ok, isTrue);
        expect(served.bytes, isNotEmpty);

        await help.markRead(chat.id);
        expect(await help.unread(), 0);

        final steps = await help.upload(file('screen.png', _png)).toList();
        expect(steps.last.done, isTrue);
        final uploaded = steps.last.file;
        expect(uploaded.id, isNotNull);
        expect(uploaded.kind, HelpAttachmentKind.image);

        final request = HelpRequest(
          subject: 'Chat with iQLY support',
          message: 'My balance looks wrong.',
          attachment: uploaded,
        );
        client.loseNextAnswer('POST', '/support/tickets');
        await expectLater(help.send(request), refusedFor(HelpFailure.offline));
        opened = await help.send(request);
        expect(opened.reference, matches(RegExp(r'^IQ-HELP-\d+$')));
        expect(opened.status, HelpTicketStatus.open);
        expect(opened.messages.single.attachment!.id, uploaded.id);
        expect(
          (await help.conversations()).where(
            (t) => t.subject == 'Chat with iQLY support',
          ),
          hasLength(1),
          reason: 'the retry carried the lost send\'s key',
        );

        final again = await help.reply(
          opened.id,
          'It shows ₦0.00.',
          idempotencyKey: LocalRows.newId(),
        );
        expect(again.status, HelpTicketStatus.open);
        expect(again.messages, hasLength(2));

        final staff = await signedIn('support@example.com');
        final answer = await staff.post(
          '/admin/support/tickets/${opened.id}/reply',
          {'message': 'Thanks, Ada. We are looking at it now.'},
        );
        expect(answer.ok, isTrue, reason: '${answer.status} ${answer.code}');
        final answered = await help.watch(opened.id).single;
        expect(answered.status, HelpTicketStatus.replied);
        expect(answered.unread, isTrue);
        expect(answered.messages.last.author, HelpAuthor.support);
        expect(await help.unread(), 1);

        final feed = await container
            .read(notificationsServiceProvider)
            .notifications();
        final row = feed.firstWhere((n) => n.facts?.type == 'support');
        expect(row.facts!.ticketId, opened.id);
        expect(row.facts!.title, 'iQLY support replied');
        final words = wordNotification(
          row,
          briefs: const {},
          awards: const {},
          withdrawals: const {},
          now: DateTime.now(),
        )!;
        expect(words.link!.location, helpThreadPath(opened.id));

        expect(
          (await help.resolve(opened.id)).status,
          HelpTicketStatus.resolved,
        );
        expect(
          (await help.resolve(opened.id)).status,
          HelpTicketStatus.resolved,
          reason: 'resolving again changes nothing',
        );

        final sent = await help.report(
          topic: 'Payments',
          details: 'A payout is missing from Activity.',
          screenshot: file('payout.png', _png),
        );
        expect(sent, matches(RegExp(r'^IQ-HELP-\d+$')));
        final filed = (await help.conversations()).firstWhere(
          (t) => t.reference == sent,
        );
        expect(filed.subject, 'Payments');
        final filedThread = await help.watch(filed.id).single;
        expect(filedThread.messages.single.attachment!.name, 'payout.png');
      });

      test('support refusals reach the app as its own words', () async {
        if (!on(LiveFeature.support)) return;
        final bob = await signedIn('bob@example.com');
        final help = LiveHelpService(linkOf(bob), files: DeviceSupportFiles());
        final mp4 = [
          0,
          0,
          0,
          0x18,
          ...'ftypmp42'.codeUnits,
          ...List.filled(64, 0),
        ];
        final m4a = [
          0,
          0,
          0,
          0x18,
          ...'ftypM4A '.codeUnits,
          ...List.filled(64, 0),
        ];

        await expectLater(
          help.upload(file('zeros.mp4', List.filled(4096, 0))).last,
          refusedFor(HelpFailure.fileType),
        );
        await expectLater(
          help
              .upload(
                file('long.mp4', mp4, length: const Duration(seconds: 61)),
              )
              .last,
          refusedFor(HelpFailure.tooLong),
        );
        await expectLater(
          help
              .upload(file('note.m4a', m4a, length: const Duration(minutes: 6)))
              .last,
          refusedFor(HelpFailure.tooLong),
        );
        await expectLater(
          help
              .upload(file('big.png', [..._png, ...List.filled(10500000, 0)]))
              .last,
          refusedFor(HelpFailure.tooLarge),
        );

        final dropped = (await help.upload(file('drop.png', _png)).last).file;
        await help.discard(dropped);
        await expectLater(
          help.send(
            HelpRequest(
              subject: 'Chat with iQLY support',
              message: 'With a file I took back.',
              attachment: dropped,
            ),
          ),
          refusedFor(HelpFailure.gone),
        );
        await expectLater(
          help.send(
            HelpRequest(
              subject: 'Nowhere activation',
              message: 'About an activation that is not there.',
              activation: Activation(
                id: '00000000-0000-4000-8000-000000000000',
                business: 'Nowhere',
                title: 'Nothing',
                minutes: 1,
                rewardKobo: 0,
                closesAt: DateTime.now(),
                spotsLeft: 0,
                spotsTotal: 0,
                steps: const [],
                link: Uri.parse('https://iqly.net'),
              ),
            ),
          ),
          refusedFor(HelpFailure.gone),
        );

        HelpRefused? throttled;
        for (var i = 0; i < 12 && throttled == null; i++) {
          try {
            await help.upload(file('again.png', _png)).last;
          } on HelpRefused catch (refused) {
            throttled = refused;
          }
        }
        expect(throttled?.failure, HelpFailure.tooManyTries);
      });

      test('support files: a report sent again after a lost answer opens '
          'one thread with one upload; a voice note and a video open threads '
          'their owner alone can read', () async {
        if (!on(LiveFeature.support)) return;
        final losing = _LosingClient(http.Client());
        final chidi = await signedIn('chidi@example.com', via: losing);
        final help = LiveHelpService(
          linkOf(chidi),
          files: DeviceSupportFiles(),
        );

        final shot = file('payout.png', _png);
        final key = LocalRows.newId();
        losing.loseNextAnswer('POST', '/support/tickets');
        await expectLater(
          help.report(
            topic: 'Payments',
            details: 'A payout is missing here.',
            screenshot: shot,
            idempotencyKey: key,
          ),
          refusedFor(HelpFailure.offline),
        );
        final sent = await help.report(
          topic: 'Payments',
          details: 'A payout is missing here.',
          screenshot: shot,
          idempotencyKey: key,
        );
        final payments = (await help.conversations())
            .where((t) => t.subject == 'Payments')
            .toList();
        expect(payments.map((t) => t.reference), [sent]);
        final reported = await help.watch(payments.single.id).single;
        expect(reported.messages.single.attachments, hasLength(1));

        final m4a = [
          0,
          0,
          0,
          0x18,
          ...'ftypM4A '.codeUnits,
          ...List.filled(512, 0),
        ];
        final mp4 = [
          0,
          0,
          0,
          0x18,
          ...'ftypmp42'.codeUnits,
          ...List.filled(512, 0),
        ];
        final note =
            (await help
                    .upload(
                      file(
                        'voice.m4a',
                        m4a,
                        length: const Duration(seconds: 20),
                      ),
                    )
                    .last)
                .file;
        expect(note.kind, HelpAttachmentKind.audio);
        final voice = await help.send(
          HelpRequest(
            subject: 'Chat with iQLY support',
            message: 'A voice note.',
            attachment: note,
            idempotencyKey: LocalRows.newId(),
          ),
        );
        final heard = voice.messages.single.attachment!;
        expect(heard.kind, HelpAttachmentKind.audio);
        expect(heard.length, const Duration(seconds: 20));
        expect(heard.lengthLabel, '0:20');

        final clip =
            (await help
                    .upload(
                      file(
                        'clip.mp4',
                        mp4,
                        length: const Duration(seconds: 30),
                      ),
                    )
                    .last)
                .file;
        final video = await help.send(
          HelpRequest(
            subject: 'Chat with iQLY support',
            message: 'A recording.',
            attachment: clip,
            idempotencyKey: LocalRows.newId(),
          ),
        );
        final seen = video.messages.single.attachment!;
        expect(seen.kind, HelpAttachmentKind.video);
        final mine = await chidi.download(seen.url.toString());
        expect(mine.ok, isTrue);
        expect(mine.bytes, mp4);

        // Recordings play from a file downloaded once to the account's
        // folder, never streamed.
        final root = await Directory.systemTemp.createTemp('iqly-e2e-files');
        addTearDown(() => root.delete(recursive: true));
        final files = SignedInFiles(api: chidi, root: root);
        final saved = await files.fetch(
          userId: 'chidi',
          id: seen.id!,
          url: seen.url.toString(),
          name: seen.name,
        );
        expect(await saved.readAsBytes(), mp4);
        expect(
          (await files.fetch(
            userId: 'chidi',
            id: seen.id!,
            url: seen.url.toString(),
            name: seen.name,
          )).path,
          saved.path,
        );
        await expectLater(
          SignedInFiles(api: api, root: root).fetch(
            userId: 'ada',
            id: seen.id!,
            url: seen.url.toString(),
            name: seen.name,
          ),
          throwsA(isA<ApiRefused>().having((r) => r.status, 'status', 404)),
        );
        await files.forget('chidi');
        expect(await Directory('${root.path}/chidi').exists(), isFalse);
        expect(
          (await api.download(seen.url.toString())).status,
          404,
          reason: 'another person cannot read it',
        );
      });

      test('the business note on the entry and its result', () async {
        expect(
          container.read(businessNoteShownProvider),
          on(LiveFeature.businessNote),
        );
        final won = (await repository().submissions()).singleWhere(
          (s) => s.id == seed.wonId,
        );
        expect(won.note!.business, 'Sunline Foods');
        expect(won.note!.body, startsWith('The bus stop detail sold it.'));
        final others = (await repository().submissions()).where(
          (s) => s.id != seed.wonId,
        );
        expect(others.every((s) => s.note == null), isTrue);
        final result = await container
            .read(outcomesServiceProvider)
            .outcome(seed.wonId);
        expect(result!.note!.body, won.note!.body);
        expect(result.note!.sentAt, isNotNull);
      });

      test('referral rewards: the amounts, each reward and the person\'s own, '
          'the ledger rows and the feed rows', () async {
        await container.read(referralsProvider.future);
        final terms = container.read(referralTermsProvider);
        if (!on(LiveFeature.referralRewards)) {
          expect(terms, isNull);
          return;
        }
        expect(terms!.amountKobo, 50000);
        expect(terms.inviteeAmountKobo, 50000);
        expect(terms.inviterReward, '₦500');
        expect(terms.earnedKobo, 0);

        final mine = container.read(referralsServiceProvider);
        final applied = await mine.applyCode(seed.referralCode);
        expect(applied.outcome, InviteCodeOutcome.applied);
        final joined = await mine.referrals();
        expect(joined.invitedBy, 'Chidi E.');
        expect(
          joined.invitedByReward!.status,
          ReferralRewardStatus.notEligible,
          reason: 'Ada won before she added the code',
        );

        final chidi = await signedIn('chidi@example.com');
        final inviter = await LiveReferralsService(
          linkOf(chidi),
          sharing: DemoReferralsService(),
        ).referrals();
        expect(inviter.invites.map((i) => i.name), ['Ada O.', 'Bob A.']);
        final adaInvite = inviter.invites.first;
        expect(adaInvite.status, InviteStatus.won);
        expect(adaInvite.reward!.status, ReferralRewardStatus.notEligible);
        final bobInvite = inviter.invites.last;
        expect(bobInvite.name, 'Bob A.');
        expect(bobInvite.status, InviteStatus.won);
        expect(bobInvite.reward!.status, ReferralRewardStatus.paid);
        expect(bobInvite.reward!.amountKobo, 50000);
        expect(inviter.terms!.earnedKobo, 50000);
        final chidiFeed = await LiveNotificationsService(linkOf(chidi))
            .notifications();
        final reward = chidiFeed.singleWhere(
          (n) => n.facts?.type == 'referral_reward',
        );
        expect(reward.event, NotificationEvent.rewardCredited);
        expect(reward.entryId, bobInvite.reward!.ledgerId);
        final rewardWords = wordNotification(
          reward,
          briefs: const {},
          awards: const {},
          withdrawals: const {},
          now: DateTime.now(),
        )!;
        expect(rewardWords.title, '₦500.00 added to your wallet');
        expect(rewardWords.detail, startsWith('Bob A. won a first brief'));
        expect(rewardWords.link!.location, Routes.referralHistory);

        final bob = await signedIn('bob@example.com');
        final invited = await LiveReferralsService(
          linkOf(bob),
          sharing: DemoReferralsService(),
        ).referrals();
        expect(invited.invitedBy, 'Chidi E.');
        expect(invited.invitedByReward!.status, ReferralRewardStatus.paid);
        expect(invited.invitedByReward!.amountKobo, 50000);
        final rows = (await bob.get('/wallet/transactions?limit=100')).data;
        final own = [
          for (final item in rows['items'] as List) ?ledgerEntryFromJson(item),
        ].singleWhere((l) => l.id == invited.invitedByReward!.ledgerId);
        expect(own.source, RewardSource.referral);
        expect(own.amountKobo, 50000);
        expect(own.note, 'First win with Chidi E.\'s invite code');
        expect(own.referred, 'Chidi E.');
      });

      test(
        'avatar photo: up, replaced, read with the token, deleted',
        () async {
          final avatars = container.read(liveAvatarServiceProvider)!;
          expect(avatars.photos, on(LiveFeature.avatarPhoto));
          if (!on(LiveFeature.avatarPhoto)) return;

          final first = (await avatars.uploadPhoto(_png))!;
          expect(first.photoShown, isTrue);
          expect(first.photoUrl, contains('/me/avatar/photo?v='));
          expect(first.spec, IqPhotoAvatar(_png));
          expect(await avatars.photo(first.photoUrl!), _png);

          await Future<void>.delayed(const Duration(milliseconds: 5));
          final second = (await avatars.uploadPhoto(_otherPng))!;
          expect(second.photoUrl, isNot(first.photoUrl));
          expect(await avatars.photo(second.photoUrl!), _otherPng);
          expect((await account().me()).avatar!['photoUrl'], second.photoUrl);

          final gone = (await avatars.deletePhoto())!;
          expect(gone.photoUrl, isNull);
          expect(gone.photoShown, isFalse);
          expect(gone.spec, isA<IqPersonAvatar>());
          expect(await avatars.photo(second.photoUrl!), isNull);

          final chidi = LiveAvatarService(
            linkOf(await signedIn('chidi@example.com')),
            photos: true,
          );
          Matcher refused(String code) =>
              throwsA(isA<ApiRefused>().having((r) => r.code, 'code', code));
          await expectLater(
            chidi.uploadPhoto(Uint8List.fromList(utf8.encode('<html></html>'))),
            refused('FILE_TYPE_NOT_ALLOWED'),
          );
          await expectLater(
            chidi.uploadPhoto(
              Uint8List.fromList([..._png, ...List.filled(2100000, 0)]),
            ),
            refused('FILE_TOO_LARGE'),
          );
        },
      );

      test('close waits for an empty wallet; restore reopens', () async {
        final profile = container.read(profileServiceProvider);
        final wallet = container.read(walletServiceProvider);
        Matcher refused(String code) =>
            throwsA(isA<ApiRefused>().having((r) => r.code, 'code', code));

        await expectLater(
          profile.deleteAccount(),
          refused('ACCOUNT_HAS_BALANCE'),
        );
        final left = (await repository().walletTotals())!.withdrawableKobo;
        expect(
          left,
          7500000 + (eleven ? 150000 : 0),
          reason: 'the activation reward is in',
        );
        final rest = await wallet.withdraw(amountKobo: left, account: payTo);
        expect(rest.ok, isTrue, reason: '${rest.failure}');
        await expectLater(
          profile.deleteAccount(),
          refused('WITHDRAWAL_IN_FLIGHT'),
        );
        await tools.post('/__local/withdrawals/${rest.withdrawal!.id}/settle');
        expect((await repository().walletTotals())!.withdrawableKobo, 0);

        await profile.deleteAccount();
        final ended = api.unauthorized.first;
        await expectLater(
          account().me(),
          throwsA(isA<ApiRefused>().having((r) => r.status, 'status', 401)),
        );
        await ended.timeout(const Duration(seconds: 5));

        final again = await container
            .read(authServiceProvider)
            .signIn(email: seed.email, password: seed.password);
        expect(again.ok, isTrue, reason: '${again.failure}');
        final closing = await account().me();
        expect(closing.closing, isTrue);
        expect(
          closing.closesAt!.difference(DateTime.now()).inHours,
          inInclusiveRange(30 * 24 - 1, 30 * 24),
        );

        // A vote or a Start while closing is turned down as closing.
        if (eleven) {
          expect(
            await container
                .read(pollsProvider.notifier)
                .vote(seed.kioskPoll, 1),
            VoteOutcome.closing,
          );
          await expectLater(
            container.read(activationsServiceProvider).start(seed.order),
            refusedWith('ACCOUNT_CLOSING'),
          );
        }
        if (on(LiveFeature.support)) {
          await expectLater(
            container.read(helpServiceProvider).resolve(opened.id),
            refusedFor(HelpFailure.closing),
          );
        }

        // A write while closing holds the queue until the account is back.
        await profile.setNotificationPreference(NotificationTopic.polls, true);
        await outbox.kick();
        expect(outbox.state.pause, OutboxPause.closing);
        expect(outbox.state.pending, 1);

        await profile.restoreAccount();
        await drain();
        final restored = await account().me();
        expect(restored.closing, isFalse);
        expect(restored.closesAt, isNull);
        final prefs = await LiveProfileService(
          container.read(accountLinkProvider)!,
        ).notificationPreferences();
        expect(prefs[NotificationTopic.polls], isTrue);
        expect(prefs[NotificationTopic.payouts], isFalse);
      });

      test('sign out ends the session on the API', () async {
        final held = await tokens.read();
        expect(held, isNotNull);
        await container.read(authServiceProvider).signOut();
        expect(await tokens.read(), isNull);

        await tokens.write(held!);
        final ended = api.unauthorized.first;
        await expectLater(
          account().me(),
          throwsA(isA<ApiRefused>().having((r) => r.status, 'status', 401)),
        );
        await ended.timeout(const Duration(seconds: 5));
      });
    },
  );

  _contract13(base);
  _contract13Off(Platform.environment['IQLY_E2E_API_S13_OFF']);
  _rules19OctOn(base);
  _rules19OctOff(Platform.environment['IQLY_E2E_API_GATES_OFF']);
  final offApi = Platform.environment['IQLY_E2E_API_OFF'];

  group(
    'Polls and activations switched off on the API',
    skip: offApi == null
        ? 'Set IQLY_E2E_API_OFF to a local API started with '
              'MOBILE_FEATURES_OFF=polls,activations to run'
        : false,
    () {
      test('health leaves them out: hidden, paused, never asked', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final asked = <String>[];
        final api = ApiClient(
          tokens: MemoryTokenStore(),
          client: _Watching(http.Client(), asked),
          baseUrl: offApi!,
          appVersion: '0.5.0+5',
          platform: 'android',
        );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(api),
            localStoreProvider.overrideWithValue(MemoryLocalStore()),
            healthServiceProvider.overrideWithValue(LiveHealthService(api)),
            backendProvider.overrideWith(
              () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
            ),
            authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
          ],
        );
        addTearDown(container.dispose);

        final report = await LiveHealthService(api).check();
        expect(report.ready, isTrue);
        expect(report.features, isNot(contains(LiveFeature.polls)));
        expect(report.features, isNot(contains(LiveFeature.activations)));
        expect(report.features, contains(LiveFeature.wallet));
        await container.read(backendProvider.notifier).check();
        await container.read(backendProvider.notifier).lock();
        final mode = container.read(liveModeProvider);
        expect(mode.isPreview, isFalse);
        expect(mode.isLive(LiveFeature.briefs), isTrue);
        expect(mode.isLive(LiveFeature.polls), isFalse);
        expect(mode.isLive(LiveFeature.activations), isFalse);

        expect(container.read(pollsShownProvider), isFalse);
        expect(container.read(activationsShownProvider), isFalse);
        for (final path in [
          Routes.polls,
          pollsOf('org_sunline'),
          Routes.activations,
          myActivationsPath,
          proofPath('a_1'),
        ]) {
          expect(hiddenRoute(container.read, path), isTrue, reason: path);
        }
        expect(container.read(pollsServiceProvider), isA<PausedPollsService>());
        expect(
          container.read(activationsServiceProvider),
          isA<PausedActivationsService>(),
        );
        await expectLater(
          container.read(pollsProvider.future),
          throwsA(isA<FeaturePaused>()),
        );
        await expectLater(
          container.read(activationsProvider.future),
          throwsA(isA<FeaturePaused>()),
        );
        final inputs = await surfaceInputs(container.read, DateTime.now());
        expect(inputs.showPolls, isFalse);
        expect(inputs.polls, isEmpty);
        expect(asked, contains('/health'));
        expect(
          asked.where(
            (p) => p.startsWith('/polls') || p.startsWith('/activations'),
          ),
          isEmpty,
        );
      });
    },
  );
}

/// Paragraphs, and a list typed with single line breaks.
const _typedAnswer =
    'I cook noodles three nights a week: they are ready in five minutes '
    '& nobody argues.\n\n'
    'What would get me to switch:\n'
    '1. A bigger pack for the same price\n'
    '2. A free sample at my market';

/// A 1×1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP49eYSAAWcArlITY1UAAAAAElFTkSuQmCC',
);

/// A 2×2 PNG, another photo.
final _otherPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGP4n8YARAwQCgArFgWVjjyH6QAAAABJRU5ErkJggg==',
);

/// What POST /__local/seed answers: who and what the walk works with.
class _Seed {
  _Seed(Map<String, dynamic> json)
    : password = json['password'] as String,
      contributorId = _at(json, ['people', 'contributor', 'id']),
      email = _at(json, ['people', 'contributor', 'email']),
      liveBriefId = _at(json, ['briefs', 'live', 'id']),
      hiddenBriefId = _at(json, ['briefs', 'hidden', 'id']),
      closedBriefId = _at(json, ['briefs', 'closed', 'id']),
      wonId = _at(json, ['submissions', 'won']),
      withdrawalId = _at(json, ['withdrawal', 'id']),
      ownerEmail = _at(json, ['people', 'owner', 'email']),
      otherEmail = _at(json, ['people', 'other', 'email']),
      flavourPoll = _at(json, ['polls', 'flavour']),
      canSizePoll = _at(json, ['polls', 'canSize']),
      kioskPoll = _at(json, ['polls', 'kiosk']),
      closedPoll = _at(json, ['polls', 'closed']),
      recipes = _at(json, ['activations', 'recipes']),
      account = _at(json, ['activations', 'account']),
      order = _at(json, ['activations', 'order']),
      paused = _at(json, ['activations', 'paused']),
      closedActivation = _at(json, ['activations', 'closed']),
      referralCode = json['referralCode'] as String;

  final String password;
  final String contributorId;
  final String email;
  final String liveBriefId;
  final String hiddenBriefId;
  final String closedBriefId;
  final String wonId;

  /// Paid out to Access Bank ••6789 before the walk.
  final String withdrawalId;

  /// Tola Bakare, who runs Sunline Foods and Harbour Telecom, and Bob Ade.
  final String ownerEmail;
  final String otherEmail;

  /// Contract 11.1 polls: flavour and can size open and not voted, kiosk
  /// voted 7 am, noodles closed and voted.
  final String flavourPoll;
  final String canSizePoll;
  final String kioskPoll;
  final String closedPoll;

  /// Contract 11.2 activations as Ada has them: recipes an offer, account
  /// past its window at step 2, order with proof waiting, paused with no
  /// run, closed with her run ended.
  final String recipes;
  final String account;
  final String order;
  final String paused;
  final String closedActivation;

  /// Chidi's invite code, which Bob added before his first win.
  final String referralCode;

  static String _at(Map<String, dynamic> json, List<String> path) {
    Object? value = json;
    for (final key in path) {
      value = (value as Map<String, dynamic>)[key];
    }
    return value as String;
  }
}

/// The local API's own tools, beside the API the app calls.
class _LocalTools {
  _LocalTools(this.base);

  final String base;

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, Object?> body = const {},
  ]) async {
    final res = await http
        .post(
          Uri.parse('$base$path'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(minutes: 1));
    if (res.statusCode != 200) {
      fail('$path answered ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['data'] as Map<String, dynamic>;
  }
}

/// A connection that notes the path of every request it sends.
class _Watching extends http.BaseClient {
  _Watching(this._inner, this.paths);

  final http.Client _inner;
  final List<String> paths;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    paths.add(request.url.path);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// A connection that drops the API's answer to a request the API took, so
/// the app's retry has to be answered with what the first send made.
class _LosingClient extends http.BaseClient {
  _LosingClient(this._inner);

  final http.Client _inner;
  final _losing = <String>{};

  void loseNextAnswer(String method, String path) =>
      _losing.add('$method $path');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (!_losing.remove('${request.method} ${request.url.path}')) {
      return response;
    }
    await response.stream.drain<void>();
    throw http.ClientException('The connection dropped', request.url);
  }

  @override
  void close() => _inner.close();
}

/// The section 13 features, each its own /health switch.
const _section13 = {
  LiveFeature.withdrawalPin,
  LiveFeature.phoneVerification,
  LiveFeature.savedBriefsSync,
  LiveFeature.closeRemindersSync,
  LiveFeature.uploads,
  LiveFeature.etags,
  LiveFeature.config,
};

/// One request as the API answered it.
typedef _Seen = ({
  String method,
  String path,
  int status,
  String? ifNoneMatch,
  String? body,
});

/// A connection that keeps what each request got, and fails the routes in
/// [offline] as a dropped connection does before anything is sent.
class _Recording extends http.BaseClient {
  _Recording(this._inner);

  final http.Client _inner;
  final seen = <_Seen>[];
  final offline = <String>{};

  List<_Seen> to(String method, String path) => [
    for (final s in seen)
      if (s.method == method && s.path == path) s,
  ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final route = '${request.method} ${request.url.path}';
    if (offline.contains(route)) {
      throw const SocketException('Connection failed (offline)');
    }
    final response = await _inner.send(request);
    seen.add((
      method: request.method,
      path: request.url.path,
      status: response.statusCode,
      ifNoneMatch: request.headers['if-none-match'],
      body: request is http.Request ? request.body : null,
    ));
    return response;
  }

  @override
  void close() => _inner.close();
}

/// A person of the seed signed in through the app's own auth on their own
/// client: the PIN, phone and upload services take it as they are.
Future<ApiClient> _signedIn(
  String base,
  String email,
  String password, {
  http.Client? client,
}) async {
  final api = ApiClient(
    tokens: MemoryTokenStore(),
    client: client ?? http.Client(),
    baseUrl: base,
    appVersion: '0.5.0+5',
    platform: 'android',
  );
  final result = await LiveAuthService(api: api)
      .signIn(email: email, password: password);
  expect(result.ok, isTrue, reason: '$email: ${result.failure}');
  return api;
}

/// The newest code the local API emailed to [email] for [type], from its
/// log (docs/local-api.md: every email is an `[email]` line).
Future<String> _emailedCode(String log, String type, String email) async {
  final lines = await File(log).readAsLines();
  final code = RegExp('\\[email\\] $type to ${RegExp.escape(email)}: (\\d{6})');
  for (final line in lines.reversed) {
    final match = code.firstMatch(line);
    if (match != null) return match[1]!;
  }
  fail('No $type code for $email in $log');
}

Future<void> _sql(String db, String statement) async {
  final result = await Process.run('psql', [db, '-c', statement]);
  if (result.exitCode != 0) fail('psql: ${result.stderr}');
}

void _contract13(String? base) {
  final log = Platform.environment['IQLY_E2E_API_LOG'];
  final db = Platform.environment['IQLY_E2E_DB'];
  group(
    'Contract 13 on the API',
    skip: base == null ? 'Set IQLY_E2E_API to the local API to run' : false,
    () {
      late _LocalTools tools;
      late Map<String, dynamic> seeded;
      late _Seed seed;
      late _Recording client;
      late ApiClient api;
      late MemoryLocalStore store;
      late ProviderContainer container;
      late Outbox outbox;

      String at(List<String> path) {
        Object? value = seeded;
        for (final key in path) {
          value = (value as Map<String, dynamic>)[key];
        }
        return value as String;
      }

      setUpAll(() async {
        tools = _LocalTools(base!);
        seeded = await tools.post('/__local/seed');
        seed = _Seed(seeded);
        SharedPreferences.resetStatic();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        client = _Recording(http.Client());
        api = ApiClient(
          tokens: MemoryTokenStore(),
          client: client,
          baseUrl: base,
          appVersion: '0.5.0+5',
          platform: 'android',
        );
        store = MemoryLocalStore();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(api),
            localStoreProvider.overrideWithValue(store),
            healthServiceProvider.overrideWithValue(LiveHealthService(api)),
            backendProvider.overrideWith(
              () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
            ),
            authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
          ],
        );
        startAccountSync(container);
        container.listen(appConfigProvider, (_, _) {});
        outbox = container.read(outboxProvider);
      });

      tearDownAll(() {
        container.dispose();
        client.close();
        AppConfig.current = AppConfig.defaults;
      });

      Future<void> drain() async {
        await outbox.kick();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await outbox.kick();
      }

      LiveRepository repository() =>
          container.read(repositoryProvider) as LiveRepository;

      test('health turns every section 13 feature on, and GET /config '
          'feeds the numbers the app shipped with', () async {
        final report = await LiveHealthService(api).check();
        expect(report.features, containsAll(_section13));
        await container.read(backendProvider.notifier).check();
        await container.read(backendProvider.notifier).lock();
        final mode = container.read(liveModeProvider);
        for (final f in _section13) {
          expect(mode.isLive(f), isTrue, reason: f.name);
        }

        await container.read(appConfigProvider.notifier).refresh();
        expect(client.to('GET', '/config').single.status, 200);
        final config = container.read(appConfigProvider);
        expect(config.supportEmail, 'support@iqly.net');
        expect(config.supportMessageMaxChars, 1000);
        expect(config.withdrawalMaximumKobo, isNull);
        expect(minimumWithdrawalKobo, 100000);
        expect(referralReward(), '₦500');
        expect(SubmitLimits.files, 5);
        expect(SubmitLimits.totalBytes, 30 * 1024 * 1024);
        expect(config.phoneResendAfterSeconds, 45);
        expect(config.closeReminderOffsets, [60]);
        expect(config.proofVideoMaxSeconds, 60);
      });

      test('Ada signs in', () async {
        final result = await container
            .read(authServiceProvider)
            .signIn(email: seed.email, password: seed.password);
        expect(result.ok, isTrue);
        final session = container.read(sessionProvider.notifier);
        await session.setUserId(result.userId);
        await session.setSignedIn(true);
        await session.setName(result.name);
        await session.setOnboardingDone(true);
        await outbox.start(seed.contributorId);
      });

      test('ETags: each tagged read sends the tag it kept, and a 304 answers '
          'the copy kept for this account', () async {
        final repo = repository();
        final wallet = await repo.walletTotals(allowCache: false);
        final again = await repo.walletTotals(allowCache: false);
        final reads = client.to('GET', '/wallet');
        expect(reads.first.ifNoneMatch, isNull);
        expect(reads.last.ifNoneMatch, isNotNull);
        expect(reads.last.status, 304);
        expect(again!.withdrawableKobo, wallet!.withdrawableKobo);

        final briefs = await repo.briefs(load: BriefsLoad.refresh);
        final briefsAgain = await repo.briefs(load: BriefsLoad.refresh);
        expect(client.to('GET', '/challenges/browse').last.status, 304);
        expect(
          [for (final b in briefsAgain) b.id],
          [for (final b in briefs) b.id],
        );
        for (final read in [
          () => repo.submissions(),
          () => repo.ledger(allowCache: false),
          () => repo.pointsLeaderboard(),
          () => repo.brief(seed.liveBriefId),
          () => container.read(notificationsServiceProvider).notifications(),
          () => container.read(referralsServiceProvider).referrals(),
        ]) {
          await read();
          await read();
        }
        for (final path in [
          '/submissions/mine',
          '/wallet/transactions',
          '/leaderboard',
          '/challenges/${seed.liveBriefId}',
          '/notifications',
          '/me/referrals',
        ]) {
          final last = client.to('GET', path).last;
          expect(last.ifNoneMatch, isNotNull, reason: path);
          expect(last.status, 304, reason: path);
        }
        final withdrawals = client.to('GET', '/wallet/withdrawals');
        expect(
          withdrawals.every((s) => s.ifNoneMatch == null),
          isTrue,
          reason: 'not a tagged read',
        );
      });

      test('saved briefs: pulled at sign-in, changes go through the outbox, '
          'a removal made elsewhere wins, a change not sent wins until it '
          'goes, and a brief that is not one is refused', () async {
        final saved = container.read(savedBriefsProvider.notifier);
        await container.read(savedBriefsProvider.future);
        await saved.pull();
        expect(
          [for (final b in container.read(savedBriefsProvider).value!) b.id],
          [seed.liveBriefId, seed.hiddenBriefId],
        );

        final hidden = container
            .read(savedBriefsProvider)
            .value!
            .firstWhere((b) => b.id == seed.hiddenBriefId);
        await saved.setSaved(hidden, false);
        await drain();
        final listed = await api.get('/me/saved-briefs');
        expect(
          [for (final i in listed.data['items'] as List) i['challengeId']],
          [seed.liveBriefId],
        );

        final elsewhere = await api.delete(
          '/me/saved-briefs/${seed.liveBriefId}',
        );
        expect(elsewhere.status, 204);
        await saved.pull();
        expect(container.read(savedBriefsProvider).value, isEmpty);

        await outbox.stop();
        await saved.setSaved(hidden, true);
        await saved.pull();
        expect(
          [for (final b in container.read(savedBriefsProvider).value!) b.id],
          [seed.hiddenBriefId],
          reason: 'not sent yet, so it wins over the pull',
        );
        await outbox.start(seed.contributorId);
        await drain();
        final after = await api.get('/me/saved-briefs');
        expect(
          [for (final i in after.data['items'] as List) i['challengeId']],
          [seed.hiddenBriefId],
        );

        final sync = container.read(briefMarksSyncProvider(BriefMark.saved))!;
        await sync.set('no-such-brief', true);
        await drain();
        final failed = (await store.outbox(seed.contributorId))
            .where((i) => i.status == OutboxStatus.failed);
        expect(failed.single.lastErrorCode, 'CHALLENGE_NOT_FOUND');
        await outbox.discard(failed.single.id);
      });

      test('close reminders: the seeded one is pulled, a new one sends its '
          'minutes, and one on a closed brief is refused and pulled '
          'away', () async {
        final reminders = container.read(closeRemindersProvider.notifier);
        await container.read(closeRemindersProvider.future);
        await reminders.pull();
        expect(container.read(closeRemindersProvider).value, {
          seed.liveBriefId,
        });
        await reminders.setReminder(seed.hiddenBriefId, true);
        await reminders.setReminder(seed.liveBriefId, false);
        await drain();
        final listed = await api.get('/me/close-reminders');
        final items = listed.data['items'] as List;
        expect([for (final i in items) i['challengeId']], [seed.hiddenBriefId]);
        expect(items.single['offsetsMinutes'], [60]);
        expect(items.single['closesAt'], isNotNull);

        await reminders.setReminder(seed.closedBriefId, true);
        await drain();
        final failed = (await store.outbox(seed.contributorId))
            .where((i) => i.status == OutboxStatus.failed);
        expect(failed.single.lastErrorCode, 'CLOSE_REMINDER_BRIEF_CLOSED');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(container.read(closeRemindersProvider).value, {
          seed.hiddenBriefId,
        });
        await outbox.discard(failed.single.id);
      });

      test('the first sync on a phone sends the marks kept only on it '
          'before a pull can drop them', () async {
        final prefs = container.read(sharedPreferencesProvider);
        final closed = (await repository().brief(seed.closedBriefId))!;
        final kept = [closed, ...container.read(savedBriefsProvider).value!];
        await prefs.setString(
          SavedBriefsNotifier.key,
          jsonEncode([for (final b in kept) b.toJson()]),
        );
        await prefs.setStringList(CloseRemindersNotifier.key, [
          seed.liveBriefId,
          ...container.read(closeRemindersProvider).value!,
        ]);
        for (final mark in BriefMark.values) {
          await prefs.remove(
            container
                .read(briefMarksSyncProvider(mark))!
                .adoptedKey(seed.contributorId),
          );
        }
        container
          ..invalidate(savedBriefsProvider)
          ..invalidate(closeRemindersProvider);
        await container.read(savedBriefsProvider.future);
        await container.read(closeRemindersProvider.future);
        await container.read(savedBriefsProvider.notifier).pull();
        await container.read(closeRemindersProvider.notifier).pull();
        await drain();

        final saved = await api.get('/me/saved-briefs');
        expect([
          for (final i in saved.data['items'] as List) i['challengeId'],
        ], contains(seed.closedBriefId));
        expect([
          for (final b in container.read(savedBriefsProvider).value!) b.id,
        ], contains(seed.closedBriefId));
        final reminders = await api.get('/me/close-reminders');
        expect([
          for (final i in reminders.data['items'] as List) i['challengeId'],
        ], containsAll([seed.liveBriefId, seed.hiddenBriefId]));
        expect(
          container.read(closeRemindersProvider).value,
          containsAll([seed.liveBriefId, seed.hiddenBriefId]),
        );
        expect(
          prefs.getBool(
            container
                .read(briefMarksSyncProvider(BriefMark.saved))!
                .adoptedKey(seed.contributorId),
          ),
          isTrue,
        );
      });

      test('phone codes: the verified number, a new one by SMS, each '
          'refusal, and a different number saved clears the check', () async {
        final phones = container.read(phoneServiceProvider)!;
        final before = await phones.status();
        expect(before.verified, isTrue);
        expect(before.phone, '+2348031234567');
        expect(
          (await container.read(profileServiceProvider).accountDetails())
              .phoneVerified,
          isTrue,
        );
        Future<PhoneRefused> refusal(Future<Object?> call) async {
          try {
            await call;
          } on PhoneRefused catch (refused) {
            return refused;
          }
          fail('taken');
        }

        expect(
          (await refusal(phones.sendCode())).problem,
          PhoneProblem.alreadyVerified,
        );
        expect(
          (await refusal(phones.sendCode('0703 12'))).problem,
          PhoneProblem.invalid,
        );
        // The seed confirmed Ada's number through the same SMS limits, so
        // the first new code may have to wait out the person's window.
        PhoneCodeSent sent;
        try {
          sent = await phones.sendCode('0803 555 0101');
        } on PhoneRefused catch (refused) {
          expect(refused.problem, PhoneProblem.rateLimited);
          await Future<void>.delayed(
            refused.retryAfter! + const Duration(seconds: 1),
          );
          sent = await phones.sendCode('0803 555 0101');
        }
        expect(sent.to, '+2348035550101');
        expect(sent.resendAt, isNotNull);
        final limited = await refusal(phones.sendCode('0803 555 0101'));
        expect(limited.problem, PhoneProblem.rateLimited);
        expect(limited.retryAfter, isNotNull);

        final texts = await http.get(
          Uri.parse('$base/__local/sms?to=08035550101'),
        );
        final sms = (jsonDecode(texts.body)['data']['items'] as List).first;
        final code = (sms as Map)['code'] as String;
        final wrong = await refusal(
          phones.verify(code == '000000' ? '111111' : '000000'),
        );
        expect(wrong.problem, PhoneProblem.codeInvalid);
        expect(wrong.attemptsLeft, 4);
        final verified = await phones.verify(code);
        expect(verified.verified, isTrue);
        expect(verified.phone, '+2348035550101');
        expect(
          (await refusal(phones.verify(code))).problem,
          PhoneProblem.codeExpired,
          reason: 'a code works once',
        );
        final details = await container
            .read(profileServiceProvider)
            .accountDetails();
        expect(details.phone, '+2348035550101');
        expect(details.phoneVerified, isTrue);

        await container
            .read(profileServiceProvider)
            .saveDetails(
              details.copyWith(phone: '+2348035550102'),
              container.read(profileAnswersProvider),
              before: details,
              answersBefore: container.read(profileAnswersProvider),
            );
        await drain();
        final changed = await container
            .read(profileServiceProvider)
            .accountDetails();
        expect(changed.phone, '+2348035550102');
        expect(changed.phoneVerified, isFalse);
      }, timeout: const Timeout(Duration(minutes: 2)));

      test(
        'uploads: one goes up and is dropped, each refusal maps, and an '
        'entry sent offline is queued, then goes once with its upload',
        () async {
          final uploads = container.read(submissionUploadsProvider)!;
          AttachmentFile file(String name, List<int> bytes) => AttachmentFile(
            name: name,
            bytes: bytes.length,
            read: () async => bytes,
          );
          final kept = await uploads.upload(
            file('kiosk.png', _png),
            briefId: seed.liveBriefId,
          );
          expect(kept.expiresAt, isNotNull);
          final dropped = await uploads.upload(file('drop.png', _png));
          await uploads.drop(dropped.id);
          expect(
            (await api.get('/submissions/uploads/${dropped.id}')).code,
            'SUBMISSION_UPLOAD_NOT_FOUND',
          );
          Future<UploadProblem> problem(AttachmentFile f) async {
            try {
              await uploads.upload(f, briefId: seed.liveBriefId);
            } on UploadRefused catch (refused) {
              return refused.problem;
            }
            fail('${f.name} was taken');
          }

          expect(
            await problem(file('notes.txt', utf8.encode('plain words'))),
            UploadProblem.fileType,
          );
          expect(
            await problem(file('fake.png', utf8.encode('not a png at all'))),
            UploadProblem.fileType,
          );
          expect(
            await problem(
              file('big.png', [..._png, ...List.filled(11 << 20, 0)]),
            ),
            UploadProblem.tooLarge,
          );

          final service = container.read(submitServiceProvider);
          await service.open(seed.liveBriefId);
          client.offline.add(
            'POST /submissions/challenges/${seed.liveBriefId}',
          );
          final request = SubmitRequest(
            briefId: seed.liveBriefId,
            title: 'Noodles on a weeknight',
            answer: _typedAnswer,
            answers: const {
              'q1': ['Indomie'],
              'q2': ['A free sample'],
            },
            uploadIds: [
              kept.id,
              at(['upload']),
            ],
          );
          final queued = await service.submit(request);
          expect(queued.queued, isTrue);
          final waiting = (await store.outbox(seed.contributorId)).single;
          expect(waiting.kind, submitKind);

          client.offline.clear();
          await outbox.networkBack();
          await drain();
          expect(await store.outbox(seed.contributorId), isEmpty);
          final mine = await api.get(
            '/submissions/mine/by-challenge/${seed.liveBriefId}',
          );
          final submissionId = mine.data['id'] as String;
          final entry = await api.get('/submissions/$submissionId');
          expect(entry.data['files'], hasLength(2));

          final replay = await service.submit(request);
          expect(replay.block, SubmitBlock.alreadySubmitted);
          expect(
            client
                .to('POST', '/submissions/challenges/${seed.liveBriefId}')
                .where((s) => s.status == 201),
            hasLength(1),
            reason: 'one entry',
          );

          await service.open(seed.hiddenBriefId);
          final gone = await service.submit(
            SubmitRequest(
              briefId: seed.hiddenBriefId,
              title: 'Data that lasts',
              answer: _typedAnswer,
              uploadIds: [dropped.id],
            ),
          );
          expect(gone.failure, SubmitFailure.uploadsGone);
          final inUse = await service.submit(
            SubmitRequest(
              briefId: seed.hiddenBriefId,
              title: 'Data that lasts',
              answer: _typedAnswer,
              uploadIds: [kept.id],
            ),
          );
          expect(inUse.failure, isNotNull);
          expect(
            client
                .to('POST', '/submissions/challenges/${seed.hiddenBriefId}')
                .map((s) => s.status),
            containsAll([404, 409]),
          );
          for (final item in await store.outbox(seed.contributorId)) {
            await outbox.discard(item.id);
          }

          final limits = <UploadProblem>{};
          for (
            var i = 0;
            i < 40 && !limits.contains(UploadProblem.limit);
            i++
          ) {
            try {
              await uploads.upload(file('many-$i.png', _png));
            } on UploadRefused catch (refused) {
              limits.add(refused.problem);
              if (refused.problem == UploadProblem.rateLimited) {
                await Future<void>.delayed(const Duration(seconds: 61));
              }
            }
          }
          expect(limits, contains(UploadProblem.rateLimited));
          expect(limits, contains(UploadProblem.limit));
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );

      test('the withdrawal PIN: Bob withdraws with it, wrong PINs count, '
          'five lock it, a reset by emailed code opens it, and the third '
          'lock needs the reset', () async {
        final losing = _LosingClient(http.Client());
        final bob = await _signedIn(
          base!,
          at(['pin', 'email']),
          seed.password,
          client: losing,
        );
        final pins = PinService(bob);
        final wallet = LiveWalletService(bob, bankAccounts: true);
        const account = SavedBank(
          bankCode: '058',
          bankName: 'Guaranty Trust Bank',
          accountName: 'BOB ADE',
          accountNumber: '••7890',
        );
        Future<PinRefused> refusal(Future<Object?> call) async {
          try {
            await call;
          } on PinRefused catch (refused) {
            return refused;
          }
          fail('taken');
        }

        final pin = at(['pin', 'pin']);
        final status = await pins.status();
        expect(status.set, isTrue);
        expect(status.attemptsLeft, 5);
        final without = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
        );
        expect(without.pin!.problem, PinProblem.required);
        final wrongWithdraw = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
          pin: '0000',
        );
        expect(wrongWithdraw.pin!.problem, PinProblem.incorrect);
        expect(wrongWithdraw.pin!.attemptsLeft, 4);
        await pins.verify(pin);
        final made = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
          pin: pin,
        );
        expect(made.withdrawal, isNotNull);
        expect((await pins.status()).attemptsLeft, 5);

        Future<int> count() async =>
            ((await bob.get('/wallet/withdrawals')).data['items'] as List)
                .length;
        final before = await count();
        losing.loseNextAnswer('POST', '/wallet/withdrawals');
        final lost = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
          pin: pin,
        );
        expect(lost.unsettled, isTrue);
        final again = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
        );
        expect(again.withdrawal, isNotNull, reason: '${again.failure}');
        expect(again.earlier, isTrue);
        expect(await count(), before + 1, reason: 'one key, one withdrawal');

        expect(
          (await refusal(pins.change('0000', '1357'))).problem,
          PinProblem.incorrect,
        );
        await pins.change(pin, '1357');
        await pins.verify('1357');
        PinRefused? last;
        for (var i = 0; i < 5; i++) {
          last = await refusal(pins.verify('0000'));
        }
        expect(last!.problem, PinProblem.locked);
        expect(last.retryAfter, isNotNull);
        expect(
          (await refusal(pins.verify('1357'))).problem,
          PinProblem.locked,
          reason: 'the right PIN is refused while locked',
        );
        final lockedStatus = await pins.status();
        expect(lockedStatus.locked, isTrue);
        expect(lockedStatus.lockedUntil, isNotNull);

        if (log == null || db == null) {
          markTestSkipped(
            'Set IQLY_E2E_API_LOG and IQLY_E2E_DB for the reset by code',
          );
          return;
        }
        await pins.sendCode();
        expect(
          (await refusal(pins.sendCode())).problem,
          PinProblem.rateLimited,
        );
        final code = await _emailedCode(
          log,
          'withdrawal_pin_code',
          at(['pin', 'email']),
        );
        final wrongCode = await refusal(
          pins.reset(code == '000000' ? '111111' : '000000', '2468'),
        );
        expect(wrongCode.problem, PinProblem.codeInvalid);
        expect(wrongCode.attemptsLeft, isNotNull);
        final reset = await pins.reset(code, '2468');
        expect(reset.locked, isFalse);
        await pins.verify('2468');
        expect(
          (await refusal(pins.reset(code, '1111'))).problem,
          PinProblem.codeExpired,
          reason: 'a code works once',
        );

        final bobId = at(['people', 'other', 'id']);
        await _sql(
          db,
          "update withdrawal_pins set lock_count = 2 where user_id = '$bobId'",
        );
        for (var i = 0; i < 5; i++) {
          last = await refusal(pins.verify('0000'));
        }
        expect(
          (await refusal(pins.verify('2468'))).problem,
          PinProblem.resetRequired,
        );
        expect((await pins.status()).resetRequired, isTrue);
        // Withdrawals are limited to 5 a minute per person.
        await Future<void>.delayed(const Duration(seconds: 61));
        final blocked = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
          pin: '2468',
        );
        expect(blocked.pin!.problem, PinProblem.resetRequired);
      }, timeout: const Timeout(Duration(minutes: 4)));

      test(
        'a first PIN with the password; a wrong password is refused',
        () async {
          final pins = container.read(pinServiceProvider)!;
          expect((await pins.status()).set, isFalse);
          await expectLater(
            pins.create('2468', password: 'not-the-password'),
            throwsA(
              isA<PinRefused>().having(
                (r) => r.problem,
                'problem',
                PinProblem.passwordIncorrect,
              ),
            ),
          );
          final created = await pins.create('2468', password: seed.password);
          expect(created.set, isTrue);
          await expectLater(
            pins.create('1357', password: seed.password),
            throwsA(
              isA<PinRefused>().having(
                (r) => r.problem,
                'problem',
                PinProblem.alreadySet,
              ),
            ),
          );
          final wallet = container.read(walletServiceProvider);
          final account = (await repository().savedBanks()).first;
          final needs = await wallet.withdraw(
            amountKobo: 100000,
            account: account,
          );
          expect(needs.pin!.problem, PinProblem.required);
        },
      );
    },
  );
}

/// The same walk against a local API started with every section 13
/// feature in MOBILE_FEATURES_OFF: the app keeps its older behaviour.
void _contract13Off(String? base) {
  group(
    'Contract 13 switched off on the API',
    skip: base == null
        ? 'Set IQLY_E2E_API_S13_OFF to a local API started with '
              'MOBILE_FEATURES_OFF=withdrawalPin,phoneVerification,'
              'savedBriefsSync,closeRemindersSync,uploads,etags,config to run'
        : false,
    () {
      test(
        'health leaves them out: nothing asked, older behaviour kept',
        () async {
          final tools = _LocalTools(base!);
          final seeded = await tools.post('/__local/seed');
          final seed = _Seed(seeded);
          SharedPreferences.resetStatic();
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final client = _Recording(http.Client());
          addTearDown(client.close);
          final api = ApiClient(
            tokens: MemoryTokenStore(),
            client: client,
            baseUrl: base,
            appVersion: '0.5.0+5',
            platform: 'android',
          );
          final store = MemoryLocalStore();
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              apiClientProvider.overrideWithValue(api),
              localStoreProvider.overrideWithValue(store),
              healthServiceProvider.overrideWithValue(LiveHealthService(api)),
              backendProvider.overrideWith(
                () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
              ),
              authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
            ],
          );
          addTearDown(container.dispose);
          startAccountSync(container);

          final report = await LiveHealthService(api).check();
          for (final f in _section13) {
            expect(report.features, isNot(contains(f)), reason: f.name);
          }
          await container.read(backendProvider.notifier).check();
          await container.read(backendProvider.notifier).lock();
          await container.read(appConfigProvider.notifier).refresh();
          expect(client.to('GET', '/config'), isEmpty);
          expect(minimumWithdrawalKobo, 100000);

          final pin = seeded['pin'] as Map<String, dynamic>;
          final result = await container
              .read(authServiceProvider)
              .signIn(email: pin['email'] as String, password: seed.password);
          final session = container.read(sessionProvider.notifier);
          await session.setUserId(result.userId);
          await session.setSignedIn(true);
          await session.setOnboardingDone(true);
          final outbox = container.read(outboxProvider);
          await outbox.start(result.userId!);

          expect(container.read(pinServiceProvider), isNull);
          expect(container.read(phoneServiceProvider), isNull);
          expect(container.read(submissionUploadsProvider), isNull);
          expect(container.read(submitQueueProvider), isNull);
          expect(
            container.read(briefMarksSyncProvider(BriefMark.saved)),
            isNull,
          );
          expect(
            container.read(briefMarksSyncProvider(BriefMark.reminder)),
            isNull,
          );

          final repo = container.read(repositoryProvider) as LiveRepository;
          await repo.walletTotals(allowCache: false);
          await repo.walletTotals(allowCache: false);
          expect(
            client.to('GET', '/wallet').every((s) => s.ifNoneMatch == null),
            isTrue,
          );

          final account = (await repo.savedBanks()).first;
          final made = await container
              .read(walletServiceProvider)
              .withdraw(amountKobo: 100000, account: account);
          expect(made.withdrawal, isNotNull, reason: 'no PIN asked: $made');

          final brief = (await repo.brief(seed.liveBriefId))!;
          await container.read(savedBriefsProvider.future);
          await container
              .read(savedBriefsProvider.notifier)
              .setSaved(brief, true);
          await container
              .read(closeRemindersProvider.notifier)
              .setReminder(seed.liveBriefId, true);
          await outbox.kick();
          expect(
            client.seen.where(
              (s) =>
                  s.path.startsWith('/me/saved-briefs') ||
                  s.path.startsWith('/me/close-reminders') ||
                  s.path.startsWith('/me/phone') ||
                  s.path.startsWith('/wallet/pin') ||
                  s.path.startsWith('/submissions/uploads'),
            ),
            isEmpty,
          );
        },
      );
    },
  );
}

/// The switches of 19 Oct: proof one step at a time, brief audiences and
/// help replies signed by name.
const _rules19Oct = {
  LiveFeature.activationStepProof,
  LiveFeature.briefAudience,
  LiveFeature.helpAuthorNames,
};

/// A web session for [email], as the business dashboard and the staff
/// console sign in.
Future<ApiClient> _webSession(
  String base,
  String email,
  String password,
) async {
  final session = ApiClient(
    tokens: MemoryTokenStore(),
    baseUrl: base,
    appVersion: '0.5.0+5',
    platform: 'android',
  );
  final res = await session.post('/auth/web/sign-in/email', {
    'email': email,
    'password': password,
  });
  expect(res.ok, isTrue, reason: '$email: ${res.status} ${res.code}');
  return session;
}

/// Ada in the app on a freshly seeded local API, with Tola acting for
/// Sunline Foods beside her: its dashboard and its own server.
class _Walk {
  _Walk._(this.base, this.seed, this.api, this.client, this.container);

  final String base;
  final _Seed seed;
  final ApiClient api;
  final http.Client client;
  final ProviderContainer container;
  late final ApiClient owner;
  final _folder = Directory.systemTemp.createTempSync('iqly-rules');
  var _txn = 0;

  static Future<_Walk> start(String base) async {
    final seed = _Seed(await _LocalTools(base).post('/__local/seed'));
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = http.Client();
    final api = ApiClient(
      tokens: MemoryTokenStore(),
      client: client,
      baseUrl: base,
      appVersion: '0.5.0+5',
      platform: 'android',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        healthServiceProvider.overrideWithValue(LiveHealthService(api)),
        backendProvider.overrideWith(
          () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
        ),
        authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
      ],
    );
    startAccountSync(container);
    await container.read(backendProvider.notifier).check();
    await container.read(backendProvider.notifier).lock();
    final result = await container
        .read(authServiceProvider)
        .signIn(email: seed.email, password: seed.password);
    expect(result.ok, isTrue, reason: '${result.failure}');
    final session = container.read(sessionProvider.notifier);
    await session.setUserId(result.userId);
    await session.setSignedIn(true);
    await session.setName(result.name);
    await session.setOnboardingDone(true);
    return _Walk._(base, seed, api, client, container)
      ..owner = await _webSession(base, seed.ownerEmail, seed.password);
  }

  void close() {
    container.dispose();
    client.close();
    _folder.deleteSync(recursive: true);
  }

  ActivationsService get activations =>
      container.read(activationsServiceProvider);

  LiveRepository get repository =>
      container.read(repositoryProvider) as LiveRepository;

  Future<List<AppNotification>> feed() =>
      container.read(notificationsServiceProvider).notifications();

  Future<Map<String, dynamic>> asOwner(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final res = await owner.send(
      method,
      path,
      body: body ?? (method == 'GET' ? null : const <String, Object?>{}),
    );
    expect(res.ok, isTrue, reason: '$method $path: ${res.code}');
    return res.data;
  }

  /// A Sunline Foods activation of two steps for ₦500, confirmed in [mode]
  /// and paid by step when it has [stepRewards], held [holdHours] after a
  /// postback; paid for at the stand-in checkout and live now.
  Future<String> publish(
    String title, {
    String mode = 'proof',
    List<int>? stepRewards,
    int holdHours = 0,
  }) async {
    final made = await asOwner('POST', '/activations/owner', {
      'brandOrgId': 'org_sunline',
      'title': title,
      'minutes': 5,
      'rewardKobo': 50000,
      'slots': 10,
      'steps': [
        {
          'title': 'Sign up with code IQLY',
          'hint': 'Enter IQLY.',
          'rewardKobo': ?stepRewards?[0],
        },
        {
          'title': 'Rate a recipe',
          'hint': 'Any recipe counts.',
          'rewardKobo': ?stepRewards?[1],
        },
      ],
      'link': mode == 'postback'
          ? 'https://sunline.example/app?ref={code}'
          : 'https://sunline.example/app',
      'confirmationMode': mode,
      'rewardMode': stepRewards == null ? 'per_run' : 'per_step',
      'payoutHoldHours': holdHours,
      'closesAt': DateTime.now()
          .add(const Duration(days: 2))
          .toUtc()
          .toIso8601String(),
    });
    final id = made['id'] as String;
    final checkout = await asOwner(
      'POST',
      '/activations/owner/$id/payment/initiate',
      {'callbackUrl': 'http://localhost:3001/activations/paid'},
    );
    await _LocalTools(base)
        .post('/__local/payments/${checkout['reference']}/pay');
    await asOwner('POST', '/activations/owner/$id/publish');
    return id;
  }

  /// Ada's run at [activation].
  Future<String> runOf(String activation) async {
    final res = await api.get('/activations/$activation');
    return ((res.data['progress'] as Map)['id']) as String;
  }

  /// A short MP4 (the API reads its ftyp box).
  ProofVideo recording(String name) {
    final media = [
      0,
      0,
      0,
      0x18,
      ...'ftypmp42'.codeUnits,
      ...List.filled(512, 7),
    ];
    final file = File('${_folder.path}/$name')..writeAsBytesSync(media);
    return ProofVideo(
      name: name,
      bytes: media.length,
      length: const Duration(seconds: 12),
      source: file.uri,
    );
  }

  Future<String> upload(String activation, ProofVideo video) async =>
      (await activations.upload(activation, video).last).id!;

  /// Records [step] of [activation] and has Sunline Foods approve it.
  Future<Activation> prove(String activation, int step) async {
    final video = recording('step-$step.mp4');
    final checking = await activations.sendProof(
      activation,
      step: step,
      uploadId: await upload(activation, video),
      video: video,
    );
    expect(checking.phaseAt(DateTime.now()), ActivationPhase.checking);
    final run = await runOf(activation);
    await asOwner(
      'POST',
      '/activations/owner/$activation/completions/$run/approve',
    );
    return activations.refresh(activation);
  }

  ({String id, String keyId, String secret})? _key;
  var _signed = 0;

  /// A live key of Sunline Foods, a new one every nine postbacks: the API
  /// takes ten a minute per key.
  Future<({String id, String keyId, String secret})> _liveKey() async {
    final kept = _key;
    if (kept != null && _signed < 9) return kept;
    if (kept != null) {
      await asOwner('DELETE', '/brands/org_sunline/api-keys/${kept.id}');
    }
    final made = await asOwner('POST', '/brands/org_sunline/api-keys', {
      'mode': 'live',
    });
    _signed = 0;
    return _key = (
      id: made['id'] as String,
      keyId: made['keyId'] as String,
      secret: made['secret'] as String,
    );
  }

  /// Sunline Foods' server confirming [step] of the run with [code], signed
  /// with a live key; [txn] sends one again.
  Future<Map<String, dynamic>> postback(
    String code,
    int step, {
    String? txn,
  }) async {
    final key = await _liveKey();
    _signed++;
    final body = jsonEncode({
      'code': code,
      'step': step,
      'txn_id': txn ?? 'e2e-$code-${_txn++}',
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    final res = await client.post(
      Uri.parse('$base/v1/postbacks'),
      headers: {
        'content-type': 'application/json',
        'x-iqly-key': key.keyId,
        'x-iqly-signature': Hmac(
          sha256,
          utf8.encode(key.secret),
        ).convert(utf8.encode(body)).toString(),
      },
      body: body,
    );
    expect(res.statusCode, 200, reason: res.body);
    return (jsonDecode(res.body) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
  }

  /// Ada's onboarding answers again, with [interests]: the noodles brief is
  /// for people into agriculture and food.
  Future<void> answerInterests(List<String> interests) async {
    final res = await api.post(
      '/me/onboarding',
      onboardingBody(
        OnboardingProfile(
          occupation: 'student',
          state: 'Lagos',
          city: 'Yaba',
          education: 'hnd_bsc',
          university: 'University of Lagos',
          interests: interests,
          dateOfBirth: DateTime(2001, 4, 9),
        ),
        today: DateTime.now(),
      ),
    );
    expect(res.ok, isTrue, reason: '${res.status} ${res.code}');
  }

  /// Help about [activation] from Ada, answered by Sunline Foods from its
  /// dashboard.
  Future<HelpTicket> askSunline(String activation) async {
    final help = container.read(helpServiceProvider);
    expect(help, isA<LiveHelpService>());
    final opened = await help.send(
      HelpRequest(
        subject: 'Sunline Foods activation',
        message: 'My second step has not counted yet.',
        activation: await activations.refresh(activation),
        idempotencyKey: LocalRows.newId(),
      ),
    );
    expect(opened.status, HelpTicketStatus.open);
    final reply = await owner.post(
      '/support/brand/tickets/${opened.id}/reply',
      {'message': 'Thanks, Ada. It counts now.'},
    );
    expect(reply.ok, isTrue, reason: '${reply.status} ${reply.code}');
    return help.watch(opened.id).single;
  }
}

Matcher _refusedWith(String code) =>
    throwsA(isA<ApiRefused>().having((r) => r.code, 'code', code));

void _rules19OctOn(String? base) {
  final db = Platform.environment['IQLY_E2E_DB'];
  group(
    'The rules of 19 Oct on the API',
    skip: base == null || db == null
        ? 'Set IQLY_E2E_API and IQLY_E2E_DB to the local API and its '
              'database to run'
        : false,
    () {
      late _Walk walk;

      setUpAll(() async => walk = await _Walk.start(base!));
      tearDownAll(() => walk.close());

      Future<void> startedAgo(String run, String interval) => _sql(
        db!,
        "update activation_completions set started_at = now() - "
        "interval '$interval' where id = '$run'",
      );

      test('health turns the three on, and the app runs them', () async {
        final report = await LiveHealthService(walk.api).check();
        expect(report.features, containsAll(_rules19Oct));
        final mode = walk.container.read(liveModeProvider);
        for (final feature in _rules19Oct) {
          expect(mode.isLive(feature), isTrue, reason: feature.name);
        }
        expect(walk.container.read(briefAudienceProvider), isTrue);
        expect(walk.container.read(helpAuthorNamesProvider), isTrue);
      });

      test('proof mode, paid by the run: each step recorded in order from '
          'Start, and the run paid on the last', () async {
        final service = walk.activations;
        final id = await walk.publish('Rate a recipe, one step at a time');
        final offer = await service.refresh(id);
        expect(offer.confirmationMode, ConfirmationMode.proof);
        expect(offer.rewardMode, RewardMode.perRun);
        expect(offerReward(offer), '₦500 per completion');

        final started = await service.start(id);
        expect(started.phaseAt(DateTime.now()), ActivationPhase.recording);
        expect(started.proofStep, 0);
        expect(started.paysFor(0), 0, reason: 'D1: only the last step pays');
        expect(started.paysFor(1), 50000);
        expect(progressLine(started), 'Not started · 2 steps');

        final video = walk.recording('early.mp4');
        final early = await walk.upload(id, video);
        await expectLater(
          service.sendProof(id, step: 1, uploadId: early, video: video),
          _refusedWith('ACTIVATION_PROOF_NOT_DUE'),
        );
        final checking = await service.sendProof(
          id,
          step: 0,
          uploadId: early,
          video: video,
        );
        expect(checking.phaseAt(DateTime.now()), ActivationPhase.checking);
        final run = await walk.runOf(id);
        await walk.asOwner(
          'POST',
          '/activations/owner/$id/completions/$run/approve',
        );
        final next = await service.refresh(id);
        expect(next.phaseAt(DateTime.now()), ActivationPhase.recording);
        expect(next.proofStep, 1);
        expect(next.credited, isFalse);
        expect(progressLine(next), 'Step 1 of 2 confirmed');

        final paid = await walk.prove(id, 1);
        expect(paid.phaseAt(DateTime.now()), ActivationPhase.credited);
        final ledgerId = paid.progress!.ledgerId!;
        final reward = (await walk.repository.ledger()).singleWhere(
          (l) => l.id == ledgerId,
        );
        expect(reward.amountKobo, 50000);
        expect(reward.activationId, id);
        final told = [
          for (final n in await walk.feed())
            if (n.facts?.type == 'activation_approved' &&
                n.facts?.activationId == id)
              n.facts!.amountKobo,
        ];
        expect(told, [50000], reason: 'one money notice, for the run');
      });

      test('proof mode, paid by step: each step pays its own amount as it is '
          'confirmed', () async {
        final service = walk.activations;
        final id = await walk.publish(
          'Rate a recipe, paid step by step',
          stepRewards: [20000, 30000],
        );
        final offer = await service.refresh(id);
        expect(offer.rewardMode, RewardMode.perStep);
        expect([for (final s in offer.steps) s.rewardKobo], [20000, 30000]);
        expect(offer.showsStepRewards, isTrue);
        expect(offerReward(offer), 'Up to ₦500');
        expect(
          [stepRewardText(offer, 0), stepRewardText(offer, 1)],
          ['₦200', '₦300'],
        );

        final started = await service.start(id);
        expect(started.phaseAt(DateTime.now()), ActivationPhase.recording);
        expect(earnedLine(started), '₦0 earned of up to ₦500');
        expect(progressLine(started), 'No steps confirmed yet');

        final one = await walk.prove(id, 0);
        expect(one.phaseAt(DateTime.now()), ActivationPhase.recording);
        expect(one.proofStep, 1);
        final first = one.payoutOf(0)!;
        expect(first.kobo, 20000);
        expect(stepRewardText(one, 0), 'Paid ₦200');
        expect(earnedLine(one), '₦200 earned of up to ₦500');
        expect(progressLine(one), 'Step 1 of 2 confirmed');

        final paid = await walk.prove(id, 1);
        expect(paid.phaseAt(DateTime.now()), ActivationPhase.credited);
        expect(
          [for (final p in paid.progress!.stepPayouts) p.kobo],
          [20000, 30000],
        );
        expect(earnedLine(paid), '₦500 earned of up to ₦500');
        final ledger = await walk.repository.ledger();
        for (final payout in paid.progress!.stepPayouts) {
          final row = ledger.singleWhere((l) => l.id == payout.ledgerId);
          expect(row.amountKobo, payout.kobo);
          expect(row.activationId, id);
        }
        final told = [
          for (final n in await walk.feed())
            if (n.facts?.type == 'activation_approved' &&
                n.facts?.activationId == id)
              n.facts!.amountKobo,
        ];
        expect(told, unorderedEquals([20000, 30000]));
      });

      test('postback mode: the run\'s code, one signed postback per step, '
          'and the run paid on the last', () async {
        final service = walk.activations;
        final recipes = walk.seed.recipes;
        final offer = await service.refresh(recipes);
        expect(offer.confirmationMode, ConfirmationMode.postback);
        expect(offer.progress, isNull);

        final started = await service.start(recipes);
        final code = started.progress!.refCode!;
        expect(code, matches(RegExp(r'^IQ-[A-Z0-9]{5}$')));
        expect(started.link.queryParameters['ref'], code);
        expect(started.phaseAt(DateTime.now()), ActivationPhase.started);

        final tooSoon = await walk.postback(code, 0);
        expect(tooSoon['status'], 'flagged');
        expect(tooSoon['reason'], 'too_fast');
        expect((await service.refresh(recipes)).confirmed, 0);

        await startedAgo(await walk.runOf(recipes), '2 minutes');
        final first = await walk.postback(code, 0);
        expect(first['status'], 'accepted');
        expect(first['paid'], isFalse);
        final confirming = await service.refresh(recipes);
        expect(confirming.phaseAt(DateTime.now()), ActivationPhase.confirming);
        expect(confirming.waitingStep, 1);
        expect(progressLine(confirming), 'Step 1 of 3 confirmed');

        expect((await walk.postback(code, 1))['paid'], isFalse);
        final last = await walk.postback(code, 2, txn: 'e2e-recipes-last');
        expect(last['status'], 'accepted');
        expect(last['paid'], isTrue);
        final again = await walk.postback(code, 2, txn: 'e2e-recipes-last');
        expect(again['duplicate'], isTrue);

        final paid = await service.refresh(recipes);
        expect(paid.phaseAt(DateTime.now()), ActivationPhase.credited);
        final reward = (await walk.repository.ledger()).singleWhere(
          (l) => l.id == paid.progress!.ledgerId,
        );
        expect(reward.amountKobo, 50000);
        expect(reward.activationId, recipes);
      });

      test('postback mode, a day without the business: step 1 can be '
          'proven, and the proof pays its step', () async {
        final service = walk.activations;
        final id = await walk.publish(
          'Sign up and rate, counted by our app',
          mode: 'postback',
          stepRewards: [20000, 30000],
        );
        final started = await service.start(id);
        expect(started.phaseAt(DateTime.now()), ActivationPhase.started);
        final video = walk.recording('fallback.mp4');
        final upload = await walk.upload(id, video);
        await expectLater(
          service.sendProof(id, step: 0, uploadId: upload, video: video),
          _refusedWith('ACTIVATION_PROOF_NOT_DUE'),
        );

        final run = await walk.runOf(id);
        await startedAgo(run, '25 hours');
        final stuck = await service.refresh(id);
        expect(stuck.phaseAt(DateTime.now()), ActivationPhase.notConfirmed);
        expect(stuck.proofStep, 0);
        final checking = await service.sendProof(
          id,
          step: 0,
          uploadId: upload,
          video: video,
        );
        expect(checking.phaseAt(DateTime.now()), ActivationPhase.checking);
        await walk.asOwner(
          'POST',
          '/activations/owner/$id/completions/$run/approve',
        );
        final one = await service.refresh(id);
        expect(one.confirmed, 1);
        expect(one.payoutOf(0)!.kobo, 20000);
        expect(one.phaseAt(DateTime.now()), ActivationPhase.confirming);

        final rest = await walk.postback(one.progress!.refCode!, 1);
        expect(rest['status'], 'accepted');
        expect(rest['paid'], isTrue);
        final paid = await service.refresh(id);
        expect(paid.phaseAt(DateTime.now()), ActivationPhase.credited);
        expect(
          [for (final p in paid.progress!.stepPayouts) p.kobo],
          [20000, 30000],
        );
      });

      test('postback mode, a step the business holds: it waits on the '
          'business, with no proof even a day on', () async {
        final service = walk.activations;
        final id = await walk.publish(
          'Open the app, held a day',
          mode: 'postback',
          holdHours: 24,
        );
        final started = await service.start(id);
        final code = started.progress!.refCode!;
        expect(started.progress!.heldSteps, isEmpty);
        final run = await walk.runOf(id);
        await startedAgo(run, '25 hours');
        expect(
          (await service.refresh(id)).phaseAt(DateTime.now()),
          ActivationPhase.notConfirmed,
        );

        final held = await walk.postback(code, 0);
        expect(held['status'], 'accepted');
        expect(held['payAfter'], isNotNull);
        expect(held['paid'], isFalse);
        final waiting = await service.refresh(id);
        final step = waiting.progress!.heldSteps.single;
        expect(step.step, 0);
        expect(
          step.until!.difference(DateTime.now()).inMinutes,
          inInclusiveRange(23 * 60, 24 * 60),
        );
        expect(waiting.heldAt(0), isTrue);
        expect(waiting.phaseAt(DateTime.now()), ActivationPhase.confirming);
        expect(waiting.proofStep, isNull);
        expect(waiting.waitingSince, isNull);
        expect(progressLine(waiting), 'No steps confirmed yet');
        expect(
          (await walk.api.get('/activations/$id')).data['phase'],
          'confirming',
        );

        final video = walk.recording('held.mp4');
        final upload = await walk.upload(id, video);
        final refused = await walk.api.post('/activations/$id/proof', {
          'step': 0,
          'uploadId': upload,
        });
        expect(refused.code, 'ACTIVATION_PROOF_NOT_DUE');
        final details = (refused.body['error'] as Map)['details'] as Map;
        expect(details['heldUntil'], isNotNull);
        await service.discard(id, upload);

        await walk.asOwner(
          'POST',
          '/activations/owner/$id/completions/$run/confirm-step',
          {'step': 0},
        );
        final counted = await service.refresh(id);
        expect(counted.progress!.heldSteps, isEmpty);
        expect(counted.confirmed, 1);
        expect(counted.heldAt(0), isFalse);
        expect(counted.phaseAt(DateTime.now()), ActivationPhase.confirming);
      });

      test('a proof turned down, then the step reported and held: no proof '
          'is offered, and the API refuses one, naming the hold', () async {
        final service = walk.activations;
        final id = await walk.publish(
          'Open the app, proof first, then held',
          mode: 'postback',
          holdHours: 24,
        );
        final code = (await service.start(id)).progress!.refCode!;
        final run = await walk.runOf(id);
        await startedAgo(run, '25 hours');
        final video = walk.recording('turned-down.mp4');
        final checking = await service.sendProof(
          id,
          step: 0,
          uploadId: await walk.upload(id, video),
          video: video,
        );
        expect(checking.phaseAt(DateTime.now()), ActivationPhase.checking);
        await walk.asOwner(
          'POST',
          '/activations/owner/$id/completions/$run/reject',
          {'reason': 'The recording ends too soon.'},
        );
        final refused = await service.refresh(id);
        expect(refused.phaseAt(DateTime.now()), ActivationPhase.notAccepted);
        expect(refused.proofStep, 0);

        final held = await walk.postback(code, 0);
        expect(held['status'], 'accepted');
        expect(held['payAfter'], isNotNull);
        final raw = (await walk.api.get('/activations/$id')).data;
        expect(raw['phase'], 'confirming', reason: 'the API reads it so too');
        expect(
          (((raw['progress'] as Map)['heldSteps'] as List).single
              as Map)['step'],
          0,
        );
        final waiting = await service.refresh(id);
        expect(waiting.phaseAt(DateTime.now()), ActivationPhase.confirming);
        expect(waiting.proofStep, isNull);
        const words = 'Waiting for Sunline Foods to confirm.';
        expect(proofHeldBack(waiting, DateTime.now()), words);

        final again = walk.recording('again.mp4');
        final upload = await walk.upload(id, again);
        try {
          await service.sendProof(id, step: 0, uploadId: upload, video: again);
          fail('a proof of a held step went through');
        } on ApiRefused catch (refusal) {
          expect(refusal.code, 'ACTIVATION_PROOF_NOT_DUE');
          expect(refusal.details?['heldUntil'], isNotNull);
          expect(proofNotDueText(waiting, refusal.details), words);
        }
        await service.discard(id, upload);
      });

      test('proof mode: the business confirms a step by hand while its '
          'recording waits; the send is refused as not due, the next step is '
          'the one to prove, and the upload can be dropped', () async {
        final service = walk.activations;
        final id = await walk.publish('Rate a recipe, confirmed by hand');
        expect((await service.start(id)).proofStep, 0);
        final video = walk.recording('by-hand.mp4');
        final upload = await walk.upload(id, video);
        final run = await walk.runOf(id);
        await walk.asOwner(
          'POST',
          '/activations/owner/$id/completions/$run/confirm-step',
          {'step': 0},
        );
        try {
          await service.sendProof(id, step: 0, uploadId: upload, video: video);
          fail('a proof of a confirmed step went through');
        } on ApiRefused catch (refusal) {
          expect(refusal.code, 'ACTIVATION_PROOF_NOT_DUE');
          expect(refusal.details?['step'], 1);
        }
        final next = await service.refresh(id);
        expect(next.proofStep, 1, reason: 'the draft for step 1 is stale');
        expect(next.phaseAt(DateTime.now()), ActivationPhase.recording);
        await service.discard(id, upload);
        final gone = await walk.api.delete(
          '/activations/$id/proof/uploads/$upload',
        );
        expect(gone.code, 'ACTIVATION_UPLOAD_NOT_FOUND');
      });

      test('closed while a step is held: the step still waits on the '
          'business and pays when its hold ends', () async {
        final service = walk.activations;
        final id = await walk.publish(
          'Open the app, held a day, then closed',
          mode: 'postback',
          stepRewards: [20000, 30000],
          holdHours: 24,
        );
        final code = (await service.start(id)).progress!.refCode!;
        await startedAgo(await walk.runOf(id), '25 hours');
        final held = await walk.postback(code, 0);
        expect(held['status'], 'accepted');
        expect(held['payAfter'], isNotNull);
        await walk.asOwner('POST', '/activations/owner/$id/close');

        final raw = (await walk.api.get('/activations/$id')).data;
        expect(raw['status'], 'closed');
        expect((raw['progress'] as Map)['status'], 'started');
        expect(raw['phase'], 'confirming');
        final closed = await service.refresh(id);
        final now = DateTime.now();
        expect(closed.closedAt(now), isTrue);
        expect(closed.progress!.heldSteps.single.step, 0);
        expect(closed.phaseAt(now), ActivationPhase.confirming);
        expect(closed.canProveAt(now), isFalse);
        expect(closed.paysFor(0), 20000);
        expect(closed.stillPayable, 20000);
        expect(earnedLine(closed, now: now), '₦0 earned of up to ₦200');
        expect(
          [closed.stepEndedAt(0, now), closed.stepEndedAt(1, now)],
          [false, true],
        );
        expect(
          proofHeldBack(closed, now),
          'Waiting for Sunline Foods to confirm.',
        );
        final late = await walk.postback(code, 1);
        expect(late['status'], 'flagged');
        expect(late['reason'], 'run_ended');
      });

      for (final (name, stepRewards) in [
        ('per_run with a step still to do', null),
        ('per_step whose held step pays nothing', [0, 50000]),
      ]) {
        test('closed while a step is held that cannot pay the run ($name): '
            'the API and the app read it as ended', () async {
          final service = walk.activations;
          final id = await walk.publish(
            'Held a day, then closed: $name',
            mode: 'postback',
            stepRewards: stepRewards,
            holdHours: 24,
          );
          final offer = await service.refresh(id);
          expect(
            [for (final step in offer.steps) step.rewardKobo],
            stepRewards ?? <int?>[null, null],
            reason: 'step rewards on per_step only, 0 for a step paying none',
          );
          final code = (await service.start(id)).progress!.refCode!;
          await startedAgo(await walk.runOf(id), '25 hours');
          expect((await walk.postback(code, 0))['payAfter'], isNotNull);
          final open = await service.refresh(id);
          expect(open.phaseAt(DateTime.now()), ActivationPhase.confirming);
          await walk.asOwner('POST', '/activations/owner/$id/close');

          final raw = (await walk.api.get('/activations/$id')).data;
          expect(raw['phase'], 'expired');
          final closed = await service.refresh(id);
          final now = DateTime.now();
          expect(closed.sentPhase, ActivationPhase.expired);
          expect(closed.stillPayable, 0);
          expect(closed.phaseAt(now), ActivationPhase.expired);
          expect(
            closed.withProgress(closed.progress!).phaseAt(now),
            ActivationPhase.expired,
            reason: 'worked out on the phone the same way',
          );
          expect(proofHeldBack(closed, now), isNull);
        });
      }

      test('a brief outside the audience: not in the feed, blocked on the '
          'brief and at opening, and refused on send', () async {
        final submit = walk.container.read(submitServiceProvider);
        final noodles = walk.seed.liveBriefId;
        expect((await submit.open(noodles)).block, isNull);

        await walk.answerInterests(['finance_fintech', 'education']);
        final feed = await walk.repository.briefs(load: BriefsLoad.refresh);
        expect(feed.map((b) => b.id), isNot(contains(noodles)));
        final brief = (await walk.repository.brief(noodles))!;
        expect(brief.inAudience, isFalse);
        expect(walk.container.read(briefAudienceProvider), isTrue);
        final opening = await submit.open(noodles);
        expect(opening.block, SubmitBlock.notInAudience);
        expect(opening.form, isNull);

        final sent = await submit.submit(
          SubmitRequest(
            briefId: noodles,
            title: 'Noodles on a Friday',
            answer: _typedAnswer,
          ),
        );
        expect(sent.ok, isFalse);
        expect(sent.failure, SubmitFailure.blocked);
        expect(sent.block, SubmitBlock.notInAudience);

        await walk.answerInterests([
          'finance_fintech',
          'education',
          'agriculture_food',
        ]);
        expect((await submit.open(noodles)).block, isNull);
      });

      test('help about an activation: the business answers in its own name, '
          'and staff as iQLY support', () async {
        final thread = await walk.askSunline(walk.seed.recipes);
        final reply = thread.messages.last;
        expect(reply.author, HelpAuthor.support);
        expect(reply.authorName, 'Sunline Foods');
        expect(reply.fromBusiness, isTrue);
        expect(thread.messages.first.authorName, isNull);
        expect(thread.business, 'Sunline Foods');
        final help = walk.container.read(helpServiceProvider);
        final names = walk.container.read(helpAuthorNamesProvider);
        final row = (await help.conversations()).singleWhere(
          (t) => t.id == thread.id,
        );
        expect(
          conversationLine(row, DateTime.now(), names: names),
          startsWith('Sunline Foods replied · '),
        );
        final told = (await walk.feed()).firstWhere(
          (n) => n.facts?.type == 'support' && n.facts?.ticketId == thread.id,
        );
        expect(told.facts!.title, 'Sunline Foods replied');

        final staff = await _webSession(
          walk.base,
          'support@example.com',
          walk.seed.password,
        );
        final answer = await staff.post(
          '/admin/support/tickets/${thread.id}/reply',
          {'message': 'iQLY here: it is in your wallet.'},
        );
        expect(answer.ok, isTrue, reason: '${answer.status} ${answer.code}');
        final after = await help.watch(thread.id).single;
        expect(after.messages.last.authorName, iqlySupport);
        expect(after.messages.last.fromBusiness, isFalse);
        expect(after.business, 'Sunline Foods');
        final again = (await help.conversations()).singleWhere(
          (t) => t.id == thread.id,
        );
        expect(
          conversationLine(again, DateTime.now(), names: names),
          startsWith('Support replied · '),
        );
      });
    },
  );
}

void _rules19OctOff(String? base) {
  group(
    'The rules of 19 Oct switched off on the API',
    skip: base == null
        ? 'Set IQLY_E2E_API_GATES_OFF to a local API started with '
              'MOBILE_FEATURES_OFF=activationStepProof,briefAudience,'
              'helpAuthorNames to run'
        : false,
    () {
      late _Walk walk;

      setUpAll(() async => walk = await _Walk.start(base!));
      tearDownAll(() => walk.close());

      test(
        'health leaves the three out; the app keeps its older ways',
        () async {
          final report = await LiveHealthService(walk.api).check();
          expect(report.features.intersection(_rules19Oct), isEmpty);
          expect(
            report.features,
            containsAll({
              LiveFeature.activations,
              LiveFeature.briefs,
              LiveFeature.support,
            }),
          );
          final mode = walk.container.read(liveModeProvider);
          for (final feature in _rules19Oct) {
            expect(mode.isLive(feature), isFalse, reason: feature.name);
          }
          expect(mode.isLive(LiveFeature.activations), isTrue);
          expect(walk.container.read(briefAudienceProvider), isFalse);
          expect(walk.container.read(helpAuthorNamesProvider), isFalse);
        },
      );

      test('activations read as before: no modes, step amounts or code, '
          'and no proof right after Start', () async {
        final service = walk.activations;
        for (final a in await service.activations()) {
          expect(a.confirmationMode, isNull, reason: a.title);
          expect(a.rewardMode, RewardMode.perRun, reason: a.title);
          expect(a.steps.map((s) => s.rewardKobo), everyElement(isNull));
          expect(a.progress?.refCode, isNull, reason: a.title);
          expect(a.progress?.stepPayouts ?? const [], isEmpty);
        }

        final id = await walk.publish(
          'Rate a recipe, paid step by step',
          stepRewards: [20000, 30000],
        );
        final offer = await service.refresh(id);
        expect(offer.showsStepRewards, isFalse);
        expect(offerReward(offer), '₦500 per completion');
        final started = await service.start(id);
        expect(
          (await walk.api.get('/activations/$id')).data['phase'],
          'not_confirmed',
          reason: 'the API would take proof of step 1 now',
        );
        expect(started.phaseAt(DateTime.now()), ActivationPhase.started);
        expect(started.proofStep, isNull);
        expect(progressLine(started), 'Not started · 2 steps');

        final recipes = await service.start(walk.seed.recipes);
        expect(recipes.progress!.refCode, isNull);
        expect(recipes.link.queryParameters['ref'], startsWith('IQ-'));
        expect(recipes.phaseAt(DateTime.now()), ActivationPhase.started);
      });

      test('a brief outside the audience opens as before; the API refuses '
          'the send, and the screen says why', () async {
        final submit = walk.container.read(submitServiceProvider);
        final noodles = walk.seed.liveBriefId;
        expect((await submit.open(noodles)).block, isNull);
        await walk.answerInterests(['finance_fintech', 'education']);
        expect((await walk.repository.brief(noodles))!.inAudience, isFalse);
        final opening = await submit.open(noodles);
        expect(opening.block, isNull);
        expect(opening.form, isNotNull);
        final sent = await submit.submit(
          SubmitRequest(
            briefId: noodles,
            title: 'Noodles on a Friday',
            answer: _typedAnswer,
          ),
        );
        expect(sent.block, SubmitBlock.notInAudience);
        await walk.answerInterests([
          'finance_fintech',
          'education',
          'agriculture_food',
        ]);
      });

      test('a business reply reads as support\'s, as before', () async {
        final thread = await walk.askSunline(walk.seed.recipes);
        expect(thread.messages.last.author, HelpAuthor.support);
        final names = walk.container.read(helpAuthorNamesProvider);
        expect(names, isFalse);
        final row =
            (await walk.container.read(helpServiceProvider).conversations())
                .singleWhere((t) => t.id == thread.id);
        expect(
          conversationLine(row, DateTime.now(), names: names),
          startsWith('Support replied · '),
        );
      });
    },
  );
}
