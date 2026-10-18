import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../data/app_config.dart';
import '../../data/onboarding_service.dart';
import '../../data/phone_service.dart';
import '../../data/profile_service.dart';
import '../../data/reference_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/chip.dart';
import '../../ui/field.dart';
import '../../ui/option_row.dart';
import '../more/more_widgets.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/onboarding_sheets.dart';
import '../onboarding/what_you_like_screen.dart';
import '../onboarding/your_work_screen.dart';
import 'profile_sheets.dart';
import 'profile_state.dart';
import 'your_details_screen.dart';

/// The B7 Edit pages (429:18775 phone, 429:18828 date of birth, 429:18881
/// state, 484:22641 university, 429:18966 interests, 484:22898 occupation,
/// 484:22728 city, 484:22815 education): one value, Save in the action bar
/// (designer answer 40). Back leaves without saving. A save the account
/// refuses keeps the page and says so on the error banner.
///
/// Figma over its own frames: Edit · City selects Lekki and Edit · Interests
/// Technology and Business while Your details reads Ikeja and Marketing &
/// advertising · Finance & fintech; the pages open on the account's values.
class EditDetailScreen extends StatelessWidget {
  const EditDetailScreen({super.key, required this.field});

  final DetailField field;

  @override
  Widget build(BuildContext context) => switch (field) {
    DetailField.phone => const _PhoneEdit(),
    DetailField.dateOfBirth => const _DateOfBirthEdit(),
    DetailField.interests => const _InterestsEdit(),
    DetailField.occupation => const _OccupationEdit(),
    DetailField.state ||
    DetailField.university ||
    DetailField.city ||
    DetailField.education => _OptionEdit(field: field),
  };
}

/// The Edit page frame: [body] over the Save bar. [onSave] runs with Save
/// loading; when it throws, the error banner shows and the page stays. A
/// live launch that pauses the profile refuses the save without trying, so
/// the banner keeps its first sentence only (no frame for it).
class _EditPage extends StatefulWidget {
  const _EditPage({
    required this.title,
    required this.body,
    required this.onSave,
    this.canSave = true,
  });

  final String title;
  final Widget body;
  final Future<bool> Function() onSave;
  final bool canSave;

  static const failedText = 'Not saved. Check your connection.';
  static const pausedText = 'Not saved.';

  @override
  State<_EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<_EditPage> {
  bool _saving = false;
  bool _failed = false;
  bool _paused = false;

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _failed = false;
    });
    bool done;
    try {
      done = await widget.onSave();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
        _paused = error is FeaturePaused;
      });
      errorHaptic();
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (done) goBack(context);
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: IqBanner(
              kind: IqBannerKind.error,
              title: _paused ? _EditPage.pausedText : _EditPage.failedText,
              showAction: false,
              visible: _failed,
              margin: const EdgeInsets.only(bottom: IqSpace.s3),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              child: widget.body,
            ),
          ),
        ],
      ),
      actions: [
        IqButton(
          label: 'Save',
          showIcon: false,
          width: double.infinity,
          disabled: !widget.canSave,
          loading: _saving,
          onTap: _save,
        ),
      ],
    );
  }
}

class _PhoneEdit extends ConsumerStatefulWidget {
  const _PhoneEdit();

  @override
  ConsumerState<_PhoneEdit> createState() => _PhoneEditState();
}

