import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/core/session.dart';
import 'package:iqly_mobile/data/live/live_submit_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_data_fixtures.dart';

final _now = DateTime.utc(2026, 10, 17, 9);

/// Brief c_1 as open, and no entry from the person yet.
void _openBrief(FakeApi api, [Map<String, Object?> change = const {}]) {
  api.data('GET', '/challenges/c_1', challengeJson(change));
  api.data('GET', '/submissions/mine/by-challenge/c_1', null);
}

/// The API takes every send, answering the entry and the count.
void _takes(FakeApi api) => api.on(
  'POST',
  '/submissions/challenges/c_1',
  (_) => ok({
    ...submissionJson({
      'id': 's_new',
      'challengeId': 'c_1',
      'result': 'under_review',
      'award': null,
      'brief': {
        'id': 'c_1',
        'slug': 'make-sunday-data-day',
        'title': 'Make Sunday data day',
        'businessName': 'Kudi Box',
        'logoUrl': null,
        'coverUrl': null,
        'deadline': '2026-10-25T17:00:00.000Z',
        'rewardPool': 15000000,
        'status': 'live',
      },
    }),
    'entries': 13,
  }, status: 201),
);

const _request = SubmitRequest(
  briefId: 'c_1',
  title: 'Sunday is data day',
  answer: 'Give a bonus bundle on Sundays.',
  answers: {
    'q_lang': ['Pidgin'],
    'q_where': ['USSD', 'Agent'],
    'q_why': ['It is the day people top up.'],
  },
);

String _part(http.Request request, String name) {
  final body = utf8.decode(request.bodyBytes);
  final match = RegExp(
    'name="$name"\\r\\n\\r\\n(.*?)\\r\\n--',
    dotAll: true,
  ).firstMatch(body);
  return match![1]!;
}

