import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deadline.dart';
import '../core/money.dart';
import '../core/session.dart';
import '../core/backend.dart';
import 'api_client.dart';
import 'live/live_account.dart';
import 'live/live_repository.dart' show liveModeProvider;
import 'models.dart';
import 'share_service.dart';

enum InviteStatus { won, joined, invited }

enum ReferralRewardStatus { pending, paid, capped, notEligible }

/// One referral reward as the API decided it (contract 12.3): what it pays
/// or would pay, and when and on which ledger row it was paid.
class ReferralReward {
  const ReferralReward({
    required this.status,
    required this.amountKobo,
    this.at,
    this.ledgerId,
  });

  final ReferralRewardStatus status;

  /// What it pays or would pay; 0 where the API names no amount (a reward
  /// capped or not owed).
  final int amountKobo;
  final DateTime? at;
  final String? ledgerId;

  bool get paid => status == ReferralRewardStatus.paid;
}

/// What referrals pay (contract 12.3): the inviter's and the invited
/// friend's amounts, and what the person has been paid so far.
class ReferralTerms {
  const ReferralTerms({
    required this.amountKobo,
    required this.inviteeAmountKobo,
    this.earnedKobo,
  });

  /// The preview's ₦500 each way.
  static const demo = ReferralTerms(
    amountKobo: 50000,
    inviteeAmountKobo: 50000,
  );

  /// To the person who invited, for a friend's first win.
  final int amountKobo;

  /// To the friend, for their own first win.
  final int inviteeAmountKobo;

  /// Every referral reward paid to the person, their own included; null
  /// where the wallet's ledger counts it (the preview).
  final int? earnedKobo;

  /// "₦500" for inviting, while that half pays.
  String? get inviterReward => amountKobo > 0 ? rewardPool(amountKobo) : null;

  /// "₦500" for the friend's own first win, while that half pays.
  String? get inviteeReward =>
      inviteeAmountKobo > 0 ? rewardPool(inviteeAmountKobo) : null;

  /// Both halves pay, so "you both get" holds.
  bool get both => amountKobo > 0 && inviteeAmountKobo > 0;
}

/// A friend the person invited, and how far they got.
class Invite {
  const Invite({
    required this.name,
    required this.status,
    this.at,
    this.reward,
  });

  final String name;
  final InviteStatus status;

  /// When they joined (joined) or were invited (invited).
  final DateTime? at;

  /// The person's reward for this friend, once the API decides one.
  final ReferralReward? reward;
}

/// The person's own code and who used it. [invitedBy] is the friend whose
/// code the person added, if any.
class Referrals {
  const Referrals({
    required this.code,
    required this.invites,
    required this.memberSince,
    this.invitedBy,
    this.applyUntil,
    this.invitedByReward,
    this.terms,
  });

  final String code;
  final List<Invite> invites;
  final DateTime memberSince;
  final String? invitedBy;

  /// The last moment a friend's code can be added, when the API says.
  final DateTime? applyUntil;

  /// The person's own reward for joining with [invitedBy]'s code.
  final ReferralReward? invitedByReward;

  /// What referrals pay, while the API pays them.
  final ReferralTerms? terms;

  int get won => invites.where((i) => i.status == InviteStatus.won).length;

  int get joined =>
      invites.where((i) => i.status != InviteStatus.invited).length;

  Referrals withInviter(String name) => Referrals(
    code: code,
    invites: invites,
    memberSince: memberSince,
    invitedBy: name,
    applyUntil: applyUntil,
    invitedByReward: invitedByReward,
    terms: terms,
  );
}

enum InviteCodeOutcome {
  applied,
  invalid,
  expired,
  ownCode,

  /// A friend's code was added before; one per account.
  alreadyApplied,

  /// The code's owner joined with this person's code.
  circular,
  tooManyTries,
  closing,
  offline,
  unknown,
}

class InviteCodeResult {
  const InviteCodeResult(this.outcome, {this.inviter});

  final InviteCodeOutcome outcome;

  /// "Chidi A.", on [InviteCodeOutcome.applied].
  final String? inviter;
}

/// Referrals (B20): the person's code, their invites, and adding a friend's
/// code. Referral rewards themselves are ledger rows (RewardSource.referral).
abstract class ReferralsService {
  Future<Referrals> referrals();
  Future<InviteCodeResult> applyCode(String code);

  /// Who owns [code], when it is a friend's code that can still be used.
  Future<String?> inviterOf(String code);

  /// Shares the invite [text] straight to [app], or through the system
  /// share sheet when [app] is null (More…).
  Future<void> shareInvite(String text, {ShareApp? app});

  /// Saves the invite card to the photo library; false when refused.
  Future<bool> saveInviteImage(String code);

  /// The link a share carries: "iqly.net/r/ADAEZE24".
  static String link(String code) => 'iqly.net/r/$code';

