import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/deep_links.dart';
import 'package:iqly_mobile/features/help/help_routes.dart';
import 'package:iqly_mobile/router.dart';

void main() {
  test('existing surface routes mirror Routes', () {
    expect(DeepLinks.home, Routes.home);
    expect(DeepLinks.polls, Routes.polls);
    expect(DeepLinks.submissions, Routes.submissions);
    expect(DeepLinks.briefPattern, Routes.briefDetail);
    expect(DeepLinks.brief('c5'), Routes.brief('c5'));
    expect(DeepLinks.submit('c5'), Routes.submitTo('c5'));
    expect(DeepLinks.withdrawal('w3'), '/wallet/withdrawals/w3');
    expect(Routes.withdrawal, DeepLinks.withdrawalPattern);
    expect(DeepLinks.helpThread('t_1'), helpThreadPath('t_1'));
    expect(DeepLinks.referrals, Routes.referrals);
    expect(DeepLinks.referralHistory, Routes.referralHistory);
  });

  test('the support and referral pushes open their pages', () {
    expect(DeepLinks.route('/help/t_1'), '/help/t_1');
    expect(DeepLinks.route('iqly://app/referrals'), '/referrals');
    expect(DeepLinks.route('/referrals/history'), '/referrals/history');
    expect(DeepLinks.route('/help'), isNull);
  });

  test('uri and route round trip', () {
    final uri = DeepLinks.uri(DeepLinks.notification('n1'));
    expect(uri.toString(), 'iqly://app/notifications/n1');
    expect(DeepLinks.route(uri.toString()), '/notifications/n1');
    expect(DeepLinks.route('iqly://app/briefs/c5/submit'), '/briefs/c5/submit');
    expect(DeepLinks.route('/polls/orchid-foods'), '/polls/orchid-foods');
    expect(DeepLinks.route('iqly://app/home'), '/home');
  });

  test('foreign or unknown links are refused', () {
    expect(DeepLinks.route('https://app/home'), isNull);
    expect(DeepLinks.route('iqly://other/home'), isNull);
    expect(DeepLinks.route('iqly://app/wallet/withdraw'), isNull);
    expect(DeepLinks.route('iqly://app/'), isNull);
    expect(DeepLinks.route('iqly://app/briefs'), isNull);
  });
}
