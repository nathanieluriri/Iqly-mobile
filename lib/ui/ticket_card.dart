import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'bookmark.dart';
import 'highlight.dart';
import 'perforation.dart';
import 'pressable.dart';
import 'urgency.dart';
import 'vector.dart';

enum IqTicketCardKind { hero, list }

/// Exp/TicketCard: a brief as a ticket. The main area carries who, what and
/// the deadline chip; the stub carries the reward pool, the rule and the
/// spots left ([spots], hidden when null for an open capacity). Hero is the
/// dark ticket for Closing soon, List the paper one. [showBookmark] reveals
/// an Exp/Bookmark (Ink on Hero, Paper on List) that flips through
/// [onBookmarkChanged]; [onTap] opens the brief.
///
/// Figma over brief: the default Meta is the category ("Sunline · Marketing"), not the tier.
/// Figma over brief: the title box is 40 tall, so both kinds show at most two lines.
/// Figma over brief: the List bookmark sits top right (198, 6), the Hero one level with the chip (150, 136).
class IqTicketCard extends StatelessWidget {
  const IqTicketCard({
    super.key,
    this.kind = IqTicketCardKind.hero,
    this.title = 'A tagline for a solar kiosk network',
    this.meta = 'Sunline · Marketing',
    this.initial = 'S',
    this.reward = '₦150,000',
    this.rule = 'Top 10% paid',
    this.showRule = true,
    this.showBookmark = false,
    this.spots = '12 spots left',
    this.urgency = 'Closes in 6h',
    this.urgencyTone,
    this.bookmarkState = IqBookmarkState.off,
    this.onBookmarkChanged,
    this.onTap,
  });

  final IqTicketCardKind kind;
  final String title;
  final String meta;
  final String initial;
  final String reward;
  final String rule;
  final bool showRule;
  final bool showBookmark;
  final String? spots;
  final String urgency;

  /// Defaults to Hot on Hero and Warm on List, as in Figma.
  final IqUrgencyTone? urgencyTone;
  final IqBookmarkState bookmarkState;
  final ValueChanged<IqBookmarkState>? onBookmarkChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hero = kind == IqTicketCardKind.hero;
    final width = hero ? 300.0 : 358.0;
    final height = hero ? 188.0 : 136.0;
    final stubX = hero ? 210.0 : 260.0;
    final text = hero ? IqColors.sidebarFg : IqColors.brand;
    final soft = hero ? IqColors.sidebarFg : IqColors.fg3;

    return IqPressable(
      onTap: onTap,
      semanticLabel: title,
      builder: (context, pressed) => SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (hero)
              const Positioned.fill(
                child: IqVector(
                  'assets/vectors/ticket-card-ticket-hero.svg',
                  color: IqColors.brand,
                ),
              )
            else ...const [
              Positioned.fill(
                child: IqVector(
                  'assets/vectors/ticket-card-ticket-list-fill.svg',
                  color: IqColors.card,
                ),
              ),
              Positioned.fill(
                child: IqVector(
                  'assets/vectors/ticket-card-ticket-list-stroke.svg',
                  color: IqColors.line,
                ),
              ),
            ],
            Positioned(
              left: (hero ? 196 : 246) - 0.75,
              top: 13,
              bottom: 13,
              width: 1.5,
              child: IqPerforation(
                color: hero ? IqColors.sidebarBorder : IqColors.line2,
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              width: hero ? 170 : 182,
              height: 26,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hero
                          ? IqColors.sidebarAccent
                          : IqColors.tintStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      maxLines: 1,
                      style: IqText.label.copyWith(
                        color: hero ? IqColors.sidebarFg : IqColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: IqSpace.s2),
                  Expanded(
                    child: Text(
                      meta,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.small.copyWith(
                        color: hero
                            ? IqColors.sidebarFg.withValues(alpha: 0.8)
                            : IqColors.fg3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              top: 52,
              width: hero ? 168 : 218,
              height: 40,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: IqText.cardTitle.copyWith(color: text),
              ),
            ),
            Positioned(
              left: 16,
              top: hero ? 144 : 92,
              child: IqUrgency(
                text: urgency,
                tone:
                    urgencyTone ??
                    (hero ? IqUrgencyTone.hot : IqUrgencyTone.warm),
              ),
            ),
            if (showRule)
              Positioned(
                left: hero ? 210 : 139,
                top: hero ? 67 : 97,
                right: hero ? 4 : null,
                child: Text(
                  rule,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.small.copyWith(
                    color: hero
                        ? IqColors.primaryFg.withValues(alpha: 0.8)
                        : IqColors.fg3,
                  ),
                ),
              ),
            Positioned(
              left: stubX,
              top: 28,
              child: Text(
                'Reward pool'.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                style: IqText.mono.copyWith(
                  color: hero ? soft.withValues(alpha: 0.75) : soft,
                ),
              ),
            ),
            Positioned(
              left: stubX,
              top: 44,
              right: 4,
              child: Text(
                reward,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: IqText.figureSmall.copyWith(color: text),
              ),
            ),
            if (spots != null)
              Positioned(
                left: hero ? 201 : 256,
                top: hero ? 148 : 96,
                child: IqHighlight(
                  text: spots!,
                  tone: hero ? IqHighlightTone.inverse : IqHighlightTone.orange,
                  style: IqText.smallStrong,
                ),
              ),
            if (showBookmark)
              Positioned(
                left: hero ? 150 : 198,
                top: hero ? 136 : 6,
                child: IqBookmark(
                  state: bookmarkState,
                  tone: hero ? IqBookmarkTone.ink : IqBookmarkTone.paper,
                  onChanged: onBookmarkChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
