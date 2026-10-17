import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/live/live_submit_service.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/data/token_store.dart';

import '../../support/live_api.dart' show meJson, profileJson;
import '../../support/live_app.dart' show NoSocial;

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    if (status == 200) 'set-auth-token': 'ada.token',
  },
);

Map<String, Object> _refusal(String code) => {
  'success': false,
  'error': {'code': code, 'message': 'No.'},
};

void main() {
  group('sign-in decides first run', () {
    Future<bool> newAccount({
      required http.Response profile,
      http.Response? me,
    }) async {
      final api = ApiClient(
        tokens: MemoryTokenStore(),
        baseUrl: 'https://api.test',
        client: MockClient(
          (r) async => switch ('${r.method} ${r.url.path}') {
            'POST /auth/web/sign-in/email' => _json({
              'token': 'raw',
              'user': {'id': 'u_1', 'name': 'Ada Obi', 'email': 'ada@x.com'},
            }),
            'GET /profiles/contributors/me' => profile,
            'GET /me' => me ?? _json(_refusal('SERVICE_UNAVAILABLE'), 503),
            _ => _json(_refusal('NOT_FOUND'), 404),
          },
        ),
      );
      final result = await LiveAuthService(
        api: api,
        social: NoSocial(),
      ).signIn(email: 'ada@x.com', password: 'secret123');
      expect(result.ok, isTrue);
      return result.newAccount;
    }

    test('only the API\'s not found makes a new account', () async {
      expect(
        await newAccount(
          profile: _json(_refusal('CONTRIBUTOR_PROFILE_NOT_FOUND'), 404),
        ),
        isTrue,
      );
    });

    test('a fault or a throttle asks /me, and a finished first run stays '
        'finished', () async {
      for (final status in [503, 429, 500]) {
        expect(
          await newAccount(
            profile: _json(_refusal('SERVICE_UNAVAILABLE'), status),
            me: _json({'success': true, 'data': meJson()}),
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('/me with first run still open, or no profile, is a new account; '
        'no answer from either is a returning one', () async {
      final open = {
        ...meJson(),
        'profile': {...profileJson(), 'onboardingCompletedAt': null},
      };
      final noProfile = {...meJson(), 'profile': null};
      for (final me in [open, noProfile]) {
        expect(
          await newAccount(
            profile: _json(_refusal('SERVICE_UNAVAILABLE'), 503),
            me: _json({'success': true, 'data': me}),
          ),
          isTrue,
        );
      }
      expect(
        await newAccount(profile: _json(_refusal('SERVICE_UNAVAILABLE'), 503)),
        isFalse,
      );
    });
  });

  group('files a brief takes', () {
    test('images only, PDFs only, both, none', () {
      SubmitForm form(Map<String, bool> formats) =>
          submitFormFromJson({'acceptedFormats': formats});
      expect(form({'text': true, 'image': true}).fileExtensions, [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
      ]);
      expect(form({'pdf': true}).fileExtensions, ['pdf']);
      expect(
        form({'image': true, 'pdf': true}).fileExtensions,
        LiveSubmitService.fileExtensions,
      );
      expect(form({'text': true}).acceptsFiles, isFalse);
    });

    test('the live picker offers only what the brief takes', () async {
      final fallback = DemoAttachmentPicker();
      final picker = DeviceAttachmentPicker(
        fallback: fallback,
        extensions: LiveSubmitService.fileExtensions,
      );
      expect(picker.offered(['pdf']), ['pdf']);
      expect(picker.offered(SubmitForm.imageExtensions), [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
      ]);
      expect(picker.offered(null), LiveSubmitService.fileExtensions);
      expect(DeviceAttachmentPicker().offered(['pdf']), ['pdf']);
    });

    test('a 415 for a file the brief does not take is not a retry', () async {
      final api = ApiClient(
        tokens: MemoryTokenStore('t'),
        baseUrl: 'https://api.test',
        client: MockClient(
          (r) async => r.method == 'POST'
              ? _json(_refusal('FILE_TYPE_NOT_ALLOWED'), 415)
              : _json({'success': true, 'data': null}),
        ),
      );
      final result = await LiveSubmitService(api).submit(
        SubmitRequest(
          briefId: 'c_1',
          title: 'Noodles win on time',
          answer: 'Noodles are on the table in five minutes.',
          files: [
            AttachmentFile(
              name: 'menu.pdf',
              bytes: 4,
              read: () async => utf8.encode('%PDF'),
            ),
          ],
        ),
      );
      expect(result.failure, SubmitFailure.fileType);
    });
  });
}
