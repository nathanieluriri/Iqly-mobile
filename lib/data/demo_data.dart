import 'drafts_data.dart';
import 'models.dart';

/// Sanctioned sample dataset, mirrored from src/data/demo.ts in the web repo.
/// Every figure the UI shows is computed from these rows. Three brief titles
/// are the ones the live iqly.net hero uses; everything else is illustrative.
class DemoData {
  DemoData({DateTime? now}) : now = now ?? DateTime.now();

  final DateTime now;

  DateTime at(int days, [int hours = 0]) =>
      now.add(Duration(days: days, hours: hours));

  /// The three unread Today rows of B6 Notifications; the bell shows this.
  static const unreadNotifications = 3;

  static const user = User(
    firstName: 'Adaeze',
    lastName: 'Okafor',
    email: 'adaeze@example.com',
    state: 'Lagos',
    city: 'Ikeja',
    university: 'University of Lagos',
    interests: ['Marketing & advertising', 'Finance & fintech'],
  );

  /// The sample business art the Figma cards fill from (Sample/Logo and
  /// Sample/Cover). The live API sends image URLs in the same fields.
  static String logoOf(String slug) => 'assets/samples/logos/$slug.svg';

  static String coverOf(String slug, [int shot = 1]) =>
      'assets/samples/covers/$slug-$shot.jpg';

