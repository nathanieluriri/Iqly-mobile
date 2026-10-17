import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache_service.dart';
import '../../data/models.dart';
import '../../data/referrals_service.dart' show referralsShownProvider;
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
/// the board has not ranked them) and the invite code. A live launch shows
/// each only while its feature runs live ([leaderboardShownProvider],
/// [referralsShownProvider]).
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
  final points = ref.watch(leaderboardShownProvider);
  final referrals = ref.watch(referralsShownProvider);
  final repo = ref.watch(repositoryProvider);
  final user = ref.watch(onboardingUserProvider.future);
  final (score, board, code) = await (
    points ? _optional(repo.points()) : Future.value(null),
    points ? _optional(repo.pointsLeaderboard()) : Future.value(null),
    referrals
        ? _optional(ref.watch(referralsProvider.future))
        : Future.value(null),
  ).wait;
  return ContributorPass(
    user: await user,
    points: score,
    rank: board?.you?.rank,
    code: switch (code?.code) {
      final code? when code.isNotEmpty => code,
      _ => null,
    },
  );
});

/// A live read that fails leaves its part of the pass out.
Future<T?> _optional<T>(Future<T> read) async {
  try {
    return await read;
  } on Object {
    return null;
  }
}

/// What Clear cache would free, in bytes; null when it cannot be counted.
class CacheNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() => ref.watch(cacheServiceProvider).sizeBytes();

  Future<void> clear() async {
    await ref.read(cacheServiceProvider).clear();
    state = const AsyncData(0);
  }
}

final cacheProvider = AsyncNotifierProvider<CacheNotifier, int?>(
  CacheNotifier.new,
);
