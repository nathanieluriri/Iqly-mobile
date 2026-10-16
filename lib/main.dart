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
import 'data/token_store.dart';
import 'features/more/more_state.dart';
import 'router.dart';
import 'surfaces/surfaces.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceServiceProvider.overrideWithValue(PlatformDeviceService()),
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
        authServiceProvider.overrideWithValue(
          LiveAuthService(api: ApiClient(tokens: SecureTokenStore())),
        ),
        appVersionServiceProvider.overrideWithValue(LiveAppVersionService()),
      ],
      surfacesProvider.overrideWith(
        (ref) => Surfaces(
          router: ref.watch(routerProvider),
          signedIn: () => ref.read(sessionProvider).signedIn,
          tabRoots: {
            Routes.home,
            Routes.submissions,
            Routes.wallet,
            Routes.profile,
          },
        ),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const IqlyApp()),
  );
  unawaited(
    container.read(surfacesProvider)!.start(SurfaceInputs.demo(DateTime.now())),
  );
}