  /// The code lookup waits for typing to pause this long: the API limits
  /// it per phone.
  static const lookupPause = Duration(milliseconds: 300);

  /// How long Copy reads Copied.
  static const copiedFor = Duration(seconds: 2);

  /// [reward] is what the friend gets for their first win ("₦500"), or
  /// null while referrals pay nothing.
  static String message(String code, {required String? reward}) =>
      reward != null
      ? 'Join me on iQLY. Businesses pay for good ideas. Use my code $code and '
            'we both get $reward when you win your first brief. ${link(code)}'
      : 'Join me on iQLY. Businesses pay for good ideas. Use my code $code '
            'when you sign up. ${link(code)}';
}

/// The B20 frames' people. Ngozi E. and Tunde A. won a first brief, so their
/// ₦500 rewards are the DemoData ledger rows l5 and l4; Tunde F. joined two
/// weeks ago, Bola A. has not joined. TUNDE07 applies (Chidi A. invited
/// you); EMEKA15 has expired; any other code does not exist.
class DemoReferralsService implements ReferralsService {
  DemoReferralsService({DateTime? now, this.delay = Duration.zero})
    : now = now ?? DateTime.now();

  final DateTime now;
  final Duration delay;

  static const code = 'ADAEZE24';
  static const validCode = 'TUNDE07';
  static const expiredCode = 'EMEKA15';
  static const inviter = 'Chidi A.';

  final applied = <String>[];
  final shared = <({String text, ShareApp? app})>[];
  final savedImages = <String>[];

  @override
  Future<void> shareInvite(String text, {ShareApp? app}) async =>
      shared.add((text: text, app: app));

  @override
  Future<bool> saveInviteImage(String code) async {
    savedImages.add(code);
    return true;
  }

  @override
  Future<Referrals> referrals() async => Referrals(
    code: code,
    memberSince: DateTime(2026, 9, 2),
    invites: [
      const Invite(name: 'Ngozi E.', status: InviteStatus.won),
      const Invite(name: 'Tunde A.', status: InviteStatus.won),
      Invite(
        name: 'Tunde F.',
        status: InviteStatus.joined,
        at: now.subtract(const Duration(days: 14)),
      ),
      const Invite(name: 'Bola A.', status: InviteStatus.invited),
    ],
  );

  @override
  Future<String?> inviterOf(String code) async =>
      code.trim().toUpperCase() == validCode ? inviter : null;

  @override
  Future<InviteCodeResult> applyCode(String typed) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final value = typed.trim().toUpperCase();
    if (value == code) {
      return const InviteCodeResult(InviteCodeOutcome.ownCode);
    }
    if (value == expiredCode) {
      return const InviteCodeResult(InviteCodeOutcome.expired);
    }
    if (value != validCode) {
      return const InviteCodeResult(InviteCodeOutcome.invalid);
    }
    applied.add(value);
    return const InviteCodeResult(InviteCodeOutcome.applied, inviter: inviter);
  }
}

/// The referral rewards in [ledger], the "Earned" on Referral history.
int referralEarnedKobo(List<LedgerEntry> ledger) => ledger
    .where((l) => l.earned && l.source == RewardSource.referral)
    .fold(0, (sum, l) => sum + l.amountKobo);

/// Referrals on the iQLY API (contract 10.4), with their rewards while the
/// API pays them (12.3). Sharing stays with [sharing].
class LiveReferralsService implements ReferralsService {
  LiveReferralsService(this.link, {required this.sharing});

  final AccountLink link;
  final ReferralsService sharing;

  @override
  Future<Referrals> referrals() async {
    final json = await link.fetch('/me/referrals', AccountKeys.referrals);
    return referralsFromJson(json);
  }

  @override
  Future<InviteCodeResult> applyCode(String code) async {
    final ApiResponse res;
    try {
      res = await link.scope.guard(
        link.api.post('/me/referrals/apply', {'code': code}),
      );
    } on ApiUnreachable {
      return const InviteCodeResult(InviteCodeOutcome.offline);
    }
    if (res.ok) {
      return InviteCodeResult(
        InviteCodeOutcome.applied,
        inviter: apiText(res.data['inviter']),
      );
    }
    return InviteCodeResult(inviteCodeOutcome(res.code));
  }

  var _lookups = 0;

  /// The code an invite link brought, queued so it lands once the API
  /// answers; a refusal is heard where the outbox reports it.
  Future<void> queueApply(String code) =>
      link.queue(AccountWrite.referralApply, {'code': code});

