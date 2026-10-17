import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/avatar_service.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
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
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_rows.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_data.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/outcomes_service.dart';
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
import 'package:iqly_mobile/features/activations/activations_routes.dart';
import 'package:iqly_mobile/features/activations/activations_state.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/polls/polls_routes.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/referrals/referrals_state.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
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
            interests: const ['finance_fintech', 'education'],
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
          expect(profile.interests, ['finance_fintech', 'education']);
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
        final file = File('${files().path}/$name')..writeAsBytesSync(bytes);
        return ProofVideo(
          name: name,
          bytes: bytes.length,
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
          expect(a.phaseAt(now), phases[json['phase']], reason: a.title);
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
          expect(player.bodyBytes, clip);
          expect((await http.get(sent.source!)).statusCode, isNot(200));
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
