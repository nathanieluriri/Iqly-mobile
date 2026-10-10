import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache_service.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../referrals/referrals_state.dart';

/// The release the footer names (B7 · More): "IQLY FOR IOS 1.4.2 (310)".
abstract final class AppRelease {
  static const version = '1.4.2';
  static const build = 310;

  static String footer({required bool ios}) =>
      'iQLY for ${ios ? 'iOS' : 'Android'} $version ($build)'.toUpperCase();
}

/// What the summary card on More and the header of Your profile show: the
/// name, the iQL points, this month's place on the points board (null when
/// the board has not ranked them) and the invite code.
class ContributorPass {
  const ContributorPass({
    required this.user,
    required this.points,
    required this.rank,
    required this.code,
  });

  final User user;
  final int points;
  final int? rank;
  final String code;
}

final contributorPassProvider = FutureProvider<ContributorPass>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final (user, points, board, referrals) = await (
    repo.user(),
    repo.points(),
    repo.pointsLeaderboard(),
    ref.watch(referralsProvider.future),
  ).wait;
  return ContributorPass(
    user: user,
    points: points,
    rank: board.you?.rank,
    code: referrals.code,
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
