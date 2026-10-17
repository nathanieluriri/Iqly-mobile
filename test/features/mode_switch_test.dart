import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/more/try_notifications_screen.dart';
import 'package:iqly_mobile/features/outcomes/outcomes_state.dart';
import 'package:iqly_mobile/features/splash/splash_screen.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/screens/app_harness.dart' show signedInPrefs;
import '../golden/screens/more_harness.dart';

/// A launch on the API that records what the switch forces.
class _Forceable extends BackendNotifier {
  _Forceable(this.start);

  final Backend start;
  final forced = <bool>[];

  @override
  Backend build() => start;

  @override
  bool get canForce => true;

  @override
  Future<void> force({required bool preview}) async {
    forced.add(preview);
    state = preview ? Backend.preview : start;
  }
}

void main() {
  final live = Backend(LiveFeature.values.toSet());

  Future<(_Forceable, MemoryLocalStore, ProviderContainer)> open(
    WidgetTester tester,
  ) async {
    final backend = _Forceable(live);
    final store = MemoryLocalStore();
    await store.writeCache('u1', 'feed', {'briefs': <Object>[]});
    await store.enqueue('u1', kind: 'profile.update', payload: {'a': 1});
    final container = await pumpMore(
      tester,
      Routes.tryNotifications,
      prefs: {
        ...signedInPrefs(),
        'session.userId': 'u1',
        SavedBriefsNotifier.key: '[]',
        CloseRemindersNotifier.key: <String>['b1'],
        celebratedKey: <String>['r1'],
        'submit.draft.b1': '{}',
      },
      overrides: [
        backendProvider.overrideWith(() => backend),
        localStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.scrollUntilVisible(find.text('Live'), 200);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    return (backend, store, container);
  }

  testWidgets('holding the mode row offers Live and Preview; the mode in use '
      'changes nothing', (tester) async {
    final (backend, _, _) = await open(tester);
    await tester.longPress(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    await tester.tap(find.text('Live').last);
    await tester.pumpAndSettle();
    expect(backend.forced, isEmpty);
    expect(find.byType(TryNotificationsScreen), findsOneWidget);
  });

  testWidgets('picking Preview signs out, forgets everything the phone kept '
      'for the account, forces preview and starts again at the splash', (
    tester,
  ) async {
    final (backend, store, container) = await open(tester);
    await tester.longPress(find.text('Live'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview'));
    var splash = false;
    for (var i = 0; i < 100 && !splash; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      splash = find.byType(SplashScreen).evaluate().isNotEmpty;
    }

    expect(backend.forced, [true]);
    expect(splash, isTrue);
    final prefs = container.read(sharedPreferencesProvider);
    expect(container.read(sessionProvider).signedIn, isFalse);
    expect(prefs.getString('session.userId'), isNull);
    for (final key in [
      SavedBriefsNotifier.key,
      CloseRemindersNotifier.key,
      celebratedKey,
      'submit.draft.b1',
    ]) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(await store.readCache('u1', 'feed'), isNull);
    expect(await store.outbox('u1'), isEmpty);
    await tester.pumpAndSettle();
    expect(find.byType(TryNotificationsScreen), findsNothing);
  });
}
