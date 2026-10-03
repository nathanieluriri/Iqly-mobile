import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/what_you_like_screen.dart';

/// Date of birth on a day, month, year wheel, built like the first-run
/// sheets. Pops with the date. The row on the band reads Mob/Title on
/// Color/fg and the others Mob/Body on Color/fg2; a day the month lacks or
/// a date after today reads Color/fg3, and the wheel turns back to the
/// nearest real date once it stops.
class DateOfBirthSheet extends StatefulWidget {
  const DateOfBirthSheet({super.key, this.initial, required this.today});

  final DateTime? initial;
  final DateTime today;

  static const int firstYear = 1900;

  @override
  State<DateOfBirthSheet> createState() => _DateOfBirthSheetState();
}

class _DateOfBirthSheetState extends State<DateOfBirthSheet> {
  late final DateTime _today = DateUtils.dateOnly(widget.today);
  late final DateTime _start = _limit(
    widget.initial ??
        DateTime(widget.today.year - 20, widget.today.month, widget.today.day),
  );
  late int _day = _start.day;
  late int _month = _start.month;
  late int _year = _start.year;
  late final _days = FixedExtentScrollController(initialItem: _day - 1);
  late final _months = FixedExtentScrollController(initialItem: _month - 1);
  late final _years = FixedExtentScrollController(
    initialItem: _year - DateOfBirthSheet.firstYear,
  );
  int _turning = 0;

  DateTime _limit(DateTime date) {
    final day = DateUtils.dateOnly(date);
    return day.isAfter(_today) ? _today : day;
  }

  /// The date the wheels read, brought back inside the month and today.
  DateTime get _picked => _limit(
    DateTime(
      _year,
      _month,
      math.min(_day, DateUtils.getDaysInMonth(_year, _month)),
    ),
  );

  bool _dayValid(int day) =>
      day <= DateUtils.getDaysInMonth(_year, _month) &&
      !DateTime(_year, _month, day).isAfter(_today);

  bool _monthValid(int month) => !DateTime(_year, month).isAfter(_today);

  @override
  void dispose() {
    _days.dispose();
    _months.dispose();
    _years.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) _turning++;
    if (notification is ScrollEndNotification) {
      _turning = math.max(0, _turning - 1);
      // A wheel cannot start turning while it is still coming to rest.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _turning == 0) _settle();
      });
    }
    return false;
  }

  void _settle() {
    final target = _picked;
    if (target.day != _day) _days.turnTo(context, target.day - 1, 31);
    if (target.month != _month) _months.turnTo(context, target.month - 1, 12);
    if (target.year != _year) {
      _years.turnTo(context, target.year - DateOfBirthSheet.firstYear, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = DateFormat('MMMM');
    return _SheetLayout(
      title: 'Date of birth',
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _Wheel(
                  name: 'Day',
                  controller: _days,
                  count: 31,
                  looping: true,
                  selected: _day - 1,
                  offAxisFraction: -0.3,
                  first: true,
                  label: (i) => '${i + 1}',
                  valid: (i) => _dayValid(i + 1),
                  onSelected: (i) => setState(() => _day = i + 1),
                ),
              ),
              Expanded(
                flex: 4,
                child: _Wheel(
                  name: 'Month',
                  controller: _months,
                  count: 12,
                  looping: true,
                  selected: _month - 1,
                  label: (i) => months.format(DateTime(2000, i + 1)),
                  valid: (i) => _monthValid(i + 1),
                  onSelected: (i) => setState(() => _month = i + 1),
                ),
              ),
              Expanded(
                flex: 3,
                child: _Wheel(
                  name: 'Year',
                  controller: _years,
                  count: _today.year - DateOfBirthSheet.firstYear + 1,
                  selected: _year - DateOfBirthSheet.firstYear,
                  offAxisFraction: 0.3,
                  last: true,
                  label: (i) => '${DateOfBirthSheet.firstYear + i}',
                  valid: (_) => true,
                  onSelected: (i) =>
                      setState(() => _year = DateOfBirthSheet.firstYear + i),
                ),
              ),
            ],
          ),
        ),
      ),
      action: IqButton(
        label: 'Use this',
        showIcon: false,
        width: double.infinity,
        onTap: () => Navigator.of(context).pop(_picked),
      ),
    );
  }
}

