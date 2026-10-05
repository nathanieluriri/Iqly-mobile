/// Activations: short tasks a business pays for, verified by the business
/// (B8) or, when a step goes unconfirmed, by a recording the contributor
/// sends (B9). A design proposal behind Flags.activations: demo.ts has no
/// rows for it, so the demo values below come from the Figma frames.
library;

/// The activation rules (business rules, not motion).
abstract final class ActivationRules {
  /// A step the business has not confirmed within this window can be
  /// proven with a recording (B9 row note: "past the 24-hour window").
  static const confirmWindow = Duration(hours: 24);

  /// The longest recording accepted as proof ("UP TO 60 SECONDS").
  static const proofLength = Duration(seconds: 60);

  /// Under this the countdown counts hours ("36h"), then days ("2 days").
  static const countsHours = Duration(days: 2);

  /// Activations closing within this put their deadline on the Urgent pill
  /// and count on Discover as closing today.
  static const closingSoon = Duration(days: 1);

  /// The largest recording accepted as proof.
  static const proofBytes = 50000000;
}

class ActivationStep {
  const ActivationStep({required this.title, required this.hint, this.howTo});

  final String title;

  /// The body while the step waits to be done ("Settings → Verification").
  final String hint;

  /// The body on the offer, before it starts, when it says more than [hint]
  /// ("Settings → Verification. About 2 min").
  final String? howTo;
}

/// The recording picked as proof. [length] is null when the picker cannot
/// read it (the phone's own picker gives the file only).
class ProofVideo {
  const ProofVideo({required this.name, required this.bytes, this.length});

  final String name;
  final int bytes;
  final Duration? length;

  bool get tooLong {
    final length = this.length;
    return length != null && length > ActivationRules.proofLength;
  }

  bool get tooLarge => bytes > ActivationRules.proofBytes;

  /// Over either limit: the upload is refused before it starts.
  bool get refused => tooLong || tooLarge;
}

class ActivationProof {
  const ActivationProof({
    required this.step,
    required this.video,
    required this.receivedAt,
    this.checkedAt,
    this.notAccepted,
  });

  /// The index of the step it proves.
  final int step;
  final ProofVideo video;
  final DateTime receivedAt;

  /// When iQLY confirmed it with the business; null while checking.
  final DateTime? checkedAt;

  /// Why the business turned it down ("The recording ends before the
  /// Verification page."); null unless it was.
  final String? notAccepted;

  bool get accepted => notAccepted == null;

  ActivationProof checked(DateTime at) => ActivationProof(
    step: step,
    video: video,
    receivedAt: receivedAt,
    checkedAt: at,
  );

  ActivationProof refused(String reason) => ActivationProof(
    step: step,
    video: video,
    receivedAt: receivedAt,
    notAccepted: reason,
  );
}

/// Your run at an activation.
class ActivationProgress {
  const ActivationProgress({
    required this.startedAt,
    this.confirmedAt = const [],
    this.proof,
    this.paidAt,
  });

  final DateTime startedAt;

  /// When the business confirmed each step, in step order.
  final List<DateTime> confirmedAt;

  final ActivationProof? proof;

  /// When the reward reached the wallet; the activation is done.
  final DateTime? paidAt;

  ActivationProgress copyWith({
    List<DateTime>? confirmedAt,
    ActivationProof? proof,
    DateTime? paidAt,
  }) => ActivationProgress(
    startedAt: startedAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    proof: proof ?? this.proof,
    paidAt: paidAt ?? this.paidAt,
  );
}

/// Where an activation stands for you.
enum ActivationPhase {
  /// Not started: the offer with Start activation.
  offer,

  /// Started, nothing confirmed yet.
  started,

  /// A step is waiting for the business to confirm it.
  confirming,

  /// That step has waited past [ActivationRules.confirmWindow]: proof can
  /// be sent.
  notConfirmed,

  /// Proof sent; iQLY is checking it with the business.
  checking,

  /// The business turned the proof down; it can be recorded again.
  notAccepted,

  /// Paid to the wallet.
  credited,

  /// Closed before it was finished, or before it was started.
  expired,
}

class Activation {
  const Activation({
    required this.id,
    required this.business,
    required this.title,
    required this.minutes,
    required this.rewardKobo,
    required this.closesAt,
    required this.spotsLeft,
    required this.spotsTotal,
    required this.steps,
    required this.link,
    this.progress,
  });

  final String id;
  final String business;
  final String title;

  /// "about 10 min".
  final int minutes;
  final int rewardKobo;
  final DateTime closesAt;
  final int spotsLeft;
  final int spotsTotal;
  final List<ActivationStep> steps;

  /// Where "Open Kudi Box" goes: the business's app or its store page.
  final Uri link;

  /// Null until you start it.
  final ActivationProgress? progress;

  bool get started => progress != null;

  bool get credited => progress?.paidAt != null;

  /// Started and not paid yet.
  bool get inFlight => started && !credited;

  int get confirmed => progress?.confirmedAt.length ?? 0;

  bool get full => spotsLeft <= 0;

  bool closedAt(DateTime now) => !closesAt.isAfter(now);

