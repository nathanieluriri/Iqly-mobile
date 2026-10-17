import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/features/avatar/avatar_state.dart';
import 'package:iqly_mobile/features/profile/profile_state.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a 0.4.0+4 avatar survives a sign-out before it was ever read',
    () async {
      SharedPreferences.setMockInitialValues({
        'session.signedIn': true,
        'session.userId': 'u_1',
        'avatar.spec': '{"kind":"buddy","buddy":"Moon"}',
        'avatar.look': jsonEncode(IqAvatarPresets.person2.toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await forgetSession(container.read);
      await container.read(sessionProvider.notifier).setUserId('u_1');
      await container.read(sessionProvider.notifier).setSignedIn(true);

      expect(
        container.read(avatarProvider).spec,
        const IqBuddyAvatar(IqAvatarBuddyKind.moon),
      );
    },
  );
}
