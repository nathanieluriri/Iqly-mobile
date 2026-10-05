import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deadline.dart';
import 'package:iqly_mobile/data/activations_data.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_data.dart';
import 'package:iqly_mobile/data/notifications_service.dart';
import 'package:iqly_mobile/data/polls_data.dart';
import 'package:iqly_mobile/data/polls_service.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/polls/polls_state.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/ui/notification.dart';

import '../golden/screens/app_harness.dart';

Poll _poll(List<int> votes, {int? chosen}) => Poll(
  id: 'p',
  question: 'q',
  choices: const ['a', 'b', 'c'],
  votes: votes,
  closesAt: figmaNow,
  chosen: chosen,
);

void main() {
  group('B2 polls', () {
    test('shares are whole percentages that add up to 100', () {
      expect(_poll([96, 71, 47]).shares, [45, 33, 22]);
      expect(_poll([95, 71, 48]).shares, [44, 33, 23]);
      expect(_poll([95, 72, 47]).shares, [44, 34, 22]);
      expect(_poll([1, 1, 1]).shares, [34, 33, 33]);
      expect(_poll([0, 0, 0]).shares, [0, 0, 0]);
    });

    test('voting Zobo and ginger gives the row note: 45 / 33 / 22 of 214', () {
      final flavour = demoPolls(figmaNow).first.polls.first;
      expect(flavour.voted, isFalse);
      final voted = flavour.withVote(0);
      expect(voted.total, 214);
      expect(voted.shares, [45, 33, 22]);
      expect(voted.chosen, 0);
    });

    test('the businesses foot to DemoData.pollBrands', () {
      final businesses = demoPolls(figmaNow);
      expect(
        [for (final b in businesses) b.brand.businessName],
        [for (final b in DemoData.pollBrands) b.businessName],
      );
      for (final (i, brand) in DemoData.pollBrands.indexed) {
        expect(businesses[i].polls.length, brand.openPolls);
        expect(businesses[i].unanswered, brand.unanswered);
      }
    });

    test('rows and eyebrows read as the frames do', () {
      final [orchid, unibooks, sunline] = demoPolls(figmaNow);
      expect(businessLine(orchid, figmaNow), '2 open polls');
      expect(businessLine(unibooks, figmaNow), '1 open poll');
      expect(businessLine(sunline, figmaNow), 'You voted · results in 1 day');
      expect(sheetEyebrow(orchid), '2 open polls');
      final half = orchid.withPoll(orchid.polls.first.withVote(0));
      expect(sheetEyebrow(half), '1 of 2 answered');
      expect(businessLine(half, figmaNow), '1 open poll');
      expect(pollTimeLeft(const Duration(days: 2)), '2 days');
      expect(pollTimeLeft(const Duration(hours: 23, minutes: 59)), '23h');
      expect(pollTimeLeft(const Duration(minutes: 12)), '12 min');
    });

    test('the demo keeps a vote and refuses a second one', () async {
      final service = DemoPollsService(
        delay: Duration.zero,
        clock: () => figmaNow,
      );
      final counted = await service.vote('p1', 1);
      expect(counted.chosen, 1);
      expect(counted.total, 214);
      final again = await service.vote('p1', 2);
      expect(again.chosen, 1);
      final orchid = (await service.businesses()).first;
      expect(orchid.answered, 1);
    });
  });

  group('B6 notifications', () {
    final data = DemoData(now: figmaNow);

    test('the feed points at DemoData rows, newest first', () {
      final feed = demoNotifications(
        ledger: data.ledger,
        withdrawals: data.withdrawals,
        now: figmaNow,
      );
      expect(
        [for (final n in feed) n.id],
        ['n2', 'n1', 'n3', 'n4', 'n5', 'n6'],
      );
      expect(feed.where((n) => n.unread).length, DemoData.unreadNotifications);
      final won = feed.firstWhere((n) => n.event == NotificationEvent.won);
      final award = data.ledger.firstWhere((l) => l.id == won.entryId);
      final submission = data.submissions.firstWhere(
        (s) => s.id == award.submissionId,
      );
      expect(submission.briefId, won.briefId);
    });

    test('each row is worded from what it points at', () {
      final feed = demoNotifications(
        ledger: data.ledger,
        withdrawals: data.withdrawals,
        now: figmaNow,
      );
      final items = [
        for (final note in feed)
          wordNotification(
            note,
            briefs: {for (final b in data.briefs) b.id: b},
            awards: {for (final l in data.ledger) l.id: l},
            withdrawals: {for (final w in data.withdrawals) w.id: w},
            now: figmaNow,
          )!,
      ];
      expect(
        [for (final i in items) (i.kind, i.title, i.detail, i.when)],
        [
          (
            IqNotificationKind.deadline,
            'Closes in 6h',
            'Sunline · A tagline for a solar kiosk network',
            '1h',
          ),
          (
            IqNotificationKind.payout,
            '₦10,000.00 requested',
            'Access Bank ••6789 · pending',
            '2h',
          ),
          (
            IqNotificationKind.deadline,
            'Closes in 1 day',
            'Kudi Box · Redesign the first five minutes of our savings app',
            '5h',
          ),
          (
            IqNotificationKind.result,
            'You won ₦12,500.00',
            'Why do Lagosians skip mobile banking on Sundays?',
            '2d',
          ),
          (
            IqNotificationKind.payout,
            '₦40,000.00 paid out',
            'Sent to Access Bank ••6789 · completed',
            '10d',
          ),
          (
            IqNotificationKind.payout,
            '₦5,000.00 payout failed',
            'Access Bank ••6789 · back in your balance',
            '11d',
          ),
        ],
      );
      expect(items[0].link!.location, '/briefs/c5');
      expect(items[1].link!.location, '/wallet/withdrawals/w3');
      expect(items[3].link!.location, '/submissions/s2');
      expect(items[4].link!.tab, isTrue);
      expect(items[5].link!.location, '/wallet/withdrawals/w1');
    });

    test('a reversed payout says so', () {
      final reversed = data.withdrawals
          .firstWhere((w) => w.id == 'w1')
          .copyWith(status: WithdrawalStatus.reversed);
      final item = wordNotification(
        AppNotification(
          id: 'n',
          event: NotificationEvent.payoutFailed,
          entryId: 'w1',
          at: figmaNow,
        ),
        briefs: const {},
        awards: const {},
        withdrawals: {'w1': reversed},
        now: figmaNow,
      )!;
      expect(item.title, '₦5,000.00 payout reversed');
    });

    test('the bell starts at DemoData.unreadNotifications and clears once '
        'seen', () async {
      final service = DemoNotificationsService(
        DemoRepository(data),
        clock: () => figmaNow,
      );
      expect(await service.unseen(), DemoData.unreadNotifications);
      await service.markRead('n2');
      expect(await service.unseen(), DemoData.unreadNotifications);
      expect(
        (await service.notifications()).firstWhere((n) => n.id == 'n2').unread,
        isFalse,
      );
      await service.markSeen();
      expect(await service.unseen(), 0);
    });
  });

  group('B10 help', () {
    final kudiBox = DemoActivations(figmaNow).kudiBox;

    test('the credited reward takes the DemoData wallet to the frame', () {
      final data = DemoData(now: figmaNow);
      final before = walletTotals(data.ledger, data.withdrawals);
      expect(before.withdrawableKobo, 1500000);
      final credit = LedgerEntry(
        id: kudiBox.creditId,
        type: LedgerType.award,
        amountKobo: kudiBox.rewardKobo,
        createdAt: figmaNow,
      );
      final after = walletTotals([credit, ...data.ledger], data.withdrawals);
      expect(after.withdrawableKobo, 1650000);
      expect(after.pendingWithdrawalsKobo, 1000000);
      expect(after.totalEarnedKobo, 6650000);
    });

    test('the recording reads 0:31 and 12 MB', () {
      expect(DemoHelp.recording.lengthLabel, '0:31');
      expect(DemoHelp.recording.sizeLabel, '12 MB');
    });

    test('support types, then replies with the reward credited', () async {
      final service = DemoHelpService(
        delay: Duration.zero,
        typingAfter: Duration.zero,
        replyAfter: Duration.zero,
        clock: () => figmaNow,
      );
      final ticket = await service.send(
        HelpRequest(
          subject: 'Kudi Box activation',
          message: 'Help',
          activation: kudiBox.withProgress(
            ActivationProgress(startedAt: figmaNow),
          ),
        ),
      );
      expect(ticket.status, HelpTicketStatus.open);
      final updates = await service.watch(ticket.id).toList();
      expect([for (final t in updates) t.supportTyping], [false, true, false]);
      final replied = updates.last;
      expect(replied.status, HelpTicketStatus.replied);
      expect(replied.credit?.amountKobo, 150000);
      expect(replied.credit?.id, kudiBox.creditId);
      expect(
        replied.messages.last.body,
        'Thanks, Adaeze. All three steps confirmed. ₦1,500.00 is in your '
        'wallet.',
      );
      final resolved = await service.resolve(ticket.id);
      expect(resolved.status, HelpTicketStatus.resolved);
    });

    test('a credit lands on the wallet once', () async {
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            DemoRepository(DemoData(now: figmaNow)),
          ),
          clockProvider.overrideWithValue(() => figmaNow),
        ],
      );
      addTearDown(container.dispose);
      await container.read(walletProvider.future);
      final credit = LedgerEntry(
        id: kudiBox.creditId,
        type: LedgerType.award,
        amountKobo: kudiBox.rewardKobo,
        createdAt: figmaNow,
      );
      container.read(walletProvider.notifier)
        ..credit(credit)
        ..credit(credit);
      final wallet = container.read(walletProvider).value!;
      expect(wallet.ledger.where((l) => l.id == kudiBox.creditId).length, 1);
      expect(wallet.totals.withdrawableKobo, 1650000);
    });
  });

  test('the bubbles follow the votes', () async {
    final container = ProviderContainer(
      overrides: [
        pollsServiceProvider.overrideWithValue(
          DemoPollsService(delay: Duration.zero, clock: () => figmaNow),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(pollsProvider.notifier);
    await container.read(pollsProvider.future);
    expect(await notifier.vote('p3', 0), isTrue);
    final unibooks = container
        .read(pollsProvider)
        .value!
        .firstWhere((b) => b.id == 'unibooks');
    expect(unibooks.brand.unanswered, 0);
  });
}
