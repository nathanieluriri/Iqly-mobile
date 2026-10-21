import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../data/device.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';

/// T2 · Entry, landscape (Mobile App · tablet, 1854:61899): the brand side
/// with the logo, the headline and the art beside the 560 form column on
/// the cream canvas. Portrait keeps the app's own landing, which stacks the
/// logo and headline over the form.
class TabletEntrySplit extends StatelessWidget {
  const TabletEntrySplit({super.key, required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    if (!Layout.isExpanded(context)) return page;
    final media = MediaQuery.of(context);
    final pad = media.viewPadding;
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
                child: page,
              ),
            ),
          ),
          const SizedBox(width: IqSpace.s6),
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
