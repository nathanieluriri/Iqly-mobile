/// Activations: short tasks a business pays for, verified by the business
/// (B8) or, when a step goes unconfirmed, by a recording the contributor
/// sends (B9), behind Flags.activations. demo.ts has no rows for them, so
/// the demo values below come from the Figma frames; a live launch reads
/// the API's (contract 11.2).
///
/// An activation whose [Activation.confirmationMode] is known follows the
/// owner's rules of 19 Oct (D1, D3): in proof mode each step is recorded in
/// order from the start and the business confirms each recording; in
/// postback mode the business's app confirms each step, and a step it
/// leaves unconfirmed for a day (the first one from the start) can be
/// proven. Without a mode the rules before them hold.
library;

import 'app_config.dart';

/// The activation rules (business rules, not motion).
abstract final class ActivationRules {
  /// A step the business has not confirmed within this window can be
  /// proven with a recording (B9 row note: "past the 24-hour window").
  static const confirmWindow = Duration(hours: 24);

  /// The longest recording accepted as proof ("UP TO 60 SECONDS").
  static Duration get proofLength =>
      Duration(seconds: AppConfig.current.proofVideoMaxSeconds);

  /// Under this the countdown counts hours ("36h"), then days ("2 days").
  static const countsHours = Duration(days: 2);

  /// Activations closing within this put their deadline on the Urgent pill
  /// and count on Discover as closing today.
  static const closingSoon = Duration(days: 1);

  /// The largest recording accepted as proof.
  static int get proofBytes => AppConfig.current.proofVideoMaxBytes;
}

/// How the business confirms each step.
enum ConfirmationMode {
  /// The person records each step and the business confirms the recording.
  proof,

  /// The business's app confirms each step with the run's code.
  postback,
}

/// When the reward is paid: once for the whole run, or step by step.
enum RewardMode { perRun, perStep }

class ActivationStep {
  const ActivationStep({
    required this.title,
    required this.hint,
    this.howTo,
    this.rewardKobo,
  });

  final String title;

  /// The body while the step waits to be done ("Settings → Verification").
  final String hint;

  /// The body on the offer, before it starts, when it says more than [hint]
  /// ("Settings → Verification. About 2 min").
  final String? howTo;

  /// What confirming this step pays, on a per-step activation.
  final int? rewardKobo;
}

/// A step paid on its own, on a per-step activation.
class ActivationStepPayout {
  const ActivationStepPayout({
    required this.step,
    required this.kobo,
    required this.paidAt,
    this.ledgerId,
  });

  final int step;
  final int kobo;
  final DateTime paidAt;

  /// The wallet credit that paid it, as the API names it.
  final String? ledgerId;
}

/// Postback mode: a step the business's server confirmed that waits out the
/// business's hold, settling at [until].
class ActivationHeldStep {
  const ActivationHeldStep({required this.step, this.until});

  final int step;
  final DateTime? until;
}

/// The recording picked as proof. [length] is null when the picker cannot
/// read it (the phone's own picker gives the file only). [source] is where
/// it plays from (a file, an Android content uri or the API's link); the
/// demo's recordings have none and show the phone silhouette.
class ProofVideo {
  const ProofVideo({
    required this.name,
    required this.bytes,
    this.length,
    this.source,
  });