class _PhoneEditState extends ConsumerState<_PhoneEdit> {
  final _phone = TextEditingController();
  String _saved = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() {
      if (_error != null) _error = null;
      setState(() {});
    });
    ref.listenManual(accountDetailsProvider, (previous, next) {
      final phone = next.value?.phone;
      if (previous?.value == null && phone != null) {
        _saved = phone;
        _phone.text = phone;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _complete =>
      _phone.text.replaceAll(RegExp(r'\D'), '').length >= 13 ||
      _phone.text.replaceAll(RegExp(r'\D'), '').length == 11;

  /// A new number is confirmed with the code first; the same number saves
  /// nothing. While the API sends the codes (contract 13.2) it checks the
  /// code and saves the number itself, and a number not yet confirmed can
  /// be confirmed from here; an API without SMS saves it as typed.
  Future<bool> _save() async {
    final typed = _phone.text.trim();
    final phones = ref.read(phoneServiceProvider);
    final verified =
        ref.read(accountDetailsProvider).value?.phoneVerified ?? false;
    if (typed == _saved && (phones == null || verified)) return true;
    if (phones == null) {
      final confirmed = await context.push<bool>(
        Routes.phoneCode,
        extra: typed,
      );
      if (confirmed != true) return false;
      await saveProfile(ref, details: (d) => d.copyWith(phone: typed));
      return true;
    }
    final same = typed == _saved;
    final PhoneCodeSent sent;
    try {
      sent = await phones.sendCode(same ? null : typed);
    } on PhoneRefused catch (refused) {
      if (!mounted) return false;
      switch (refused.problem) {
        case PhoneProblem.notConfigured:
          if (!same) {
            await saveProfile(ref, details: (d) => d.copyWith(phone: typed));
          }
          return true;
        case PhoneProblem.alreadyVerified:
          _confirmed(_saved);
          return true;
        case PhoneProblem.offline:
          rethrow;
        case _:
          setState(() => _error = phoneSendError(refused));
          errorHaptic();
          return false;
      }
    }
    if (!mounted) return false;
    return _code(sent.to, sent.resendAt);
  }

  Future<bool> _code(String to, DateTime? resendAt) async {
    final status = await context.push<PhoneStatus>(
      Routes.phoneCode,
      extra: PhoneCodeArgs(to, resendAt),
    );
    if (status == null) return false;
    _confirmed(status.phone ?? to);
    return true;
  }

  void _confirmed(String phone) {
    final details = ref.read(accountDetailsProvider).value;
    if (details == null) return;
    _saved = phone;
    ref
        .read(accountDetailsProvider.notifier)
        .edit(details.copyWith(phone: phone, phoneVerified: true));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return _EditPage(
      title: 'Phone number',
      canSave: _complete,
      onSave: _save,
      body: ListView(
        children: [
          IqField(
            label: 'Phone number',
            value: '+234 801 234 5678',
            controller: _phone,
            state: error != null
                ? IqFieldState.error
                : _complete
                ? IqFieldState.valid
                : null,
            help: error ?? '',
            note: 'We send a code to confirm a new number.',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'Banks and businesses never see this. It is only for sign-in codes '
            'and payout alerts.',
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }
}

/// Why a code did not go to the number.
String phoneSendError(PhoneRefused refused) => switch (refused.problem) {
  PhoneProblem.invalid => 'Enter a Nigerian mobile number.',
  PhoneProblem.missing => 'Enter your phone number.',
  PhoneProblem.rateLimited =>
    'Too many codes. Try again in ${_waitText(refused.retryAfter)}.',
  PhoneProblem.sendFailed => 'Couldn’t send the code. Try again.',
  PhoneProblem.offline => 'No connection. Try again.',
  _ => 'Couldn’t send the code. Try again.',
};

String _waitText(Duration? wait) {
  final seconds = (wait ?? ProfileService.codeResendAfter).inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// The code page in a launch where the API sends the codes: the number the
/// code went to and when another may go.
class PhoneCodeArgs {
  const PhoneCodeArgs(this.to, this.resendAt);

  final String to;
  final DateTime? resendAt;
}

/// B7 · Edit · Phone number · code (484:22583), "Confirm your number": the
/// 6-digit code sent by SMS to [phone]. Confirm pops true. While the API
/// sends the codes it checks the code, pops the number's status, counts
/// the resend down from the API's answer and says what each refusal means.
class PhoneCodeScreen extends ConsumerStatefulWidget {
  const PhoneCodeScreen({super.key, required this.phone, this.resendAt});

  final String phone;
  final DateTime? resendAt;

  static const resendAfter = ProfileService.codeResendAfter;

  @override
  ConsumerState<PhoneCodeScreen> createState() => _PhoneCodeScreenState();
}

class _PhoneCodeScreenState extends ConsumerState<PhoneCodeScreen> {
  final _code = TextEditingController();
  Timer? _tick;
  Duration _left = PhoneCodeScreen.resendAfter;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() {
      if (_error != null) _error = null;
      setState(() {});
    });
    _start(widget.resendAt?.difference(ref.read(clockProvider)()));
  }

  void _start([Duration? wait]) {
    _tick?.cancel();
    final left = wait ?? _resendAfter;
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (_left <= Duration.zero) return;
    _tick = Timer.periodic(ProfileService.countdownStep, (timer) {
      if (!mounted) return;
      setState(() => _left -= ProfileService.countdownStep);
      if (_left <= Duration.zero) timer.cancel();
    });
  }

  Duration get _resendAfter => ref.read(phoneServiceProvider) == null
      ? PhoneCodeScreen.resendAfter
      : Duration(seconds: ref.read(appConfigProvider).phoneResendAfterSeconds);

  Future<void> _resend() async {
    final phones = ref.read(phoneServiceProvider);
    if (phones == null) return _start();
    try {
      final sent = await phones.sendCode(widget.phone);
      if (!mounted) return;
      final at = sent.resendAt;
      _start(at?.difference(ref.read(clockProvider)()));
    } on PhoneRefused catch (refused) {
      if (!mounted) return;
      if (refused.problem == PhoneProblem.rateLimited) {
        _start(refused.retryAfter);
      } else {
        setState(() => _error = phoneSendError(refused));
        errorHaptic();
      }
    }
  }

  Future<void> _confirm() async {
    final phones = ref.read(phoneServiceProvider);
    if (phones == null) return context.pop(true);
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final status = await phones.verify(_code.text.replaceAll(' ', ''));
      if (mounted) context.pop(status);
    } on PhoneRefused catch (refused) {
      if (!mounted) return;
      final left = refused.attemptsLeft;
      setState(() {
        _checking = false;
        _error = switch (refused.problem) {
          PhoneProblem.codeInvalid =>
            left == null
                ? 'That code isn’t right.'
                : 'That code isn’t right. $left '
                      '${left == 1 ? 'try' : 'tries'} left.',
          PhoneProblem.codeExpired =>
            'That code has expired. Resend a new one.',
          PhoneProblem.rateLimited =>
            'Too many tries. Try again in ${_waitText(refused.retryAfter)}.',
          PhoneProblem.offline => 'No connection. Try again.',
          _ => 'Couldn’t confirm the number. Try again.',
        };
      });
      errorHaptic();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  int get _digits => _code.text.replaceAll(' ', '').length;

  @override
  Widget build(BuildContext context) {
    final seconds = _left.inSeconds;
    final wait =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final waiting = _left > Duration.zero;
    final error = _error;
    return SubPage(
      title: 'Confirm your number',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          IqField(
            label: '6-digit code',
            value: '',
            controller: _code,
            autofocus: true,
            state: error == null ? null : IqFieldState.error,
            help: error ?? '',
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
              const _CodeGroups(),
            ],
          ),
          const SizedBox(height: IqSpace.s2),
          GestureDetector(
            onTap: waiting ? null : _resend,
            child: Text(
              waiting
                  ? 'Didn’t get it? Resend in $wait, or go back and check '
                        'the number.'
                  : 'Didn’t get it? Resend the code, or go back and check the '
                        'number.',
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ),
        ],
      ),
      actions: [
        IqButton(
          label: 'Confirm',
          showIcon: false,
          width: double.infinity,
          disabled: _digits < 6,
          loading: _checking,
          onTap: _confirm,
        ),
      ],
    );
  }
}

/// "482 152": the code in two groups of three.
class _CodeGroups extends TextInputFormatter {
  const _CodeGroups();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final text = digits.length > 3
        ? '${digits.substring(0, 3)} ${digits.substring(3)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _DateOfBirthEdit extends ConsumerStatefulWidget {
  const _DateOfBirthEdit();

  @override
  ConsumerState<_DateOfBirthEdit> createState() => _DateOfBirthEditState();
}

class _DateOfBirthEditState extends ConsumerState<_DateOfBirthEdit> {
  DateTime? _picked;

  static const adultAge = 18;

  bool _adult(DateTime born, DateTime today) {
    final eighteenth = DateTime(born.year + adultAge, born.month, born.day);
    return !eighteenth.isAfter(today);
  }

  Future<void> _pick(DateTime? current) async {
    final today = ref.read(clockProvider)();
    final picked = await showOnboardingSheet<DateTime>(
      context,
      (context) => DateOfBirthSheet(initial: current, today: today),
    );
    if (picked != null && mounted) setState(() => _picked = picked);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(accountDetailsProvider).value?.dateOfBirth;
    final date = _picked ?? saved;
    final today = ref.watch(clockProvider)();
    final adult = date == null || _adult(date, today);
    return _EditPage(
      title: 'Date of birth',
      canSave: date != null && adult,
      onSave: () async {
        final picked = _picked;
        if (picked != null) {
          await saveProfile(
            ref,
            details: (d) => d.copyWith(dateOfBirth: picked),
          );
        }
        return true;
      },
      body: ListView(
        children: [
          IqField(
            kind: IqFieldKind.picker,
            state: date == null
                ? IqFieldState.empty
                : adult
                ? IqFieldState.valid
                : IqFieldState.error,
            pickerLabel: 'Date of birth',
            pickerValue: date == null ? '' : birthDate(date),
            pickerPlaceholder: 'Pick a date',
            help: 'You must be 18 or over to be paid.',
            onTap: () => _pick(date),
          ),
        ],
      ),
    );
  }
}

class _InterestsEdit extends ConsumerStatefulWidget {
  const _InterestsEdit();

  @override
  ConsumerState<_InterestsEdit> createState() => _InterestsEditState();
}

class _InterestsEditState extends ConsumerState<_InterestsEdit> {
  List<String>? _choice;
  String? _other;

  void _toggle(List<String> picked, String value) => setState(
    () => _choice = picked.contains(value)
        ? [...picked.where((v) => v != value)]
        : [...picked, value],
  );

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(profileAnswersProvider);
    final picked = _choice ?? answers.interests;
    final other = _other ?? answers.otherInterest;
    final next = answers.copyWith(interests: picked, otherInterest: other);
    return _EditPage(
      title: 'Interests',
      canSave: OnboardingDraft.interestsComplete(next),
      onSave: () async {
        await saveProfile(
          ref,
          answers: (a) => a.copyWith(interests: picked, otherInterest: other),
        );
        return true;
      },
      body: ListView(
        children: [
          Text(
            '$interestsCaption. They order your Discover feed.',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s2),
          InterestChips(
            selected: picked,
            onToggle: (value) => _toggle(picked, value),
          ),
          OtherInterestField(
            shown: picked.contains(OnboardingDraft.otherInterest),
            value: other,
            onChanged: (text) => setState(() => _other = text),
          ),
        ],
      ),
    );
  }
}

class _OccupationEdit extends ConsumerStatefulWidget {
  const _OccupationEdit();

  @override
  ConsumerState<_OccupationEdit> createState() => _OccupationEditState();
}

class _OccupationEditState extends ConsumerState<_OccupationEdit> {
  String? _choice;
  String? _sector;
  String? _otherSector;

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(profileAnswersProvider);
    final picked = _choice ?? answers.occupation;
    final sector = _sector ?? answers.sector;
    final otherSector = _otherSector ?? answers.otherSector;
    final asksWork =
        picked != null &&
        OnboardingFlow.current
            .path(answers.withOccupation(picked))
            .contains(OnboardingStep.yourWork);
    final wordsMissing =
        asksWork &&
        sector == OnboardingFlow.otherSector &&
        otherSector.trim().isEmpty;
    return _EditPage(
      title: 'Occupation',
      canSave: picked != null && !wordsMissing,
      onSave: () async {
        if (picked != null) {
          await saveProfile(
            ref,
            answers: (a) => OnboardingFlow.current.tidy(
              a
                  .withOccupation(picked)
                  .copyWith(sector: sector, otherSector: otherSector),
            ),
          );
        }
        return true;
      },
      body: ListView(
        children: [
          Text(
            'Pick one. It helps businesses read your answers in context.',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s2),
          Wrap(
            spacing: IqSpace.s2,
            runSpacing: IqSpace.s2,
            children: [
              for (final option in Reference.occupations)
                IqChip(
                  label: occupationLabels[option.value] ?? option.label,
                  state: option.value == picked
                      ? IqChipState.selected
                      : IqChipState.standard,
                  onChanged: (_) => setState(() => _choice = option.value),
                ),
            ],
          ),
          RevealSlot(
            shown: asksWork,
            child: Padding(
              padding: const EdgeInsets.only(top: IqSpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    workQuestion(picked),
                    style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                  ),
                  const SizedBox(height: IqSpace.s2),
                  SectorChips(
                    sector: sector,
                    otherSector: otherSector,
                    onSector: (value) => setState(() => _sector = value),
                    onOtherSector: (text) =>
                        setState(() => _otherSector = text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The states, universities and cities the Edit pages list before anything
/// is typed, in the frames' order (429:18881, 484:22641, 484:22728); typing
/// searches the full lists.
const popularStates = [
  'FCT - Abuja',
  'Enugu',
  'Kaduna',
  'Kano',
  'Lagos',
  'Oyo',
  'Rivers',
];

/// The frames' "Abuja (FCT)" for the shipped "FCT - Abuja".
String _stateLabel(String state) =>
    state == 'FCT - Abuja' ? 'Abuja (FCT)' : state;

const popularUniversities = [
  'University of Lagos',
  'Lagos State University',
  'Covenant University',
  'University of Ibadan',
  'Obafemi Awolowo University',
  'Ahmadu Bello University',
  'Caleb University',
];

const popularCities = {
  'Lagos': [
    'Ikeja',
    'Lekki',
    'Surulere',
    'Yaba',
    'Victoria Island',
    'Ikorodu',
    'Ajah',
  ],
};

class _OptionEdit extends ConsumerStatefulWidget {
  const _OptionEdit({required this.field});

  final DetailField field;

  @override
  ConsumerState<_OptionEdit> createState() => _OptionEditState();
}

class _OptionEditState extends ConsumerState<_OptionEdit> {
  final _search = TextEditingController();
  String? _choice;

  /// The person's pick, else the account's value.
  String? get _picked {
    final answers = ref.read(profileAnswersProvider);
    return _choice ??
        switch (widget.field) {
          DetailField.state => answers.state,
          DetailField.university => answers.university,
          DetailField.city => answers.city.isEmpty ? null : answers.city,
          _ => answers.education,
        };
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// (value, label) rows for what is typed.
  List<RefOption> _options(OnboardingProfile answers) {
    final query = _search.text.trim();
    List<RefOption> named(Iterable<String> names) => [
      for (final name in names)
        RefOption(
          name,
          widget.field == DetailField.state ? _stateLabel(name) : name,
        ),
    ];
    List<String> withPicked(List<String> names) {
      final picked = _picked;
      return picked == null || names.contains(picked)
          ? names
          : [picked, ...names];
    }

    return switch (widget.field) {
      DetailField.education => educationOptions,
      DetailField.state => named(
        query.isEmpty
            ? withPicked(popularStates)
            : Reference.states.where(
                (s) =>
                    _stateLabel(s).toLowerCase().contains(query.toLowerCase()),
              ),
      ),
      DetailField.university => named(
        query.isEmpty
            ? withPicked(popularUniversities)
            : searchUniversities(query, state: answers.state),
      ),
      _ => named(
        query.isEmpty
            ? withPicked(
                popularCities[answers.state] ??
                    searchCities(answers.state ?? '', '').take(7).toList(),
              )
            : searchCities(answers.state ?? '', query),
      ),
    };
  }

  OnboardingProfile _apply(OnboardingProfile now, String picked) =>
      switch (widget.field) {
        DetailField.state => _answers(
          now,
          state: picked,
          city: now.state == picked ? now.city : '',
        ),
        DetailField.university => _answers(now, university: picked),
        DetailField.city => _answers(now, city: picked),
        _ => now.withEducation(picked),
      };

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(profileAnswersProvider);
    final options = _options(answers);
    final searchLabel = switch (widget.field) {
      DetailField.state => 'Search states',
      DetailField.university => 'Search universities',
      DetailField.city => 'Search cities',
      _ => null,
    };
    return _EditPage(
      title: widget.field.label,
      canSave: _picked != null,
      onSave: () async {
        final picked = _picked;
        if (picked != null) {
          await saveProfile(ref, answers: (a) => _apply(a, picked));
        }
        return true;
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (searchLabel != null) ...[
            IqField(
              label: searchLabel,
              value: widget.field == DetailField.state ? '' : searchLabel,
              controller: _search,
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: IqSpace.s2),
          ],
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final option = options[i];
                return IqOptionRow(
                  label: option.label,
                  showNote: false,
                  state: option.value == _picked
                      ? IqOptionRowState.selected
                      : IqOptionRowState.standard,
                  onTap: () => setState(() => _choice = option.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

OnboardingProfile _answers(
  OnboardingProfile now, {
  String? occupation,
  String? state,
  String? city,
  String? education,
  String? university,
  List<String>? interests,
}) => now.copyWith(
  occupation: occupation,
  state: state,
  city: city,
  education: education,
  university: university,
  interests: interests,
);
