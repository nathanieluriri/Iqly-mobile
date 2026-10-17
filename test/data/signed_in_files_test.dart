import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/signed_in_files.dart';

import 'live/live_data_fixtures.dart';

void main() {
  late Directory root;
  late FakeApi api;
  late SignedInFiles files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('iqly-files-test');
    api = FakeApi();
    files = SignedInFiles(api: api.api(), root: root);
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> fetch({List<double>? progress}) => files.fetch(
    userId: 'u_1',
    id: 'up_9',
    url: 'https://elsewhere.test/support/attachments/up_9',
    name: 'memo.m4a',
    onProgress: progress?.add,
  );

  test('a file comes down once with the session token, from the API\'s '
      'own host, into the account\'s folder', () async {
    api.on(
      'GET',
      '/support/attachments/up_9',
      (_) => http.Response.bytes(List.filled(2048, 7), 200),
    );
    final progress = <double>[];
    final file = await fetch(progress: progress);
    expect(file.path, '${root.path}/u_1/up_9.m4a');
    expect(await file.length(), 2048);
    expect(progress.first, 0);
    expect(progress.last, 1);
    final read = api.to('/support/attachments/up_9').single;
    expect(read.url.host, 'api.test');
    expect(read.headers['authorization'], 'Bearer session.signed');

    expect((await fetch()).path, file.path);
    expect(api.to('/support/attachments/up_9'), hasLength(1));

    await files.forget('u_1');
    expect(await Directory('${root.path}/u_1').exists(), isFalse);
  });

  test('a file that does not come down leaves nothing behind', () async {
    api.on(
      'GET',
      '/support/attachments/up_9',
      (_) => refused(404, 'SUPPORT_ATTACHMENT_NOT_FOUND'),
    );
    await expectLater(fetch(), throwsA(isA<ApiRefused>()));
    api.offline = true;
    await expectLater(fetch(), throwsA(isA<ApiUnreachable>()));
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
