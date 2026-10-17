import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/session.dart';
import 'data/api_client.dart';
import 'data/api_config.dart';
import 'data/app_version.dart';
import 'data/auth.dart';
import 'data/device.dart';
import 'data/live_auth.dart';
import 'data/patches.dart';
import 'data/profile_service.dart';
import 'data/repository.dart';
import 'data/token_store.dart';
import 'features/discover/discover_state.dart';
import 'features/more/more_state.dart';
import 'features/settings/settings_state.dart';
import 'router.dart';
import 'surfaces/push.dart';
import 'surfaces/surfaces.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(tokens: SecureTokenStore());
  late final ProviderContainer container;
  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceServiceProvider.overrideWithValue(
        PlatformDeviceService(
          onNotificationsAllowed: () async =>
              container.read(pushProvider)?.permissionGranted(),
        ),
      ),
      patchServiceProvider.overrideWithValue(ShorebirdPatchService()),
      buildInfoProvider.overrideWith((ref) async {
        final info = await PackageInfo.fromPlatform();
        return BuildInfo(
          version: info.version,
          build: info.buildNumber,
          patch: await ref.read(patchServiceProvider).current(),
        );
      }),
      if (ApiConfig.liveAuth) ...[
        authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
        appVersionServiceProvider.overrideWithValue(LiveAppVersionService()),
        pushProvider.overrideWith(
          (ref) => Push(
            devices: ApiPushDevices(api),
            signedIn: () => ref.read(sessionProvider).signedIn,
            onOpen: (route) => ref.read(surfacesProvider)?.openLink(route),
            onArrive: () => ref.invalidate(unreadNotificationsProvider),
          ),
        ),
      ],
      surfacesProvider.overrideWith(
        (ref) => Surfaces(
          router: ref.watch(routerProvider),
          signedIn: () => ref.read(sessionProvider).signedIn,
          tabRoots: {
            Routes.home,
            Routes.submissions,
            Routes.wallet,
            Routes.more,
          },
          channelOn: (channel) =>
              ref.read(notificationPreferencesProvider).value?[NotificationTopic
                  .values
                  .byName(channel.name)] ??
              true,
        ),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  unawaited(_startSurfaces(container));
}

Future<void> _startSurfaces(ProviderContainer container) async {
  await container
      .read(surfacesProvider)!
      .start(SurfaceInputs.demo(DateTime.now()));
  final push = container.read(pushProvider);
  if (push != null) {
    await push.start();
    container.listen(
      sessionProvider.select((s) => s.signedIn),
      (_, signedIn) => signedIn ? unawaited(push.sync()) : null,
    );
  }
  final reminders = container.read(closeRemindersProvider.notifier);
  await reminders.syncSurfaces();
  container.listen(
    notificationPreferencesProvider,
    (_, _) => unawaited(reminders.syncSurfaces()),
  );
}
