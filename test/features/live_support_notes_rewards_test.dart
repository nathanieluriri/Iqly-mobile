import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/avatar_service.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/help_service.dart';
import 'package:iqly_mobile/data/live/live_help_service.dart';
import 'package:iqly_mobile/data/live/live_notifications_service.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/notifications_data.dart';
import 'package:iqly_mobile/data/outcomes_service.dart';
import 'package:iqly_mobile/data/referrals_service.dart';
import 'package:iqly_mobile/data/signed_in_files.dart';
import 'package:iqly_mobile/data/support_files.dart';
import 'package:iqly_mobile/features/avatar/avatar_state.dart';
import 'package:iqly_mobile/features/avatar/choose_avatar.dart';
import 'package:iqly_mobile/features/more/more_screen.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/features/help/help_state.dart';
import 'package:iqly_mobile/features/help/help_thread_screen.dart';
import 'package:iqly_mobile/features/help/support_screen.dart';
import 'package:iqly_mobile/features/notifications/notifications_state.dart';
import 'package:iqly_mobile/features/referrals/referrals_state.dart';
import 'package:iqly_mobile/features/submissions/submission_files.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/wallet/wallet_routes.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/toast.dart';
import 'package:iqly_mobile/ui/avatar.dart';
import 'package:iqly_mobile/ui/list_row.dart';
import 'package:iqly_mobile/ui/recording_player.dart';
import 'package:iqly_mobile/ui/top_bar.dart';
import 'package:video_player/video_player.dart';

import '../data/live/live_data_fixtures.dart';
import '../support/live_launch.dart';

/// Ada's API: the account reads every live screen makes.
FakeApi _api() {
  final api = FakeApi();
  api.data('GET', '/me', {
    'id': 'u_1',
    'name': 'Ada Obi',
    'email': 'ada@example.com',
    'status': 'active',
  });
  api.data('GET', '/profiles/contributors/me', {'gender': 'female'});
  api.data('GET', '/me/notification-preferences', const {});
  api.data('GET', '/notifications', {
    'items': <Object>[],
    'nextCursor': null,
    'unseen': 0,
  });
  api.data('GET', '/submissions/mine', page([]));
  api.data('GET', '/challenges/browse', {'items': <Object>[], 'pageCount': 1});
  return api;
}

Backend _with(Set<LiveFeature> more) => Backend.of({...firstFeatures, ...more});

class _Files implements SupportFiles {
  HelpAttachment? next;
  final sources = <SupportSource>[];

  @override
  Future<HelpAttachment?> pickAttachment(SupportSource source) async {
    sources.add(source);
    return next;
  }

  @override
  Future<HelpAttachment?> pickScreenshot() async => next;
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP49eYSAAWcArlITY1UAAAAAElFTkSuQmCC',
);

HelpAttachment _file(String name, {HelpAttachmentKind? kind}) => HelpAttachment(
  name: name,
  bytes: _png.length,
  kind: kind ?? supportTypeOf(name)!.kind,
  read: () async => _png,
);

Future<ProviderContainer> _launch(
  WidgetTester tester,
  FakeApi api,
  String location, {
  Backend? mode,
  Map<String, Object> prefs = const {},
  SupportFiles? files,
  List<Override> overrides = const [],
}) async {
  final (container, _) = await pumpLiveLaunch(
    tester,
    location,
    api: api.api(),
    mode: mode,
    prefs: signedInLive(prefs),
    overrides: [
      if (files != null) supportFilesProvider.overrideWithValue(files),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
  return container;
}

Map<String, Object?> _attachment([Map<String, Object?> change = const {}]) => {
  'id': 'up_1',
  'kind': 'image',
  'name': 'activity.png',
  'mime': 'image/png',
  'bytes': 69,
  'lengthSeconds': null,
  'url': 'https://api.test/support/attachments/up_1',
  ...change,
};

const _at0 = '2026-10-17T08:00:00.000Z';

Map<String, Object?> _thread({
  String id = 't_1',
  String status = 'replied',
  bool unread = true,
  String subject = 'Withdrawal to Access Bank',
  String reference = 'IQ-HELP-2041',
  List<Object?>? messages,
}) => {
  'id': id,
  'reference': reference,
  'kind': 'conversation',
  'subject': subject,
  'topic': null,
  'status': status,
  'activationId': null,
  'unread': unread,
  'createdAt': '2026-10-17T07:00:00.000Z',
  'updatedAt': '2026-10-17T08:00:00.000Z',
  'resolvedAt': null,
  'messages':
      messages ??
      [
        {
          'id': 'm_1',
          'author': 'you',
          'body': 'My withdrawal still says pending.',
          'at': '2026-10-17T07:00:00.000Z',
          'attachments': [_attachment()],
        },
        {
          'id': 'm_2',
          'author': 'support',
          'body': 'Access Bank is still confirming it.',
          'at': '2026-10-17T08:00:00.000Z',
          'attachments': <Object>[],
        },
      ],
  'credit': null,
};

Map<String, Object?> _row(Map<String, Object?> thread) {
  final messages = thread['messages']! as List;
  final last = messages.last as Map;
  return {
    for (final e in thread.entries)
      if (e.key != 'messages' && e.key != 'credit') e.key: e.value,
    'lastMessage': {
      'author': last['author'],
      'authorName': last['authorName'],
      'body': last['body'],
      'at': last['at'],
    },
  };
}

class _Saver implements FileSaver {
  _Saver({this.answer = FileSave.saved});

  final FileSave answer;
  final saved = <(String, String, int)>[];

  @override
  Future<FileSave> save(
    File file, {
    required String name,
    required String mime,
  }) async {
    saved.add((name, mime, file.lengthSync()));
    return answer;
  }
}

class _FakeRecording extends VideoPlayerController {
  _FakeRecording(super.url) : super.networkUrl();

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 20),
    );
  }
}

IqListRow _listRow(WidgetTester tester, String label) => tester.widget(
  find.byWidgetPredicate((w) => w is IqListRow && w.label == label),
);

