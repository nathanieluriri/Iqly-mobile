import 'dart:math' as math;

import '../../core/money.dart';
import '../models.dart';
import '../submit_data.dart';

// Contract 1's answers as the app's models. Each mapper reads only what it
// knows and answers null for a row it cannot use, so one odd row never takes
// a screen down.

Map<String, Object?>? _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;

List<Object?> _list(Object? value) => value is List ? value : const [];

/// A string with something in it.
String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int? _int(Object? value) => switch (value) {
  final int whole => whole,
  final num number => number.toInt(),
  _ => null,
};

/// A UTC ISO time, on the phone's clock so it reads in local time.
DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Stands in for a time the API left out.
final _unknownTime = DateTime.fromMillisecondsSinceEpoch(0);

/// The rows of a list answer that map to something.
List<T> rowsOf<T>(Object? json, T? Function(Object? row) map) => [
  for (final row in _list(json)) ?map(row),
];

/// A brief from `/challenges/browse` or `/challenges/:id` (contract 4).
Brief? briefFromJson(Object? json) {
  final j = _map(json);
  final id = _text(j?['id']);
  if (j == null || id == null) return null;
  final pool = _int(j['rewardPool']);
  final cap = _int(j['maxSubmissions']);
  return Brief(
    id: id,
    title: _text(j['title']) ?? 'Untitled',
    body: _body(j),
    tier: j['tier'] == 'advanced' ? Tier.advanced : Tier.standard,
    category: categoryOf(j['category']),
    rewardPoolKobo: pool ?? 0,
    status: briefStatusOf(j['status']),
    deadline:
        _time(j['effectiveDeadline']) ??
        _time(j['extendedDeadline']) ??
        _time(j['deadline']),
    businessName: _text(j['brandName']),
    createdAt: _time(j['publishedAt']) ?? _time(j['createdAt']) ?? _unknownTime,
    interest: _list(_map(j['audienceFilters'])?['interests'])
        .whereType<String>()
        .firstOrNull,
    spotsTotal: cap,
    spotsLeft: cap == null
        ? null
        : math.max(0, cap - (_int(j['submissionCount']) ?? 0)),
    winnerRule: winnerRule(j['winnerConfig'], pool),
    minutes: _int(j['minutes']),
    logo: _text(j['brandLogoUrl']),
    cover: _text(j['coverUrl']),
  );
}

/// The overview and problem statement, then the deliverables as bullets.
String _body(Map<String, Object?> j) {
  final text = _text(j['bodyText'])?.trim();
  final deliverables = [
    for (final item in _list(j['deliverables']))
      if (_text(item) case final line?) '• ${line.trim()}',
  ];
  return [
    ?text,
    if (deliverables.isNotEmpty) deliverables.join('\n'),
  ].join('\n\n');
}

/// Snake case from the API; anything this build does not know is Other.
Category categoryOf(Object? value) => switch (value) {
  'marketing' => Category.marketing,
  'strategy' => Category.strategy,
  'customer_experience' => Category.customerExperience,
  'product_design' => Category.productDesign,
  'innovation' => Category.innovation,
  'technology' => Category.technology,
  _ => Category.other,
};

/// Only a live brief takes submissions; any other status reads as closed.
BriefStatus briefStatusOf(Object? value) =>
    value == 'live' ? BriefStatus.live : BriefStatus.closed;

/// How the pool is split, worded as iqly.net's Prize breakdown words it:
/// "1st place ₦60,000 · 2nd place ₦30,000" for places, "Top 10% share
/// ₦500,000 · Next 15% share ₦300,000" for tiers. Null without a pool or a
/// split this build knows.
String? winnerRule(Object? config, int? pool) {
  final c = _map(config);
  if (c == null || pool == null) return null;
  final rows = switch (c['type']) {
    'top_n' => _places(c, pool),
    'top_percent' => _tiers(c, pool),
    _ => null,
  };
  if (rows == null) return null;
  return rows.isEmpty
      ? 'Winners split the pool once submissions are in.'
      : rows.join(' · ');
}

