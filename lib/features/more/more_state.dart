import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/cache_service.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../referrals/referrals_state.dart';
import '../wallet/wallet_state.dart';

/// The release the footer names (B7 · More): "IQLY FOR IOS 1.4.2 (310)".
abstract final class AppRelease {
  static const version = '1.4.2';
  static const build = 310;

  static String footer({required bool ios}) =>
      'iQLY for ${ios ? 'iOS' : 'Android'} $version ($build)'.toUpperCase();
}

/// What the Exp/AchievementCard on More shows, all from the account: the
/// wallet's lifetime earned, the iQL points, the submissions and wins, the
/// month the account opened and the invite code.
class ContributorPass {
  const ContributorPass({
    required this.user,
    required this.earned,
    required this.points,
    required this.since,
    required this.submissions,
    required this.wins,
    required this.code,
    required this.joined,
  });

  final User user;
  final String earned;

  /// iQL points, the pass's right-hand field (designer doc rev 57).
  final int points;
  final String since;
  final int submissions;
  final int wins;
  final String code;

  /// Friends who joined with the code: "3 joined".
  final int joined;
}

final contributorPassProvider = FutureProvider<ContributorPass>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final (user, submissions, points, wallet, referrals) = await (
    repo.user(),
    repo.submissions(),
    repo.points(),
    ref.watch(walletProvider.future),
    ref.watch(referralsProvider.future),
  ).wait;
  final won = [
    for (final s in submissions)
      if (s.status == SubmissionStatus.winner) s,
  ];
  return ContributorPass(
    user: user,
    earned: naira(wallet.totals.totalEarnedKobo),
    points: points,
    since: DateFormat('MMM y').format(referrals.memberSince),
    submissions: submissions.length,
    wins: won.length,
    code: referrals.code,
    joined: referrals.joined,
  );
});

class CacheNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => ref.watch(cacheServiceProvider).sizeBytes();

  Future<void> clear() async {
    await ref.read(cacheServiceProvider).clear();
    state = const AsyncData(0);
  }
}

final cacheProvider = AsyncNotifierProvider<CacheNotifier, int>(
  CacheNotifier.new,
);
