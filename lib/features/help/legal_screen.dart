import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../more/more_widgets.dart';

/// A legal page's numbered or titled section.
class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

/// B21 · Terms and conditions (431:19781) and Privacy policy (431:19828):
/// the date they were updated and their sections.
///
/// Copy rule over the frames: "the brand" and "Brands" read "the business"
/// and "Businesses" (designer answer 38).
class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.updated,
    required this.sections,
  });

  final String title;
  final String updated;
  final List<LegalSection> sections;

  static const terms = LegalScreen(
    title: 'Terms and conditions',
    updated: 'Updated 1 Sep 2026',
    sections: [
      LegalSection(
        '1. Using iQLY',
        'You need to be 18 or over and resident in Nigeria to submit to '
            'briefs and be paid. One account per person. Keep your sign-in '
            'details to yourself.',
      ),
      LegalSection(
        '2. Submissions and rewards',
        'Each brief takes one submission per contributor. The business picks '
            'the winners and the split of the reward. By submitting, you '
            'grant the business a licence to use the idea you send.',
      ),
      LegalSection(
        '3. Payouts',
        'Rewards land in your iQLY wallet. Withdrawals go to a Nigerian bank '
            'account in your name through Paystack. Failed transfers are '
            'returned to your wallet.',
      ),
      LegalSection(
        '4. Referrals',
        'Referral rewards are paid when the friend you invite wins a first '
            'brief. We may change or pause the programme at any time.',
      ),
    ],
  );

  static const privacy = LegalScreen(
    title: 'Privacy policy',
    updated: 'Updated 1 Sep 2026',
    sections: [
      LegalSection(
        'What we collect',
        'Your name, email, phone number, date of birth, state and '
            'university, your submissions, and the bank account you add for '
            'payouts.',
      ),
      LegalSection(
        'How we use it',
        'To run briefs, pay rewards, confirm you are eligible, and send you '
            'the notifications you turn on. Businesses see your submissions, '
            'not your contact details.',
      ),
      LegalSection(
        'Who we share it with',
        'Paystack for payouts and our hosting providers. We do not sell your '
            'data.',
      ),
      LegalSection(
        'Your choices',
        'Change your details any time from More. Delete your account from '
            'More and we remove your personal data within 30 days.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          0,
          IqSpace.s4,
          IqSpace.s4,
        ),
        children: [
          Text(
            updated.toUpperCase(),
            style: IqText.mono.copyWith(color: IqColors.fg3),
          ),
          for (final section in sections) ...[
            const SizedBox(height: IqSpace.s2),
            Text(
              section.title,
              style: IqText.bodyStrong.copyWith(color: IqColors.fg),
            ),
            const SizedBox(height: IqSpace.s1p5),
            Text(
              section.body,
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ],
        ],
      ),
    );
  }
}
