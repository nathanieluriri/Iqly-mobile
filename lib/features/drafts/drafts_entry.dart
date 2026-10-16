import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/navigation.dart';
import '../../router.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import 'drafts_state.dart';

/// The Drafts entry on the My submissions tabs (35:24): "Drafts · 2" and
/// who they are for, opening Drafts. Nothing shows without drafts.
class DraftsEntry extends ConsumerWidget {
  const DraftsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(draftItemsProvider).value ?? const <DraftItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    return IqListRow(
      label: draftsEntryLabel(items.length),
      description: draftsEntryDescription(items, now),
      icon: IqIcons.document,
      divider: false,
      onTap: () => context.open(Routes.drafts),
    );
  }
}
