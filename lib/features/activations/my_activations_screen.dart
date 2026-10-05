import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/activations_data.dart';
import '../../theme/theme.dart';
import '../../ui/chip.dart';
import '../../ui/illustration.dart';
import '../../ui/top_bar.dart';
import '../discover/discover_routes.dart' show leave;
import 'activations_routes.dart';
import 'activations_state.dart';
import 'activations_widgets.dart';

enum MyActivationsTab { active, done }

/// B8 · My activations (485:38281): your activations under Active and Done
/// chips (#16). Active holds the ones under way, closing soonest first, the
/// first as a Feature card; Done holds the paid ones and those that closed
/// before you finished, latest first. A chip switch keeps the chrome still
/// and crossfades the list over 200 ms (#28); a cut under reduced motion
/// keeps the 150 crossfade.
class MyActivationsScreen extends ConsumerStatefulWidget {
  const MyActivationsScreen({super.key, this.tab = MyActivationsTab.active});

  final MyActivationsTab tab;

  @override
  ConsumerState<MyActivationsScreen> createState() =>
      _MyActivationsScreenState();
}

class _MyActivationsScreenState extends ConsumerState<MyActivationsScreen> {
  late var _tab = widget.tab;

  void _pick(MyActivationsTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final all = ref.watch(activationsProvider).value ?? const <Activation>[];
    final active = [
      for (final a in all)
        if (a.inFlight && !a.closedAt(now)) a,
    ]..sort((a, b) => a.closesAt.compareTo(b.closesAt));
    final done = [
      for (final a in all)
        if (a.credited || (a.inFlight && a.closedAt(now))) a,
    ]..sort((a, b) => _doneAt(b).compareTo(_doneAt(a)));
    final shown = _tab == MyActivationsTab.active ? active : done;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: IqColors.bg,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IqTopBar(
                  variant: IqTopBarVariant.page,
                  title: 'My activations',
                  onBack: () => leave(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                  child: Row(
                    children: [
                      IqChip(
                        label: 'Active',
                        state: _tab == MyActivationsTab.active
                            ? IqChipState.selected
                            : IqChipState.standard,
                        onChanged: (_) => _pick(MyActivationsTab.active),
                      ),
                      const SizedBox(width: IqSpace.s2),
                      IqChip(
                        label: 'Done',
                        state: _tab == MyActivationsTab.done
                            ? IqChipState.selected
                            : IqChipState.standard,
                        onChanged: (_) => _pick(MyActivationsTab.done),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IqSpace.s3),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: motion(context, IqDurations.swap, fade: true),
                    switchInCurve: IqCurves.easeOut,
                    switchOutCurve: IqCurves.easeOut,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: shown.isEmpty
                          ? const _Nothing()
                          : _Cards(activations: shown, now: now),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DateTime _doneAt(Activation a) => a.progress?.paidAt ?? a.closesAt;
}

class _Cards extends StatelessWidget {
  const _Cards({required this.activations, required this.now});

  final List<Activation> activations;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(IqSpace.s4, 0, IqSpace.s4, IqSpace.s4),
      children: [
        for (final (i, a) in activations.indexed) ...[
          if (i > 0) const SizedBox(height: IqSpace.s3),
          ActivationCard(
            key: ValueKey(a.id),
            activation: a,
            now: now,
            feature: i == 0,
            onTap: () => context.push(activationPath(a.id)),
          ),
        ],
      ],
    );
  }
}

/// A tab with nothing on it: the Shrug and the product's "Nothing to show
/// yet" (no frame draws it).
class _Nothing extends StatelessWidget {
  const _Nothing();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: IqSpace.s4),
      child: ActivationsEmpty(
        figure: IqFigures.shrug,
        title: 'Nothing to show yet',
      ),
    );
  }
}