const _ordinals = [
  '1st',
  '2nd',
  '3rd',
  '4th',
  '5th',
  '6th',
  '7th',
  '8th',
  '9th',
  '10th',
];

String _ordinal(int i) => i < _ordinals.length ? _ordinals[i] : '#${i + 1}';

/// Each place floors its share; the kobo left over goes to first place, as
/// the API pays it.
List<String> _places(Map<String, Object?> c, int pool) {
  final amounts = [
    for (final percent in _list(c['split'])) pool * (_int(percent) ?? 0) ~/ 100,
  ];
  if (amounts.isNotEmpty) {
    amounts[0] += pool - amounts.fold<int>(0, (sum, a) => sum + a);
  }
  return [
    for (final (i, amount) in amounts.indexed)
      '${_ordinal(i)} place ${rewardPool(amount)}',
  ];
}

List<String> _tiers(Map<String, Object?> c, int pool) {
  final tiers = [
    for (final row in _list(c['tiers']))
      if (_map(row) case final tier?)
        (
          share: _int(tier['submissionPercent']) ?? 0,
          pot: pool * (_int(tier['poolPercent']) ?? 0) ~/ 100,
        ),
  ];
  final left = pool - tiers.fold<int>(0, (sum, t) => sum + t.pot);
  return [
    for (final (i, tier) in tiers.indexed)
      '${i == 0 ? 'Top' : 'Next'} ${tier.share}% share '
          '${rewardPool(tier.pot + (i == 0 && left > 0 ? left : 0))}',
  ];
}

/// The brief a submission item embeds (contract 5): what its card shows.
/// The rest reads as a standard brief in Other with no body.
Brief? embeddedBriefFromJson(Object? json) {
  final j = _map(json);
  final id = _text(j?['id']);
  if (j == null || id == null) return null;
  return Brief(
    id: id,
    title: _text(j['title']) ?? 'Untitled',
    body: '',
    tier: Tier.standard,
    category: Category.other,
    rewardPoolKobo: _int(j['rewardPool']) ?? 0,
    status: briefStatusOf(j['status']),
    deadline: _time(j['deadline']),
    businessName: _text(j['businessName']),
    createdAt: _unknownTime,
    logo: _text(j['logoUrl']),
    cover: _text(j['coverUrl']),
  );
}

/// A submission item from `/submissions/mine`, `/submissions/:id` or the
/// submit answer (contract 5), with its brief and award as embedded.
Submission? submissionFromJson(Object? json) {
  final j = _map(json);
  final id = _text(j?['id']);
  final briefId = _text(j?['challengeId']);
  if (j == null || id == null || briefId == null) return null;
  return Submission(
    id: id,
    briefId: briefId,
    title: _text(j['title']) ?? 'Untitled',
    body: j['bodyText'] is String ? j['bodyText']! as String : '',
    status: submissionStatusOf(j['result']),
    createdAt: _time(j['createdAt']) ?? _unknownTime,
    brief: embeddedBriefFromJson(j['brief']),
    award: awardFromJson(j['award']),
  );
}

/// From the entry's `result`; anything else is still under review.
SubmissionStatus submissionStatusOf(Object? result) => switch (result) {
  'winner' => SubmissionStatus.winner,
  'not_selected' => SubmissionStatus.filteredOut,
  _ => SubmissionStatus.pending,
};

SubmissionAward? awardFromJson(Object? json) {
  final j = _map(json);
  final amount = _int(j?['amountKobo']);
  final at = _time(j?['awardedAt']);
  if (amount == null || at == null) return null;
  return SubmissionAward(
    amountKobo: amount,
    awardedAt: at,
    ledgerId: _text(j?['ledgerId']),
  );
}

