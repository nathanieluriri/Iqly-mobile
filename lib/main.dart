import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/backend.dart';
import 'core/session.dart';
import 'data/api_client.dart';
import 'data/api_config.dart';
import 'data/app_version.dart';
import 'data/auth.dart';
import 'data/device.dart';
import 'data/live_auth.dart';
import 'data/local/local_providers.dart';
import 'data/local/local_store.dart';
import 'data/local/memory_local_store.dart';
import 'data/patches.dart';
import 'data/profile_service.dart';
import 'data/token_store.dart';
import 'features/discover/discover_state.dart';
import 'features/more/more_state.dart';
import 'features/notifications/notifications_state.dart';
import 'features/profile/account_sync.dart';
import 'features/profile/profile_state.dart';
import 'features/settings/settings_state.dart';
import 'router.dart';
import 'surfaces/push.dart';
import 'surfaces/surfaces.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final version = LiveAppVersionService.installedVersion().then<String?>(
    (installed) => installed,
    onError: (Object _) => null,
  );
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(tokens: SecureTokenStore(), appVersion: await version);
  final store = ApiConfig.liveAuth ? await _openStore() : null;
  late final ProviderContainer container;
  container = ProviderContainer(
    retry: retryUnlessPaused,
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
        apiClientProvider.overrideWithValue(api),
        localStoreProvider.overrideWithValue(store!),
        healthServiceProvider.overrideWithValue(LiveHealthService(api)),
        backendProvider.overrideWith(
          () => LiveBackendNotifier(forgetPreview: forgetPreviewRecords),
        ),
        authServiceProvider.overrideWithValue(LiveAuthService(api: api)),
        appVersionServiceProvider.overrideWithValue(LiveAppVersionService()),
        pushProvider.overrideWith(
          (ref) => Push(
            devices: ApiPushDevices(api),
            signedIn: () => ref.read(sessionProvider).signedIn,
            onOpen: (route) => ref.read(surfacesProvider)?.openLink(route),
            onArrive: () => readAgainOnPush(ref),
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
  container.read(sessionGuardProvider);
  if (ApiConfig.liveAuth) _startAccount(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  unawaited(_startSurfaces(container));
}

/// The phone's local store: SQLite on Android and iOS, memory elsewhere or
/// when the database will not open. What a killed app left sending goes
/// back in line before anything runs.
Future<LocalStore> _openStore() async {
  try {
    final store = await openLocalStore();
    await store.resetSending();
    return store;
  } on Object catch (error) {
    debugPrint('Local store: kept in memory: $error');
    return MemoryLocalStore();
  }
}

/// The account's writes go out for the signed-in person, again whenever the
/// app comes back, and once the splash has handed off the account is
/// checked (Restore while it is closing, first run on the first live
/// launch).
void _startAccount(ProviderContainer container) {
  startAccountSync(container);
  unawaited(
    checkAccountAtLaunch(container.read, container.read(routerProvider)),
  );
}

Future<void> _startSurfaces(ProviderContainer container) async {
  await startSurfaces(container.read(surfacesProvider)!, container);
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
