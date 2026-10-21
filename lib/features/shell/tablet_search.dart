import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/money.dart';
import '../../data/repository.dart';
import '../../router.dart';
import '../../ui/web_command_menu.dart';
import '../activations/activations_state.dart';
import '../discover/business_art.dart';
import '../discover/discover_state.dart';
import '../polls/polls_routes.dart';
import '../polls/polls_state.dart';

/// The top bar's search (T1 · Shell · search open): Exp/Web/CommandMenu
/// with the keyboard up, the live briefs, polls and activations whose
/// title, question or business holds the query.
class TabletSearch extends ConsumerStatefulWidget {
  const TabletSearch({super.key, required this.onGo});

  final ValueChanged<String> onGo;

  @override
  ConsumerState<TabletSearch> createState() => _TabletSearchState();
}

class _TabletSearchState extends ConsumerState<TabletSearch> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    bool hit(String? text) => text != null && text.toLowerCase().contains(q);
    final now = ref.watch(clockProvider)();
    final briefs = q.isEmpty
        ? const []
        : [
            for (final b in ref.watch(discoverFeedProvider).value?.briefs ?? [])
              if (hit(b.title) || hit(b.businessName)) b,
          ];
    final polls = q.isEmpty || !ref.watch(pollsShownProvider)
        ? const []
        : [
            for (final p in ref.watch(pollsProvider).value ?? [])
              if (hit(p.name) || p.polls.any((poll) => hit(poll.question))) p,
          ];
    final activations = q.isEmpty || !ref.watch(activationsShownProvider)
        ? const []
        : [
            for (final a in ref.watch(activationsProvider).value ?? [])
              if (hit(a.title) || hit(a.business)) a,
          ];
    final groups = [
      IqWebCommandGroup(
        label: 'Briefs',
        results: [
          for (final b in briefs.take(5))
            IqWebCommandResult(
              title: b.title,
              meta: [
                ?b.businessName,
                rewardPool(b.rewardPoolKobo),
                closesIn(timeLeft(b.deadline, now), closed: !b.isLive),
              ].join(' · '),
              logo: ClipOval(child: businessLogo(b.logo, size: 28)),
              onTap: () => widget.onGo(Routes.brief(b.id)),
            ),
        ],
      ),
      IqWebCommandGroup(
        label: 'Polls',
        results: [
          for (final p in polls.take(5))
            IqWebCommandResult(
              title: p.headline,
              meta: [
                p.name,
                '${p.questionCount} ${p.questionCount == 1 ? 'question' : 'questions'}',
                if (p.allAnswered) 'Answered',
              ].join(' · '),
              logo: ClipOval(child: businessLogo(p.logo, size: 28)),
              onTap: () => widget.onGo(pollsOf(p.id)),
            ),
        ],
      ),
      IqWebCommandGroup(
        label: 'Activations',
        results: [
          for (final a in activations.take(5))
            IqWebCommandResult(
              title: a.title,
              meta: a.business,
              logo: ClipOval(child: businessLogo(activationLogo(a), size: 28)),
              onTap: () => widget.onGo('${Routes.activations}/${a.id}'),
            ),
        ],
      ),
    ];
    return IqWebCommandMenu(
      controller: _query,
      autofocus: true,
      groups: groups,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        final first = groups
            .expand((g) => g.results)
            .map((r) => r.onTap)
            .firstOrNull;
        first?.call();
      },
    );
  }
}
