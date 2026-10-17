import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/live/mappers.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/referrals_service.dart';

import 'live_data_fixtures.dart';

DateTime _utc(String iso) => DateTime.parse(iso);

void main() {
  group('brief', () {
    test('maps every field of a public brief', () {
      final brief = briefFromJson(challengeJson())!;
      expect(brief.id, 'c_1');
      expect(brief.title, 'Make Sunday data day');
      expect(
        brief.body,
        'Most of our customers top up on Sundays.\n\n'
        'What would make Sunday the day they buy data?\n\n'
        '• One campaign idea\n'
        '• A line for the poster',
      );
      expect(brief.tier, Tier.advanced);
      expect(brief.category, Category.customerExperience);
      expect(brief.rewardPoolKobo, 15000000);
      expect(brief.status, BriefStatus.live);
      expect(brief.isLive, isTrue);
      expect(
        brief.deadline!.isAtSameMomentAs(_utc('2026-10-25T17:00:00.000Z')),
        isTrue,
        reason: 'the effective deadline, extension included',
      );
      expect(brief.deadline!.isUtc, isFalse, reason: 'read in local time');
      expect(brief.businessName, 'Kudi Box');
      expect(
        brief.createdAt.isAtSameMomentAs(_utc('2026-10-10T09:00:00.000Z')),
        isTrue,
        reason: 'published, not drafted',
      );
      expect(brief.interest, 'finance_fintech');
      expect(brief.spotsTotal, 40);
      expect(brief.spotsLeft, 28);
      expect(
        brief.winnerRule,
        '1st place ₦90,000 · 2nd place ₦45,000 · 3rd place ₦15,000',
      );
      expect(brief.minutes, isNull);
      expect(brief.logo, 'https://api.test/profiles/brands/b_1/logo');
      expect(
        brief.cover,
        'https://api.test/challenges/c_1/cover?v=1760086800000',
      );
    });

    test('fills what the API leaves out', () {
      final brief = briefFromJson(
        challengeJson({
          'title': null,
          'deliverables': <String>[],
          'tier': null,
          'category': null,
          'rewardPool': null,
          'winnerConfig': null,
          'maxSubmissions': null,
          'audienceFilters': null,
          'brandName': null,
          'brandLogoUrl': null,
          'coverUrl': null,
          'publishedAt': null,
          'minutes': 7,
        }),
      )!;
      expect(brief.title, 'Untitled');
      expect(
        brief.body,
        'Most of our customers top up on Sundays.\n\n'
        'What would make Sunday the day they buy data?',
      );
      expect(brief.tier, Tier.standard);
      expect(brief.category, Category.other);
      expect(brief.rewardPoolKobo, 0);
      expect(brief.winnerRule, isNull);
      expect(brief.spotsTotal, isNull);
      expect(brief.spotsLeft, isNull);
      expect(brief.interest, isNull);
      expect(brief.businessName, isNull, reason: 'shows "Private business"');
      expect(brief.logo, isNull);
      expect(brief.cover, isNull);
      expect(
        brief.createdAt.isAtSameMomentAs(_utc('2026-10-01T09:00:00.000Z')),
        isTrue,
      );
      expect(brief.minutes, 7);
    });

    test('a brief with only deliverables is the bullets', () {
      final brief = briefFromJson(challengeJson({'bodyText': ''}))!;
      expect(brief.body, '• One campaign idea\n• A line for the poster');
    });

    test('spots left never go below zero', () {
      final full = briefFromJson(
        challengeJson({'maxSubmissions': 10, 'submissionCount': 14}),
      )!;
      expect(full.spotsTotal, 10);
      expect(full.spotsLeft, 0);
    });

    test('every category in snake case, other included; unknown is Other', () {
      const names = {
        'marketing': Category.marketing,
        'strategy': Category.strategy,
        'customer_experience': Category.customerExperience,
        'product_design': Category.productDesign,
        'innovation': Category.innovation,
        'technology': Category.technology,
        'other': Category.other,
        'space_travel': Category.other,
      };
      for (final MapEntry(:key, :value) in names.entries) {
        expect(
          briefFromJson(challengeJson({'category': key}))!.category,
          value,
          reason: key,
        );
      }
      expect(Category.other.label, 'Other');
    });

    test('closed reads closed; an unknown status reads closed too', () {
      expect(
        briefFromJson(challengeJson({'status': 'closed'}))!.status,
        BriefStatus.closed,
      );
      expect(
        briefFromJson(challengeJson({'status': 'archived'}))!.status,
        BriefStatus.closed,
      );
    });

    test('the deadline falls back to the extension, then the deadline', () {
      final brief = briefFromJson(
        challengeJson({'effectiveDeadline': null, 'extendedDeadline': null}),
      )!;
      expect(
        brief.deadline!.isAtSameMomentAs(_utc('2026-10-24T17:00:00.000Z')),
        isTrue,
      );
    });

    test('a row without an id is dropped', () {
      expect(briefFromJson(challengeJson({'id': null})), isNull);
      expect(briefFromJson('not a brief'), isNull);
      expect(rowsOf([challengeJson(), 7, null], briefFromJson), hasLength(1));
    });
  });

  group('winner rule, as iqly.net words the prize breakdown', () {
    test('places floor their share and first takes the kobo left', () {
      expect(
        winnerRule({
          'type': 'top_n',
          'n': 3,
          'split': [50, 30, 20],
        }, 10000001),
        '1st place ₦50,000 · 2nd place ₦30,000 · 3rd place ₦20,000',
      );
      expect(
        winnerRule({
          'type': 'top_n',
          'n': 12,
          'split': [for (var i = 0; i < 10; i++) 9, 5, 5],
        }, 10000000)!.split(' · ').last,
        '#12 place ₦5,000',
      );
    });

    test('tiers read Top, then Next, with their share', () {
      expect(
        winnerRule({
          'type': 'top_percent',
          'tiers': [
            {'submissionPercent': 10, 'poolPercent': 70},
            {'submissionPercent': 15, 'poolPercent': 30},
          ],
        }, 50000000),
        'Top 10% share ₦350,000 · Next 15% share ₦150,000',
      );
    });

    test('no rows, no pool or an unknown kind', () {
      expect(
        winnerRule({'type': 'top_n', 'split': <int>[]}, 100000),
        'Winners split the pool once submissions are in.',
      );
      expect(
        winnerRule({
          'type': 'top_n',
          'split': [100],
        }, null),
        isNull,
      );
      expect(winnerRule({'type': 'lottery'}, 100000), isNull);
      expect(winnerRule(null, 100000), isNull);
    });
  });

  group('submission item', () {
    test('maps the entry, its embedded brief and its award', () {
      final s = submissionFromJson(submissionJson())!;
      expect(s.id, 's_1');
      expect(s.briefId, 'c_9');
      expect(s.title, 'Sunday is data day');
      expect(s.body, 'Give a bonus bundle on Sundays.');
      expect(s.status, SubmissionStatus.winner);
      expect(
        s.createdAt.isAtSameMomentAs(_utc('2026-09-20T10:00:00.000Z')),
        isTrue,
      );
      final brief = s.brief!;
      expect(brief.id, 'c_9');
      expect(brief.title, 'Why do people stop saving?');
      expect(brief.businessName, 'Orchid Foods');
      expect(brief.status, BriefStatus.closed);
      expect(brief.rewardPoolKobo, 25000000);
      expect(
        brief.deadline!.isAtSameMomentAs(_utc('2026-09-30T17:00:00.000Z')),
        isTrue,
      );
      expect(brief.logo, 'https://api.test/profiles/brands/b_9/logo');
      expect(brief.cover, 'https://api.test/challenges/c_9/cover?v=1');
      expect(brief.body, isEmpty);
      expect(brief.category, Category.other);
      expect(brief.tier, Tier.standard);
      final award = s.award!;
      expect(award.amountKobo, 1250000);
      expect(
        award.awardedAt.isAtSameMomentAs(_utc('2026-10-02T10:00:00.000Z')),
        isTrue,
      );
      expect(award.ledgerId, 't_1');
    });

    test('status comes from the result', () {
      SubmissionStatus of(Object? result) =>
          submissionFromJson(submissionJson({'result': result}))!.status;
      expect(of('under_review'), SubmissionStatus.pending);
      expect(of('winner'), SubmissionStatus.winner);
      expect(of('not_selected'), SubmissionStatus.filteredOut);
      expect(of('appealed'), SubmissionStatus.pending, reason: 'unknown');
      expect(of(null), SubmissionStatus.pending);
    });

    test('an entry under review: no award, an anonymous brief', () {
      final s = submissionFromJson(
        submissionJson({
          'result': 'under_review',
          'status': 'filtered_out',
          'title': null,
          'award': null,
          'brief': {
            'id': 'c_2',
            'slug': null,
            'title': 'A tagline for a solar kiosk network',
            'businessName': null,
            'logoUrl': null,
            'coverUrl': null,
            'deadline': '2026-10-30T17:00:00.000Z',
            'rewardPool': 15000000,
            'status': 'live',
          },
        }),
      )!;
      expect(s.status, SubmissionStatus.pending, reason: 'AI-filtered stays');
      expect(s.title, 'Untitled');
      expect(s.award, isNull);
      expect(s.brief!.businessName, isNull);
      expect(s.brief!.isLive, isTrue);
    });

    test('an entry without an id or a brief id is dropped', () {
      expect(submissionFromJson(submissionJson({'id': null})), isNull);
      expect(submissionFromJson(submissionJson({'challengeId': null})), isNull);
    });
  });

  group('ledger row', () {
    test('a winner credit is an award for its submission', () {
      final l = ledgerEntryFromJson(transactionJson())!;
      expect(l.id, 't_1');
      expect(l.type, LedgerType.award);
      expect(l.amountKobo, 1250000);
      expect(
        l.createdAt.isAtSameMomentAs(_utc('2026-10-02T10:00:00.000Z')),
        isTrue,
      );
      expect(l.submissionId, 's_1');
      expect(l.business, 'Orchid Foods');
      expect(l.note, isNull);
      expect(l.referred, isNull);
      expect(l.reversal, isFalse);
      expect(l.earned, isTrue);
      expect(l.source, RewardSource.submission);
    });

    test('a withdrawal is money out, signed as sent', () {
      final l = ledgerEntryFromJson(
        transactionJson({
          'id': 't_2',
          'amount': -1000000,
          'type': 'withdrawal',
          'reference': 'w_1',
          'source': 'withdrawal',
          'submissionId': null,
          'challengeId': null,
          'challengeTitle': null,
          'businessName': null,
          'withdrawalId': 'w_1',
        }),
      )!;
      expect(l.type, LedgerType.withdrawal);
      expect(l.amountKobo, -1000000);
      expect(l.earned, isFalse);
    });

    test('a reversal is money back, never earnings', () {
      final rows = [
        transactionJson(),
        transactionJson({
          'id': 't_2',
          'amount': -1000000,
          'type': 'withdrawal',
          'source': 'withdrawal',
          'submissionId': null,
          'businessName': null,
        }),
        transactionJson({
          'id': 't_3',
          'amount': 1000000,
          'type': 'reversal',
          'source': 'reversal',
          'submissionId': null,
          'challengeId': null,
          'challengeTitle': null,
          'businessName': null,
          'withdrawalId': 'w_1',
          'note': null,
          'referredName': null,
        }),
      ];
      final ledger = rowsOf(rows, ledgerEntryFromJson);
      final reversal = ledger.last;
      expect(reversal.type, LedgerType.award);
      expect(reversal.amountKobo, 1000000);
      expect(reversal.reversal, isTrue);
      expect(reversal.earned, isFalse);

      final totals = walletTotals(ledger, const []);
      expect(totals.totalEarnedKobo, 1250000);
      expect(totals.withdrawableKobo, 1250000);
      expect(referralEarnedKobo(ledger), 0);
    });

    test('a note and a referred friend come across as sent', () {
      final l = ledgerEntryFromJson(
        transactionJson({
          'submissionId': null,
          'businessName': null,
          'note': 'Ngozi E. won a first brief',
          'referredName': 'Ngozi E.',
        }),
      )!;
      expect(l.note, 'Ngozi E. won a first brief');
      expect(l.referred, 'Ngozi E.');
    });

    test('an unknown kind, or no amount, is dropped', () {
      expect(ledgerEntryFromJson(transactionJson({'type': 'fee'})), isNull);
      expect(ledgerEntryFromJson(transactionJson({'amount': null})), isNull);
      expect(ledgerEntryFromJson(transactionJson({'id': null})), isNull);
    });
  });

  group('withdrawal', () {
    test('maps every field, the account as its last four digits', () {
      final w = withdrawalFromJson(
        withdrawalJson({
          'status': 'failed',
          'failureReason': 'Account name mismatch',
          'sentAt': '2026-10-17T08:01:00.000Z',
          'completedAt': '2026-10-17T08:05:00.000Z',
        }),
      )!;
      expect(w.id, 'w_1');
      expect(w.amountKobo, 1000000);
      expect(w.status, WithdrawalStatus.failed);
      expect(
        w.createdAt.isAtSameMomentAs(_utc('2026-10-17T08:00:00.000Z')),
        isTrue,
      );
      expect(w.reference, 'IQ-WD-261017-K7QM');
      expect(w.bankName, 'Access Bank');
      expect(w.accountNumber, '6789');
      expect(w.destination, 'Access Bank ••6789');
      expect(
        w.sentAt!.isAtSameMomentAs(_utc('2026-10-17T08:01:00.000Z')),
        isTrue,
      );
      expect(
        w.completedAt!.isAtSameMomentAs(_utc('2026-10-17T08:05:00.000Z')),
        isTrue,
      );
      expect(w.failureReason, 'Account name mismatch');
      expect(w.approvedAt, isNull);
      expect(w.held, isFalse);
    });

    test('status by name; an unknown one reads as pending', () {
      for (final status in WithdrawalStatus.values) {
        expect(
          withdrawalFromJson(withdrawalJson({'status': status.name}))!.status,
          status,
        );
      }
      expect(
        withdrawalFromJson(withdrawalJson({'status': 'held'}))!.status,
        WithdrawalStatus.pending,
      );
    });

    test('an older row without a destination keeps the rest', () {
      final w = withdrawalFromJson(
        withdrawalJson({
          'reference': null,
          'bankName': null,
          'accountLast4': null,
        }),
      )!;
      expect(w.reference, isNull);
      expect(w.destination, isNull);
      expect(withdrawalFromJson(withdrawalJson({'amount': null})), isNull);
    });
  });

  group('banks', () {
    test('a bank is its code and name', () {
      final banks = rowsOf([
        ...banksJson,
        {'code': '999'},
      ], bankFromJson);
      expect(
        [for (final b in banks) '${b.code} ${b.name}'],
        ['044 Access Bank', '058 Guaranty Trust Bank'],
      );
    });

    test('the saved account reads its last four digits', () {
      final saved = savedBankFromJson(bankAccountJson())!;
      expect(saved.bankCode, '044');
      expect(saved.bankName, 'Access Bank');
      expect(saved.accountName, 'ADAEZE OKAFOR');
      expect(saved.accountNumber, '6789');
      expect(saved.label, 'Access Bank ••6789');
      expect(saved.holder, 'Adaeze Okafor');
      expect(savedBankFromJson(null), isNull, reason: 'no account yet');
      expect(
        savedBankFromJson(bankAccountJson({'accountLast4': '89'})),
        isNull,
      );
    });
  });

  test('wallet figures come from GET /wallet', () {
    final totals = walletTotalsFromJson(walletJson());
    expect(totals.totalEarnedKobo, 6500000);
    expect(totals.pendingWithdrawalsKobo, 1000000);
    expect(totals.withdrawableKobo, 1500000);
    expect(
      walletTotalsFromJson(walletJson({'withdrawable': null})).withdrawableKobo,
      1500000,
      reason: 'available less what is on its way',
    );
  });

  group('submit form', () {
    test('choices with their options, multiple or not, and free text', () {
      final form = submitFormFromJson(challengeJson());
      expect(
        [for (final q in form.questions) q.id],
        ['q_lang', 'q_where', 'q_why'],
      );
      final [lang, where, why] = form.questions;
      expect(lang.text, 'Which language should lead?');
      expect(lang.options, ['English', 'Pidgin', 'Both, side by side']);
      expect(lang.choice, isTrue);
      expect(lang.multi, isFalse);
      expect(where.multi, isTrue);
      expect(why.choice, isFalse);
      expect(why.multi, isFalse);
      expect(form.acceptsFiles, isTrue);
    });

    test('files only when images or PDFs are taken', () {
      bool accepts(Object? formats) =>
          submitFormFromJson(challengeJson({'acceptedFormats': formats}))
              .acceptsFiles;
      expect(accepts({'text': true}), isFalse);
      expect(accepts({'text': true, 'pdf': true}), isTrue);
      expect(accepts({'text': true, 'videoLink': true}), isFalse);
      expect(accepts(null), isFalse);
    });

    test('no survey is the answer alone', () {
      final form = submitFormFromJson(
        challengeJson({'audienceSurvey': null, 'acceptedFormats': null}),
      );
      expect(form.questions, isEmpty);
      expect(form.hasQuestions, isFalse);
    });
  });
}
