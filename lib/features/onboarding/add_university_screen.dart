import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/top_bar.dart';
import 'onboarding_draft.dart';
import 'onboarding_layout.dart';

/// B11 · Add your university (480:20477), from "Add my university" in the
/// university search: one field, filled with what was typed there. "Add
/// it" makes the typed name the university (sent for review with the
/// profile, answer 11) and returns to Where you studied.
class AddUniversityScreen extends ConsumerStatefulWidget {
  const AddUniversityScreen({super.key, this.initialName = ''});

  final String initialName;

  @override
  ConsumerState<AddUniversityScreen> createState() =>
      _AddUniversityScreenState();
}

class _AddUniversityScreenState extends ConsumerState<AddUniversityScreen> {
  // The caret starts at the end so the autofocus shows no selection handle.
  late final _name = TextEditingController.fromValue(
    TextEditingValue(
      text: widget.initialName,
      selection: TextSelection.collapsed(offset: widget.initialName.length),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _typed => _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _add() {
    final name = _typed;
    if (name.isEmpty) return;
    ref.read(onboardingDraftProvider.notifier).setUniversity(name);
    FocusManager.instance.primaryFocus?.unfocus();
    leaveStep(context, Routes.onboardingWhereYouStudied);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                  title: 'Add your university',
                  onBack: () =>
                      leaveStep(context, Routes.onboardingWhereYouStudied),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IqField(
                          label: 'University name',
                          value: '',
                          controller: _name,
                          autofocus: true,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.done,
                          showStatus: false,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _add(),
                        ),
                        const SizedBox(height: IqSpace.s2),
                        Text(
                          'Pick it from the list if it is already there. '
                          'Your profile shows the name you typed until we '
                          'confirm it.',
                          style: IqText.small.copyWith(color: IqColors.fg2),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(IqSpace.s3)
                      .copyWith(left: IqSpace.s4, right: IqSpace.s4),
                  child: IqButton(
                    label: 'Add it',
                    showIcon: false,
                    width: double.infinity,
                    disabled: _typed.isEmpty,
                    onTap: _add,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
