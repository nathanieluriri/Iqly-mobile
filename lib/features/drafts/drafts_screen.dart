import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../core/transitions.dart';
import '../../data/drafts_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/draft_row.dart';
import '../../ui/sample_logo.dart';
import '../../ui/section_title.dart';
import '../../ui/top_bar.dart';
import '../submit/submit_parts.dart';
import 'draft_sheets.dart';
import 'drafts_state.dart';

/// B4 · My submissions · Drafts (481:23202), a sub page: the drafts on this
/// phone as Exp/DraftRow. Tap opens the draft actions (499:26919); long
/// press, or the Select link, starts selecting (499:27119) with Select all
/// or Deselect all and Discard N behind a confirm (499:27256). Back while
/// selecting leaves selecting; otherwise it returns to the opener.
class DraftsScreen extends ConsumerStatefulWidget {
  const DraftsScreen({super.key});

  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> {
  bool _selecting = false;
  final _selected = <String>{};

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.submissions, extra: NavDirection.back);
    }
  }

  void _back() {
    if (_selecting) {
      _stopSelecting();
    } else {
      _leave();
    }
  }

  void _select([String? first]) {
    IqHaptics.select.play();
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..addAll([?first]);
    });
  }

  void _stopSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Future<void> _open(DraftItem item) async {
    final now = ref.read(clockProvider)();
    final draft = item.draft;
    final keepWriting = await showDraftSheet(
      context,
      title: draft.title.isEmpty ? item.brief?.title ?? '' : draft.title,
      body: draftActionsBody(item, now),
      confirmLabel: 'Continue writing',
      cancelLabel: 'Discard draft',
    );
    if (!mounted || keepWriting == null) return;
    if (keepWriting) {
      context.push(Routes.submitTo(draft.briefId));
      return;
    }
    final discard = await showDiscardOneSheet(context);
    if (!mounted || discard != true) return;
    await ref.read(draftsProvider.notifier).discard([draft.briefId]);
  }

  Future<void> _discardSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final discard = count == 1
        ? await showDiscardOneSheet(context)
        : await showDiscardManySheet(context, count);
    if (!mounted || discard != true) return;
    await ref.read(draftsProvider.notifier).discard({..._selected});
    if (mounted) _stopSelecting();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(draftsProvider, (_, next) {
      if (!(next.value?.isEmpty ?? false)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _leave();
      });
    });
    final items = ref.watch(draftItemsProvider);
    final now = ref.watch(clockProvider)();
    final list = items.value ?? const <DraftItem>[];
    final all = list.isNotEmpty && _selected.length == list.length;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: IqColors.bg,
          body: SafeArea(
            child: CenteredContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IqTopBar(
                    variant: IqTopBarVariant.page,
                    title: 'Drafts',
                    onBack: _back,
                  ),
                  Expanded(
                    child: items.hasError && list.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(IqSpace.s4),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: IqBanner(
                                kind: IqBannerKind.error,
                                title: 'Couldn’t load. Check your connection.',
                                action: 'Try again',
                                onAction: () =>
                                    ref.invalidate(draftItemsProvider),
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              IqSpace.s4,
                              0,
                              IqSpace.s4,
                              IqSpace.s6,
                            ),
                            children: [
                              IqSectionTitle(
                                title: _selecting
                                    ? '${_selected.length} selected'
                                    : draftsCount(list.length),
                                link: !_selecting
                                    ? 'Select'
                                    : all
                                    ? 'Deselect all'
                                    : 'Select all',
                                onSeeAll: () {
                                  if (!_selecting) {
                                    _select();
                                  } else {
                                    setState(() {
                                      if (all) {
                                        _selected.clear();
                                      } else {
                                        _selected.addAll(
                                          list.map((i) => i.draft.briefId),
                                        );
                                      }
                                    });
                                  }
                                },
                              ),
                              for (final item in list) ...[
                                const SizedBox(height: IqSpace.s3),
                                _Row(
                                  key: ValueKey(item.draft.briefId),
                                  item: item,
                                  now: now,
                                  selecting: _selecting,
                                  selected: _selected.contains(
                                    item.draft.briefId,
                                  ),
                                  onTap: () => _selecting
                                      ? _toggle(item.draft.briefId)
                                      : _open(item),
                                  onLongPress: _selecting
                                      ? null
                                      : () => _select(item.draft.briefId),
                                ),
                              ],
                            ],
                          ),
                  ),
                  _SelectBar(
                    open: _selecting,
                    count: _selected.length,
                    onDiscard: _discardSelected,
                    onCancel: _stopSelecting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.item,
    required this.now,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final DraftItem item;
  final DateTime now;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final draft = item.draft;
    return IqDraftRow(
      title: draft.title.isEmpty ? item.brief?.title ?? '' : draft.title,
      meta: draftMeta(item, now),
      step2Done: draft.step >= DraftSteps.questions,
      step3Done: draft.step >= DraftSteps.ready,
      logo: IqSampleLogo(sampleBrandOf(item.brief), size: IqDraftRow.logoSize),
      mode: selecting ? IqDraftRowMode.selecting : IqDraftRowMode.standard,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// The selecting action bar (499:27119): Discard N drafts on the Danger
/// sticker and Cancel. It rises with selecting and drops when it ends.
class _SelectBar extends StatelessWidget {
  const _SelectBar({
    required this.open,
    required this.count,
    required this.onDiscard,
    required this.onCancel,
  });

  final bool open;
  final int count;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Collapse(
      open: open,
      child: ColoredBox(
        color: IqColors.bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s4,
            vertical: IqSpace.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IqButton(
                kind: IqButtonKind.danger,
                label: discardLabel(count),
                showIcon: false,
                width: double.infinity,
                disabled: count == 0,
                onTap: onDiscard,
              ),
              IqButton(
                kind: IqButtonKind.ghost,
                label: 'Cancel',
                width: double.infinity,
                onTap: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
