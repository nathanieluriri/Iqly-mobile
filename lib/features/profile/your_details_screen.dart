import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/onboarding_service.dart';
import '../../data/profile_service.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/progress_thread.dart';
import '../../ui/top_bar.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/onboarding_sheets.dart';
import 'profile_sheets.dart';
import 'profile_state.dart';

enum _Field {
  dateOfBirth,
  gender,
  stateOfOrigin,
  state,
  city,
  university,
  interests,
}

enum _Closing { no, saving, saved }

/// B7 · Your details (40:141). The four Figma fields keep their order and
/// place; below them Profile keeps gender (brief: date of birth and gender
/// live on Profile) and the first-run answers through the first-run sheets,
/// so onboarding and Profile edit one profile.
///
/// Every edit autosaves: the thread turns Progress ("Saving…" and how many
/// of the eight fields hold a value, the line shortening to half) and grows
/// back to Ready when the account has it, its check popping in (spec 7.2,
/// 5.26). Save changes waits for the last save (spinner), lands a check
/// with the success haptic and returns to Profile. Fields settle in with
/// the push.
///
/// The frame draws the older Field set; here a filled field is Exp/Field
/// Valid without its status icon (hairline base) and an empty one is Empty.
/// Date of birth is a Picker over a day, month, year wheel where the frame
/// draws a Text field.
class YourDetailsScreen extends ConsumerStatefulWidget {
  const YourDetailsScreen({super.key});

  static const readyText = 'All saved · edit any field';
  static const savingText = 'Saving…';
  static const errorText = 'Not saved. Check your connection.';

  @override
  ConsumerState<YourDetailsScreen> createState() => _YourDetailsScreenState();
}

