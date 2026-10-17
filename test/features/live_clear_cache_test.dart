import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/cache_service.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/live/live_account.dart';
import 'package:iqly_mobile/data/live/live_repository.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/router.dart';

import '../data/live/live_data_fixtures.dart' show challengeJson;
import '../support/live_api.dart';
import '../support/live_app.dart';
import '../support/outbox_fakes.dart';

class _Images extends ImageCache {
  var cleared = 0;
  var liveCleared = 0;

  @override
  void clear() {
    cleared++;
    super.clear();
  }

  @override
  void clearLiveImages() {
    liveCleared++;
    super.clearLiveImages();
  }
}

/// What the phone keeps for Ada (u_1) and for Bola (u_2).
Future<MemoryLocalStore> _kept() async {
  final store = MemoryLocalStore();
  await store.writeCache('u_1', LiveCacheKeys.briefs, [challengeJson()]);
  await store.writeCache('u_1', AccountKeys.me, meJson());
  await store.writeCache('u_2', LiveCacheKeys.briefs, [challengeJson()]);
  await store.saveDraft(
    'u_1',
    Draft(
      briefId: 'c_1',
      title: 'Sunday plan',
      answer: 'Bundles',
      editedAt: DateTime(2026, 10, 17, 9),
    ),
  );
  await store.enqueue(
    'u_1',
    kind: AccountWrite.preferences.kind,
    payload: livePreferences,
  );
  return store;
}

Future<void> _openClearCache(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Clear cache'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a live launch names the size the phone keeps for the person, '
      'and clears those answers: never drafts, the outbox or anyone '
      'else\'s', (tester) async {
    final store = await _kept();
    final bytes = [
      jsonEncode([challengeJson()]),
      jsonEncode(meJson()),
    ].fold(0, (sum, json) => sum + utf8.encode(json).length);
    final size = '${(bytes / 1000).ceil()} KB';
    await pumpLive(tester, Routes.more, accountApi(), store: store);
    await _openClearCache(tester);
    expect(
      find.text(
        'Removes $size of saved briefs and images from this phone. Your '
        'account and submissions are not affected.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('42 MB'), findsNothing);

    await tester.tap(find.text('Clear $size'));
    await tester.pumpAndSettle();
    expect(await store.readCache('u_1', LiveCacheKeys.briefs), isNull);
    expect(await store.readCache('u_1', AccountKeys.me), isNull);
    expect(await store.readCache('u_2', LiveCacheKeys.briefs), isNotNull);
    expect(await store.drafts('u_1'), hasLength(1));
    expect(await store.outbox('u_1'), hasLength(1));

    await _openClearCache(tester);
    expect(find.text('Clear 0 KB'), findsOneWidget);
  });

  test('clearing drops the images the app holds too', () async {
    final images = _Images();
    final store = await _kept();
    await LiveCacheService(store, 'u_1', images: () => images).clear();
    expect((images.cleared, images.liveCleared), (1, 1));
    expect(await store.readCache('u_1', AccountKeys.me), isNull);
  });

  testWidgets('a store that cannot count leaves the size unnamed', (
    tester,
  ) async {
    final store = GatedStore(await _kept());
    expect(await LiveCacheService(store, 'u_1').sizeBytes(), isNull);
    await pumpLive(tester, Routes.more, accountApi(), store: store);
    await _openClearCache(tester);
    expect(
      find.text(
        'Removes saved briefs and images from this phone. Your account and '
        'submissions are not affected.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(await store.readCache('u_1', LiveCacheKeys.briefs), isNull);
  });
}