  /// The step the business is confirming, once one step is confirmed and
  /// until the last is, while no accepted proof stands in for it.
  int? get waitingStep {
    final run = progress;
    if (run == null || credited || (run.proof?.accepted ?? false)) return null;
    final done = run.confirmedAt.length;
    if (done == 0 || done >= steps.length) return null;
    return done;
  }

  /// The ledger row its reward lands as, whoever pays it (the business's
  /// confirmation or support), so it counts once.
  String get creditId => creditIdOf(id);

  /// [creditId] for the activation with [activationId].
  static String creditIdOf(String activationId) => 'activation-$activationId';

  /// Since when [waitingStep] has waited: its predecessor's confirmation.
  DateTime? get waitingSince =>
      waitingStep == null ? null : progress!.confirmedAt.last;

  ActivationPhase phaseAt(DateTime now) {
    final run = progress;
    if (credited) return ActivationPhase.credited;
    final proof = run?.proof;
    if (proof != null) {
      return proof.accepted
          ? ActivationPhase.checking
          : ActivationPhase.notAccepted;
    }
    if (closedAt(now)) return ActivationPhase.expired;
    if (run == null) return ActivationPhase.offer;
    final since = waitingSince;
    if (since == null) {
      return run.confirmedAt.isEmpty
          ? ActivationPhase.started
          : ActivationPhase.confirming;
    }
    return now.difference(since) >= ActivationRules.confirmWindow
        ? ActivationPhase.notConfirmed
        : ActivationPhase.confirming;
  }

  Activation withProgress(ActivationProgress progress) => Activation(
    id: id,
    business: business,
    title: title,
    minutes: minutes,
    rewardKobo: rewardKobo,
    closesAt: closesAt,
    spotsLeft: spotsLeft,
    spotsTotal: spotsTotal,
    steps: steps,
    link: link,
    progress: progress,
  );
}

/// The activations of the Figma frames (rows B8 and B9) at [now]: rewards,
/// times left and Kudi Box's steps are the frames'. Orchid Foods and
/// Unibooks have no detail frame, so their steps reuse Kudi Box's first step
/// and add their own (written for the demo, listed for the owner).
class DemoActivations {
  DemoActivations(this.now);

  final DateTime now;

  static const signUp = ActivationStep(
    title: 'Sign up with code IQLY',
    hint: 'Enter IQLY at the referral step.',
  );

  late final orchidFoods = Activation(
    id: 'a1',
    business: 'Orchid Foods',
    title: 'Rate 3 recipes in the Orchid Foods app',
    minutes: 5,
    rewardKobo: 50000,
    closesAt: now.add(const Duration(hours: 5, minutes: 40)),
    spotsLeft: 38,
    spotsTotal: 1600,
    steps: const [
      signUp,
      ActivationStep(
        title: 'Rate your first recipe',
        hint: 'Any recipe counts.',
      ),
      ActivationStep(
        title: 'Rate two more recipes',
        hint: 'Three ratings in all.',
      ),
    ],
    link: Uri.parse('https://orchidfoods.example/app'),
  );

  late final kudiBox = Activation(
    id: 'a2',
    business: 'Kudi Box',
    title: 'Open a Kudi Box account and save ₦1,000.00',
    minutes: 10,
    rewardKobo: 150000,
    closesAt: now.add(const Duration(days: 2, hours: 6)),
    spotsLeft: 188,
    spotsTotal: 500,
    steps: const [
      signUp,
      ActivationStep(
        title: 'Verify your BVN in the app',
        hint: 'Settings → Verification',
        howTo: 'Settings → Verification. About 2 min',
      ),
      ActivationStep(
        title: 'Make your first save of ₦1,000.00',
        hint: 'Any savings plan counts.',
      ),
    ],
    link: Uri.parse('https://kudibox.example/app'),
  );

  late final unibooks = Activation(
    id: 'a3',
    business: 'Unibooks',
    title: 'Place your first Unibooks order',
    minutes: 5,
    rewardKobo: 80000,
    closesAt: now.add(const Duration(days: 2, hours: 6)),
    spotsLeft: 120,
    spotsTotal: 200,
    steps: const [
      signUp,
      ActivationStep(title: 'Place an order', hint: 'Any book counts.'),
    ],
    link: Uri.parse('https://unibooks.example/app'),
  );

  /// The B9 situation: started yesterday, step 1 confirmed 24 h 20 min ago
  /// (Figma: Thu, 1:52 pm, seen on Friday afternoon), step 2 still waiting.
  ActivationProgress get stuckAtStep2 => ActivationProgress(
    startedAt: now.subtract(const Duration(days: 1, hours: 1)),
    confirmedAt: [now.subtract(const Duration(days: 1, minutes: 20))],
  );

  /// Started an hour ago, nothing confirmed yet.
  ActivationProgress get justStarted =>
      ActivationProgress(startedAt: now.subtract(const Duration(hours: 1)));

  /// Why the business turns a proof down (B9 · Proof · not accepted).
  static const endsEarly = 'The recording ends before the Verification page.';

  /// The app's demo, as B8 · My activations shows it: Orchid Foods and Kudi
  /// Box under way (Kudi Box past its window at step 2, so its proof flow
  /// opens), Unibooks still an offer.
  List<Activation> get all => [
    orchidFoods.withProgress(justStarted),
    kudiBox.withProgress(stuckAtStep2),
    unibooks,
  ];
}
