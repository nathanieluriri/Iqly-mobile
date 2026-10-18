import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/app_config.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/live/brief_marks_sync.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_notifications_service.dart';
import 'package:iqly_mobile/data/live/live_onboarding_service.dart';
import 'package:iqly_mobile/data/live/live_outcomes_service.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live/live_submit_service.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/live/submit_queue.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
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
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/wallet/wallet_format.dart';
import 'package:iqly_mobile/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's live services against a real iQLY API, wired as main.dart wires
/// a live build: the local API from the platform repo (docs/local-api.md),
/// which this walk reseeds through its /__local tools. Plain test(), not
/// testWidgets: the widget binding would stub out real HTTP.
void main() {
  final base = Platform.environment['IQLY_E2E_API'];

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
        expect(report.ready, isTrue);
        expect(report.contract, Backend.contract);
        expect(report.features, LiveFeature.values.toSet());
        expect(Backend.from(report).live, LiveFeature.values.toSet());

        await container.read(backendProvider.notifier).check();
        expect(
          container.read(backendProvider).live,
          LiveFeature.values.toSet(),
        );
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
          expect((await repo.savedBanks()).single.accountNumber, '4321');

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

      test('close waits for an empty wallet; restore reopens', () async {
        final profile = container.read(profileServiceProvider);
        final wallet = container.read(walletServiceProvider);
        Matcher refused(String code) =>
            throwsA(isA<ApiRefused>().having((r) => r.code, 'code', code));

        await expectLater(
          profile.deleteAccount(),
          refused('ACCOUNT_HAS_BALANCE'),
        );
        final rest = await wallet.withdraw(amountKobo: 7500000, account: payTo);
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
      withdrawalId = _at(json, ['withdrawal', 'id']);

  final String password;
  final String contributorId;
  final String email;
  final String liveBriefId;
  final String hiddenBriefId;
  final String closedBriefId;
  final String wonId;

  /// Paid out to Access Bank ••6789 before the walk.
  final String withdrawalId;

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
Future<ApiClient> _signedIn(String base, String email, String password) async {
  final api = ApiClient(
    tokens: MemoryTokenStore(),
    client: http.Client(),
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
        final bob = await _signedIn(base!, at(['pin', 'email']), seed.password);
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
        final blocked = await wallet.withdraw(
          amountKobo: 100000,
          account: account,
          pin: '2468',
        );
        expect(blocked.pin!.problem, PinProblem.resetRequired);
      });

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
