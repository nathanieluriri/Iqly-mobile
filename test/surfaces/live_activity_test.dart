import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/surfaces/live_activity.dart';

void main() {
  final now = DateTime(2026, 10, 3, 9, 41);
  final w3 = DemoData(now: now).withdrawals.firstWhere((w) => w.id == 'w3');

  test('lock screen lines (347:16446)', () {
    final s = PayoutActivityState.of(w3, notificationId: 'n1')!;
    expect(s.headline, '₦10,000.00 on its way');
    expect(s.detail, 'To Access Bank ••6789 · usually within minutes');
    expect(s.compact, 'On its way');
    expect(PayoutActivityState.steps, ['Requested', 'Sent', 'Arrived']);
    expect(s.step, PayoutStep.requested);
    expect(s.route, '/notifications/n1');
  });

  test('steps follow the withdrawal', () {
    expect(
      PayoutActivityState.of(
        w3.copyWith(sentAt: now),
        notificationId: 'n1',
      )!.step,
      PayoutStep.sent,
    );
    final arrived = PayoutActivityState.of(
      w3.copyWith(
        status: WithdrawalStatus.completed,
        completedAt: DateTime(2026, 10, 3, 15, 6),
      ),
      notificationId: 'n1',
    )!;
    expect(arrived.finished, isTrue);
    expect(arrived.headline, '₦10,000.00 paid out');
    expect(arrived.detail, 'Arrived at Access Bank ••6789 at 3:06 pm');
    expect(
      PayoutActivityState.of(
        w3.copyWith(status: WithdrawalStatus.failed),
        notificationId: 'n1',
      ),
      isNull,
    );
  });

  test('ContentState json', () {
    expect(PayoutActivityState.of(w3, notificationId: 'n1')!.toJson(), {
      'withdrawalId': 'w3',
      'amount': '₦10,000.00',
      'headline': '₦10,000.00 on its way',
      'detail': 'To Access Bank ••6789 · usually within minutes',
      'step': 1,
      'steps': ['Requested', 'Sent', 'Arrived'],
      'compact': 'On its way',
      'link': 'iqly://app/notifications/n1',
    });
  });
}
