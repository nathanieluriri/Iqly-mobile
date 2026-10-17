import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/memory_local_store.dart';
import 'package:iqly_mobile/data/local/outbox.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/profile/account_sync.dart';

class _SpyOutbox extends Outbox {
  _SpyOutbox() : super(MemoryLocalStore());

  var backs = 0;

  @override
  Future<void> networkBack() async => backs++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the outbox hears that the network is back from the API itself',
    () async {
      var offline = true;
      final api = ApiClient(
        tokens: MemoryTokenStore('t'),
        baseUrl: 'https://api.test',
        client: MockClient((_) async {
          if (offline) throw http.ClientException('no route');
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      );
      final outbox = _SpyOutbox();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          outboxProvider.overrideWithValue(outbox),
        ],
      );
      addTearDown(container.dispose);
      container.read(outboxOnResumeProvider);

      await expectLater(api.get('/me'), throwsA(isA<ApiUnreachable>()));
      await pumpEventQueue();
      expect(outbox.backs, 0);

      offline = false;
      await api.get('/me');
      await api.get('/briefs');
      await pumpEventQueue();
      expect(outbox.backs, 1);
    },
  );
}