  late final List<Brief> briefs = [
    Brief(
      id: 'c1',
      title: 'Naming a new sparkling water brand for Gen Z.',
      body: 'Three flavours, one can. Give us a name that travels from Lagos to Accra and still fits a hashtag.',
      tier: Tier.standard,
      category: Category.marketing,
      rewardPoolKobo: 25000000,
      status: BriefStatus.live,
      deadline: at(5),
      businessName: 'Orchid Foods',
      minutes: 3,
      logo: logoOf('orchid-foods'),
      cover: coverOf('orchid-foods', 2),
      createdAt: at(-9),
      interest: 'marketing_advertising',
    ),
    Brief(
      id: 'c2',
      title: 'A grocery delivery service that beats Bolt Food.',
      body: 'Tell us the one thing that would make you switch for your weekly shop, and how we should say it.',
      tier: Tier.advanced,
      category: Category.strategy,
      rewardPoolKobo: 60000000,
      status: BriefStatus.live,
      deadline: at(12),
      businessName: 'Basket NG',
      minutes: 5,
      logo: logoOf('basket-ng'),
      cover: coverOf('basket-ng', 1),
      createdAt: at(-4),
      interest: 'business_entrepreneurship',
    ),
    Brief(
      id: 'c3',
      title: 'Why do Lagosians skip mobile banking on Sundays?',
      body: 'Our app sessions dip every Sunday. Help us understand why before we spend on a campaign.',
      tier: Tier.advanced,
      category: Category.customerExperience,
      rewardPoolKobo: 40000000,
      status: BriefStatus.closed,
      deadline: at(-3),
      businessName: null,
      minutes: 4,
      logo: logoOf('private'),
      cover: coverOf('private', 1),
      createdAt: at(-40),
      interest: 'finance_fintech',
    ),
    Brief(
      id: 'c4',
      title: 'Redesign the first five minutes of our savings app',
      body: 'New users drop before their first deposit. Sketch an onboarding that earns the first ₦1,000.',
      tier: Tier.advanced,
      category: Category.productDesign,
      rewardPoolKobo: 50000000,
      status: BriefStatus.live,
      deadline: at(1),
      businessName: 'Kudi Box',
      minutes: 10,
      logo: logoOf('kudi-box'),
      cover: coverOf('kudi-box', 1),
      createdAt: at(-12),
      interest: 'finance_fintech',
      spotsLeft: 3,
      spotsTotal: 20,
    ),
    Brief(
      id: 'c5',
      title: 'A tagline for a solar kiosk network',
      body: 'Kiosks charge phones and sell airtime off-grid. We need one line that works in English and Pidgin.',
      tier: Tier.standard,
      category: Category.marketing,
      rewardPoolKobo: 15000000,
      status: BriefStatus.live,
      deadline: at(0, 6),
      businessName: 'Sunline',
      minutes: 2,
      logo: logoOf('sunline'),
      cover: coverOf('sunline', 1),
      createdAt: at(-7),
      interest: 'marketing_advertising',
      spotsLeft: 12,
      spotsTotal: 40,
      winnerRule: 'Winners split the pool.',
    ),
    Brief(
      id: 'c6',
      title: 'How should a campus bookshop sell online?',
      body: 'Students buy from WhatsApp sellers. Help a university bookshop compete without a big budget.',
      tier: Tier.standard,
      category: Category.innovation,
      rewardPoolKobo: 10000000,
      status: BriefStatus.live,
      deadline: at(20),
      businessName: 'Unibooks',
      minutes: 5,
      logo: logoOf('unibooks'),
      cover: coverOf('unibooks', 1),
      createdAt: at(-2),
      interest: 'education',
    ),
    Brief(
      id: 'c7',
      title: 'Cut queue time at our branch counters',
      body: 'Customers wait 40 minutes on Mondays. Propose a fix staff can roll out in a week.',
      tier: Tier.advanced,
      category: Category.customerExperience,
      rewardPoolKobo: 35000000,
      status: BriefStatus.live,
      deadline: at(8),
      businessName: 'Harbour Microfinance',
      minutes: 8,
      logo: logoOf('harbour'),
      cover: coverOf('harbour', 1),
      createdAt: at(-6),
      interest: 'business_entrepreneurship',
    ),
    Brief(
      id: 'c8',
      title: 'Name our electric okada fleet',
      body: 'A fleet of electric bikes for last-mile delivery needs a name riders are proud to wear.',
      tier: Tier.standard,
      category: Category.marketing,
      rewardPoolKobo: 20000000,
      status: BriefStatus.closed,
      deadline: at(-15),
      businessName: 'Volt Riders',
      minutes: 3,
      logo: logoOf('volt-riders'),
      cover: coverOf('volt-riders', 1),
      createdAt: at(-45),
      interest: 'marketing_advertising',
    ),
    Brief(
      id: 'c9',
      title: 'What would make you trust a used-phone marketplace?',
      body: 'Buyers fear stolen or faulty phones. Tell us what proof would get you to pay.',
      tier: Tier.standard,
      category: Category.technology,
      rewardPoolKobo: 12000000,
      status: BriefStatus.live,
      deadline: null,
      businessName: 'Swapit',
      minutes: 5,
      logo: logoOf('swapit'),
      cover: coverOf('swapit', 1),
      createdAt: at(-1),
      interest: 'tech_gadgets',
    ),
    Brief(
      id: 'c10',
      title: 'Packaging ideas for a cassava snack',
      body: 'We are moving from plain sachets to shelf packs. Pitch a look that stands out in a supermarket.',
      tier: Tier.standard,
      category: Category.productDesign,
      rewardPoolKobo: 18000000,
      status: BriefStatus.live,
      deadline: at(3),
      businessName: 'Garri & Co',
      minutes: 5,
      logo: logoOf('garri-and-co'),
      cover: coverOf('garri-and-co', 1),
      createdAt: at(-10),
      interest: 'agriculture_food',
    ),
    Brief(
      id: 'c11',
      title: 'Grow weekday ridership on our ferry route',
      body: 'Weekends are full, weekdays are not. Give us a plan to fill the 9am ferry.',
      tier: Tier.advanced,
      category: Category.strategy,
      rewardPoolKobo: 45000000,
      status: BriefStatus.live,
      deadline: at(15),
      businessName: 'Lagoon Lines',
      minutes: 6,
      logo: logoOf('lagoon-lines'),
      cover: coverOf('lagoon-lines', 1),
      createdAt: at(-3),
      interest: 'business_entrepreneurship',
    ),
    Brief(
      id: 'c12',
      title: 'Rename our youth current account',
      body: 'Our account for 18 to 25 year olds has a name nobody remembers. Suggest a better one.',
      tier: Tier.standard,
      category: Category.marketing,
      rewardPoolKobo: 8000000,
      status: BriefStatus.live,
      deadline: at(9),
      businessName: 'Harbour Microfinance',
      minutes: 3,
      logo: logoOf('harbour'),
      cover: coverOf('harbour', 2),
      createdAt: at(-5),
      interest: 'finance_fintech',
    ),
    Brief(
      id: 'c13',
      title: 'Make school fee payments less stressful',
      body: 'Parents pay fees in three trips to the bank. Design a flow that takes one.',
      tier: Tier.advanced,
      category: Category.productDesign,
      rewardPoolKobo: 55000000,
      status: BriefStatus.live,
      deadline: at(25),
      businessName: 'Classpay',
      minutes: 10,
      logo: logoOf('classpay'),
      cover: coverOf('classpay', 2),
      createdAt: at(-1),
      interest: 'education',
    ),
  ];

  /// Illustrative design proposals (activations, saved briefs, close
  /// reminders): the API does not serve them yet.
  static const activations = ActivationsSummary(closingToday: 1);

  static const savedBriefIds = ['c5', 'c4'];

  static const closeReminderIds = ['c5'];