class _YourDetailsScreenState extends ConsumerState<YourDetailsScreen> {
  final _phone = TextEditingController();
  final _phoneFocus = FocusNode();
  _Field? _open;
  _Closing _closing = _Closing.no;
  int _failures = 0;
  Timer? _leaving;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
    ref.listenManual(accountDetailsProvider, (previous, next) {
      final details = next.value;
      if (previous?.value == null && details != null) {
        _phone.text = details.phone;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _leaving?.cancel();
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  DetailsSaveNotifier get _saver => ref.read(detailsSaveProvider.notifier);

  /// Edits apply to the loaded details only, so a failed load never sends
  /// blanks over the account's values.
  Future<void> _editDetails(
    AccountDetails Function(AccountDetails details) change, {
    Duration after = Duration.zero,
  }) async {
    final AccountDetails details;
    try {
      details = await ref.read(accountDetailsProvider.future);
    } on Exception {
      return;
    }
    ref.read(accountDetailsProvider.notifier).edit(change(details));
    _saver.schedule(after);
  }

  void _editAnswers(OnboardingProfile Function(OnboardingProfile now) change) {
    final now = ref.read(profileAnswersProvider);
    ref.read(onboardingDraftProvider.notifier).setProfile(change(now));
    _saver.schedule();
  }

  /// A new state keeps the city only if that state's list has it, as in
  /// first run.
  void _setState(String state) => _editAnswers(
    (now) => now.state == state
        ? now
        : _answers(now, state: state, city: listedCity(state, now.city) ?? ''),
  );

  Future<T?> _pick<T>(_Field field, WidgetBuilder sheet) async {
    // Unfocusing the field itself, not the page's scope, so the page does not
    // hand the keyboard back to it when the sheet closes.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _open = field);
    final picked = await showOnboardingSheet<T>(context, sheet);
    if (mounted) setState(() => _open = null);
    return picked;
  }

  Future<void> _pickDateOfBirth(AccountDetails? details) async {
    final today = ref.read(clockProvider)();
    final picked = await _pick<DateTime>(
      _Field.dateOfBirth,
      (context) =>
          DateOfBirthSheet(initial: details?.dateOfBirth, today: today),
    );
    if (picked != null) _editDetails((d) => d.copyWith(dateOfBirth: picked));
  }

  Future<void> _pickOption(
    _Field field,
    String title,
    List<RefOption> options,
    String? selected,
    void Function(String value) apply,
  ) async {
    final picked = await _pick<String>(
      field,
      (context) =>
          OptionSheet(title: title, options: options, selected: selected),
    );
    if (picked != null) apply(picked);
  }

  Future<void> _pickCity(OnboardingProfile answers) async {
    final picked = await _pick<String>(
      _Field.city,
      (context) => CityPickerFlow(
        state: answers.state,
        city: answers.city,
        onState: _setState,
      ),
    );
    if (picked != null) _editAnswers((now) => _answers(now, city: picked));
  }

  Future<void> _pickUniversity(OnboardingProfile answers) async {
    final picked = await _pick<String>(
      _Field.university,
      (context) =>
          UniversitySheet(selected: answers.university, state: answers.state),
    );
    if (picked != null) {
      _editAnswers((now) => _answers(now, university: picked));
    }
  }

  Future<void> _pickInterests(OnboardingProfile answers) async {
    final picked = await _pick<List<String>>(
      _Field.interests,
      (context) => InterestsSheet(selected: answers.interests),
    );
    if (picked != null) {
      _editAnswers((now) => _answers(now, interests: picked));
    }
  }

  Future<void> _saveChanges() async {
    if (_closing != _Closing.no) return;
    FocusScope.of(context).unfocus();
    setState(() => _closing = _Closing.saving);
    final saved = await _saver.save();
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _closing = _Closing.no;
        _failures++;
      });
      errorHaptic();
      return;
    }
    IqHaptics.success.play();
    setState(() => _closing = _Closing.saved);
    _leaving = Timer(motion(context, IqDurations.mark, fade: true), _leave);
  }

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.profile);
    }
  }

  IqFieldState _picker(_Field field, bool filled) => _open == field
      ? IqFieldState.active
      : filled
      ? IqFieldState.valid
      : IqFieldState.empty;

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(accountDetailsProvider).value;
    final answers = ref.watch(profileAnswersProvider);
    final save = ref.watch(detailsSaveProvider);
    final born = details?.dateOfBirth;
    final gender = optionLabel(Reference.genders, details?.gender);
    final origin = details?.stateOfOrigin;
    final city = answers.city.trim();
    final university = answers.university;
    final interests = interestsLine(answers.interests);
    final phoneFilled = _phone.text.trim().isNotEmpty;

    final fields = <Widget>[
      IqField(
        label: 'Phone number',
        value: '',
        controller: _phone,
        focusNode: _phoneFocus,
        state: _phoneFocus.hasFocus || !phoneFilled ? null : IqFieldState.valid,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        ],
        showStatus: false,
        showNote: false,
        onChanged: (value) => _editDetails(
          (d) => d.copyWith(phone: value.trim()),
          after: ProfileService.typingPause,
        ),
        onSubmitted: (_) => _saver.save(),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.dateOfBirth, born != null),
        pickerLabel: 'Date of birth',
        pickerValue: born == null ? '' : birthDate(born),
        pickerPlaceholder: 'Select…',
        showStatus: false,
        onTap: () => _pickDateOfBirth(details),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.stateOfOrigin, origin != null),
        pickerLabel: 'State of origin',
        pickerValue: origin ?? '',
        pickerPlaceholder: 'Select state',
        showStatus: false,
        onTap: () => _pickOption(
          _Field.stateOfOrigin,
          'State of origin',
          stateOptions,
          origin,
          (value) => _editDetails((d) => d.copyWith(stateOfOrigin: value)),
        ),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.interests, interests.isNotEmpty),
        pickerLabel: 'Interests',
        pickerValue: interests,
        pickerPlaceholder: 'Select…',
        showStatus: false,
        onTap: () => _pickInterests(answers),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.gender, gender != null),
        pickerLabel: 'Gender',
        pickerValue: gender ?? '',
        pickerPlaceholder: 'Select…',
        showStatus: false,
        onTap: () => _pickOption(
          _Field.gender,
          'Gender',
          Reference.genders,
          details?.gender,
          (value) => _editDetails((d) => d.copyWith(gender: value)),
        ),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.state, answers.state != null),
        pickerLabel: 'State of residence',
        pickerValue: answers.state ?? '',
        pickerPlaceholder: 'Select state',
        showStatus: false,
        onTap: () => _pickOption(
          _Field.state,
          'State of residence',
          stateOptions,
          answers.state,
          _setState,
        ),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.city, city.isNotEmpty),
        pickerLabel: 'City',
        pickerValue: city,
        pickerPlaceholder: 'Select city',
        showStatus: false,
        onTap: () => _pickCity(answers),
      ),
      IqField(
        kind: IqFieldKind.picker,
        state: _picker(_Field.university, university != null),
        pickerLabel: 'University',
        pickerValue: university ?? '',
        pickerPlaceholder: 'Search universities',
        showStatus: false,
        onTap: () => _pickUniversity(answers),
      ),
    ];
    final filled = [
      phoneFilled,
      born != null,
      origin != null,
      interests.isNotEmpty,
      gender != null,
      answers.state != null,
      city.isNotEmpty,
      university != null,
    ].where((value) => value).length;

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
                  title: 'Your details',
                  onBack: _leave,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s2,
                    IqSpace.s4,
                    IqSpace.s2,
                  ),
                  child: Shake(
                    trigger: _failures,
                    child: _SaveThread(
                      save: save,
                      count: '$filled of ${fields.length}',
                    ),
                  ),
                ),
                Expanded(
                  child: Stagger(
                    move: StaggerMove.settle,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        IqSpace.s4,
                        0,
                        IqSpace.s4,
                        IqSpace.s4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, field) in fields.indexed) ...[
                            if (i > 0) const SizedBox(height: IqSpace.s2),
                            StaggerItem(index: i, child: field),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IqSpace.s4,
                    IqSpace.s3,
                    IqSpace.s4,
                    IqSpace.s3,
                  ),
                  child: _SaveChangesButton(
                    closing: _closing,
                    onTap: _saveChanges,
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

OnboardingProfile _answers(
  OnboardingProfile now, {
  String? state,
  String? city,
  String? university,
  List<String>? interests,
}) => OnboardingProfile(
  occupation: now.occupation,
  state: state ?? now.state,
  city: city ?? now.city,
  education: now.education,
  university: university ?? now.university,
  interests: interests ?? now.interests,
);

/// The pinned Exp/ProgressThread: Ready ("All saved · edit any field"), an
/// edit on its way Progress with [count], a save the account refused Error.
class _SaveThread extends StatelessWidget {
  const _SaveThread({required this.save, required this.count});

  final DetailsSaveState save;
  final String count;

  @override
  Widget build(BuildContext context) {
    final state = switch (save.status) {
      DetailsSave.idle => IqProgressThreadState.ready,
      DetailsSave.failed => IqProgressThreadState.error,
      DetailsSave.pending ||
      DetailsSave.saving => IqProgressThreadState.progress,
    };
    return Semantics(
      liveRegion: true,
      child: IqProgressThread(
        state: state,
        status: YourDetailsScreen.savingText,
        count: count,
        readyText: YourDetailsScreen.readyText,
        errorText: YourDetailsScreen.errorText,
      ),
    );
  }
}

/// Save changes: the primary pill drops on press, turns to the spinner
/// while the last save lands, then a check pops in before Profile returns.
class _SaveChangesButton extends StatelessWidget {
  const _SaveChangesButton({required this.closing, required this.onTap});

  final _Closing closing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saved = closing == _Closing.saved;
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          excluding: saved,
          child: IqButton(
            label: saved ? '' : 'Save changes',
            showIcon: !saved,
            width: double.infinity,
            loading: closing == _Closing.saving,
            onTap: onTap,
          ),
        ),
        if (saved)
          IgnorePointer(
            child: Semantics(
              liveRegion: true,
              label: 'Saved',
              child: const _SavedCheck(
                child: IqIcon(
                  IqIcons.check,
                  size: 24,
                  color: IqColors.primaryFg,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Lands [child] like the autosave check (spec 5.10): .6 to 1 on the stamp
/// curve with the opacity in the first half, 200 ms; shown at once under
/// reduced motion.
class _SavedCheck extends StatefulWidget {
  const _SavedCheck({required this.child});

  final Widget child;

  @override
  State<_SavedCheck> createState() => _SavedCheckState();
}

class _SavedCheckState extends State<_SavedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: IqDurations.swap,
  );
  late final Animation<double> _scale = _land.drive(
    Tween<double>(
      begin: IqScale.pop,
      end: 1,
    ).chain(CurveTween(curve: IqCurves.stamp)),
  );
  late final Animation<double> _opacity = _land.drive(
    CurveTween(curve: const Interval(0, 0.5, curve: IqCurves.easeOut)),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _land.value = 1;
    } else {
      _land.forward();
    }
  }

  @override
  void dispose() {
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}