/// A row of `/wallet/transactions` (contract 6). A credit, or a reversal
/// that brings a payout back, is money in; a withdrawal is money out, its
/// amount negative as sent. Any other kind is dropped.
LedgerEntry? ledgerEntryFromJson(Object? json) {
  final j = _map(json);
  final id = _text(j?['id']);
  final amount = _int(j?['amount']);
  if (j == null || id == null || amount == null) return null;
  final type = switch (j['type']) {
    'credit' || 'reversal' => LedgerType.award,
    'withdrawal' => LedgerType.withdrawal,
    _ => null,
  };
  if (type == null) return null;
  return LedgerEntry(
    id: id,
    type: type,
    amountKobo: amount,
    createdAt: _time(j['createdAt']) ?? _unknownTime,
    submissionId: _text(j['submissionId']),
    business: _text(j['businessName']),
    note: _text(j['note']),
    referred: _text(j['referredName']),
    reversal: j['type'] == 'reversal',
  );
}

/// A withdrawal from `/wallet/withdrawals` (contract 6). The account number
/// is the last four digits, all the API keeps on it.
Withdrawal? withdrawalFromJson(Object? json) {
  final j = _map(json);
  final id = _text(j?['id']);
  final amount = _int(j?['amount']);
  if (j == null || id == null || amount == null) return null;
  final last4 = _text(j['accountLast4']);
  return Withdrawal(
    id: id,
    amountKobo: amount,
    status: withdrawalStatusOf(j['status']),
    createdAt: _time(j['createdAt']) ?? _unknownTime,
    reference: _text(j['reference']),
    bankName: _text(j['bankName']),
    accountNumber: last4 == null || last4.length <= 4
        ? last4
        : last4.substring(last4.length - 4),
    sentAt: _time(j['sentAt']),
    completedAt: _time(j['completedAt']),
    failureReason: _text(j['failureReason']),
  );
}

/// By name. A status this build does not know reads as pending, so the
/// money shows as on its way rather than disappearing.
WithdrawalStatus withdrawalStatusOf(Object? value) =>
    WithdrawalStatus.values.asNameMap()[value] ?? WithdrawalStatus.pending;

/// A bank from `GET /banks`.
Bank? bankFromJson(Object? json) {
  final j = _map(json);
  final code = _text(j?['code']);
  final name = _text(j?['name']);
  if (code == null || name == null) return null;
  return Bank(code: code, name: name);
}

/// The payout account from `/wallet/bank-account`. The account number is
/// the last four digits the API answers.
SavedBank? savedBankFromJson(Object? json) {
  final j = _map(json);
  final code = _text(j?['bankCode']);
  final name = _text(j?['bankName']);
  final holder = _text(j?['accountName']);
  final last4 = _text(j?['accountLast4']);
  if (code == null || name == null || holder == null || last4 == null) {
    return null;
  }
  if (last4.length < 4) return null;
  return SavedBank(
    bankCode: code,
    bankName: name,
    accountName: holder,
    accountNumber: last4,
  );
}

/// `GET /wallet` (contract 6): the figures the Wallet shows.
WalletTotals walletTotalsFromJson(Object? json) {
  final j = _map(json) ?? const {};
  final pending = _int(j['pendingWithdrawals']) ?? 0;
  return WalletTotals(
    totalEarnedKobo: _int(j['totalEarned']) ?? 0,
    pendingWithdrawalsKobo: pending,
    withdrawableKobo:
        _int(j['withdrawable']) ??
        math.max(0, (_int(j['available']) ?? 0) - pending),
  );
}

/// What a brief asks for beyond the title and the answer: its audience
/// survey, a choice for each question with options and free text for the
/// rest, and attachments when it takes images or PDFs.
SubmitForm submitFormFromJson(Object? json) {
  final j = _map(json);
  final formats = _map(j?['acceptedFormats']);
  return SubmitForm(
    questions: rowsOf(
      _map(j?['audienceSurvey'])?['questions'],
      surveyQuestionFromJson,
    ),
    acceptsFiles: formats?['image'] == true || formats?['pdf'] == true,
  );
}

SurveyQuestion? surveyQuestionFromJson(Object? json) {
  final j = _map(json);
  final id = _text(j?['id']);
  if (j == null || id == null) return null;
  final choice = j['type'] == 'mcq';
  return SurveyQuestion(
    id: id,
    text: j['q'] is String ? j['q']! as String : '',
    options: choice ? rowsOf(j['options'], _text) : const [],
    multi: choice && j['multi'] == true,
  );
}
