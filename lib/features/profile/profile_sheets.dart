import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/what_you_like_screen.dart';
import 'profile_motion.dart' as motion;

/// Date of birth on a day, month, year wheel, built like the first-run
/// sheets. Pops with the date.
class DateOfBirthSheet extends StatefulWidget {
  const DateOfBirthSheet({super.key, this.initial, required this.today});

  final DateTime? initial;
  final DateTime today;

  @override
  State<DateOfBirthSheet> createState() => _DateOfBirthSheetState();
}

class _DateOfBirthSheetState extends State<DateOfBirthSheet> {
  late DateTime _date =
      widget.initial ??
      DateTime(widget.today.year - 20, widget.today.month, widget.today.day);

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(widget.today);
    return _SheetLayout(
      title: 'Date of birth',
      body: CupertinoTheme(
        data: CupertinoThemeData(
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: IqText.title.copyWith(color: IqColors.fg),
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          dateOrder: DatePickerDateOrder.dmy,
          initialDateTime: _date.isAfter(today) ? today : _date,
          minimumYear: 1900,
          maximumDate: today,
          itemExtent: 44,
          selectionOverlayBuilder:
              (context, {required columnCount, required selectedIndex}) =>
                  CupertinoPickerDefaultSelectionOverlay(
                    background: IqColors.brandSoft,
                    capStartEdge: selectedIndex == 0,
                    capEndEdge: selectedIndex == columnCount - 1,
                  ),
          onDateTimeChanged: (date) => _date = date,
        ),
      ),
      actions: [
        IqButton(
          label: 'Use this',
          showIcon: false,
          width: double.infinity,
          onTap: () => Navigator.of(context).pop(DateUtils.dateOnly(_date)),
        ),
      ],
    );
  }
}

/// The first-run interest chips in a sheet. "Use this" stays off under two
/// picks, as Finish does in first run. Pops with the values.
class InterestsSheet extends StatefulWidget {
  const InterestsSheet({super.key, required this.selected});

  final List<String> selected;

  @override
  State<InterestsSheet> createState() => _InterestsSheetState();
}

class _InterestsSheetState extends State<InterestsSheet> {
  late final _picked = [...widget.selected];

  void _toggle(String value) {
    motion.selectHaptic();
    setState(
      () =>
          _picked.contains(value) ? _picked.remove(value) : _picked.add(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetLayout(
      title: 'Interests',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          IqSpace.s4,
          IqSpace.s1,
          IqSpace.s4,
          IqSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick at least ${OnboardingDraft.minInterests}',
              style: IqText.body.copyWith(color: IqColors.fg2),
            ),
            const SizedBox(height: IqSpace.s5),
            InterestChips(selected: _picked, onToggle: _toggle),
          ],
        ),
      ),
      actions: [
        IqButton(
          label: 'Use this',
          showIcon: false,
          width: double.infinity,
          disabled: _picked.length < OnboardingDraft.minInterests,
          onTap: () => Navigator.of(context).pop(_picked),
        ),
      ],
    );
  }
}

class _SheetLayout extends StatelessWidget {
  const _SheetLayout({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: title,
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(child: body),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: IqSpace.s3),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions,
            ),
          ),
        ),
      ],
    );
  }
}
