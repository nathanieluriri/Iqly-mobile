import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../data/polls_data.dart';
import 'notification_content.dart';
import 'notification_sounds.dart';
import 'surfaces.dart';

/// The B18 and B19 examples on the sample records their frames show: the
/// ₦10,000.00 withdrawal to Access Bank ••6789 (w3), the Orchid Foods polls,
/// the ₦12,500.00 win for "Sunday is data day" (l3) and the Sunline draft
/// six hours before the close (c5).
class SurfaceSamples {
  SurfaceSamples(this.now) : _data = DemoData(now: now);

  final DateTime now;
  final DemoData _data;

  late final SurfaceInputs inputs = SurfaceInputs.demo(now);

  /// w3 asked for, then sent, then paid out.
  List<Withdrawal> get payoutSteps {
    final w = _data.withdrawals.firstWhere((w) => w.id == 'w3');
    return [
      w,
      w.copyWith(status: WithdrawalStatus.processing, sentAt: now),
      w.copyWith(
        status: WithdrawalStatus.completed,
        sentAt: now,
        completedAt: now,
      ),
    ];
  }

  SurfaceNotification get poll => pollNotification(
    demoPolls(now).firstWhere((b) => b.name == 'Orchid Foods'),
  )!;

  SurfaceNotification get won {
    final award = _data.ledger.firstWhere((l) => l.id == 'l3');
    final submission = _data.submissions.firstWhere(
      (s) => s.id == award.submissionId,
    );
    final brief = _data.briefs.firstWhere((b) => b.id == submission.briefId);
    return resultNotification(
      award,
      submission,
      brief,
      notificationId: inputs.feedIdFor(award.id)!,
    );
  }

  SurfaceNotification get draft {
    final brief = _data.briefs.firstWhere((b) => b.id == 'c5');
    final row = inputs.feed.firstWhere((n) => n.briefId == brief.id);
    return draftNotification(brief, now, notificationId: row.id)!;
  }

  /// Remind me on the Sunline brief, as if it closed an hour from now.
  SurfaceNotification get reminder {
    final b = _data.briefs.firstWhere((b) => b.id == 'c5');
    return closeReminderNotification(
      Brief(
        id: b.id,
        title: b.title,
        body: b.body,
        tier: b.tier,
        category: b.category,
        rewardPoolKobo: b.rewardPoolKobo,
        status: b.status,
        deadline: now.add(closeReminderLead),
        businessName: b.businessName,
        createdAt: b.createdAt,
      ),
    )!;
  }
}

/// What Try notifications does with a tap: its notification lands
/// [landsAfter] later, so the phone can be locked first, and the payout
/// then moves on to Sent and Arrived [stepEvery] apart. Each one lands even
/// when its topic is off in Notification preferences, as polls are by
/// default.
class NotificationTrial {
  NotificationTrial(this._surfaces, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Surfaces _surfaces;
  final DateTime Function() _clock;

  static const landsAfter = Duration(seconds: 3);
  static const stepEvery = Duration(milliseconds: 2500);

  Future<void> payout() async {
    final samples = SurfaceSamples(_clock());
    for (final (i, step) in samples.payoutSteps.indexed) {
      await Future<void>.delayed(i == 0 ? landsAfter : stepEvery);
      await _surfaces.payoutChanged(step, samples.inputs, anyway: true);
    }
  }

  Future<void> poll() => _land((s) => s.poll);

  Future<void> won() => _land((s) => s.won);

  Future<void> draft() => _land((s) => s.draft);

  Future<void> reminder() => _land((s) => s.reminder);

  Future<void> sound(IqSound sound) async {
    await Future<void>.delayed(landsAfter);
    await _surfaces.playSample(sound);
  }

  /// True when the phone has the widgets to draw them.
  Future<bool> widgets() => _surfaces.publish(SurfaceSamples(_clock()).inputs);

  Future<void> _land(SurfaceNotification Function(SurfaceSamples) pick) async {
    await Future<void>.delayed(landsAfter);
    await _surfaces.show(pick(SurfaceSamples(_clock())), anyway: true);
  }
}

/// Null wherever the surfaces did not start (tests, Windows).
final notificationTrialProvider = Provider<NotificationTrial?>((ref) {
  final surfaces = ref.watch(surfacesProvider);
  return surfaces == null ? null : NotificationTrial(surfaces);
});
