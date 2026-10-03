import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/step_mark.dart';
import 'entry_state.dart';
import 'entry_widgets.dart';

/// B0 Your name (227:10921).
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_first.text.isEmpty ? _first : _last).focus.requestFocus();
    });
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

  IqField _field(EntryInput input, String label, {required bool last}) =>
      IqField(
        size: IqFieldSize.large,
        label: label,
        value: '',
        state: fieldStateFor(input, valid: input.text.isNotEmpty),
        showStatus: false,
        showNote: false,
        controller: input.controller,
        focusNode: input.focus,
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
        action: NextBar(enabled: _ready, onTap: _next),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: IqStepMark(
              step: IqStepMarkStep.twoOfThree,
              icon: IqIcons.profile,
            ),
          ),
          const SizedBox(height: IqSpace.s4),
          const EntryTitle('What’s your name?'),
          const SizedBox(height: IqSpace.s4),
          _field(_first, 'First name', last: false),
          const SizedBox(height: IqSpace.s4),
          _field(_last, 'Last name', last: true),
        ],
      ),
    );
  }
}
