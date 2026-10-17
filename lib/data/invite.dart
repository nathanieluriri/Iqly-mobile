import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import 'api_client.dart';
import 'live/live_repository.dart' show liveModeProvider;
import 'referrals_service.dart' show lookUpInviter;

/// A friend's invite: the code and the name sign up shows as "Invited by
/// Chidi A." (answer 22).
class Invite {
  const Invite({required this.code, this.inviterName = ''});

  final String code;

  /// Empty while the code could not be checked yet.
  final String inviterName;
}

/// Looks up the code an invite link carries. The demo knows the Figma
/// 485:39127 invite; the live API replaces it behind the same interface.
/// Null means no such code; a throw means it could not be checked.
abstract class InviteService {
  Future<Invite?> lookUp(String code);
}

class DemoInviteService implements InviteService {
  const DemoInviteService();

  static const sample = Invite(code: 'CHIDI7', inviterName: 'Chidi A.');

  @override
  Future<Invite?> lookUp(String code) async =>
      code.trim().toUpperCase() == sample.code ? sample : null;
}

/// `GET /referrals/codes/:code`, public, so it works before sign-up. Only
/// INVITE_CODE_INVALID says the code does not exist.
class LiveInviteService implements InviteService {
  const LiveInviteService(this.api);

  final ApiClient api;

  @override
  Future<Invite?> lookUp(String code) async {
    final typed = code.trim().toUpperCase();
    final inviter = await lookUpInviter(api, typed);
    return inviter == null ? null : Invite(code: typed, inviterName: inviter);
  }
}

/// A live launch without referrals cannot check a code, so the sample's
/// invite never shows and the code is kept for when it can.
class NoInviteService implements InviteService {
  const NoInviteService();

  @override
  Future<Invite?> lookUp(String code) =>
      Future.error(const FeaturePaused(LiveFeature.referrals));
}

final inviteServiceProvider = Provider<InviteService>((ref) {
  final mode = ref.watch(liveModeProvider);
  final api = ref.watch(apiClientProvider);
  if (mode.isPreview || api == null) return const DemoInviteService();
  return mode.isLive(LiveFeature.referrals)
      ? LiveInviteService(api)
      : const NoInviteService();
});
