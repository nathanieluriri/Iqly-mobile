enum Tier {
  standard('Standard'),
  advanced('Advanced');

  const Tier(this.label);
  final String label;
}

enum BriefStatus {
  live('Live'),
  closed('Closed');

  const BriefStatus(this.label);
  final String label;
}

enum Category {
  marketing('Marketing'),
  strategy('Strategy'),
  customerExperience('Customer experience'),
  productDesign('Product design'),
  innovation('Innovation'),
  technology('Technology');

  const Category(this.label);
  final String label;
}

/// Raw API statuses. The product shows pending and scored as "Under review".
enum SubmissionStatus {
  pending,
  scored,
  winner,
  filteredOut;

  String get label => switch (this) {
    pending || scored => 'Under review',
    winner => 'Winner',
    filteredOut => 'Not selected',
  };
}

/// Shown raw, as the product does: pending, processing, completed, failed, reversed.
enum WithdrawalStatus { pending, processing, completed, failed, reversed }

enum LedgerType { award, withdrawal }

class Brief {
  const Brief({
    required this.id,
    required this.title,
    required this.body,
    required this.tier,
    required this.category,
    required this.rewardPoolKobo,
    required this.status,
    required this.deadline,
    required this.businessName,
    required this.createdAt,
    this.interest,
    this.spotsLeft,
    this.spotsTotal,
    this.winnerRule,
  });

  final String id;
  final String title;
  final String body;
  final Tier tier;
  final Category category;
  final int rewardPoolKobo;
  final BriefStatus status;
  final DateTime? deadline;
  final String? businessName;
  final DateTime createdAt;

  /// The onboarding interest value this brief is filed under (For you
  /// groups). Illustrative: demo.ts has categories only.
  final String? interest;

  /// Illustrative (Figma tickets); demo.ts has no capacity. Null is no limit.
  final int? spotsLeft;
  final int? spotsTotal;

  /// How the pool is split, when the business set a rule. Null shows none.
  final String? winnerRule;

  bool get isLive => status == BriefStatus.live;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'tier': tier.name,
    'category': category.name,
    'rewardPoolKobo': rewardPoolKobo,
    'status': status.name,
    'deadline': deadline?.toIso8601String(),
    'businessName': businessName,
    'createdAt': createdAt.toIso8601String(),
    'interest': interest,
    'spotsLeft': spotsLeft,
    'spotsTotal': spotsTotal,
    'winnerRule': winnerRule,
  };

  factory Brief.fromJson(Map<String, Object?> json) {
    final deadline = json['deadline'] as String?;
    return Brief(
      id: json['id']! as String,
      title: json['title']! as String,
      body: json['body']! as String,
      tier: Tier.values.byName(json['tier']! as String),
      category: Category.values.byName(json['category']! as String),
      rewardPoolKobo: json['rewardPoolKobo']! as int,
      status: BriefStatus.values.byName(json['status']! as String),
      deadline: deadline == null ? null : DateTime.parse(deadline),
      businessName: json['businessName'] as String?,
      createdAt: DateTime.parse(json['createdAt']! as String),
      interest: json['interest'] as String?,
      spotsLeft: json['spotsLeft'] as int?,
      spotsTotal: json['spotsTotal'] as int?,
      winnerRule: json['winnerRule'] as String?,
    );
  }
}

/// A business with open polls, as a Discover brand bubble.
class PollBrand {
  const PollBrand({
    required this.businessName,
    required this.openPolls,
    required this.unanswered,
  });

  final String businessName;
  final int openPolls;
  final int unanswered;

  String get initial => businessName.substring(0, 1);
  bool get allAnswered => unanswered == 0;
}

/// The Activations row on Discover.
class ActivationsSummary {
  const ActivationsSummary({required this.closingToday});

  final int closingToday;
}

class Submission {
  const Submission({
    required this.id,
    required this.briefId,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String briefId;
  final String title;
  final String body;
  final SubmissionStatus status;
  final DateTime createdAt;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amountKobo,
    required this.createdAt,
    this.submissionId,
  });

  final String id;
  final LedgerType type;

  /// The winning submission an award pays out; null for withdrawals.
  final String? submissionId;

  /// Signed: awards are positive, withdrawals negative.
  final int amountKobo;
  final DateTime createdAt;
}

class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amountKobo,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final int amountKobo;
  final WithdrawalStatus status;
  final DateTime createdAt;
}

class Bank {
  const Bank({required this.code, required this.name});

  final String code;
  final String name;
}

class SavedBank {
  const SavedBank({
    required this.bankCode,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  final String bankCode;
  final String bankName;
  final String accountName;
  final String accountNumber;

  String get maskedNumber =>
      '••${accountNumber.substring(accountNumber.length - 4)}';
}

class User {
  const User({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.state,
    required this.city,
    required this.university,
    required this.interests,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String state;
  final String city;
  final String university;
  final List<String> interests;

  String get name => '$firstName $lastName';
  String get initial => firstName.substring(0, 1);
}

class WalletTotals {
  const WalletTotals({
    required this.totalEarnedKobo,
    required this.pendingWithdrawalsKobo,
    required this.withdrawableKobo,
  });

  final int totalEarnedKobo;
  final int pendingWithdrawalsKobo;
  final int withdrawableKobo;
}

/// Mirrors walletTotals() in the web app: every wallet figure derives from
/// the ledger and withdrawal rows, so the numbers always foot.
WalletTotals walletTotals(
  List<LedgerEntry> ledger,
  List<Withdrawal> withdrawals,
) {
  final earned = ledger
      .where((l) => l.type == LedgerType.award)
      .fold(0, (sum, l) => sum + l.amountKobo);
  final balance = ledger.fold(0, (sum, l) => sum + l.amountKobo);
  final pending = withdrawals
      .where(
        (w) =>
            w.status == WithdrawalStatus.pending ||
            w.status == WithdrawalStatus.processing,
      )
      .fold(0, (sum, w) => sum + w.amountKobo);
  return WalletTotals(
    totalEarnedKobo: earned,
    pendingWithdrawalsKobo: pending,
    withdrawableKobo: balance - pending,
  );
}
