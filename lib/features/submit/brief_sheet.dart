import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/transitions.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/brief_hero.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../discover/business_art.dart';
import '../discover/discover_widgets.dart';

/// B3 · Submit · brief sheet (547:24763): the brief over the draft, opened
/// by View the brief. Back to writing and the scrim return to the same
/// screen with the draft as it was. Rises 300, drops 200.
Future<void> showBriefSheet(BuildContext context, Brief brief) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showIqSheet<void>(
    Navigator.of(context, rootNavigator: true).context,
    (context) =>
        BriefSheet(brief: brief, onBack: () => Navigator.of(context).pop()),
    scrim: IqScrim.sheet,
  );
}

class BriefSheet extends ConsumerWidget {
  const BriefSheet({super.key, required this.brief, this.onBack});

  final Brief brief;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: child,
    );
    return Material(
      color: IqColors.card,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(IqConfirmSheet.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 12),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: IqColors.line2,
                  borderRadius: BorderRadius.circular(IqRadius.full),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IqBriefHero(
                    cover: businessCover(brief.cover),
                    logo: businessLogo(brief.logo),
                    showDots: false,
                    height: 232,
                  ),
                  const SizedBox(height: 5),
                  pad(
                    Padding(
                      padding: const EdgeInsets.only(left: 66),
                      child: Text(
                        businessLabel(brief),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IqText.smallStrong.copyWith(color: IqColors.fg),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  pad(
                    Text(
                      brief.title,
                      style: IqText.headline.copyWith(color: IqColors.fg),
                    ),
                  ),
                  const SizedBox(height: 14),
                  pad(
                    Wrap(
                      spacing: IqSpace.s1p5,
                      runSpacing: IqSpace.s1p5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: briefMeta(brief, now),
                    ),
                  ),
                  const SizedBox(height: 14),
                  pad(
                    Text(
                      brief.body,
                      style: IqText.body.copyWith(color: IqColors.fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s6 + IqSpace.s3,
              IqSpace.s4,
              0,
            ),
            child: IqButton(
              label: 'Back to writing',
              kind: IqButtonKind.secondary,
              width: double.infinity,
              onTap: onBack,
            ),
          ),
          SizedBox(height: math.max(inset, IqConfirmSheet.homeIndicator)),
        ],
      ),
    );
  }
}