void main() {
  late FakeApi api;
  late LiveSubmitService service;

  setUp(() {
    api = FakeApi();
    service = LiveSubmitService(api.api(), clock: () => _now);
  });

  group('open', () {
    test('an open brief: the form from its survey and formats', () async {
      _openBrief(api);
      final opening = await service.open('c_1');
      expect(opening.block, isNull);
      expect(opening.brief!.title, 'Make Sunday data day');
      final form = opening.form!;
      expect(
        [for (final q in form.questions) (q.id, q.choice, q.multi)],
        [
          ('q_lang', true, false),
          ('q_where', true, true),
          ('q_why', false, false),
        ],
      );
      expect(form.acceptsFiles, isTrue);
      expect(
        [for (final r in api.requests) r.url.path],
        unorderedEquals([
          '/challenges/c_1',
          '/submissions/mine/by-challenge/c_1',
        ]),
      );
    });

    test('blocks in the order the product checks them', () async {
      Future<SubmitBlock?> block(
        Map<String, Object?> change, {
        bool sent = false,
      }) async {
        _openBrief(api, change);
        if (sent) {
          api.data('GET', '/submissions/mine/by-challenge/c_1', {
            'id': 's_9',
            'status': 'pending',
          });
        }
        return (await service.open('c_1')).block;
      }

      const everything = {
        'status': 'closed',
        'effectiveDeadline': '2026-10-16T17:00:00.000Z',
        'maxSubmissions': 12,
        'submissionCount': 12,
      };
      expect(await block(everything, sent: true), SubmitBlock.alreadySubmitted);
      expect(await block(everything), SubmitBlock.full);
      expect(
        await block({...everything, 'maxSubmissions': null}),
        SubmitBlock.deadlinePassed,
      );
      expect(
        await block({'status': 'closed', 'maxSubmissions': null}),
        SubmitBlock.closed,
      );
      expect(
        await block({
          'effectiveDeadline': '2026-10-17T09:00:00.000Z',
          'deadline': '2026-10-30T17:00:00.000Z',
        }),
        SubmitBlock.deadlinePassed,
        reason: "the server's effective deadline, to the second",
      );
      expect(await block({}), isNull);
    });

    test('already sent names the entry, so the flow opens it', () async {
      _openBrief(api);
      api.data('GET', '/submissions/mine/by-challenge/c_1', {
        'id': 's_9',
        'status': 'pending',
      });
      final opening = await service.open('c_1');
      expect(opening.block, SubmitBlock.alreadySubmitted);
      expect(opening.submissionId, 's_9');
      expect(opening.brief!.id, 'c_1');
    });

    test('an unknown brief is closed; no connection fails the load', () async {
      api.data('GET', '/submissions/mine/by-challenge/gone', null);
      final opening = await service.open('gone');
      expect(opening.block, SubmitBlock.closed);
      expect(opening.brief, isNull);
      api.offline = true;
      await expectLater(service.open('c_1'), throwsA(anything));
    });
  });

  group('the answer as HTML', () {
    test('paragraphs split on blank lines, escaped, each in <p>', () {
      expect(
        answerHtml(
          'Give a bonus <bundle> & a badge.\n\n'
          'Then tell people.\r\n  \r\nOn Sundays.\nEvery week.',
        ),
        '<p>Give a bonus &lt;bundle&gt; &amp; a badge.</p>'
        '<p>Then tell people.</p>'
        '<p>On Sundays.\nEvery week.</p>',
      );
      expect(answerHtml('One line'), '<p>One line</p>');
      expect(answerHtml('a\n\n\n\nb'), '<p>a</p><p>b</p>');
    });
  });

  group('submit', () {
    test(
      'a multipart send with the HTML answer, the survey and files',
      () async {
        _openBrief(api);
        _takes(api);
        await service.open('c_1');
        final progress = <double>[];
        final result = await service.submit(
          SubmitRequest(
            briefId: 'c_1',
            title: 'Sunday is data day',
            answer: 'Give a bonus bundle.\n\nOn Sundays & holidays.',
            answers: _request.answers,
            files: [
              AttachmentFile(
                name: 'Poster.JPG',
                bytes: 3,
                read: () async => [1, 2, 3],
              ),
              AttachmentFile(
                name: 'deck.pdf',
                bytes: 2,
                read: () async => [4, 5],
              ),
            ],
            onProgress: progress.add,
          ),
        );
        final request = api.to('/submissions/challenges/c_1').single;
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(_part(request, 'title'), 'Sunday is data day');
        expect(
          _part(request, 'body'),
          '<p>Give a bonus bundle.</p><p>On Sundays &amp; holidays.</p>',
        );
        expect(jsonDecode(_part(request, 'surveyAnswers')), {
          'q_lang': 'Pidgin',
          'q_where': ['USSD', 'Agent'],
          'q_why': 'It is the day people top up.',
        });
        final body = latin1.decode(request.bodyBytes);
        expect(
          body,
          contains(
            'content-type: image/jpeg\r\n'
            'content-disposition: form-data; name="file"; '
            'filename="Poster.JPG"',
          ),
        );
        expect(body, contains('content-type: application/pdf'));
        expect(request.headers['idempotency-key'], hasLength(36));
        expect(progress.first, 0);
        expect(progress.last, 1);

        final receipt = result.receipt!;
        expect(receipt.entries, 13);
        expect(receipt.submission.id, 's_new');
        expect(receipt.submission.briefId, 'c_1');
        expect(receipt.submission.status, SubmissionStatus.pending);
      },
    );

    test('a brief without a survey sends no survey answers', () async {
      _openBrief(api, {'audienceSurvey': null});
      _takes(api);
      await service.open('c_1');
      await service.submit(
        const SubmitRequest(
          briefId: 'c_1',
          title: 'Sunday is data day',
          answer: 'Give a bonus bundle on Sundays.',
        ),
      );
      final body = utf8.decode(
        api.to('/submissions/challenges/c_1').single.bodyBytes,
      );
      expect(body, isNot(contains('surveyAnswers')));
    });

    test('a retry of the same send carries the same key; a new send a new '
        'one', () async {
      _openBrief(api);
      await service.open('c_1');
      api.offline = true;
      expect((await service.submit(_request)).failure, SubmitFailure.offline);
      api.offline = false;
      api.on(
        'POST',
        '/submissions/challenges/c_1',
        (_) => refused(503, 'INFRASTRUCTURE_ERROR'),
      );
      expect((await service.submit(_request)).failure, SubmitFailure.unknown);
      _takes(api);
      expect((await service.submit(_request)).ok, isTrue);

      final keys = [
        for (final r in api.requests)
          if (r.method == 'POST') r.headers['idempotency-key'],
      ];
      expect(keys, hasLength(3));
      expect(keys.toSet(), hasLength(1));

      api.offline = true;
      await service.submit(_request);
      api.offline = false;
      await service.submit(_request);
      final after = [
        for (final r in api.requests)
          if (r.method == 'POST') r.headers['idempotency-key'],
      ];
      expect(
        after.last,
        isNot(keys.first),
        reason:
            'a new send after one '
            'the API confirmed',
      );
    });

    test('an answer from the API ends the attempt', () async {
      _openBrief(api);
      await service.open('c_1');
      api.on(
        'POST',
        '/submissions/challenges/c_1',
        (_) => refused(403, 'UNDER_AGE'),
      );
      await service.submit(_request);
      await service.submit(_request);
      final keys = [
        for (final r in api.requests)
          if (r.method == 'POST') r.headers['idempotency-key'],
      ];
      expect(keys.toSet(), hasLength(2));
    });

    test('maps every refusal', () async {
      _openBrief(api);
      await service.open('c_1');
      Future<SubmitResult> answering(http.Response response) {
        api.on('POST', '/submissions/challenges/c_1', (_) => response);
        return service.submit(_request);
      }

      final blocks = {
        'SUBMISSION_DEADLINE_PASSED': SubmitBlock.deadlinePassed,
        'SUBMISSION_CHALLENGE_NOT_OPEN': SubmitBlock.closed,
        'SUBMISSION_CAP_REACHED': SubmitBlock.full,
        'SUBMISSION_DUPLICATE': SubmitBlock.alreadySubmitted,
      };
      for (final MapEntry(:key, :value) in blocks.entries) {
        final result = await answering(refused(409, key));
        expect(result.failure, SubmitFailure.blocked, reason: key);
        expect(result.block, value, reason: key);
      }
      for (final (status, code) in [
        (403, 'UNDER_AGE'),
        (403, 'ACCOUNT_CLOSING'),
        (415, 'FILE_TYPE_NOT_ALLOWED'),
        (413, 'FILE_TOO_LARGE'),
        (400, 'SUBMISSION_SURVEY_INVALID'),
        (422, 'VALIDATION_ERROR'),
        (429, 'RATE_LIMITED'),
        (500, 'INTERNAL'),
      ]) {
        final result = await answering(refused(status, code));
        expect(result.failure, SubmitFailure.unknown, reason: code);
        expect(result.block, isNull, reason: code);
      }
      api.offline = true;
      expect((await service.submit(_request)).failure, SubmitFailure.offline);
    });

    test('a file that cannot be read is not sent', () async {
      _openBrief(api);
      _takes(api);
      await service.open('c_1');
      final result = await service.submit(
        const SubmitRequest(
          briefId: 'c_1',
          title: 'Sunday is data day',
          answer: 'Give a bonus bundle on Sundays.',
          files: [AttachmentFile(name: 'voice-note.m4a', bytes: 524288)],
        ),
      );
      expect(result.failure, SubmitFailure.unknown);
      expect(api.to('/submissions/challenges/c_1'), isEmpty);
    });

    test('sends without opening first by reading the brief', () async {
      api.data('GET', '/challenges/c_1', challengeJson());
      _takes(api);
      expect((await service.submit(_request)).ok, isTrue);
      expect(
        jsonDecode(
          _part(api.to('/submissions/challenges/c_1').single, 'surveyAnswers'),
        ),
        containsPair('q_where', ['USSD', 'Agent']),
      );
    });
  });

  test('media types by extension', () {
    expect(LiveSubmitService.mediaTypeOf('a.jpeg'), 'image/jpeg');
    expect(LiveSubmitService.mediaTypeOf('a.png'), 'image/png');
    expect(LiveSubmitService.mediaTypeOf('a.webp'), 'image/webp');
    expect(LiveSubmitService.mediaTypeOf('a.gif'), 'image/gif');
    expect(LiveSubmitService.mediaTypeOf('a.PDF'), 'application/pdf');
    expect(
      LiveSubmitService.mediaTypeOf('voice.m4a'),
      'application/octet-stream',
    );
  });

  group('providers', () {
    Future<ProviderContainer> container(List<Override> overrides) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('submit live: the API, images and PDFs, files in the send', () async {
      final c = await container(liveOverrides(api.api()));
      expect(c.read(submitServiceProvider), isA<LiveSubmitService>());
      final picker = c.read(attachmentPickerProvider) as DeviceAttachmentPicker;
      expect(picker.extensions, ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf']);
      final uploader = c.read(attachmentUploaderProvider);
      expect(uploader, isA<LiveAttachmentUploader>());
      final progress = <double>[];
      expect(
        await uploader.upload(
          const AttachmentFile(name: 'a.pdf', bytes: 1),
          progress.add,
        ),
        isTrue,
      );
      expect(progress, [1]);
    });

    test('preview, or submit on preview: the demo, any file', () async {
      for (final overrides in [
        <Override>[],
        liveOverrides(api.api(), mode: Backend.of({LiveFeature.briefs})),
      ]) {
        final c = await container(overrides);
        final demo = c.read(submitServiceProvider) as DemoSubmitService;
        final repo = c.read(repositoryProvider);
        expect(
          demo.data,
          same(
            repo is DemoRepository
                ? repo.data
                : c.read(demoRepositoryProvider).data,
          ),
        );
        final picker =
            c.read(attachmentPickerProvider) as DeviceAttachmentPicker;
        expect(picker.extensions, isNull);
        expect(
          c.read(attachmentUploaderProvider),
          isA<DemoAttachmentUploader>(),
        );
      }
    });
  });
}
