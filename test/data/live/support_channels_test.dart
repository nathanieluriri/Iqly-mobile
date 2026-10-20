import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/help_data.dart';
import 'package:iqly_mobile/data/live/live_help_service.dart';

void main() {
  test('a contributor_business thread names its business, who read it and '
      'who wrote each reply', () {
    final ticket = helpTicketFromJson({
      'id': 't_1',
      'channel': 'contributor_business',
      'with': {
        'kind': 'business',
        'name': 'Kudi Box',
        'logoUrl': 'https://api.iqly.net/profiles/brands/o_1/logo',
      },
      'subject': 'Kudi Box activation',
      'status': 'replied',
      'activationId': 'a_2',
      'readBy': {'iqly': null, 'business': '2026-10-19T09:00:00.000Z'},
      'messages': [
        {
          'id': 'm_1',
          'author': 'you',
          'body': 'Hi',
          'at': '2026-10-19T08:00:00.000Z',
        },
        {
          'id': 'm_2',
          'author': 'support',
          'authorName': 'iQLY support',
          'authorKind': 'iqly',
          'body': 'We asked them',
          'at': '2026-10-19T09:00:00.000Z',
        },
        {
          'id': 'm_3',
          'author': 'support',
          'authorName': 'Kudi Box',
          'authorKind': 'business',
          'body': 'Done',
          'at': '2026-10-19T10:00:00.000Z',
        },
      ],
    })!;
    expect(ticket.channel, HelpChannel.business);
    expect(ticket.withName, 'Kudi Box');
    expect(ticket.withLogo, contains('/logo'));
    expect(ticket.readAt!.toUtc(), DateTime.utc(2026, 10, 19, 9));
    expect(ticket.messages[1].side, HelpSide.iqly);
    expect(ticket.messages[1].fromBusiness, isFalse);
    expect(ticket.messages[2].fromBusiness, isTrue);
  });

  test('an API without supportChannels reads as a thread with iQLY', () {
    final ticket = helpTicketFromJson({
      'id': 't_2',
      'subject': 'Chat with iQLY support',
      'status': 'open',
      'messages': const [],
    })!;
    expect(ticket.channel, HelpChannel.iqly);
    expect(ticket.readAt, isNull);
  });
}