  /// Asks only once typing pauses: a newer lookup makes this one answer
  /// null without asking.
  @override
  Future<String?> inviterOf(String code) async {
    final lookup = ++_lookups;
    await Future<void>.delayed(ReferralsService.lookupPause);
    if (lookup != _lookups) return null;
    try {
      return await lookUpInviter(link.api, code);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> shareInvite(String text, {ShareApp? app}) =>
      sharing.shareInvite(text, app: app);

  @override
  Future<bool> saveInviteImage(String code) => sharing.saveInviteImage(code);
}

/// What an apply refusal means for the person (contract 10.4).
InviteCodeOutcome inviteCodeOutcome(String? code) => switch (code) {
  'INVITE_CODE_INVALID' || 'NOT_FOUND' => InviteCodeOutcome.invalid,
  'INVITE_CODE_EXPIRED' => InviteCodeOutcome.expired,
  'INVITE_CODE_OWN' => InviteCodeOutcome.ownCode,
  'INVITE_CODE_ALREADY_APPLIED' => InviteCodeOutcome.alreadyApplied,
  'INVITE_CODE_CIRCULAR' => InviteCodeOutcome.circular,
  'RATE_LIMITED' => InviteCodeOutcome.tooManyTries,
  'ACCOUNT_CLOSING' => InviteCodeOutcome.closing,
  _ => InviteCodeOutcome.unknown,
};

/// `GET /referrals/codes/:code`: who owns [code], or null when no one does
/// (404 INVITE_CODE_INVALID). Throws [ApiUnreachable] or [ApiRefused] when
/// the API cannot say.
Future<String?> lookUpInviter(ApiClient api, String code) async {
  final typed = code.trim();
  if (typed.isEmpty) return null;
  final res = await api.get('/referrals/codes/${Uri.encodeComponent(typed)}');
  if (res.code == 'INVITE_CODE_INVALID') return null;
  if (!res.ok) throw ApiRefused.of(res);
  return apiText(res.data['inviter']);
}

/// `GET /me/referrals`. A status the app does not know reads as joined;
/// a reward the app cannot read reads as none.
Referrals referralsFromJson(Map<String, dynamic> json) {
  final invites = json['invites'];
  final rewards = json['rewards'];
  return Referrals(
    code: apiText(json['code']) ?? '',
    memberSince: apiTime(json['memberSince']) ?? DateTime.now(),
    invitedBy: apiText(json['invitedBy']),
    applyUntil: apiTime(json['applyUntil']),
    invitedByReward: referralRewardFromJson(json['invitedByReward']),
    terms: rewards is Map && rewards['enabled'] == true
        ? ReferralTerms(
            amountKobo: apiInt(rewards['amountKobo']) ?? 0,
            inviteeAmountKobo: apiInt(rewards['inviteeAmountKobo']) ?? 0,
            earnedKobo: apiInt(rewards['earnedKobo']),
          )
        : null,
    invites: [
      if (invites is List)
        for (final invite in invites)
          if (invite is Map)
            Invite(
              name: apiText(invite['name']) ?? '',
              status: switch (invite['status']) {
                'won' => InviteStatus.won,
                'invited' => InviteStatus.invited,
                _ => InviteStatus.joined,
              },
              at: apiTime(invite['at']),
              reward: referralRewardFromJson(invite['reward']),
            ),
    ],
  );
}

ReferralReward? referralRewardFromJson(Object? json) {
  if (json is! Map) return null;
  final status = switch (json['status']) {
    'pending' => ReferralRewardStatus.pending,
    'paid' => ReferralRewardStatus.paid,
    'capped' => ReferralRewardStatus.capped,
    'not_eligible' => ReferralRewardStatus.notEligible,
    _ => null,
  };
  if (status == null) return null;
  return ReferralReward(
    status: status,
    amountKobo: apiInt(json['amountKobo']) ?? 0,
    at: apiTime(json['at']),
    ledgerId: apiText(json['ledgerId']),
  );
}

/// Whether referrals show this launch: always in the preview, and in a live
/// launch only while the API runs them.
final referralsShownProvider = Provider<bool>((ref) {
  final mode = ref.watch(liveModeProvider);
  return mode.isPreview || mode.isLive(LiveFeature.referrals);
});

/// The demo in a preview launch, the API while referrals run live; a live
/// launch without them refuses, so no sample code shows as the person's.
final referralsServiceProvider = Provider<ReferralsService>((ref) {
  ref.watch(accountProvider);
  final demo = DemoReferralsService(now: ref.watch(clockProvider)());
  if (ref.watch(liveModeProvider).isPreview) return demo;
  final link = ref.watch(liveLinkProvider(LiveFeature.referrals));
  if (link == null) return const PausedReferralsService();
  return LiveReferralsService(link, sharing: demo);
});

/// Referrals a live launch does not run: reads fail, nothing is sent.
class PausedReferralsService implements ReferralsService {
  const PausedReferralsService();

  static Future<Never> _paused() =>
      Future.error(const FeaturePaused(LiveFeature.referrals));

  @override
  Future<Referrals> referrals() => _paused();

  @override
  Future<InviteCodeResult> applyCode(String code) => _paused();

  @override
  Future<String?> inviterOf(String code) async => null;

  @override
  Future<void> shareInvite(String text, {ShareApp? app}) => _paused();

  @override
  Future<bool> saveInviteImage(String code) => _paused();
}
