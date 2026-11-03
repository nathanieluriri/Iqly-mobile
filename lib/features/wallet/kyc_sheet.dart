import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../data/kyc_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/segmented.dart';
import '../../ui/spinner.dart';
import '../../ui/top_bar.dart';
import 'wallet_sheet.dart';
import 'withdraw_sheet.dart';

/// The withdraw route. A live wallet that still needs a name match shows the
/// NIN or BVN fields here, then [WithdrawSheet]. No check, an existing match,
/// or a wallet that is not configured opens [WithdrawSheet] at once.
class WithdrawEntry extends ConsumerStatefulWidget {
  const WithdrawEntry({super.key, this.amountKobo, this.account});

  final int? amountKobo;
  final String? account;

  @override
  ConsumerState<WithdrawEntry> createState() => _WithdrawEntryState();
}

enum _Step { checking, failed, form, withdraw }

class _WithdrawEntryState extends ConsumerState<WithdrawEntry> {
  final _number = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  var _step = _Step.checking;
  var _method = KycMethod.nin;
  var _busy = false;
  DateTime? _dob;
  String? _banner;
  String? _numberError;
  String? _firstError;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = ref.read(kycServiceProvider);
    if (service == null) {
      setState(() => _step = _Step.withdraw);
      return;
    }
    setState(() {
      _step = _Step.checking;
      _banner = null;
    });
    try {
      final status = await service.status();
      if (!mounted) return;
      setState(() => _step = status.needsCheck ? _Step.form : _Step.withdraw);
    } on KycRefused catch (refused) {
      if (!mounted) return;
      if (refused.problem == KycProblem.notConfigured) {
        setState(() => _step = _Step.withdraw);
        return;
      }
      setState(() {
        _step = _Step.failed;
        _banner = kycError(refused);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _step = _Step.failed;
        _banner = 'Couldn’t check your details. Try again.';
      });
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final number = _number.text.trim();
    final first = _first.text.trim();
    final last = _last.text.trim();
    final numberError = RegExp(r'^\d{11}$').hasMatch(number)
        ? null
        : 'Enter the 11 digit NIN or BVN.';
    final firstError = first.length >= 2 ? null : 'Enter your first name.';
    final lastError = last.length >= 2 ? null : 'Enter your last name.';
    setState(() {
      _numberError = numberError;
      _firstError = firstError;
      _lastError = lastError;
      _banner = null;
    });
    if (numberError != null || firstError != null || lastError != null) return;
    final service = ref.read(kycServiceProvider);
    if (service == null) {
      setState(() => _step = _Step.withdraw);
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await service.verify(
        KycCheck(
          method: _method,
          number: number,
          firstName: first,
          lastName: last,
          dob: _dob == null ? null : _iso(_dob!),
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (status.verified) {
          _step = _Step.withdraw;
        } else {
          _banner =
              'That name does not match this ID. Check the name and the number.';
        }
      });
    } on KycRefused catch (refused) {
      if (!mounted) return;
      if (refused.problem == KycProblem.notConfigured) {
        setState(() {
          _busy = false;
          _step = _Step.withdraw;
        });
        return;
      }
      setState(() {
        _busy = false;
        _banner = kycError(refused);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = 'Couldn’t check that ID. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.withdraw) {
      return WithdrawSheet(
        amountKobo: widget.amountKobo,
        account: widget.account,
      );
    }
    if (_step == _Step.form) return _form();
    final failed = _step == _Step.failed;
    return WalletSheet(
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: 'Confirm your name',
          onClose: () => context.pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            IqSpace.s3,
            IqSpace.s4,
            IqSpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failed && _banner != null)
                IqBanner(
                  kind: IqBannerKind.error,
                  title: _banner,
                  action: 'Try again',
                  onAction: _load,
                )
              else if (_step == _Step.checking) ...[
                const Center(child: IqSpinner(color: IqColors.brand, size: 24)),
                const SizedBox(height: IqSpace.s3),
                Text(
                  'Checking your details.',
                  textAlign: TextAlign.center,
                  style: IqText.body.copyWith(color: IqColors.fg2),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _form() {
    final id = _method == KycMethod.nin ? 'NIN' : 'BVN';
    final tablet = Layout.isTablet(context);
    final fieldList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Before your first withdrawal, we match your name to your '
          'NIN or BVN.',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        const SizedBox(height: IqSpace.s3),
        IqSegmented(
          option1: 'NIN',
          option2: 'BVN',
          option3: null,
          selected: _method == KycMethod.nin
              ? IqSegmentedSelected.first
              : IqSegmentedSelected.second,
          onChanged: (selected) => setState(() {
            _method = selected == IqSegmentedSelected.first
                ? KycMethod.nin
                : KycMethod.bvn;
          }),
        ),
        const SizedBox(height: IqSpace.s3),
        IqField(
          label: id,
          value: '12345678901',
          controller: _number,
          state: _numberError == null ? null : IqFieldState.error,
          help: _numberError ?? '11 digits.',
          showNote: false,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: IqSpace.s2),
        IqField(
          label: 'First name',
          value: 'Adaeze',
          controller: _first,
          state: _firstError == null ? null : IqFieldState.error,
          help: _firstError ?? '',
          showNote: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: IqSpace.s2),
        IqField(
          label: 'Last name',
          value: 'Okafor',
          controller: _last,
          state: _lastError == null ? null : IqFieldState.error,
          help: _lastError ?? '',
          showNote: false,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.familyName],
          keyboardType: TextInputType.name,
          onSubmitted: (_) => _confirm(),
        ),
        const SizedBox(height: IqSpace.s2),
        IqField(
          kind: IqFieldKind.picker,
          pickerLabel: 'Date of birth',
          pickerValue: _dob == null ? '' : _iso(_dob!),
          pickerPlaceholder: 'Optional',
          state: _dob == null ? IqFieldState.empty : IqFieldState.valid,
          help: 'Optional.',
          showNote: false,
          showStatus: false,
          onTap: _pickDob,
        ),
      ],
    );
    // Tablet WalletSheet already scrolls. A nested scroll view has no height.
    final fields = tablet
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s4,
              vertical: IqSpace.s3,
            ),
            child: fieldList,
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s4,
              vertical: IqSpace.s3,
            ),
            child: fieldList,
          );
    return WalletSheet(
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: 'Confirm your name',
          onClose: () => context.pop(),
        ),
        if (_banner != null)
          Padding(
            padding: const EdgeInsets.only(
              left: IqSpace.s4,
              top: IqSpace.s3,
              right: IqSpace.s4,
            ),
            child: IqBanner(
              kind: IqBannerKind.error,
              title: _banner,
              showAction: false,
            ),
          ),
        if (tablet) fields else Flexible(child: fields),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s4,
            vertical: IqSpace.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IqButton(
                label: 'Check and continue',
                showIcon: false,
                width: double.infinity,
                loading: _busy,
                onTap: _confirm,
              ),
              const SizedBox(height: IqSpace.s3),
              Text(
                'We keep the last 4 digits, not the full number.',
                textAlign: TextAlign.center,
                style: IqText.small.copyWith(color: IqColors.fg3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