  final String name;
  final int bytes;
  final Duration? length;
  final Uri? source;

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
    this.ledgerId,
    this.refCode,
    this.stepPayouts = const [],
    this.heldSteps = const [],
  });

  final DateTime startedAt;

  /// When the business confirmed each step, in step order.
  final List<DateTime> confirmedAt;

  final ActivationProof? proof;

  /// When the reward reached the wallet; the activation is done.
  final DateTime? paidAt;

  /// The wallet credit that paid it, as the API names it.
  final String? ledgerId;

  /// The run's code ("IQ-7K3P2"), which the business's app receives through
  /// the link in postback mode.
  final String? refCode;

  /// What each step paid so far, on a per-step activation.
  final List<ActivationStepPayout> stepPayouts;

  /// Steps the business's server confirmed that are waiting out its hold.
  final List<ActivationHeldStep> heldSteps;

  ActivationProgress copyWith({
    List<DateTime>? confirmedAt,
    ActivationProof? proof,
    DateTime? paidAt,
    List<ActivationStepPayout>? stepPayouts,
    List<ActivationHeldStep>? heldSteps,
  }) => ActivationProgress(
    startedAt: startedAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    proof: proof ?? this.proof,
    paidAt: paidAt ?? this.paidAt,
    ledgerId: ledgerId,
    refCode: refCode,
    stepPayouts: stepPayouts ?? this.stepPayouts,
    heldSteps: heldSteps ?? this.heldSteps,
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
  /// be sent. In postback mode the first step waits from the start.
  notConfirmed,

  /// Proof mode: the next step is yours to do and record.
  recording,

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
    this.live = false,
    this.logoUrl,
    this.imageUrl,
    this.paused = false,
    this.confirmationMode,
    this.rewardMode = RewardMode.perRun,
  });

  final String id;
  final String business;
  final String title;

  /// How its steps are confirmed; null keeps the rules from before the
  /// modes (the API does not say, or the launch does not run them).
  final ConfirmationMode? confirmationMode;
  final RewardMode rewardMode;

  /// From the API: its art is [logoUrl] and [imageUrl], never a sample
  /// business's, and the anonymous mark when it has none.
  final bool live;
  final String? logoUrl;
  final String? imageUrl;

  /// The business has stopped new starts for now; runs under way go on.
  final bool paused;

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

  /// Whether a recording can still go as proof: started, not paid, and
  /// open. A proof turned down after the close cannot be recorded again,
  /// as the run ended with the activation.
  bool canProveAt(DateTime now) => started && !credited && !closedAt(now);

  bool get perStep => rewardMode == RewardMode.perStep;

  /// What confirming step [i] pays: its own amount on a per-step
  /// activation; on a per-run one the reward, on its last step only once
  /// the run has a mode (D1: before, a checked proof paid the whole run).
  int paysFor(int i) {
    if (perStep) return i < steps.length ? steps[i].rewardKobo ?? 0 : 0;
    if (confirmationMode == null) return rewardKobo;
    return i == steps.length - 1 ? rewardKobo : 0;
  }

  /// Round 18: once more than one step pays, each paying step shows its
  /// amount.
  bool get showsStepRewards =>
      perStep && steps.where((s) => (s.rewardKobo ?? 0) > 0).length > 1;

  /// What step [i] was paid, once it was.
  ActivationStepPayout? payoutOf(int i) =>
      progress?.stepPayouts.where((p) => p.step == i).firstOrNull;

  /// Postback mode: step [i] is confirmed by the business's server and
  /// waits out its hold, so it is never one to prove.
  bool heldAt(int i) =>
      confirmationMode == ConfirmationMode.postback &&
      (progress?.heldSteps.any((h) => h.step == i) ?? false);

  /// Postback mode: whether any step waits out the business's hold.
  bool get holding =>
      confirmationMode == ConfirmationMode.postback &&
      (progress?.heldSteps.isNotEmpty ?? false);

  /// The proof that still stands: with a mode, one accepted or whose step
  /// is already confirmed is done with, as the API reads it, and so is any
  /// for a step the business has since reported and holds: the hold
  /// stands, as the API reads it too.
  ActivationProof? get pendingProof {
    final run = progress;
    final proof = run?.proof;
    if (run == null || proof == null) return null;
    if (confirmationMode == null) return proof;
    if (heldAt(proof.step)) return null;
    final accepted = proof.accepted && proof.checkedAt != null;
    return proof.step >= run.confirmedAt.length && !accepted ? proof : null;
  }

  /// The step the business is confirming, while no accepted proof stands in
  /// for it: from the first confirmation on, and in postback mode from the
  /// start. Proof mode has none: each step waits on its recording.
  int? get waitingStep {
    final run = progress;
    if (run == null || credited || (pendingProof?.accepted ?? false)) {
      return null;
    }
    final done = run.confirmedAt.length;
    if (done >= steps.length) return null;
    return switch (confirmationMode) {
      null => done == 0 ? null : done,
      ConfirmationMode.postback => done,
      ConfirmationMode.proof => null,
    };
  }

  /// The step a recording proves: the next one in proof mode, else the one
  /// waiting on the business, unless the business's hold has it.
  int? get proofStep {
    if (confirmationMode != ConfirmationMode.proof) {
      final step = waitingStep;
      return step == null || heldAt(step) ? null : step;
    }
    final run = progress;
    if (run == null || credited) return null;
    final done = run.confirmedAt.length;
    return done < steps.length ? done : null;
  }

  /// The ledger row its reward lands as, whoever pays it (the business's
  /// confirmation or support), so it counts once.
  String get creditId => creditIdOf(id);

  /// [creditId] for the activation with [activationId].
  static String creditIdOf(String activationId) => 'activation-$activationId';

  /// Since when [waitingStep] has waited: its predecessor's confirmation,
  /// or the start for the first step. A held step has no window to run out.
  DateTime? get waitingSince {
    final step = waitingStep;
    if (step == null || heldAt(step)) return null;
    final run = progress!;
    return step == 0 ? run.startedAt : run.confirmedAt.last;
  }

  ActivationPhase phaseAt(DateTime now) {
    final run = progress;
    if (credited) return ActivationPhase.credited;
    final proof = pendingProof;
    if (proof != null) {
      return proof.accepted
          ? ActivationPhase.checking
          : ActivationPhase.notAccepted;
    }
    // A step the business holds still pays when the hold ends, close or not.
    if (closedAt(now) && !holding) return ActivationPhase.expired;
    if (run == null) return ActivationPhase.offer;
    if (confirmationMode == ConfirmationMode.proof) {
      return proofStep == null
          ? ActivationPhase.confirming
          : ActivationPhase.recording;
    }
    final waiting = waitingStep;
    if (waiting != null && heldAt(waiting)) return ActivationPhase.confirming;
    final since = waitingSince;
    if (since != null &&
        now.difference(since) >= ActivationRules.confirmWindow) {
      return ActivationPhase.notConfirmed;
    }
    return run.confirmedAt.isEmpty
        ? ActivationPhase.started
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
    live: live,
    logoUrl: logoUrl,
    imageUrl: imageUrl,
    paused: paused,
    confirmationMode: confirmationMode,
    rewardMode: rewardMode,
  );
}