extension on FixedExtentScrollController {
  /// Turns to [item], by the shortest way round when the wheel has [loop]
  /// rows and loops; at once under reduced motion.
  void turnTo(BuildContext context, int item, int? loop) {
    var target = item;
    if (loop != null) {
      final now = selectedItem;
      target = now - now % loop + item;
      if (target - now > loop / 2) target -= loop;
      if (now - target > loop / 2) target += loop;
    }
    final duration = motion(context, IqDurations.swap);
    if (duration == Duration.zero) {
      jumpToItem(target);
    } else {
      animateToItem(target, duration: duration, curve: IqCurves.easeInOut);
    }
  }
}

/// One wheel of the date: 44 pt rows on the brand-soft band, read out as an
/// adjustable value. A tap on a row turns to it.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.name,
    required this.controller,
    required this.count,
    required this.selected,
    required this.label,
    required this.valid,
    required this.onSelected,
    this.looping = false,
    this.offAxisFraction = 0,
    this.first = false,
    this.last = false,
  });

  static const double _row = 44;

  final String name;
  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int index) label;
  final bool Function(int index) valid;
  final ValueChanged<int> onSelected;
  final bool looping;
  final double offAxisFraction;
  final bool first;
  final bool last;

  int? get _loop => looping ? count : null;

  Widget _item(BuildContext context, int index) {
    final Color ink;
    final TextStyle style;
    if (index == selected) {
      style = IqText.title;
      ink = valid(index) ? IqColors.fg : IqColors.fg3;
    } else {
      style = IqText.body;
      ink = valid(index) ? IqColors.fg2 : IqColors.fg3;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => controller.turnTo(context, index, _loop),
      child: Center(
        child: Text(
          label(index),
          maxLines: 1,
          softWrap: false,
          style: style.copyWith(color: ink),
        ),
      ),
    );
  }

  void _select(int index) {
    if (defaultTargetPlatform == TargetPlatform.iOS) IqHaptics.select.play();
    onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final before = looping ? (selected - 1) % count : selected - 1;
    final after = looping ? (selected + 1) % count : selected + 1;
    return Semantics(
      label: name,
      value: label(selected),
      increasedValue: after < count ? label(after) : null,
      decreasedValue: before >= 0 ? label(before) : null,
      onIncrease: after < count
          ? () => controller.turnTo(context, after, _loop)
          : null,
      onDecrease: before >= 0
          ? () => controller.turnTo(context, before, _loop)
          : null,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                height: _row,
                child: CupertinoPickerDefaultSelectionOverlay(
                  background: IqColors.brandSoft,
                  capStartEdge: first,
                  capEndEdge: last,
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: _row,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.07,
              squeeze: 1.25,
              offAxisFraction: offAxisFraction,
              onSelectedItemChanged: _select,
              childDelegate: looping
                  ? ListWheelChildLoopingListDelegate(
                      children: [
                        for (var i = 0; i < count; i++) _item(context, i),
                      ],
                    )
                  : ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: _item,
                    ),
            ),
          ],
        ),
      ),
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
      action: IqButton(
        label: 'Use this',
        showIcon: false,
        width: double.infinity,
        disabled: _picked.length < OnboardingDraft.minInterests,
        onTap: () => Navigator.of(context).pop(_picked),
      ),
    );
  }
}

/// The picker sheets' layout. The foot is the University sheet's (188:8340):
/// the primary, then the ghost's 52 pt slot, so "Use this" sits at the same
/// height on every picker sheet; these two have no second action.
class _SheetLayout extends StatelessWidget {
  const _SheetLayout({
    required this.title,
    required this.body,
    required this.action,
  });

  final String title;
  final Widget body;
  final Widget action;

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
              children: [
                action,
                const SizedBox(height: IqSpace.s2 + IqButton.height),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
