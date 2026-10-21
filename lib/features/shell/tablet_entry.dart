import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../data/device.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';
import '../../ui/ticket_card.dart';

/// T2 · Entry, sign up and sign in (Mobile App · tablet, 1854:61899).
/// Landscape keeps the desktop split: the brand side with the logo, the
/// headline and the art beside the 560 form column on the cream canvas.
/// Portrait stacks the logo, the headline and the hero (the figure with
/// the Sunline ticket) over the form, and drops the hero while the
/// keyboard is up. The pages under it lay their form out as [TabletEntryScope]
/// asks: a 400 column, centred, its button under the fields.
///
/// Figma over brief: the spec note says portrait drops the art, but every
/// portrait frame (1854:62273 to 1854:63998) draws the hero; the frames win.
class TabletEntrySplit extends StatelessWidget {
  const TabletEntrySplit({super.key, required this.page});

  final Widget page;

  static bool covers(String location) =>
      location == '/landing' ||
      location.startsWith('/invite/') ||
      const [
        '/sign-up',
        '/sign-in',
        '/verify-email',
        '/forgot-password',
      ].any((r) => location == r || location.startsWith('$r/'));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pad = media.viewPadding;
    final scoped = TabletEntryScope(child: page);
    if (!Layout.isExpanded(context)) {
      final typing = media.viewInsets.bottom > 0;
      return Material(
        color: IqColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: pad.top + IqSpace.s6),
            const Center(child: IqBrandLogo(height: 32)),
            const SizedBox(height: IqSpace.s6),
            Text(
              'Businesses pay for\ngood ideas.',
              textAlign: TextAlign.center,
              style: IqLandText.h2.copyWith(color: IqColors.brand),
            ),
            if (!typing) ...[
              const SizedBox(height: IqSpace.s12),
              const Center(child: _Hero()),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => MediaQuery(
                  data: media.copyWith(
                    size: box.biggest,
                    padding: media.padding.copyWith(top: 0),
                    viewPadding: pad.copyWith(top: 0),
                  ),
                  child: scoped,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: IqColors.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                IqSpace.s12,
                pad.top + IqSpace.s6,
                IqSpace.s6,
                pad.bottom + IqSpace.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IqBrandLogo(height: 32),
                  const SizedBox(height: IqSpace.s16),
                  Text(
                    'Businesses pay for good ideas.',
                    style: IqLandText.h2.copyWith(color: IqColors.brand),
                  ),
                  const Spacer(),
                  const IqFigure(IqFigures.thinker, width: 260),
                  const Spacer(),
                  Row(
                    children: [
                      _Link('Terms of Service', LegalLinks.terms),
                      const SizedBox(width: IqSpace.s4),
                      _Link('Privacy Policy', LegalLinks.privacy),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 560,
            child: LayoutBuilder(
              builder: (context, box) => MediaQuery(
                data: media.copyWith(size: box.biggest),
                child: scoped,
              ),
            ),
          ),
          const SizedBox(width: IqSpace.s6),
        ],
      ),
    );
  }
}

/// Marks an entry page laid out by [TabletEntrySplit]: its form is a 400
/// column with the button under the fields and no back bar.
class TabletEntryScope extends InheritedWidget {
  const TabletEntryScope({super.key, required super.child});

  static const double formWidth = 400;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabletEntryScope>() != null;

  @override
  bool updateShouldNotify(TabletEntryScope oldWidget) => false;
}

/// The portrait hero: the thinker with the Sunline ticket tilted over her
/// right side (1854:62273).
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      height: 320,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            child: IqFigure(IqFigures.thinker, width: 260),
          ),
          Positioned(
            left: 226,
            top: 96,
            child: Transform.rotate(
              angle: 0.05,
              // Art: the ticket keeps its drawn size at any text scale.
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.noScaling),
                child: const ExcludeSemantics(
                  child: IqTicketCard(
                    meta: 'Sunline · Standard',
                    showRule: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Link extends ConsumerWidget {
  const _Link(this.label, this.url);

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IqPressable(
      onTap: () => ref.read(deviceServiceProvider).openUrl(url),
      tactile: false,
      semanticLabel: label,
      builder: (context, pressed) => SizedBox(
        height: 44,
        child: Center(
          child: Text(
            label,
            style: IqWebText.metaCaption.copyWith(
              color: pressed ? IqColors.fg : IqColors.fg3,
            ),
          ),
        ),
      ),
    );
  }
}
