import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A friend's invite: the code and the name sign up shows as "Invited by
/// Chidi A." (answer 22).
class Invite {
  const Invite({required this.code, required this.inviterName});

  final String code;
  final String inviterName;
}

/// Looks up the code an invite link carries. The demo knows the Figma
/// 485:39127 invite; the live API replaces it behind the same interface.
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

final inviteServiceProvider = Provider<InviteService>(
  (ref) => const DemoInviteService(),
);
