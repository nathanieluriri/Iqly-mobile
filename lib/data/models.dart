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
    this.minutes,
    this.logo,
    this.cover,
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

  /// About how long a response takes, in minutes (the card's time chip).
  final int? minutes;

  /// The business logo and the cover photo: asset paths in the demo, image
  /// URLs from the API. Null falls back to the anonymous art.
  final String? logo;
  final String? cover;

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
    'minutes': minutes,
    'logo': logo,
    'cover': cover,
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
      minutes: json['minutes'] as int?,
      logo: json['logo'] as String?,
      cover: json['cover'] as String?,
    );
  }
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
    this.reference,
    this.bankName,
    this.accountNumber,
    this.approvedAt,
    this.sentAt,
    this.completedAt,
    this.failureReason,
  });

  final String id;
  final int amountKobo;
  final WithdrawalStatus status;
  final DateTime createdAt;

  /// The transfer reference on the receipt.
  final String? reference;
  final String? bankName;
  final String? accountNumber;

  /// When iQLY approved it, the transfer left for the bank, and the money
  /// arrived. Null until each happens (or when the API does not say).
  final DateTime? approvedAt;
  final DateTime? sentAt;
  final DateTime? completedAt;

  /// The bank's words when it failed or reversed the transfer.
  final String? failureReason;

  /// The word the product shows: processing reads as pending, as on the web.
  String get statusWord => switch (status) {
    WithdrawalStatus.processing => WithdrawalStatus.pending.name,
    _ => status.name,
  };

  /// Pending and processing are on hold.
  bool get onHold =>
      status == WithdrawalStatus.pending ||
      status == WithdrawalStatus.processing;

  bool get failed =>
      status == WithdrawalStatus.failed || status == WithdrawalStatus.reversed;

  /// "Access Bank ••6789".
  String? get destination {
    final bank = bankName;
    final number = accountNumber;
    if (bank == null) return null;
    if (number == null || number.length < 4) return bank;
    return '$bank ••${number.substring(number.length - 4)}';
  }

  Withdrawal copyWith({
    WithdrawalStatus? status,
    DateTime? approvedAt,
    DateTime? sentAt,
    DateTime? completedAt,
    String? failureReason,
  }) => Withdrawal(
    id: id,
    amountKobo: amountKobo,
    status: status ?? this.status,
    createdAt: createdAt,
    reference: reference,
    bankName: bankName,
    accountNumber: accountNumber,
    approvedAt: approvedAt ?? this.approvedAt,
    sentAt: sentAt ?? this.sentAt,
    completedAt: completedAt ?? this.completedAt,
    failureReason: failureReason ?? this.failureReason,
  );
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
