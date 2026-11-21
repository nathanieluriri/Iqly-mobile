import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/discover/business_art.dart';
import 'package:iqly_mobile/features/wallet/wallet_rows.dart';
import 'package:iqly_mobile/features/wallet/wallet_state.dart';
import 'package:iqly_mobile/ui/network_image.dart';
import 'package:iqly_mobile/ui/sample_logo.dart';

Brief _brief({String? logo, String? name = 'PlaSpool'}) => Brief(
  id: 'c',
  title: 'A brief',
  body: 'Body',
  tier: Tier.standard,
  category: Category.marketing,
  rewardPoolKobo: 1,
  status: BriefStatus.live,
  deadline: DateTime(2026),
  businessName: name,
  createdAt: DateTime(2026),
  logo: logo,
);

LedgerEntry _award({
  String? submissionId,
  String? business,
  RewardSource from = RewardSource.submission,
  String? activationId,
}) => LedgerEntry(
  id: 'l',
  type: LedgerType.award,
  amountKobo: 100,
  createdAt: DateTime(2026),
  submissionId: submissionId,
  business: business,
  from: from,
  activationId: activationId,
);

Future<void> _pumpRow(
  WidgetTester tester, {
  required LedgerEntry award,
  Map<String, Brief> briefs = const {},
}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: WalletActivityRow(
        item: ActivityItem.award(award),
        briefs: briefs,
        now: DateTime(2026),
        hidden: false,
        divider: false,
      ),
    ),
  );
}

void main() {
  testWidgets('a logo URL is preferred over the initial', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: businessMark(
          logo: 'https://cdn.example/logo.png',
          name: 'PlaSpool',
        ),
      ),
    );
    expect(find.byType(IqNetworkImage), findsOneWidget);
    expect(find.text('P'), findsNothing);
  });

  testWidgets('a named business without a logo shows its initial', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: businessMark(name: 'PlaSpool'),
      ),
    );
    expect(find.text('P'), findsOneWidget);
    expect(find.byType(IqSampleLogo), findsNothing);
  });

  testWidgets('an unnamed business without a logo shows the private mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: businessMark()),
    );
    expect(
      tester.widget<IqSampleLogo>(find.byType(IqSampleLogo)).brand,
      IqSampleLogoBrand.private,
    );
  });

  testWidgets('a submission reward uses the brief logo', (tester) async {
    await _pumpRow(
      tester,
      award: _award(submissionId: 's', business: 'PlaSpool'),
      briefs: {'s': _brief(logo: 'https://cdn.example/logo.png')},
    );
    expect(find.byType(IqNetworkImage), findsOneWidget);
  });

  testWidgets('a live activation reward uses the business initial', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      award: _award(
        business: 'PlaSpool',
        from: RewardSource.activation,
        activationId: 'a1',
      ),
    );
    expect(find.text('P'), findsOneWidget);
  });
}
