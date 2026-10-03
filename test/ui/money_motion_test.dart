import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/activity_row.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/receipt_card.dart';

import '../golden/golden.dart';

const _ms = Duration(milliseconds: 1);

double _eo(double t) => IqCurves.easeOut.transform(t);

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

double _fadeOf(WidgetTester tester, Finder of) => tester
    .widget<FadeTransition>(
      find.ancestor(of: of, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

void main() {
  setUpAll(loadAppFonts);

  group('IqReceiptCard', () {
    Finder tear() =>
        find.descendant(of: find.byType(Wipe), matching: find.byType(ClipRect));

    /// The tear line's width is the card's 358 less 19 on each side.
    double drawn(WidgetTester tester) {
      final clip = tester.widget<ClipRect>(tear());
      if (clip.clipBehavior == Clip.none) return 320;
      return clip.clipper!.getClip(const Size(320, 1.5)).width;
    }

    testWidgets('the tear line draws left to right, 240 from +120', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const IqReceiptCard()));
      // It starts once seen, on the frame after the first.
      await tester.pump();
      expect(drawn(tester), 0);
      await tester.pump(_ms * 120);
      expect(drawn(tester), 0);
      await tester.pump(_ms * 120);
      expect(drawn(tester), closeTo(320 * _eo(0.5), 0.5));
      await tester.pump(_ms * 121);
      expect(drawn(tester), 320);
    });

    testWidgets('a new status crossfades the tag, 150', (tester) async {
      await tester.pumpWidget(_app(const IqReceiptCard(status: 'Pending')));
      await tester.pumpWidget(_app(const IqReceiptCard(status: 'Completed')));
      await tester.pump(_ms * 75);
      expect(_fadeOf(tester, find.text('Completed')), closeTo(_eo(0.5), 0.01));
      expect(
        _fadeOf(tester, find.text('Pending')),
        closeTo(_eo(0.5), 0.01),
        reason: 'the old tag runs the same curve backwards',
      );
      await tester.pump(_ms * 76);
      expect(find.text('Pending'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: the tear line is drawn, the tag still '
        'crossfades in 150', (tester) async {
      await tester.pumpWidget(
        _app(const IqReceiptCard(status: 'Pending'), reduced: true),
      );
      expect(drawn(tester), 320);
      await tester.pumpWidget(
        _app(const IqReceiptCard(status: 'Completed'), reduced: true),
      );
      await tester.pump(_ms * 75);
      expect(find.text('Pending'), findsOneWidget);
      await tester.pump(_ms * 76);
      expect(find.text('Pending'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('IqActivityRow', () {
    testWidgets('a new status crossfades the chip, 150', (tester) async {
      Widget row(String status) => _app(
        SizedBox(width: 358, child: IqActivityRowWithdrawal(status: status)),
      );
      await tester.pumpWidget(row('pending'));
      await tester.pumpWidget(row('completed'));
      await tester.pump(_ms * 75);
      expect(find.text('pending'), findsOneWidget);
      expect(_fadeOf(tester, find.text('completed')), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 76);
      expect(find.text('pending'), findsNothing);
    });

    testWidgets('reduced motion: the chip still crosses in 150', (
      tester,
    ) async {
      Widget row(String status) => _app(
        SizedBox(width: 358, child: IqActivityRowWithdrawal(status: status)),
        reduced: true,
      );
      await tester.pumpWidget(row('pending'));
      await tester.pumpWidget(row('failed'));
      await tester.pump(_ms * 75);
      expect(_fadeOf(tester, find.text('failed')), closeTo(_eo(0.5), 0.01));
      await tester.pump(_ms * 76);
      expect(find.text('pending'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('under the finger the row fills card to panel, 100 in and '
        '160 out', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(width: 358, child: IqActivityRowWithdrawal(onTap: () {})),
        ),
      );
      Color fill() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byType(IqActivityRowWithdrawal),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      expect(fill(), IqColors.card);
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(IqActivityRowWithdrawal)),
      );
      await tester.pump();
      await tester.pump(_ms * 50);
      expect(
        fill(),
        isSameColorAs(Color.lerp(IqColors.card, IqColors.panel, _eo(0.5))!),
      );
      await tester.pump(_ms * 51);
      expect(fill(), isSameColorAs(IqColors.panel));
      await finger.up();
      await tester.pump();
      await tester.pump(_ms * 80);
      expect(
        fill(),
        isSameColorAs(Color.lerp(IqColors.panel, IqColors.card, _eo(0.5))!),
      );
      await tester.pumpAndSettle();
      expect(fill(), IqColors.card);
    });
  });

  group('IqBalanceHero', () {
    Widget hero({
      String amount = '₦12,500',
      bool reduced = false,
      bool ticking = true,
    }) => _app(
      TickerMode(
        enabled: ticking,
        child: SizedBox(width: 358, child: IqBalanceHero(amount: amount)),
      ),
      reduced: reduced,
    );

    testWidgets('the wash drifts on its own layer while it is on screen', (
      tester,
    ) async {
      await tester.pumpWidget(hero());
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      final painter = find.descendant(
        of: find.byType(IqBalanceHero),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null && w.child == null,
        ),
      );
      expect(painter, findsOneWidget);
      expect(
        find.ancestor(of: painter, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the wash holds still under reduced motion and with its '
        'tab hidden', (tester) async {
      await tester.pumpWidget(hero(reduced: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(hero(ticking: false));
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the wash stops once scrolled off screen', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 358,
            height: 600,
            child: ListView(
              controller: scroll,
              children: const [IqBalanceHero(), SizedBox(height: 2000)],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      scroll.jumpTo(250);
      await tester.pump();
      await tester.pump();
      expect(find.byType(IqBalanceHero, skipOffstage: false), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a figure rolls when it changes, never on arrival', (
      tester,
    ) async {
      await tester.pumpWidget(hero(reduced: true));
      expect(find.text('₦12,500'), findsOneWidget);
      await tester.pumpWidget(hero(amount: '₦7,500'));
      await tester.pump(_ms * 80);
      expect(find.text('₦12,500'), findsOneWidget);
      expect(find.text('₦7,500'), findsOneWidget);
      await tester.pump(_ms * 81);
      await tester.pump();
      expect(find.text('₦12,500'), findsNothing);
      expect(find.text('₦7,500'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
