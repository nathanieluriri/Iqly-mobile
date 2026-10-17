import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache_service.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../onboarding/onboarding_draft.dart';
import '../referrals/referrals_state.dart';

/// The build the footer names (B7 · More): "IQLY FOR IOS 1.4.2 (310)", and
/// the Shorebird patch it runs, so a patch's arrival can be checked.
///
/// Brief over Figma: " · PATCH 2" follows when a patch is running.
class BuildInfo {
  const BuildInfo({required this.version, required this.build, this.patch});

  /// The frame's own numbers, for demo builds and goldens.
  static const sample = BuildInfo(version: '1.4.2', build: '310');

  final String version;
  final String build;
  final int? patch;

  String footer({required bool ios}) => [
    'iQLY for ${ios ? 'iOS' : 'Android'} $version ($build)',
    if (patch != null) 'patch $patch',
  ].join(' · ').toUpperCase();
}

final buildInfoProvider = FutureProvider<BuildInfo>(
  (ref) async => BuildInfo.sample,
);

/// What the summary card on More and the header of Your profile show: the
/// name, the iQL points, this month's place on the points board (null when
/// the board has not ranked them) and the invite code. A live launch has
/// the name alone ([pointsAndReferralsProvider]).
class ContributorPass {
  const ContributorPass({
    required this.user,
    this.points,
    this.rank,
    this.code,
  });

  final User user;
  final int? points;
  final int? rank;
  final String? code;
}

final contributorPassProvider = FutureProvider<ContributorPass>((ref) async {
  if (!ref.watch(pointsAndReferralsProvider)) {
    return ContributorPass(
      user: await ref.watch(onboardingUserProvider.future),
    );
  }
  final repo = ref.watch(repositoryProvider);
  final (user, points, board, referrals) = await (
    ref.watch(onboardingUserProvider.future),
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