/// The activations of the Figma frames (rows B8 and B9) at [now]: rewards,
/// times left and Kudi Box's steps are the frames'. Orchid Foods and
/// Unibooks have no detail frame, so their steps reuse Kudi Box's first step
/// and add their own (written for the demo, listed for the owner). Kudi Box
/// and Unibooks are confirmed by the business's app, as B8 and B9 draw it;
/// Orchid Foods takes a recording of each step, so the preview walks the
/// proof flow of 19 Oct. Each pays per run, as the sample wallet foots;
/// [orchidFoodsByStep] is the same activation paid step by step (amounts
/// written for the demo).
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
    confirmationMode: ConfirmationMode.proof,
  );

  /// Orchid Foods paying ₦100, ₦200 and ₦200 as each step is confirmed.
  late final orchidFoodsByStep = Activation(
    id: orchidFoods.id,
    business: orchidFoods.business,
    title: orchidFoods.title,
    minutes: orchidFoods.minutes,
    rewardKobo: orchidFoods.rewardKobo,
    closesAt: orchidFoods.closesAt,
    spotsLeft: orchidFoods.spotsLeft,
    spotsTotal: orchidFoods.spotsTotal,
    steps: [
      for (final (i, step) in orchidFoods.steps.indexed)
        ActivationStep(
          title: step.title,
          hint: step.hint,
          howTo: step.howTo,
          rewardKobo: const [10000, 20000, 20000][i],
        ),
    ],
    link: orchidFoods.link,
    confirmationMode: ConfirmationMode.proof,
    rewardMode: RewardMode.perStep,
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
    confirmationMode: ConfirmationMode.postback,
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
    confirmationMode: ConfirmationMode.postback,
  );

  /// The B9 situation: started yesterday, step 1 confirmed 24 h 20 min ago
  /// (Figma: Thu, 1:52 pm, seen on Friday afternoon), step 2 still waiting.
  /// Its code is the one the owner's brief quotes.
  ActivationProgress get stuckAtStep2 => ActivationProgress(
    startedAt: now.subtract(const Duration(days: 1, hours: 1)),
    confirmedAt: [now.subtract(const Duration(days: 1, minutes: 20))],
    refCode: runCode,
  );

  static const runCode = 'IQ-7K3P2';

  /// Why the business turns a proof down (B9 · Proof · not accepted).
  static const endsEarly = 'The recording ends before the Verification page.';

  /// The app's demo: Kudi Box under way and past its window at step 2, so
  /// its proof flow opens; Orchid Foods and Unibooks still offers, as B3
  /// Pick a brief shows Orchid Foods.
  List<Activation> get all => [
    orchidFoods,
    kudiBox.withProgress(stuckAtStep2),
    unibooks,
  ];
}

/// The activation reward the sample wallet already holds (B5 Wallet 37:24,
/// Activity · Rewards 331:15107): Kudi Box, ₦1,500.00, three days ago, as an
/// award row. Its ledger id is Kudi Box's [Activation.creditId], so a payout
/// of the same activation in the app counts once.
abstract final class ActivationRewards {
  static const activationId = 'a2';
  static const business = 'Kudi Box';
  static const amountKobo = 150000;
  static const paidDaysAgo = 3;
  static const detail = 'Reward · activation · step 2 confirmed';

  static String get ledgerId => Activation.creditIdOf(activationId);
}
