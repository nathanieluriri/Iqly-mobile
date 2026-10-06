import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/entry/landing_screen.dart';
import 'package:iqly_mobile/features/entry/sign_in_screen.dart';
import 'package:iqly_mobile/ui/banner.dart';
import 'package:iqly_mobile/ui/box_field.dart';
import 'package:iqly_mobile/ui/brief_card.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/dock.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/section_title.dart';
import 'package:iqly_mobile/ui/tip_card.dart';

import 'harness.dart';

/// A signed-in contributor who has finished onboarding and seen the tip:
/// the app opens from the splash straight onto Discover.
const returning = <String, Object>{
  'session.signedIn': true,
  'session.onboardingDone': true,
  'session.firstTipSeen': true,
};

/// Kudi Box's activation, stuck at step 2 in the demo.
const kudiBox = 'Open a Kudi Box account and save ₦1,000.00';

/// The first poll card on Discover, there once the feed is in.
final feedIn = find.text('Which flavour should we launch first?');

/// The IqButton labelled [label].
Finder button(String label) =>
    find.byWidgetPredicate((w) => w is IqButton && w.label == label);

/// returning_sign_in at a brisker pace: from the splash of a fresh install,
/// the known email on the landing, the banner's Sign in, the password, to
/// Discover once its feed is in.
Future<void> signIn(Director d) async {
  await d.arrive(find.byType(LandingScreen), hold: 0.8);
  await d.tap(find.byType(IqBoxField), label: 'email-box');
  await d.hold(0.3);
  await d.type('adaeze@example.com', cps: 16);
  await d.hold(0.4);
  await d.tap(button('Continue'), label: 'continue');
  final banner = find.descendant(
    of: find.byType(IqBanner),
    matching: find.text('Sign in'),
  );
  await d.waitFor(banner);
  await d.hold(0.8);
  await d.tap(banner, label: 'banner-sign-in');

  await d.arrive(find.byType(SignInScreen), hold: 0.5);
  await d.type(DemoAuthService.password, cps: 14);
  await d.hold(0.4);
  await d.tap(button('Sign in'), label: 'sign-in');
  await onDiscover(d);
}

/// Waits for Discover's feed and lets it come to rest.
Future<void> onDiscover(Director d, {double hold = 1}) async {
  await d.waitFor(find.byType(HomeScreen));
  await d.waitFor(feedIn);
  await d.settle(on: find.byType(HomeScreen));
  await d.hold(hold);
}

/// The link of the section titled [title] ("Filter", "See all"): its hit
/// band is the 72 pt at the title's right edge.
Finder sectionLink(String title) => find
    .descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(IqSectionTitle),
      ),
      matching: find.byType(IqPressable),
    )
    .last;

/// The feed card of the brief titled [title].
Finder briefCard(String title) => find.byWidgetPredicate(
  (w) => w is IqBriefCard && w.title == title,
  description: 'the "$title" card',
);

/// The link of the one section title on screen (Select all, See all).
final onlySectionLink = find.descendant(
  of: find.byType(IqSectionTitle),
  matching: find.byType(IqPressable),
);

/// The dock tab labelled [label].
Future<void> dockTab(Director d, String label) => d.tap(
  find.descendant(of: find.byType(IqDock), matching: find.text(label)),
  label: '${label.toLowerCase()}-tab',
);

/// The first tip over Discover: waits for its card to finish arriving (it
/// follows the feed's own arrival), leaves it up to be read, dismisses it
/// and stays a second on the feed.
Future<void> readFirstTip(Director d) async {
  final ok = find.text('OK, got it');
  await d.waitFor(ok);
  final card = find
      .ancestor(
        of: find.byType(IqTipCard),
        matching: find.byType(FadeTransition),
      )
      .first;
  for (
    var i = 0;
    d.tester.widget<FadeTransition>(card).opacity.value < 1;
    i++
  ) {
    if (i == 180) {
      throw TestFailure('${d.name}: the first tip never arrived at ${d.time}s');
    }
    await d.frames(1);
  }
  await d.hold(1.2);
  await d.tap(ok);
  await d.gone(ok);
  await d.hold(1);
}

/// The close button of the sheet on top. Its semantics merge into the
/// sheet's own node ("Orchid Foods, Close"), so it is found by its icon.
Future<void> closeSheet(Director d) => d.tap(
  find.byWidgetPredicate((w) => w is IqIcon && w.icon == IqIcons.close).last,
  label: 'close',
);

/// The first vertical list inside [screen].
Finder listIn(Finder screen) => find
    .descendant(
      of: screen,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

/// Scrolls the first list in [screen] until [item] is in view, then taps it.
Future<void> revealAndTap(
  Director d,
  Finder item,
  Finder screen, {
  String? label,
}) async {
  final list = listIn(screen);
  await d.reveal(item, list);
  // The dock floats over the list's foot, so an item there is not tappable.
  for (var i = 0; item.hitTestable().evaluate().isEmpty; i++) {
    if (i == 4) break;
    await d.scroll(list, -160, seconds: 0.4);
    await d.hold(0.3);
  }
  await d.hold(0.4);
  await d.tap(item, label: label);
}
