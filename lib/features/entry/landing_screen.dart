import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../data/auth.dart';
import '../../data/device.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/box_field.dart';
import '../../ui/button.dart';
import '../../ui/provider_button.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';
import 'line_art_loop.dart';

/// B0 Landing (227:10756) and its email focused state (231:11204): the
/// providers and OR step aside, the drawing shrinks and Continue appears
/// under the box while it has focus or holds text.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final _email = EntryInput();
  late final _terms = TapGestureRecognizer()
    ..onTap = () => ref.read(deviceServiceProvider).openUrl(LegalLinks.terms);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => ref.read(deviceServiceProvider).openUrl(LegalLinks.privacy);
  bool _checking = false;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _email.controller.text = ref.read(entryDraftProvider).email;
  }

  @override
  void dispose() {
    _email.dispose();
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  bool get _focused =>
      _email.focus.hasFocus || _email.controller.text.isNotEmpty;

  void _leaveEmail() {
    _email.controller.clear();
    _email.focus.unfocus();
  }

  Future<void> _continue() async {
    final email = _email.text;
    if (!isEmail(email) || _checking) return;
    setState(() => _checking = true);
    final known = await ref.read(authServiceProvider).isKnownEmail(email);
    if (!mounted) return;
    setState(() => _checking = false);
    ref.read(entryDraftProvider.notifier).setEmail(email);
    context.push(known ? Routes.signIn : Routes.yourName);
  }

  Future<void> _continueWith(AuthProvider provider) async {
    if (_signingIn) return;
    _signingIn = true;
    final result = await ref.read(authServiceProvider).continueWith(provider);
    _signingIn = false;
    if (!mounted || !result.ok) return;
    await completeSignIn(ref, newAccount: result.newAccount);
    if (!mounted) return;
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
                    child: CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _body(context, focused),
                        ),
                      ],
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
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    const curve = Curves.easeOut;
    final valid = isEmail(_email.controller.text);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: Column(
        children: [
          AnimatedContainer(
            duration: motion,
            curve: curve,
            height: focused ? IqSpace.s2 : 28,
          ),
          SvgPicture.asset(
            'assets/brand/iqly-logo.svg',
            width: 120,
            semanticsLabel: 'iQLY',
          ),
          AnimatedContainer(
            duration: motion,
            curve: curve,
            height: focused ? IqSpace.s2p5 : IqSpace.s5,
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: focused ? 120 : 220),
            duration: motion,
            curve: curve,
            builder: (context, size, _) => LineArtLoop(size: size),
          ),
          AnimatedContainer(
            duration: motion,
            curve: curve,
            height: focused ? IqSpace.s2p5 : IqSpace.s5,
          ),
          // Padding, not a 300 wide box: SliverFillRemaining sizes by
          // intrinsics, and a box's width is not passed to them.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 29),
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
          const Spacer(),
          const SizedBox(height: IqSpace.s4),
          _resize(
            motion,
            focused
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      IqProviderButton(
                        kind: IqProviderButtonKind.apple,
                        width: double.infinity,
                        onTap: () => _continueWith(AuthProvider.apple),
                      ),
                      const SizedBox(height: IqSpace.s3),
                      IqProviderButton(
                        kind: IqProviderButtonKind.google,
                        width: double.infinity,
                        onTap: () => _continueWith(AuthProvider.google),
                      ),
                      const SizedBox(height: IqSpace.s3),
                      const _OrDivider(),
                      const SizedBox(height: IqSpace.s3),
                    ],
                  ),
          ),
          IqBoxField(
            tone: IqBoxFieldTone.paper,
            controller: _email.controller,
            focusNode: _email.focus,
            width: double.infinity,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _continue(),
          ),
          if (focused) ...[
            const SizedBox(height: IqSpace.s3),
            IqButton(
              label: 'Continue',
              showIcon: false,
              width: double.infinity,
              disabled: !valid,
              loading: _checking,
              onTap: _continue,
            ),
            const SizedBox(height: IqSpace.s3),
          ] else ...[
            const SizedBox(height: 3),
            LinkRow(
              lead: 'Already with us?',
              link: 'Sign in',
              onTap: () => context.push(Routes.signIn),
            ),
            const SizedBox(height: 3),
          ],
          _legal(),
          SizedBox(height: focused ? IqSpace.s3 : 14),
        ],
      ),
    );
  }

  /// AnimatedSize cannot run at zero duration, so reduced motion swaps
  /// without it.
  Widget _resize(Duration motion, Widget child) {
    if (motion == Duration.zero) return child;
    return AnimatedSize(
      duration: motion,
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: child,
    );
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
