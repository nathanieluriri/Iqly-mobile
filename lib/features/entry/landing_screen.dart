import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/auth.dart';
import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/box_field.dart';
import '../../ui/brand_logo.dart';
import '../../ui/button.dart';
import '../../ui/provider_button.dart';
import 'entry_copy.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'line_art_loop.dart';

/// B0 Landing (227:10756) and its email focused state (231:11204): the
/// providers and OR step aside, the drawing shrinks and Continue appears
/// under the box while it has focus or holds text. A failed Apple or Google
/// attempt drops an Error banner in at the top until the next try.
///
/// Motion (MOTION-SPEC 4.2, 6.2): one controller moves the whole column,
/// 300 ms ease-out into the focused layout as the box takes focus (not when
/// the keyboard moves) and 240 back. The gaps close, the drawing's slot
/// goes 220 to 120 while the drawing scales with it, the providers, OR and
/// the "Already with us?" row fade out in the first 90 ms as their slots
/// close (and fade back in over the last 120 on the way back), Continue's
/// slot opens as it appears from +120 (fading out in the first 90 on the
/// way back). On short screens the column scrolls so the box and Continue
/// stay above the keyboard. The landing comes in with the logo already in
/// place: the drawing arrives at 0, the headline at +60, then the rows 40
/// apart from +120. Reduced motion: the focused layout at once with
/// Continue fading in over 150, and the entrance fades in together.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  /// The logo sits this far below the safe area at rest; the splash lands
  /// its wordmark here (spec 3.9).
  static const double logoTop = 28;

  /// The logo's width.
  static const double logoWidth = 120;

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with TickerProviderStateMixin {
  static const double _focusedTop = IqSpace.s2;
  static const double _gap = IqSpace.s5;
  static const double _focusedGap = IqSpace.s2p5;
  static const double _drawing = 220;
  static const double _focusedDrawing = 120;
  static const double _linkGap = 3;
  static const double _restBottom = 14;

  final _email = EntryInput();
  late final _terms = TapGestureRecognizer()
    ..onTap = () => ref.read(deviceServiceProvider).openUrl(LegalLinks.terms);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => ref.read(deviceServiceProvider).openUrl(LegalLinks.privacy);

  late final AnimationController _focus = AnimationController(
    vsync: this,
    duration: IqDurations.screen,
    reverseDuration: IqDurations.screenBack,
    value: _focused ? 1 : 0,
  );
  late final Animation<double> _layout = CurvedAnimation(
    parent: _focus,
    curve: IqCurves.easeOut,
  );
  late final Animation<double> _aside = CurvedAnimation(
    parent: _focus,
    curve: Interval(
      0,
      _share(IqLandingTiming.clear, IqDurations.screen),
      curve: IqCurves.easeIn,
    ),
    reverseCurve: Interval(
      0,
      _share(IqDurations.chain, IqDurations.screenBack),
      curve: IqCurves.easeIn,
    ),
  );
  late final Animation<double> _continue = CurvedAnimation(
    parent: _focus,
    curve: Interval(
      _share(IqDurations.chain, IqDurations.screen),
      1,
      curve: IqCurves.easeOut,
    ),
    reverseCurve: Interval(
      1 - _share(IqLandingTiming.clear, IqDurations.screenBack),
      1,
      curve: IqCurves.easeOut,
    ),
  );

  /// Under reduced motion the layout cuts and these fade: Continue in, the
  /// providers and the link row back.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: IqDurations.crossfade,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<double> _fadeIn = _fade.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final AnimationController _failure = AnimationController(
    vsync: this,
    duration: IqBanner.enter,
    reverseDuration: IqBanner.exit,
  );
  late final Animation<double> _failed = CurvedAnimation(
    parent: _failure,
    curve: IqCurves.easeOut,
  );

  bool _checking = false;
  bool _signingIn = false;
  AuthProvider? _failedProvider;
  bool _showFailure = false;
  bool _wasFocused = false;

  static double _share(Duration part, Duration whole) =>
      part.inMicroseconds / whole.inMicroseconds;

  @override
  void initState() {
    super.initState();
    _email.controller.text = ref.read(entryDraftProvider).email;
    _wasFocused = _focused;
    _focus.value = _wasFocused ? 1 : 0;
    _email.focus.addListener(_onFocus);
    _email.changes.addListener(_syncFocus);
  }

  @override
  void dispose() {
    _email.changes.removeListener(_syncFocus);
    _email.focus.removeListener(_onFocus);
    _email.dispose();
    _terms.dispose();
    _privacy.dispose();
    _focus.dispose();
    _fade.dispose();
    _failure.dispose();
    super.dispose();
  }

  bool get _focused =>
      _email.focus.hasFocus || _email.controller.text.isNotEmpty;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _onFocus() {
    if (_email.focus.hasFocus && _showFailure) _setFailure(false);
  }

  void _syncFocus() {
    final focused = _focused;
    if (focused == _wasFocused) return;
    _wasFocused = focused;
    if (_reduced) {
      _focus.value = focused ? 1 : 0;
      _fade.forward(from: 0);
    } else if (focused) {
      _focus.forward();
    } else {
      _focus.reverse();
    }
  }

  void _setFailure(bool shown) {
    setState(() => _showFailure = shown);
    if (_reduced) {
      _failure.value = shown ? 1 : 0;
    } else if (shown) {
      _failure.forward();
    } else {
      _failure.reverse();
    }
  }

  void _leaveEmail() {
    _email.controller.clear();
    _email.focus.unfocus();
  }

  Future<void> _continueTapped() async {
    final email = _email.text;
    if (email.isEmpty || _checking) return;
    if (!isEmail(email)) {
      _email.fail(EntryCopy.badEmail);
      return;
    }
    setState(() => _checking = true);
    final result = await ref.read(authServiceProvider).lookUpEmail(email);
    if (!mounted) return;
    setState(() => _checking = false);
    if (result.failure == AuthFailure.offline) {
      _email.fail(EntryCopy.offline);
      return;
    }
    ref.read(entryDraftProvider.notifier).setEmail(email);
    // Any other lookup failure goes on to sign up, which sends a taken email
    // to Sign in anyway.
    final known = result.ok && !result.newAccount;
    context.push(known ? Routes.signIn : Routes.yourName);
  }

  Future<void> _continueWith(AuthProvider provider) async {
    if (_signingIn) return;
    _signingIn = true;
    if (_showFailure) _setFailure(false);
    final result = await ref.read(authServiceProvider).continueWith(provider);
    _signingIn = false;
    if (!mounted) return;
    final failure = result.failure;
    if (failure == AuthFailure.cancelled) return;
    if (failure != null) {
      _failedProvider = provider;
      _setFailure(true);
      errorHaptic();
      return;
    }
    await completeSignIn(ref, newAccount: result.newAccount);
    if (!mounted) return;
    if (result.newAccount) IqHaptics.success.play();
    context.go(result.newAccount ? Routes.onboarding : Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: ListenableBuilder(
        listenable: _email.changes,
        builder: (context, _) {
          final focused = _focused;
          return PopScope(
            canPop: !focused,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _leaveEmail();
            },
            child: Scaffold(
              backgroundColor: IqColors.bg,
              resizeToAvoidBottomInset: true,
              body: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _email.focus.unfocus(),
                child: SafeArea(
                  child: CenteredContent(
                    child: Sequence(
                      length:
                          IqLandingTiming.rowsAt +
                          IqDurations.stagger * 5 +
                          BeatMove.arrive.length,
                      play: arrivalOf(context) == NavDirection.forward,
                      child: _body(context, focused),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, bool focused) {
    // The two groups sit at the top and bottom of at least a screen's
    // height and scroll when they do not fit. No intrinsic sizing: the
    // hidden banner still measures its strip.
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: AnimatedBuilder(
              animation: Listenable.merge([_focus, _failure]),
              builder: (context, _) => Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: _top(focused)),
                  Column(children: _bottom(focused)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _lerp(double from, double to) => from + (to - from) * _layout.value;

  List<Widget> _top(bool focused) {
    final provider = _failedProvider;
    final rest = (1 - _layout.value) * (1 - _failed.value);
    final drawing = _lerp(_drawing, _focusedDrawing);
    return [
      SizedBox(
        height: _focusedTop + (LandingScreen.logoTop - _focusedTop) * rest,
      ),
      Semantics(
        liveRegion: true,
        child: IqBanner(
          kind: IqBannerKind.error,
          title: provider == null ? '' : EntryCopy.social(provider),
          showAction: false,
          visible: _showFailure && !focused,
        ),
      ),
      SizedBox(height: IqSpace.s3 * _failed.value),
      const IqBrandLogo(width: LandingScreen.logoWidth),
      SizedBox(height: _lerp(_gap, _focusedGap)),
      Beat(
        move: BeatMove.arrive,
        child: SizedBox(
          width: _drawing,
          height: drawing,
          child: OverflowBox(
            maxHeight: _drawing,
            alignment: Alignment.topCenter,
            child: Transform.scale(
              scale: drawing / _drawing,
              alignment: Alignment.topCenter,
              child: const LineArtLoop(size: _drawing),
            ),
          ),
        ),
      ),
      SizedBox(height: _lerp(_gap, _focusedGap)),
      Beat(
        at: IqLandingTiming.headlineAt,
        child: SizedBox(
          width: 300,
          child: Semantics(
            header: true,
            child: GestureDetector(
              onTap: focused ? _leaveEmail : null,
              child: Text(
                'The arena for bold African thinkers.',
                textAlign: TextAlign.center,
                style: IqText.headline.copyWith(color: IqColors.fg),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Item [i] of the six rows that arrive 40 apart from +120.
  Widget _row(int i, Widget child) => Beat(
    at: IqLandingTiming.rowsAt + IqDurations.stagger * i,
    move: BeatMove.arrive,
    child: child,
  );

  /// What steps aside while the box has focus: its slot closes with the
  /// layout while it fades in the first 90 ms, and it leaves the tree once
  /// the box has focus. The empty slot keeps its place in the column: a
  /// child of another kind there would rebuild the box below it and close
  /// its keyboard.
  Widget _stepAside(Widget child) {
    if (_focus.isCompleted) return _slot(0, const SizedBox.shrink());
    return _slot(
      1 - _layout.value,
      FadeTransition(
        opacity: _reduced ? _fadeIn : ReverseAnimation(_aside),
        child: child,
      ),
    );
  }

  /// [open] of [child]'s height, clipped only while it opens or closes so
  /// the sticker and outlines that reach past the column show at rest.
  static Widget _slot(double open, Widget child) => ClipRect(
    clipBehavior: open >= 1 ? Clip.none : Clip.hardEdge,
    child: Align(
      alignment: Alignment.topCenter,
      heightFactor: open,
      child: child,
    ),
  );

  List<Widget> _bottom(bool focused) {
    final reduced = _reduced;
    final rising = !reduced && _focus.status != AnimationStatus.reverse;
    return [
      const SizedBox(height: IqSpace.s4),
      _stepAside(
        Column(
          children: [
            _row(
              0,
              IqProviderButton(
                kind: IqProviderButtonKind.apple,
                width: double.infinity,
                onTap: () => _continueWith(AuthProvider.apple),
              ),
            ),
            const SizedBox(height: IqSpace.s3),
            _row(
              1,
              IqProviderButton(
                kind: IqProviderButtonKind.google,
                width: double.infinity,
                onTap: () => _continueWith(AuthProvider.google),
              ),
            ),
            const SizedBox(height: IqSpace.s3),
            _row(2, const _OrDivider()),
            const SizedBox(height: IqSpace.s3),
          ],
        ),
      ),
      _row(
        3,
        Shake(
          trigger: _email.fails,
          child: IqBoxField(
            tone: IqBoxFieldTone.paper,
            state: _email.error == null ? null : IqBoxFieldState.error,
            help: _email.error ?? '',
            controller: _email.controller,
            focusNode: _email.focus,
            width: double.infinity,
            textInputAction: TextInputAction.go,
            scrollPadding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + IqSpace.s3 * 2 + IqButton.defaultHeight,
            ),
            onSubmitted: (_) => _continueTapped(),
          ),
        ),
      ),
      if (!_focus.isDismissed)
        _slot(
          _layout.value,
          FadeTransition(
            opacity: reduced ? _fadeIn : _continue,
            child: Transform.translate(
              offset: Offset(
                0,
                rising ? IqTravel.rise * (1 - _continue.value) : 0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: IqSpace.s3),
                child: IqButton(
                  label: 'Continue',
                  showIcon: false,
                  width: double.infinity,
                  disabled: _email.text.isEmpty,
                  loading: _checking,
                  onTap: _continueTapped,
                ),
              ),
            ),
          ),
        ),
      _stepAside(
        _row(
          4,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: _linkGap),
            child: LinkRow(
              lead: 'Already with us?',
              link: 'Sign in',
              onTap: () => context.push(Routes.signIn),
            ),
          ),
        ),
      ),
      _row(5, _legal()),
      SizedBox(height: _lerp(_restBottom, IqSpace.s3)),
    ];
  }

  Widget _legal() {
    final base = IqText.small.copyWith(color: IqColors.fg2);
    final link = base.copyWith(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(text: 'Terms of Service', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final rule = Expanded(
      child: Container(height: 1, color: IqColors.brand.withValues(alpha: 0.3)),
    );
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          rule,
          const SizedBox(width: IqSpace.s3),
          Text('OR', style: IqText.mono.copyWith(color: IqColors.fg2)),
          const SizedBox(width: IqSpace.s3),
          rule,
        ],
      ),
    );
  }
}
