/// Strings read off the B18 and B19 frames.
abstract final class SurfaceCopy {
  static const appName = 'iQLY';

  static const payoutSubtext = 'Payout';
  static String onItsWay(String amount) => '$amount on its way';
  static String payoutDetailAndroid(String to) =>
      'To $to · usually within minutes, up to 24h';
  static String payoutDetailLive(String to) =>
      'To $to · usually within minutes';
  static const compactOnItsWay = 'On its way';
  static const stepRequested = 'Requested';
  static const stepSent = 'Sent';
  static const stepArrived = 'Arrived';

  static String newPoll(String business) => 'New poll from $business';
  static const pollTakes = 'Takes 10 seconds.';
  static const voteNow = 'Vote now';
  static const remindMeLater = 'Remind me later';

  static String youWon(String amount) => 'You won $amount';
  static String wasPicked(String title) =>
      '"$title" was picked. It is in your wallet.';

  static String draftWaiting(String? business) => business == null
      ? 'Your draft is waiting'
      : 'Your $business draft is waiting';
  static String draftLeft(String left) =>
      '$left left to send it. Pick up where you stopped.';

  static const closingSoon = 'Closing soon';
  static String briefMeta(String left, String pool) => '$left · $pool pool';
  static const pollsOpenOne = 'poll open';
  static const pollsOpenMany = 'polls open';
  static String closesIn(String business, String left) =>
      '$business closes in $left';

  static const answerQuickPoll = 'Answer a quick poll';
  static const continueDraft = 'Continue my draft';
  static const mySubmissions = 'My submissions';

  static const confirmItIsYou = 'Confirm it is you';
  static String withdrawTo(String amount, String to) =>
      'Withdraw $amount to $to';
  static const touchSensor = 'Touch the fingerprint sensor';
  static const cancel = 'Cancel';
  static const usePin = 'Use PIN';
}
