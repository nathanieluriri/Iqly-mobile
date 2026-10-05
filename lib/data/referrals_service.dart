import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deadline.dart';
import 'models.dart';
import 'share_service.dart';

enum InviteStatus { won, joined, invited }

/// A friend the person invited, and how far they got.
class Invite {
  const Invite({required this.name, required this.status, this.at});

  final String name;
  final InviteStatus status;

  /// When they joined (joined) or were invited (invited).
  final DateTime? at;
}

/// The person's own code and who used it. [invitedBy] is the friend whose
/// code the person added, if any.
class Referrals {
  const Referrals({
    required this.code,
    required this.invites,
    required this.memberSince,
    this.invitedBy,
  });

  final String code;
  final List<Invite> invites;
  final DateTime memberSince;
  final String? invitedBy;

  int get joined =>
      invites.where((i) => i.status != InviteStatus.invited).length;

  Referrals withInviter(String name) => Referrals(
    code: code,
    invites: invites,
    memberSince: memberSince,
    invitedBy: name,
  );
}

enum InviteCodeOutcome { applied, invalid, expired, ownCode }

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

  /// How long Copy reads Copied.
  static const copiedFor = Duration(seconds: 2);

  static String message(String code) =>
      'Join me on iQLY. Businesses pay for good ideas. Use my code $code and '
      'we both get ₦500 when you win your first brief. ${link(code)}';
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
    .where(
      (l) => l.type == LedgerType.award && l.source == RewardSource.referral,
    )
    .fold(0, (sum, l) => sum + l.amountKobo);

final referralsServiceProvider = Provider<ReferralsService>(
  (ref) => DemoReferralsService(now: ref.watch(clockProvider)()),
);
