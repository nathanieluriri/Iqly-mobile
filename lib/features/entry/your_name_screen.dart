import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Your name (227:10921).
///
/// Motion (MOTION-SPEC 6.4): the page pushes in from the landing as its
/// title, FIRST NAME and LAST NAME settle 40 apart; the first empty field
/// has focus from the first frame, so the keyboard stays up. On to Password
/// the step mark morphs (2 to 3, profile to lock) and the next button holds.
class YourNameScreen extends ConsumerStatefulWidget {
  const YourNameScreen({super.key});

  @override
  ConsumerState<YourNameScreen> createState() => _YourNameScreenState();
}

class _YourNameScreenState extends ConsumerState<YourNameScreen> {
  late final EntryInput _first;
  late final EntryInput _last;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(entryDraftProvider);
    _first = EntryInput(draft.firstName);
    _last = EntryInput(draft.lastName);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  bool get _ready => _first.text.isNotEmpty && _last.text.isNotEmpty;

  void _next() {
    if (!_ready) return;
    ref.read(entryDraftProvider.notifier).setName(_first.text, _last.text);
    context.push(Routes.createPassword);
  }

  Widget _field(EntryInput input, String label, {required bool last}) =>
      EntryField(
        input: input,
        label: label,
        valid: input.text.isNotEmpty,
        autofocus: last ? _first.text.isNotEmpty : _first.text.isEmpty,
        keyboardType: TextInputType.name,
        autofillHints: [
          last ? AutofillHints.familyName : AutofillHints.givenName,
        ],
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: (_) => last ? _next() : _last.focus.requestFocus(),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_first.changes, _last.changes]),
      builder: (context, _) => EntryScaffold(
        onBack: () => goBack(context, Routes.landing),
        settle: true,
        action: NextBar(enabled: _ready, onTap: _next),
        children: [
          const EntryStepMark(
            step: IqStepMarkStep.twoOfThree,
            icon: IqIcons.profile,
          ),
          const SizedBox(height: IqSpace.s4),
          const StaggerItem(index: 0, child: EntryTitle('What’s your name?')),
          const SizedBox(height: IqSpace.s4),
          StaggerItem(
            index: 1,
            child: _field(_first, 'First name', last: false),
          ),
          const SizedBox(height: IqSpace.s4),
          StaggerItem(index: 2, child: _field(_last, 'Last name', last: true)),
        ],
      ),
    );
  }
}