void main() {
  group('support', () {
    test('every support refusal maps to the words the app has', () {
      expect(helpFailureOf(429, 'RATE_LIMITED'), HelpFailure.tooManyTries);
      expect(helpFailureOf(403, 'ACCOUNT_CLOSING'), HelpFailure.closing);
      expect(helpFailureOf(413, 'FILE_TOO_LARGE'), HelpFailure.tooLarge);
      expect(helpFailureOf(413, 'VIDEO_TOO_LONG'), HelpFailure.tooLong);
      expect(helpFailureOf(413, 'AUDIO_TOO_LONG'), HelpFailure.tooLong);
      expect(helpFailureOf(415, 'FILE_TYPE_NOT_ALLOWED'), HelpFailure.fileType);
      for (final code in [
        'SUPPORT_UPLOAD_NOT_FOUND',
        'SUPPORT_UPLOAD_IN_USE',
        'SUPPORT_TICKET_NOT_FOUND',
        'ACTIVATION_NOT_FOUND',
      ]) {
        expect(helpFailureOf(404, code), HelpFailure.gone, reason: code);
      }
      expect(helpFailureOf(503, null), HelpFailure.offline);
      expect(helpFailureOf(400, 'VALIDATION_ERROR'), HelpFailure.unknown);
    });

    test('a thread and an inbox row from the API', () {
      final thread = helpTicketFromJson(_thread())!;
      expect(thread.reference, 'IQ-HELP-2041');
      expect(thread.status, HelpTicketStatus.replied);
      expect(thread.unread, isTrue);
      expect(thread.messages, hasLength(2));
      final picture = thread.messages.first.attachment!;
      expect(picture.kind, HelpAttachmentKind.image);
      expect(picture.lengthLabel, isNull);
      expect(picture.sizeLabel, '1 KB');
      expect(thread.messages.last.author, HelpAuthor.support);

      final row = helpTicketFromJson(_row(_thread()))!;
      expect(row.messages.single.body, 'Access Bank is still confirming it.');
    });

    test('replies name who wrote them; only the person’s own are theirs', () {
      final thread = helpTicketFromJson(
        _thread(
          messages: [
            {'author': 'you', 'authorName': 'Ada', 'body': 'Hi', 'at': _at0},
            {
              'author': 'support',
              'authorName': 'Harbour Telecom',
              'body': 'We see it.',
              'at': _at0,
            },
            {
              'author': 'support',
              'authorName': 'iQLY support',
              'body': 'Stepping in.',
              'at': _at0,
            },
            {'author': 'brand', 'body': 'From an older build', 'at': _at0},
          ],
        ),
      )!;
      final [you, business, staff, unknown] = thread.messages;
      expect(you.author, HelpAuthor.you);
      expect(you.authorName, isNull);
      expect(business.fromBusiness, isTrue);
      expect(business.authorName, 'Harbour Telecom');
      expect(staff.fromBusiness, isFalse);
      expect(unknown.author, HelpAuthor.support, reason: 'never the person’s');
      expect(unknown.fromBusiness, isFalse);
      expect(thread.business, 'Harbour Telecom');
      expect(thread.lastReply, same(unknown));

      final row = helpTicketFromJson(
        _row(
            _thread(
              messages: [
                {
                  'author': 'support',
                  'authorName': 'Harbour Telecom',
                  'body': 'We see it.',
                  'at': _at0,
                },
              ],
            ),
          )
          ..['lastMessage'] = {
            'author': 'support',
            'authorName': 'Harbour Telecom',
            'body': 'We see it.',
            'at': _at0,
          },
      )!;
      expect(row.messages.single.authorName, 'Harbour Telecom');
    });

    test('times a week old or more show their date', () {
      final saturday = DateTime(2026, 10, 17, 15);
      expect(
        supportTime(DateTime(2026, 10, 17, 15, 6), saturday),
        'Sat, 3:06 pm',
      );
      expect(
        supportTime(DateTime(2026, 10, 11, 15, 6), saturday),
        'Sun, 3:06 pm',
      );
      expect(
        supportTime(DateTime(2026, 10, 10, 15, 6), saturday),
        '10 Oct, 3:06 pm',
      );
      expect(
        supportTime(DateTime(2026, 10, 12, 15, 6), DateTime(2026, 10, 19, 9)),
        '12 Oct, 3:06 pm',
      );
    });

    for (final names in [true, false]) {
      testWidgets(
        'a business reply ${names ? 'names the business' : 'reads '
                  'as iQLY support without helpAuthorNames'}',
        (tester) async {
          final thread = {
            ..._thread(
              subject: 'Harbour Telecom activation',
              messages: [
                {
                  'author': 'you',
                  'body': 'Stuck on step 2.',
                  'at': '2026-10-09T07:00:00.000Z',
                },
                {
                  'author': 'support',
                  'authorName': 'Harbour Telecom',
                  'body': 'We see your run. Try again now.',
                  'at': '2026-10-17T08:00:00.000Z',
                },
              ],
            ),
            'activationId': 'a_1',
          };
          final api = _api()
            ..on('GET', '/support/unread', (_) => ok({'unread': 1}))
            ..data('GET', '/support/tickets', page([_row(thread)]))
            ..data('GET', '/support/tickets/t_1', thread)
            ..on('POST', '/support/tickets/t_1/read', (_) => ok({'unread': 0}));
          await _launch(
            tester,
            api,
            Routes.support,
            mode: _with({
              LiveFeature.support,
              if (names) LiveFeature.helpAuthorNames,
            }),
          );
          expect(
            find.textContaining(
              names ? 'Harbour Telecom replied · ' : 'Support replied · ',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Harbour Telecom activation'));
          await tester.pumpAndSettle();
          expect(find.text('We see your run. Try again now.'), findsOneWidget);
          expect(find.textContaining('9 Oct, '), findsOneWidget);
          if (names) {
            expect(find.text('Harbour Telecom'), findsOneWidget);
            expect(find.text('iQLY support'), findsNothing);
            expect(find.text('iQ'), findsNothing);
            expect(find.text('Harbour Telecom replied'), findsOneWidget);
            expect(find.text('Write to Harbour Telecom'), findsOneWidget);
          } else {
            expect(find.text('iQLY support'), findsOneWidget);
            expect(find.text('Support replied'), findsOneWidget);
            expect(find.text('Write to support'), findsOneWidget);
          }
        },
      );
    }

    testWidgets('iQLY support stepping into a business thread keeps its name '
        'and sticker', (tester) async {
      final thread = {
        ..._thread(
          subject: 'Harbour Telecom activation',
          messages: [
            {'author': 'you', 'body': 'Stuck.', 'at': _at0},
            {
              'author': 'support',
              'authorName': 'Harbour Telecom',
              'body': 'Looking.',
              'at': _at0,
            },
            {
              'author': 'support',
              'authorName': 'iQLY support',
              'body': 'We confirmed it for you.',
              'at': _at0,
            },
          ],
        ),
        'activationId': 'a_1',
      };
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..data('GET', '/support/tickets/t_1', thread)
        ..on('POST', '/support/tickets/t_1/read', (_) => ok({'unread': 0}));
      await _launch(
        tester,
        api,
        helpThreadPath('t_1'),
        mode: _with({LiveFeature.support, LiveFeature.helpAuthorNames}),
      );
      expect(find.text('iQLY support'), findsOneWidget);
      expect(find.text('iQ'), findsOneWidget);
      expect(find.text('Harbour Telecom'), findsOneWidget);
      expect(find.text('Support replied'), findsOneWidget);
      expect(find.text('Write to Harbour Telecom'), findsOneWidget);
    });

    testWidgets('preview: the samples, both ways to support and no badge', (
      tester,
    ) async {
      final c = await _launch(
        tester,
        _api(),
        Routes.helpCentre,
        mode: Backend.preview,
      );
      expect(c.read(helpServiceProvider), isA<DemoHelpService>());
      expect(find.text('Chat with us'), findsOneWidget);
      expect(find.text('Report an issue'), findsOneWidget);
      expect(_listRow(tester, 'Chat with us').count, 0);
      await tester.tap(find.text('Chat with us'));
      await tester.pumpAndSettle();
      expect(find.text('Withdrawal to Access Bank'), findsOneWidget);
    });

    testWidgets('live without support: no way to a thread and no sample one', (
      tester,
    ) async {
      final api = _api();
      final c = await _launch(tester, api, Routes.helpCentre);
      expect(c.read(helpServiceProvider), isA<PausedHelpService>());
      expect(find.text('Common questions'), findsOneWidget);
      expect(find.text('Chat with us'), findsNothing);
      expect(find.text('Report an issue'), findsNothing);

      await tester.tap(find.text('How long does a withdrawal take?'));
      await tester.pumpAndSettle();
      expect(find.text('Still stuck? Chat with us'), findsNothing);

      c.read(routerProvider).go(Routes.support);
      await tester.pumpAndSettle();
      expect(find.text('Withdrawal to Access Bank'), findsNothing);
      expect(
        api.requests.where((r) => r.url.path.startsWith('/support')),
        isEmpty,
      );
    });

    testWidgets('live with support: the unread badge, the inbox, the thread '
        'read and marked read', (tester) async {
      var unread = 1;
      final report = _thread(
        id: 't_2',
        status: 'open',
        unread: false,
        subject: 'The app',
        reference: 'IQ-HELP-2042',
      );
      final api = _api()
        ..on('GET', '/support/unread', (_) => ok({'unread': unread}))
        ..data('GET', '/support/tickets', page([_row(report), _row(_thread())]))
        ..data('GET', '/support/tickets/t_1', _thread())
        ..on('POST', '/support/tickets/t_1/read', (_) {
          unread = 0;
          return ok({'unread': 0});
        });
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.support}),
      );
      expect(c.read(helpServiceProvider), isA<LiveHelpService>());
      expect(_listRow(tester, 'Help centre').count, 1);
      expect(find.byType(IqCountBadge), findsOneWidget);

      await tester.tap(find.text('Help centre'));
      await tester.pumpAndSettle();
      expect(_listRow(tester, 'Chat with us').count, 1);

      await tester.tap(find.text('Chat with us'));
      await tester.pumpAndSettle();
      expect(find.text('The app'), findsOneWidget);
      expect(find.textContaining('Sent · '), findsOneWidget);
      expect(find.textContaining('Support replied · '), findsOneWidget);

      await tester.tap(find.text('Withdrawal to Access Bank'));
      await tester.pumpAndSettle();
      expect(find.text('Access Bank is still confirming it.'), findsOneWidget);
      expect(find.text('Attached activity.png · 1 KB'), findsOneWidget);
      expect(api.to('/support/tickets/t_1/read', method: 'POST'), hasLength(1));
      expect(await c.read(supportUnreadProvider.future), 0);
    });

    testWidgets('a new conversation opens with one Idempotency-Key, kept '
        'across a send that got no answer; a throttle in its own words', (
      tester,
    ) async {
      var answer = 0;
      final sent = _thread(
        id: 't_9',
        status: 'open',
        unread: false,
        subject: 'Chat with iQLY support',
        messages: [
          {
            'id': 'm_9',
            'author': 'you',
            'body': 'Hello there',
            'at': '2026-10-17T09:59:00.000Z',
            'attachments': <Object>[],
          },
        ],
      );
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..data('GET', '/support/tickets', page([]))
        ..on('POST', '/support/tickets', (request) {
          answer++;
          if (answer == 1) throw http.ClientException('lost', request.url);
          if (answer == 2) return refused(429, 'RATE_LIMITED');
          return ok(sent, status: 201);
        })
        ..on('GET', '/support/tickets/t_9', (_) => ok(sent));
      await _launch(
        tester,
        api,
        Routes.newConversation,
        mode: _with({LiveFeature.support}),
      );
      await tester.enterText(find.byType(EditableText), 'Hello there');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t send. Check your connection.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(
        find.text('Too many tries. Wait a minute, then try again.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      final sends = api.to('/support/tickets', method: 'POST');
      expect(sends, hasLength(3));
      final keys = {for (final s in sends) s.headers['idempotency-key']};
      expect(sends[0].headers['idempotency-key'], isNotNull);
      expect(
        sends[0].headers['idempotency-key'],
        sends[1].headers['idempotency-key'],
        reason: 'the lost send may have landed',
      );
      expect(keys, hasLength(2), reason: 'a refusal starts a new key');
      final body = jsonDecode(sends.last.body) as Map;
      expect(body['subject'], 'Chat with iQLY support');
      expect(body['message'], 'Hello there');
      expect(find.text('Hello there'), findsOneWidget);
    });

    testWidgets('a help request uploads its file first and sends its id; a '
        'refused file and a lost upload say so', (tester) async {
      final files = _Files()..next = _file('screen.mp4');
      var uploads = 0;
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..on('POST', '/support/uploads', (request) {
          uploads++;
          if (uploads == 1) return refused(413, 'VIDEO_TOO_LONG');
          if (uploads == 2) throw http.ClientException('lost', request.url);
          return ok({
            'id': 'up_7',
            'kind': 'video',
            'name': 'screen.mp4',
            'mime': 'video/mp4',
            'bytes': _png.length,
            'lengthSeconds': 31,
          }, status: 201);
        })
        ..on(
          'POST',
          '/support/tickets',
          (_) => ok(_thread(id: 't_5', status: 'open', unread: false)),
        )
        ..data(
          'GET',
          '/support/tickets/t_5',
          _thread(id: 't_5', status: 'open', unread: false),
        );
      await _launch(
        tester,
        api,
        Routes.help,
        mode: _with({LiveFeature.support}),
        files: files,
      );
      await tester.enterText(find.byType(EditableText), 'It says checking.');
      await tester.tap(find.text('Choose a video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from your photos'));
      await tester.pumpAndSettle();
      expect(find.text('That recording is over 60 seconds'), findsOneWidget);

      await tester.tap(find.text('Choose another'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from your photos'));
      await tester.pumpAndSettle();
      expect(files.sources, [SupportSource.photos, SupportSource.photos]);
      expect(
        find.text('Upload failed. Check your connection and retry.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('uploaded, ready to send'), findsOneWidget);
      final upload = api.to('/support/uploads', method: 'POST').last;
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      expect(
        latin1.decode(upload.bodyBytes),
        contains('filename="screen.mp4"'),
      );

      await tester.tap(find.text('Send to support'));
      await tester.pumpAndSettle();
      final body = jsonDecode(
        api.to('/support/tickets', method: 'POST').single.body,
      ) as Map;
      expect(body['uploadIds'], ['up_7']);
      expect(body['subject'], 'Help');
      expect(find.text('Access Bank is still confirming it.'), findsOneWidget);
    });

    testWidgets('a report sends its screenshot and shows the API\'s ticket', (
      tester,
    ) async {
      final files = _Files()..next = _file('activity.png');
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..data('POST', '/support/uploads', _attachment({'id': 'up_3'}))
        ..on(
          'POST',
          '/support/tickets',
          (_) => ok(_thread(id: 't_3', reference: 'IQ-HELP-2044')),
        );
      await _launch(
        tester,
        api,
        Routes.reportIssue,
        mode: _with({LiveFeature.support}),
        files: files,
      );
      await tester.tap(find.text('The app'));
      await tester.enterText(find.byType(EditableText), 'Activity is slow.');
      await tester.tap(find.text('Add a screenshot'));
      await tester.pumpAndSettle();
      expect(find.text('activity.png'), findsOneWidget);
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      final body = jsonDecode(
        api.to('/support/tickets', method: 'POST').single.body,
      ) as Map;
      expect(body['topic'], 'the_app');
      expect(body['subject'], 'The app');
      expect(body['uploadIds'], ['up_3']);
      expect(find.textContaining('Ticket IQ-HELP-2044.'), findsOneWidget);
    });

    testWidgets('Mark as resolved, and a closing account is offered Restore', (
      tester,
    ) async {
      var closing = false;
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..data('GET', '/support/tickets/t_1', _thread(unread: false))
        ..data('POST', '/support/tickets/t_1/read', {'unread': 0})
        ..on(
          'POST',
          '/support/tickets/t_1/resolve',
          (_) => closing
              ? refused(403, 'ACCOUNT_CLOSING')
              : ok(_thread(status: 'resolved', unread: false)),
        );
      final c = await _launch(
        tester,
        api,
        helpThreadPath('t_1'),
        mode: _with({LiveFeature.support}),
      );
      await tester.tap(find.text('Mark as resolved'));
      await tester.pumpAndSettle();
      expect(api.to('/support/tickets/t_1/resolve'), hasLength(1));
      expect(
        c.read(helpTicketsProvider)['t_1']!.status,
        HelpTicketStatus.resolved,
      );

      closing = true;
      await expectLater(
        c.read(helpTicketsProvider.notifier).resolve('t_1'),
        throwsA(
          isA<HelpRefused>().having(
            (r) => r.failure,
            'failure',
            HelpFailure.closing,
          ),
        ),
      );
    });

    testWidgets('the support feed row opens its thread', (tester) async {
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 1})
        ..data('GET', '/notifications', {
          'items': [
            {
              'id': 'n_9',
              'type': 'support',
              'createdAt': '2026-10-17T09:00:00.000Z',
              'readAt': null,
              'title': 'iQLY support replied',
              'body': 'Access Bank is still confirming it.',
              'refs': {'ticketId': 't_1'},
              'amountKobo': null,
              'brief': null,
              'withdrawal': null,
            },
          ],
          'nextCursor': null,
          'unseen': 1,
        })
        ..data('POST', '/notifications/read', {'read': 1})
        ..data('GET', '/support/tickets/t_1', _thread())
        ..data('POST', '/support/tickets/t_1/read', {'unread': 0});
      final c = await _launch(
        tester,
        api,
        Routes.notifications,
        mode: _with({LiveFeature.support}),
      );
      await tester.tap(find.text('iQLY support replied'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpThreadScreen), findsOneWidget);
      expect(c.read(helpTicketsProvider)['t_1'], isNotNull);
      expect(api.to('/support/tickets/t_1', method: 'GET'), isNotEmpty);
    });

    test(
      'without support the row stays in the API\'s words, going nowhere',
      () {
        final note = notificationFromJson({
          'id': 'n_9',
          'type': 'support',
          'createdAt': '2026-10-17T09:00:00.000Z',
          'readAt': null,
          'title': 'iQLY support replied',
          'body': 'Hi',
          'refs': {'ticketId': 't_1'},
        })!;
        final now = DateTime(2026, 10, 17, 10);
        NotificationItem? word({required bool support}) => wordNotification(
          note,
          briefs: const {},
          awards: const {},
          withdrawals: const {},
          now: now,
          support: support,
        );
        expect(word(support: true)!.link!.location, helpThreadPath('t_1'));
        expect(word(support: false)!.link, isNull);
      },
    );
    for (final support in [true, false]) {
      testWidgets('a withdrawal ${support ? 'offers' : 'does not offer'} '
          'help with support ${support ? 'on' : 'off'}', (tester) async {
        final api = _api()
          ..data('GET', '/support/unread', {'unread': 0})
          ..data('GET', '/wallet/withdrawals/w_1', withdrawalJson());
        await _launch(
          tester,
          api,
          withdrawalPath('w_1'),
          mode: support ? _with({LiveFeature.support}) : null,
        );
        expect(
          find.text('Get help with this withdrawal'),
          support ? findsOneWidget : findsNothing,
        );
      });
    }
  });

  group('support sends and files', () {
    testWidgets('a report sent again after a lost answer uploads its '
        'screenshot once and carries the same key', (tester) async {
      final files = _Files()..next = _file('payout.png');
      var opens = 0;
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..data('POST', '/support/uploads', _attachment({'id': 'up_4'}))
        ..on('POST', '/support/tickets', (request) {
          if (++opens == 1) throw http.ClientException('lost', request.url);
          return ok(_thread(id: 't_4', reference: 'IQ-HELP-2045'));
        });
      await _launch(
        tester,
        api,
        Routes.reportIssue,
        mode: _with({LiveFeature.support}),
        files: files,
      );
      await tester.enterText(find.byType(EditableText), 'A payout is missing.');
      await tester.tap(find.text('Add a screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text('Not sent. Check your connection.'), findsOneWidget);
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(api.to('/support/uploads', method: 'POST'), hasLength(1));
      final sends = api.to('/support/tickets', method: 'POST');
      expect(sends, hasLength(2));
      expect(
        sends.first.headers['idempotency-key'],
        sends.last.headers['idempotency-key'],
      );
      expect(sends.first.body, sends.last.body);
      expect(find.textContaining('Ticket IQ-HELP-2045.'), findsOneWidget);
    });

    testWidgets('a reply carries a key kept across a lost answer and a new '
        'one after it lands; a reply from support while the thread is open '
        'is marked read', (tester) async {
      var replies = 0;
      var thread = _thread(unread: false);
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..on('GET', '/support/tickets/t_1', (_) => ok(thread))
        ..data('POST', '/support/tickets/t_1/read', {'unread': 0})
        ..on('POST', '/support/tickets/t_1/messages', (request) {
          if (++replies == 1) throw http.ClientException('lost', request.url);
          return ok(_thread(status: 'open', unread: false));
        });
      final c = await _launch(
        tester,
        api,
        helpThreadPath('t_1'),
        mode: _with({LiveFeature.support}),
      );
      expect(api.to('/support/tickets/t_1/read'), hasLength(1));

      await tester.enterText(find.byType(EditableText), 'Any news?');
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Thanks.');
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      final keys = [
        for (final r in api.to('/support/tickets/t_1/messages'))
          r.headers['idempotency-key'],
      ];
      expect(keys, hasLength(3));
      expect(keys[0], isNotNull);
      expect(keys[1], keys[0], reason: 'the lost reply may have landed');
      expect(keys[2], isNot(keys[0]));

      thread = _thread(
        messages: [
          ...(_thread()['messages']! as List),
          {
            'id': 'm_3',
            'author': 'support',
            'body': 'It has landed now.',
            'at': '2026-10-17T09:30:00.000Z',
            'attachments': <Object>[],
          },
        ],
      );
      c.read(helpTicketsProvider.notifier).refreshOpen();
      await tester.pumpAndSettle();
      expect(find.text('It has landed now.'), findsOneWidget);
      expect(api.to('/support/tickets/t_1/read'), hasLength(2));
    });

    testWidgets('a thread the API does not have says it is gone', (
      tester,
    ) async {
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..on(
          'GET',
          '/support/tickets/t_8',
          (_) => refused(404, 'SUPPORT_TICKET_NOT_FOUND'),
        );
      await _launch(
        tester,
        api,
        helpThreadPath('t_8'),
        mode: _with({LiveFeature.support}),
      );
      expect(find.text('This conversation is gone'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a voice note comes from the voice notes; a refused one and '
        'a picture over its size say their own limits', (tester) async {
      final files = _Files()
        ..next = _file('memo.m4a', kind: HelpAttachmentKind.audio);
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..on('POST', '/support/uploads', (_) => refused(413, 'AUDIO_TOO_LONG'));
      await _launch(
        tester,
        api,
        Routes.help,
        mode: _with({LiveFeature.support}),
        files: files,
      );
      await tester.tap(find.text('Choose a video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a voice note'));
      await tester.pumpAndSettle();
      expect(files.sources, [SupportSource.voiceNote]);
      expect(find.text('That voice note is over 5 minutes'), findsOneWidget);
      expect(
        find.textContaining('Voice notes go up to 5 minutes'),
        findsOneWidget,
      );

      files.next = HelpAttachment(
        name: 'photo.jpg',
        bytes: 11 * 1024 * 1024,
        kind: HelpAttachmentKind.image,
        read: () async => _png,
      );
      await tester.tap(find.text('Choose another'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from your photos'));
      await tester.pumpAndSettle();
      expect(find.text('That picture is over 10 MB'), findsOneWidget);
      expect(
        api.to('/support/uploads', method: 'POST'),
        hasLength(1),
        reason: 'a picture over its size never goes up',
      );
    });

    test('voice notes, 3GP audio and HEIC photos type as the API takes '
        'them', () {
      expect(supportTypeOf('memo.opus', audio: true)!.mime, 'audio/ogg');
      expect(supportTypeOf('memo.aac')!.kind, HelpAttachmentKind.audio);
      final recorded = supportTypeOf('memo.3gp', audio: true)!;
      expect(recorded.kind, HelpAttachmentKind.audio);
      expect(recorded.mime, 'audio/3gpp');
      expect(supportTypeOf('clip.3gp')!.kind, HelpAttachmentKind.video);
      final heic = supportTypeOf('IMG_0001.HEIC')!;
      expect(heic.kind, HelpAttachmentKind.image);
      expect(heic.mime, 'image/heic');
    });

    testWidgets('a picture and a recording are downloaded with the session '
        'token to the account\'s folder and open from there, once', (
      tester,
    ) async {
      final opened = <Uri>[];
      Recordings.open = (source) {
        opened.add(source);
        return _FakeRecording(source);
      };
      addTearDown(() => Recordings.open = openRecording);
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('iqly-files-test'),
      );
      addTearDown(() => tester.runAsync(() => root!.delete(recursive: true)));
      final memo = [0, 0, 0, 0x18, ...'ftypM4A '.codeUnits];
      final api = _api()
        ..data('GET', '/support/unread', {'unread': 0})
        ..on(
          'GET',
          '/support/attachments/up_1',
          (_) => http.Response.bytes(_png, 200),
        )
        ..on(
          'GET',
          '/support/attachments/up_2',
          (_) => http.Response.bytes(memo, 200),
        )
        ..data(
          'GET',
          '/support/tickets/t_1',
          _thread(
            unread: false,
            messages: [
              {
                'id': 'm_1',
                'author': 'you',
                'body': 'Here is what I see.',
                'at': '2026-10-17T07:00:00.000Z',
                'attachments': [
                  _attachment(),
                  _attachment({
                    'id': 'up_2',
                    'kind': 'audio',
                    'name': 'memo.m4a',
                    'mime': 'audio/mp4',
                    'lengthSeconds': 20,
                    'url': 'https://elsewhere.test/support/attachments/up_2',
                  }),
                ],
              },
            ],
          ),
        )
        ..data('POST', '/support/tickets/t_1/read', {'unread': 0});
      final c = await _launch(
        tester,
        api,
        helpThreadPath('t_1'),
        mode: _with({LiveFeature.support}),
        overrides: [
          signedInFilesProvider.overrideWith(
            (ref) =>
                SignedInFiles(api: ref.watch(apiClientProvider)!, root: root),
          ),
        ],
      );
      await tester.tap(find.text('Attached activity.png · 1 KB'));
      await tester.pump();
      for (
        var i = 0;
        i < 20 && find.byType(InteractiveViewer).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final picture = api.to('/support/attachments/up_1', method: 'GET');
      expect(picture, hasLength(1));
      expect(picture.single.url.host, 'api.test');
      expect(picture.single.headers['authorization'], 'Bearer session.signed');
      final image = tester
          .widget<Image>(
            find.descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(Image),
            ),
          )
          .image;
      final shown = ((image as ResizeImage).imageProvider as FileImage).file;
      expect(shown.path, startsWith('${root!.path}/u_1/'));

      await tester.pageBack();
      await tester.pumpAndSettle();
      Future<void> openMemo() async {
        await tester.tap(find.text('Attached memo.m4a · 0:20 · 1 KB'));
        await tester.pump();
        for (
          var i = 0;
          i < 20 && find.byType(IqRecordingPlayer).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await openMemo();
      final read = api.to('/support/attachments/up_2', method: 'GET');
      expect(read, hasLength(1));
      expect(read.single.url.host, 'api.test');
      expect(read.single.headers['authorization'], 'Bearer session.signed');
      expect(opened.single.scheme, 'file');
      final file = File.fromUri(opened.single);
      expect(file.path, startsWith('${root.path}/u_1/'));
      expect(await tester.runAsync(file.readAsBytes), memo);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openMemo();
      expect(
        api.to('/support/attachments/up_2', method: 'GET'),
        hasLength(1),
        reason: 'the downloaded file is used again',
      );
      expect(opened, hasLength(2));

      await tester.runAsync(() => c.read(signedInFilesProvider)!.forget('u_1'));
      expect(
        await tester.runAsync(() => Directory('${root.path}/u_1').exists()),
        isFalse,
      );
    });
  });

  group('business note', () {
    final note = {
      'business': 'Sunline Foods',
      'body': 'The bus stop detail sold it.',
      'sentAt': '2026-10-16T10:00:00.000Z',
    };
    FakeApi noteApi() => _api()
      ..data(
        'GET',
        '/submissions/mine',
        page([
          submissionJson({'note': note}),
        ]),
      )
      ..data('GET', '/submissions/s_1', submissionJson({'note': note}))
      ..data('GET', '/submissions/s_1/outcome', {
        'submissionId': 's_1',
        'challengeId': 'c_9',
        'link': 'https://iqly.net/challenges/a-closed-brief',
        'resultsPublishedAt': '2026-10-02T10:00:00.000Z',
        'entries': 12,
        'rank': 1,
        'leaders': <Object>[],
        'note': note,
      });

    testWidgets('live with the note on: Submission detail and the result '
        'show it', (tester) async {
      final api = noteApi();
      final c = await _launch(
        tester,
        api,
        submissionPath('s_1'),
        mode: _with({LiveFeature.businessNote}),
      );
      expect(c.read(businessNoteShownProvider), isTrue);
      expect(find.text('A note from the business'), findsOneWidget);
      expect(find.text('The bus stop detail sold it.'), findsOneWidget);

      c.read(routerProvider).go(resultPath('s_1'));
      await tester.pumpAndSettle();
      expect(find.text('You did it.'), findsOneWidget);
      expect(find.text('The bus stop detail sold it.'), findsOneWidget);
    });

    testWidgets('live with the note off: neither shows it', (tester) async {
      final c = await _launch(tester, noteApi(), submissionPath('s_1'));
      expect(c.read(businessNoteShownProvider), isFalse);
      expect(find.text('A note from the business'), findsNothing);
      c.read(routerProvider).go(resultPath('s_1'));
      await tester.pumpAndSettle();
      expect(find.text('You did it.'), findsOneWidget);
      expect(find.text('The bus stop detail sold it.'), findsNothing);
    });

    test('the note on a submission item and an outcome', () {
      final submission = submissionFromJson(submissionJson({'note': note}))!;
      expect(submission.note!.business, 'Sunline Foods');
      expect(submissionFromJson(submissionJson())!.note, isNull);
    });
  });

  group('submission files', () {
    final files = [
      {
        'id': 'f_1',
        'type': 'image',
        'url': 'https://api.test/submissions/files/f_1',
      },
      {
        'id': 'f_2',
        'type': 'pdf',
        'url': 'https://api.test/submissions/files/f_2',
      },
    ];

    test(
      'a submission item lists its files; one without a url is left out',
      () {
        final submission = submissionFromJson(
          submissionJson({
            'files': [
              ...files,
              {'id': 'f_3', 'type': 'pdf'},
            ],
          }),
        )!;
        expect(
          [for (final f in submission.files) (f.id, f.label)],
          [('f_1', 'Image attachment'), ('f_2', 'PDF attachment')],
        );
        expect(
          submissionFromJson(submissionJson({'files': null}))!.files,
          isEmpty,
        );
      },
    );

    testWidgets('Submission detail lists them; a picture opens read with the '
        'session token, a PDF goes to the save dialog', (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('iqly-files-test'),
      );
      addTearDown(() => tester.runAsync(() => root!.delete(recursive: true)));
      final saver = _Saver();
      final api = _api()
        ..data('GET', '/submissions/s_1', submissionJson({'files': files}))
        ..on(
          'GET',
          '/submissions/files/f_1',
          (_) => http.Response.bytes(
            _png,
            200,
            headers: {'content-type': 'image/png'},
          ),
        )
        ..on(
          'GET',
          '/submissions/files/f_2',
          (_) => http.Response.bytes(
            utf8.encode('%PDF-1.4'),
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        );
      await _launch(
        tester,
        api,
        submissionPath('s_1'),
        overrides: [
          signedInFilesProvider.overrideWith(
            (ref) =>
                SignedInFiles(api: ref.watch(apiClientProvider)!, root: root),
          ),
          fileSaverProvider.overrideWithValue(saver),
        ],
      );
      expect(find.text('Attachments'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);

      Future<void> open(String label) async {
        await tester.scrollUntilVisible(find.text(label), 100);
        await tester.tap(find.text(label));
        await tester.pump();
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await open('Image attachment');
      final read = api.to('/submissions/files/f_1', method: 'GET');
      expect(read.single.headers['authorization'], 'Bearer session.signed');
      final image = tester.widget<Image>(find.byType(Image)).image;
      expect(image, isA<FileImage>());
      expect((image as FileImage).file.path, startsWith('${root!.path}/u_1/'));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('PDF attachment'), 100);
      await tester.tap(find.text('PDF attachment'));
      await tester.pump();
      for (var i = 0; i < 20 && saver.saved.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PDF saved'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        api
            .to('/submissions/files/f_2', method: 'GET')
            .single
            .headers['authorization'],
        'Bearer session.signed',
      );
      expect(saver.saved, [
        ('Why do people stop saving.pdf', 'application/pdf', 8),
      ]);
    });

    test('a saved PDF is named after the brief, numbered when there are '
        'more, and after its id without a title', () {
      const image = SubmissionFile(id: 'f_1', type: 'image', url: 'u');
      const pdf = SubmissionFile(id: 'f_2', type: 'pdf', url: 'u');
      const other = SubmissionFile(id: 'f_3', type: 'pdf', url: 'u');
      expect(
        submissionPdfName('Weeknight dinner: why noodles win?', pdf, [
          image,
          pdf,
        ]),
        'Weeknight dinner why noodles win.pdf',
      );
      expect(
        submissionPdfName('Data / plans', other, [image, pdf, other]),
        'Data plans 2.pdf',
      );
      expect(submissionPdfName(null, pdf, [pdf]), 'f_2.pdf');
      expect(submissionPdfName('  ?  ', pdf, [pdf]), 'f_2.pdf');
      expect(submissionPdfName('a' * 120, pdf, [pdf]), '${'a' * 80}.pdf');
    });

    for (final (name, answer, status, toast) in [
      ('a cancelled save says nothing', FileSave.cancelled, 200, null),
      (
        'a save that fails says so',
        FileSave.failed,
        200,
        'PDF not saved. Try again.',
      ),
      (
        'a PDF the API no longer has says so, not to check the connection',
        FileSave.saved,
        404,
        'This file is no longer available.',
      ),
    ]) {
      testWidgets(name, (tester) async {
        final saver = _Saver(answer: answer);
        final root = await tester.runAsync(
          () => Directory.systemTemp.createTemp('iqly-files-test'),
        );
        addTearDown(() => tester.runAsync(() => root!.delete(recursive: true)));
        final api = _api()
          ..data('GET', '/submissions/s_1', submissionJson({'files': files}))
          ..on(
            'GET',
            '/submissions/files/f_2',
            (_) => http.Response.bytes(
              utf8.encode('%PDF-1.4'),
              status,
              headers: {'content-type': 'application/pdf'},
            ),
          );
        await _launch(
          tester,
          api,
          submissionPath('s_1'),
          overrides: [
            signedInFilesProvider.overrideWith(
              (ref) =>
                  SignedInFiles(api: ref.watch(apiClientProvider)!, root: root),
            ),
            fileSaverProvider.overrideWithValue(saver),
          ],
        );
        await tester.scrollUntilVisible(find.text('PDF attachment'), 100);
        await tester.tap(find.text('PDF attachment'));
        await tester.pump();
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (saver.saved.isNotEmpty ||
              find.byType(IqToast).evaluate().isNotEmpty) {
            break;
          }
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(saver.saved, hasLength(status == 200 ? 1 : 0));
        expect(find.text('PDF saved'), findsNothing);
        expect(
          find.text('Couldn’t load. Check your connection.'),
          findsNothing,
        );
        if (toast == null) {
          expect(find.byType(IqToast), findsNothing);
        } else {
          expect(find.text(toast), findsOneWidget);
        }
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a picture the API no longer has says so, with nothing to '
        'try again', (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('iqly-files-test'),
      );
      addTearDown(() => tester.runAsync(() => root!.delete(recursive: true)));
      final api = _api()
        ..data('GET', '/submissions/s_1', submissionJson({'files': files}))
        ..on('GET', '/submissions/files/f_1', (_) => http.Response('', 404));
      await _launch(
        tester,
        api,
        submissionFilePath('s_1', 'f_1'),
        overrides: [
          signedInFilesProvider.overrideWith(
            (ref) =>
                SignedInFiles(api: ref.watch(apiClientProvider)!, root: root),
          ),
        ],
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('This file is no longer available.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a picture opened from a link finds its file by id; without '
        'one, or for a file that is not a picture, back to the submission', (
      tester,
    ) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('iqly-files-test'),
      );
      addTearDown(() => tester.runAsync(() => root!.delete(recursive: true)));
      final api = _api()
        ..data('GET', '/submissions/s_1', submissionJson({'files': files}))
        ..on(
          'GET',
          '/submissions/files/f_1',
          (_) => http.Response.bytes(
            _png,
            200,
            headers: {'content-type': 'image/png'},
          ),
        );
      final container = await _launch(
        tester,
        api,
        submissionFilePath('s_1', 'f_1'),
        overrides: [
          signedInFilesProvider.overrideWith(
            (ref) =>
                SignedInFiles(api: ref.watch(apiClientProvider)!, root: root),
          ),
        ],
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(SubmissionFileScreen), findsOneWidget);
      expect(find.text('Image attachment'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image)).image;
      expect((image as FileImage).file.path, startsWith('${root!.path}/u_1/'));

      final router = container.read(routerProvider);
      for (final location in [
        '/submissions/s_1/file',
        submissionFilePath('s_1', 'f_2'),
        submissionFilePath('s_1', 'f_9'),
      ]) {
        router.go(location);
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(SubmissionFileScreen),
          findsNothing,
          reason: location,
        );
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          submissionPath('s_1'),
          reason: location,
        );
      }
    });
  });

  group('referral rewards', () {
    Map<String, Object?> referrals({bool enabled = true}) => {
      'code': 'ADA24',
      'memberSince': '2026-10-15T10:00:00.000Z',
      'invitedBy': 'Chidi E.',
      'invitedByReward': {
        'status': 'paid',
        'amountKobo': 60000,
        'at': '2026-10-16T10:00:00.000Z',
        'ledgerId': 'l_9',
      },
      'applyUntil': '2026-11-14T10:00:00.000Z',
      'invites': [
        {
          'name': 'Ngozi E.',
          'status': 'won',
          'at': '2026-10-10T10:00:00Z',
          'reward': {
            'status': 'paid',
            'amountKobo': 75000,
            'at': '2026-10-10T10:00:00Z',
            'ledgerId': 'l_8',
          },
        },
        {
          'name': 'Tunde A.',
          'status': 'won',
          'at': '2026-10-11T10:00:00Z',
          'reward': {
            'status': 'capped',
            'amountKobo': 75000,
            'at': '2026-10-11T10:00:00Z',
            'ledgerId': null,
          },
        },
      ],
      'rewards': {
        'enabled': enabled,
        'amountKobo': 75000,
        'inviteeAmountKobo': 60000,
        'monthlyCap': 20,
        'earnedKobo': 135000,
        'paid': 1,
        'paidThisMonth': 1,
      },
    };

    testWidgets('live with rewards on: the API\'s amounts, each reward\'s '
        'status and the person\'s own', (tester) async {
      final api = _api()..data('GET', '/me/referrals', referrals());
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.referrals, LiveFeature.referralRewards}),
      );
      expect(c.read(referralTermsProvider)!.amountKobo, 75000);
      expect(find.text('Invite friends, earn ₦750'), findsOneWidget);
      expect(find.textContaining('₦500'), findsNothing);

      await tester.tap(find.text('Invite friends, earn ₦750'));
      await tester.pumpAndSettle();
      expect(find.text('Invite friends and earn'), findsOneWidget);
      expect(
        find.text(
          'You both get ₦750 when a friend you invite wins their first brief.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Referral history'));
      await tester.pumpAndSettle();
      expect(find.text('₦1,350.00'), findsOneWidget);
      expect(find.text('EARNED'), findsOneWidget);
      expect(find.text('Chidi E. invited you'), findsOneWidget);
      expect(find.text('Won a first brief · ₦600 paid to you'), findsOneWidget);
      expect(find.text('Won a first brief · ₦750 paid to you'), findsOneWidget);
      expect(find.text('Won a first brief'), findsOneWidget);
    });

    testWidgets('live with rewards off: no money promised, whatever the API '
        'answers', (tester) async {
      final api = _api()..data('GET', '/me/referrals', referrals());
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.referrals}),
      );
      expect(c.read(referralTermsProvider), isNull);
      expect(find.text('Invite friends to iQLY'), findsOneWidget);
      await tester.tap(find.text('Invite friends to iQLY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Referral history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('₦'), findsNothing);
      expect(find.text('Chidi E. invited you'), findsNothing);
      expect(find.text('WON'), findsOneWidget);
    });

    test('the share message carries the friend\'s amount, or none', () {
      expect(
        ReferralsService.message('ADA24', reward: '₦600'),
        contains('we both get ₦600 when you win your first brief'),
      );
      expect(
        ReferralsService.message('ADA24', reward: null),
        isNot(contains('₦')),
      );
    });

    test('a reward feed row opens Referral history; the ledger row is a '
        'referral by its source', () {
      final note = notificationFromJson({
        'id': 'n_7',
        'type': 'referral_reward',
        'createdAt': '2026-10-17T09:00:00.000Z',
        'readAt': null,
        'title': '₦500.00 added to your wallet',
        'body':
            'Ngozi E. won a first brief, so your ₦500.00 referral reward is '
            'in your wallet now.',
        'refs': {'ledgerId': 'l_8'},
        'amountKobo': 50000,
      })!;
      expect(note.event, NotificationEvent.rewardCredited);
      expect(note.entryId, 'l_8');
      final words = wordNotification(
        note,
        briefs: const {},
        awards: const {},
        withdrawals: const {},
        now: DateTime(2026, 10, 17, 10),
      )!;
      expect(words.title, '₦500.00 added to your wallet');
      expect(words.link!.location, Routes.referralHistory);

      final row = ledgerEntryFromJson(
        transactionJson({
          'id': 'l_9',
          'amount': 50000,
          'source': 'referral',
          'submissionId': null,
          'challengeId': null,
          'challengeTitle': null,
          'businessName': null,
          'note': 'First win with Chidi E.\'s invite code',
          'referredName': 'Chidi E.',
        }),
      )!;
      expect(row.source, RewardSource.referral);
      expect(row.note, 'First win with Chidi E.\'s invite code');
    });
  });

  group('avatar photo', () {
    Map<String, Object?> avatar({String? url, bool photo = false}) => {
      'spec': photo
          ? {'kind': 'photo', 'url': ?url}
          : {'kind': 'buddy', 'buddy': 'Moon'},
      'look': IqAvatarPresets.person2.toJson(),
      'preset': null,
      'isDefault': false,
      'updatedAt': '2026-10-01T10:00:00.000Z',
      'photoUrl': url,
    };
    const url = 'https://api.test/me/avatar/photo?v=1';

    testWidgets('a picked photo goes up and is the account\'s; it stays the '
        'account\'s after a sign out', (tester) async {
      var account = avatar();
      final api = _api()
        ..on('GET', '/me/avatar', (_) => ok(account))
        ..on('PUT', '/me/avatar/photo', (_) {
          account = avatar(url: url, photo: true);
          return ok(account);
        })
        ..on('GET', '/me/avatar/photo', (_) => http.Response.bytes(_png, 200))
        ..on('PUT', '/me/avatar', (_) => ok(avatar()));
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar, LiveFeature.avatarPhoto}),
      );
      await c.read(avatarProvider.notifier).choose(IqPhotoAvatar(_png));
      await tester.pumpAndSettle();
      final put = api.to('/me/avatar/photo', method: 'PUT').single;
      expect(put.headers['content-type'], startsWith('multipart/form-data'));
      expect(latin1.decode(put.bodyBytes), contains('image/png'));
      expect(put.headers['authorization'], 'Bearer session.signed');
      expect(api.to('/me/avatar', method: 'PUT'), isEmpty);
      expect(c.read(avatarProvider).spec, IqPhotoAvatar(_png));

      await c.read(avatarProvider.notifier).forget();
      await tester.pumpAndSettle();
      expect(c.read(avatarProvider).spec, IqPhotoAvatar(_png));
    });

    testWidgets('a new phone reads the account\'s photo with the session '
        'token and shows it', (tester) async {
      final api = _api()
        ..data('GET', '/me/avatar', avatar(url: url, photo: true))
        ..on(
          'GET',
          '/me/avatar/photo',
          (_) => http.Response.bytes(
            _png,
            200,
            headers: {'content-type': 'image/png'},
          ),
        );
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar, LiveFeature.avatarPhoto}),
      );
      final read = api.to('/me/avatar/photo', method: 'GET').single;
      expect(read.url.query, 'v=1');
      expect(read.headers['authorization'], 'Bearer session.signed');
      expect(
        c.read(avatarProvider).spec,
        IqPhotoAvatar(Uint8List.fromList(_png)),
      );
    });

    testWidgets('holding the photo removes it from the account', (
      tester,
    ) async {
      final api = _api()
        ..data('GET', '/me/avatar', avatar(url: url, photo: true))
        ..on('GET', '/me/avatar/photo', (_) => http.Response.bytes(_png, 200))
        ..on('DELETE', '/me/avatar/photo', (_) => ok(avatar()));
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar, LiveFeature.avatarPhoto}),
      );
      expect(c.read(avatarProvider).photo, isNotNull);
      chooseAvatar(tester.element(find.byType(MoreScreen)));
      await tester.pumpAndSettle();
      await tester.longPress(find.bySemanticsLabel('Your photo'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this photo?'), findsOneWidget);
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(api.to('/me/avatar/photo', method: 'DELETE'), hasLength(1));
      expect(c.read(avatarProvider).photo, isNull);
      expect(c.read(avatarProvider).spec, isNot(isA<IqPhotoAvatar>()));
    });

    testWidgets('photos off: the photo stays on the phone, as before', (
      tester,
    ) async {
      final api = _api()
        ..data('GET', '/me/avatar', avatar())
        ..on('PUT', '/me/avatar', (_) => ok(avatar()));
      final c = await _launch(
        tester,
        api,
        Routes.more,
        mode: _with({LiveFeature.avatar}),
      );
      expect(c.read(liveAvatarServiceProvider)!.photos, isFalse);
      await c.read(avatarProvider.notifier).choose(IqPhotoAvatar(_png));
      await tester.pumpAndSettle();
      expect(api.to('/me/avatar/photo'), isEmpty);
      expect(c.read(avatarProvider).spec, IqPhotoAvatar(_png));
    });

    test('the media type comes from the bytes', () {
      expect(photoMediaType(_png), 'image/png');
      expect(
        photoMediaType(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0])),
        'image/jpeg',
      );
    });
  });
}