  late final List<Submission> submissions = [
    Submission(
      id: 's1',
      briefId: 'c1',
      title: 'Fizzo: short, loud, easy to say',
      body: 'A two-syllable name that works on a can and in a hashtag, with room for flavour lines.',
      status: SubmissionStatus.pending,
      createdAt: at(-3),
    ),
    Submission(
      id: 's2',
      briefId: 'c3',
      title: 'Sunday is data day',
      body: 'Data bundles reset on Sunday, so people wait to open apps until the new bundle lands.',
      status: SubmissionStatus.winner,
      createdAt: at(-34),
    ),
    Submission(
      id: 's3',
      briefId: 'c8',
      title: 'Ekpe: a name riders own',
      body: 'A short, local name with a strong sound, printed big on the tank and the rider vest.',
      status: SubmissionStatus.winner,
      createdAt: at(-30),
    ),
    Submission(
      id: 's4',
      briefId: 'c6',
      title: 'Bring the shop to the hostel',
      body: 'A WhatsApp catalogue plus a weekly hostel drop beats a website nobody visits.',
      status: SubmissionStatus.scored,
      createdAt: at(-1),
    ),
    Submission(
      id: 's5',
      briefId: 'c7',
      title: 'One counter for quick jobs',
      body: 'Split deposits under ₦50,000 to a fast counter and send everything else to the main line.',
      status: SubmissionStatus.filteredOut,
      createdAt: at(-20),
    ),
  ];

  /// The two drafts of the Drafts frames (481:23202): Unibooks at step 2,
  /// edited 2 hours ago, and Sunline at step 1, edited yesterday. Sunline's
  /// is the B17 Writing draft (16 of the 20 characters the answer needs).
  late final List<Draft> drafts = [
    Draft(
      briefId: 'c6',
      title: 'No light? We dey',
      answer: 'A WhatsApp catalogue with a pickup shelf in each hostel, priced like the sellers.',
      step: 2,
      editedAt: now.subtract(const Duration(hours: 2)),
    ),
    Draft(
      briefId: 'c5',
      title: 'Charge up, stay connected',
      answer: 'No light? We dey',
      editedAt: at(-1),
    ),
  ];

  /// Award 50,000 (13d ago), failed 5,000 (11d), paid out 40,000 (10d),
  /// award 12,500 (2d), 10,000 requested (2h). Earned 62,500.00, paid out
  /// 40,000.00, on hold 10,000.00, available 12,500.00.
  late final List<LedgerEntry> ledger = [
    LedgerEntry(
      id: 'l3',
      type: LedgerType.award,
      amountKobo: 1250000,
      createdAt: at(-2),
      submissionId: 's2',
    ),
    LedgerEntry(
      id: 'l2',
      type: LedgerType.withdrawal,
      amountKobo: -4000000,
      createdAt: at(-10),
    ),
    LedgerEntry(
      id: 'l1',
      type: LedgerType.award,
      amountKobo: 5000000,
      createdAt: at(-13),
      submissionId: 's3',
    ),
  ];

  /// References, banks, step times and the failure reason come from the B14
  /// receipts (demo.ts has amounts, statuses and dates only). At the Figma
  /// 9:41 the pending one was requested today at 7:40 am and the failed one
  /// 11 days ago at 2:05 pm, approved at 4:40 pm.
  late final List<Withdrawal> withdrawals = [
    Withdrawal(
      id: 'w3',
      amountKobo: 1000000,
      status: WithdrawalStatus.pending,
      createdAt: now.subtract(const Duration(hours: 2, minutes: 1)),
      reference: 'IQ-WD-241003-9A2M',
      bankName: savedBank.bankName,
      accountNumber: savedBank.accountNumber,
    ),
    Withdrawal(
      id: 'w2',
      amountKobo: 4000000,
      status: WithdrawalStatus.completed,
      createdAt: at(-10),
      reference: 'IQ-WD-240923-7F3K',
      bankName: savedBank.bankName,
      accountNumber: savedBank.accountNumber,
    ),
    Withdrawal(
      id: 'w1',
      amountKobo: 500000,
      status: WithdrawalStatus.failed,
      createdAt: at(-11).add(const Duration(hours: 4, minutes: 24)),
      reference: 'IQ-WD-240922-3C7Q',
      bankName: savedBank.bankName,
      accountNumber: savedBank.accountNumber,
      approvedAt: at(-11).add(const Duration(hours: 6, minutes: 59)),
      failureReason: 'Account name didn’t match.',
    ),
  ];

  /// Names as Paystack's bank list returns them; the live app loads this list from Paystack.
  static const banks = [
    Bank(code: '044', name: 'Access Bank'),
    Bank(code: '070', name: 'Fidelity Bank'),
    Bank(code: '011', name: 'First Bank of Nigeria'),
    Bank(code: '214', name: 'First City Monument Bank'),
    Bank(code: '058', name: 'Guaranty Trust Bank'),
    Bank(code: '50211', name: 'Kuda Bank'),
    Bank(code: '50515', name: 'Moniepoint MFB'),
    Bank(code: '999992', name: 'OPay Digital Services Limited (OPay)'),
    Bank(code: '999991', name: 'PalmPay'),
    Bank(code: '033', name: 'United Bank For Africa'),
    Bank(code: '035', name: 'Wema Bank'),
    Bank(code: '057', name: 'Zenith Bank'),
  ];

  static const savedBank = SavedBank(
    bankCode: '044',
    bankName: 'Access Bank',
    accountName: 'ADAEZE OKAFOR',
    accountNumber: '0123456789',
  );
}
