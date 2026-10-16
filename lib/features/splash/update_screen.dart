import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/session.dart';
import '../../core/updates.dart';
import '../../data/api_config.dart';
import '../../data/app_version.dart';
import '../../data/device.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/button.dart';
import '../../ui/pressable.dart';
import 'splash_screen.dart';

/// B · Update · required (Figma 1310:26448): this build is below the
/// minimum the API supports, so nothing else opens until it is updated
/// (note 1313:92110). Back leaves the app, and the wallet line shows only
/// to someone signed in.
///
/// Motion: handed over by the splash ([glide]), the logo glides from its
/// splash place, 210 to 113 wide, 300 ms ease-out, then the copy rises 8
/// and fades in, 220 ms each, 40 ms apart, the footer last with the button.
/// Any other arrival is the route's 150 ms crossfade.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key, this.glide = false});

  final bool glide;

  static const title = 'Time to update';
  static const body =
      'This version of iQLY no longer works.\nUpdate to keep answering briefs.';
  static const reassurance = 'Your wallet and submissions are safe.';
  static const updateLabel = 'Update iQLY';
  static const double logoHeight = 28;
  static const double homeIndicator = 34;

  /// The version line: YOU HAVE 0.1.0 · NEEDS 0.2.0.
  static String versions(AppRelease release) {
    final have = 'You have ${versionName(release.installed)}';
    final minimum = release.minimum;
    final line = minimum == null
        ? have
        : '$have · needs ${versionName(minimum)}';
    return line.toUpperCase();
  }

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen>
    with SingleTickerProviderStateMixin {
  final _stage = GlobalKey();
  final _logo = GlobalKey();
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: IqDurations.screen,
    animationBehavior: AnimationBehavior.preserve,
  );
  Rect? _landing;
  late bool _landed = !widget.glide;

  @override
  void initState() {
    super.initState();
    if (widget.glide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted) return;
    final logo = _logo.currentContext?.findRenderObject();
    final stage = _stage.currentContext?.findRenderObject();
    if (logo is! RenderBox || stage is! RenderBox) {
      setState(() => _landed = true);
      return;
    }
    final at = logo.localToGlobal(Offset.zero, ancestor: stage);
    setState(() => _landing = at & logo.size);
    _glide
      ..addStatusListener((status) {
        if (status.isCompleted && mounted) setState(() => _landed = true);
      })
      ..forward();
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  void _open(Uri url) => ref.read(deviceServiceProvider).openUrl(url);

  /// Item [index] of the copy: hidden while the logo glides, then rising in.
  Widget _enter(int index, Widget child) {
    if (!widget.glide) return child;
    if (!_landed) {
      return IgnorePointer(child: Opacity(opacity: 0, child: child));
    }
    return Appear(delay: IqDurations.stagger * index, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(updatesProvider);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final inset = MediaQuery.viewPaddingOf(context);
    final web = Uri.parse(ApiConfig.webUrl);
    final copy = [
      Text(
        UpdateScreen.title,
        textAlign: TextAlign.center,
        style: IqText.display.copyWith(color: IqColors.primaryFg),
      ),
      Text(
        UpdateScreen.body,
        textAlign: TextAlign.center,
        style: IqText.body.copyWith(color: IqColors.primaryFg),
      ),
      if (signedIn)
        Text(
          UpdateScreen.reassurance,
          textAlign: TextAlign.center,
          style: IqText.body.copyWith(color: IqColors.primaryFg),
        ),
      if (release != null)
        Opacity(
          opacity: IqOpacity.updateVersion,
          child: Text(
            UpdateScreen.versions(release),
            textAlign: TextAlign.center,
            style: IqText.mono.copyWith(color: IqColors.primaryFg),
          ),
        ),
    ];
    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, IqSpace.s3, IqSpace.s4, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IqButton(
            kind: IqButtonKind.inverse,
            label: UpdateScreen.updateLabel,
            showIcon: false,
            width: double.infinity,
            onTap: () => _open(release?.updateUrl ?? web),
          ),
          _Fallback(onTap: () => _open(web)),
        ],
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: IqColors.brandDark,
          body: Stack(
            key: _stage,
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  SizedBox(height: inset.top),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: CenteredContent(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                IqSpace.s6,
                                IqSpace.s6,
                                IqSpace.s6,
                                IqSpace.s4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Opacity(
                                      opacity: _landed ? 1 : 0,
                                      child: IqBrandLogo(
                                        key: _logo,
                                        tone: IqBrandTone.onDark,
                                        height: UpdateScreen.logoHeight,
                                      ),
                                    ),
                                  ),
                                  // Figma's 28 spacer between two 12 gaps.
                                  const SizedBox(
                                    height: IqSpace.s3 + 28 + IqSpace.s3,
                                  ),
                                  for (var i = 0; i < copy.length; i++) ...[
                                    if (i > 0)
                                      const SizedBox(height: IqSpace.s3),
                                    _enter(i, copy[i]),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  CenteredContent(child: _enter(copy.length, footer)),
                  SizedBox(
                    height: math.max(inset.bottom, UpdateScreen.homeIndicator),
                  ),
                ],
              ),
              if (!_landed)
                AnimatedBuilder(
                  animation: _glide,
                  builder: (context, _) {
                    final from = SplashScreen.wordmarkRect(
                      MediaQuery.sizeOf(context),
                    );
                    final rect = Rect.lerp(
                      from,
                      _landing ?? from,
                      IqCurves.easeOut.transform(_glide.value),
                    )!;
                    return Positioned.fromRect(
                      rect: rect,
                      child: const IqBrandLogo(tone: IqBrandTone.onDark),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Can't update? Use iqly.net in your browser.": the whole line is one
/// 48 pt tap target (Figma 1317:26867).
class _Fallback extends StatelessWidget {
  const _Fallback({required this.onTap});

  final VoidCallback onTap;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final style = IqText.small.copyWith(color: IqColors.primaryFg);
    return IqPressable(
      onTap: onTap,
      builder: (context, pressed) => PressDim(
        pressed: pressed,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(
            child: Opacity(
              opacity: IqOpacity.updateFallback,
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    const TextSpan(text: "Can't update? Use "),
                    TextSpan(
                      text: 'iqly.net',
                      style: style.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: IqColors.primaryFg,
                      ),
                    ),
                    const TextSpan(text: ' in your browser.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
