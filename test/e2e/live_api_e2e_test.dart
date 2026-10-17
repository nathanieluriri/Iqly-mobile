import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/avatar_service.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/live/live_help_service.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/data/support_files.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/referrals/referrals_state.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_notifications_service.dart';
import 'package:iqly_mobile/data/live/live_onboarding_service.dart';
import 'package:iqly_mobile/data/live/live_outcomes_service.dart';
import 'package:iqly_mobile/data/live/live_profile_service.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/live/live_submit_service.dart';
import 'package:iqly_mobile/data/live/live_wallet_service.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/local_rows.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_data.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/onboarding_service.dart';
import 'package:iqly_mobile/data/outcomes_service.dart';
import 'package:iqly_mobile/data/profile_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/data/wallet_service.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';
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
          // Ada's Access Bank ••6789 is saved too (contract 10.2).
          expect(
            (await repo.savedBanks()).map((b) => b.accountNumber),
            contains('4321'),
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

      /// Another seeded person on their own session, as their phone would be.
      Future<ApiClient> signedIn(String email, {http.Client? via}) async {
        final other = ApiClient(
          tokens: MemoryTokenStore(),
          client: via,
          baseUrl: base!,
          appVersion: '0.5.0+5',
          platform: 'android',
        );
        final result = await LiveAuthService(api: other)
            .signIn(email: email, password: seed.password);
        expect(result.ok, isTrue, reason: '$email: ${result.failure}');
        return other;
      }

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
