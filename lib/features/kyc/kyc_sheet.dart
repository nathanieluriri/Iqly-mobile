import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/live/live_account.dart' show meProvider;
import '../../data/kyc_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/brand_logo.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/segmented.dart';
import '../../ui/spinner.dart';
import '../../ui/top_bar.dart';
import '../wallet/wallet_sheet.dart';
import 'kyc_controller.dart';

class KycPicker {
  Future<KycEvidence?> document() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (file == null) return null;
    return KycEvidence(
      filename: file.name,
      bytes: await file.readAsBytes(),
      contentType: _contentType(file.name),
    );
  }

  Future<KycEvidence?> selfie() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo == null) return null;
    final bytes = await File(photo.path).readAsBytes();
    return KycEvidence(
      filename: 'selfie.jpg',
      bytes: bytes,
      contentType: 'image/jpeg',
    );
  }
}

String _contentType(String name) =>
    switch (name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'image/png',
    };

final kycPickerProvider = Provider<KycPicker>((ref) => KycPicker());

/// Reusable progressive identity, document and biometric flow.
class KycSheet extends ConsumerStatefulWidget {
  const KycSheet({
    super.key,
    this.initialStatus,
    this.onComplete,
    this.onClose,
  });

  final KycStatus? initialStatus;
  final ValueChanged<KycStatus>? onComplete;
  final VoidCallback? onClose;

  @override
  ConsumerState<KycSheet> createState() => _KycSheetState();
}

class _KycSheetState extends ConsumerState<KycSheet> {
  final _number = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  KycMethod _method = KycMethod.nin;
  var _identityStep = 'number';
  var _confirmedName = false;
  KycEvidence? _evidence;
  KycStatus? _status;
  KycRefused? _error;
  String? _numberError;
  String? _firstError;
  String? _lastError;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _method = _status?.ninOnly == true
        ? KycMethod.nin
        : _status?.method ?? KycMethod.nin;
  }

  @override
  void dispose() {
    _number.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  KycState? get _live =>
      widget.initialStatus == null ? ref.watch(kycControllerProvider) : null;

  KycStatus? get _current => _status ?? _live?.status;
  KycRefused? get _refused => _error ?? _live?.error;
  bool get _ninOnly => _current?.ninOnly ?? false;
  String get _methodLabel =>
      _ninOnly || _method == KycMethod.nin ? 'NIN' : 'BVN';

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _pick(KycCheckKind check) async {
    setState(() => _error = null);
    final picker = ref.read(kycPickerProvider);
    final file = check == KycCheckKind.document
        ? await picker.document()
        : await picker.selfie();
    if (file != null && mounted) setState(() => _evidence = file);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final status = _current;
    if (status == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      KycStatus? next;
      if (status.nextCheck == KycCheckKind.identity) {
        final number = _number.text.trim();
        final first = _first.text.trim();
        final last = _last.text.trim();
        if (_identityStep == 'number') {
          setState(() {
            _busy = false;
            _numberError = RegExp(r'^\d{11}$').hasMatch(number)
                ? null
                : 'Enter the 11 digit NIN.';
          });
          if (_numberError == null) {
            setState(() => _identityStep = 'name');
          }
          return;
        }
        setState(() {
          _numberError = RegExp(r'^\d{11}$').hasMatch(number)
              ? null
              : 'Enter the 11 digit NIN.';
          _firstError = first.length >= 2 ? null : 'Enter your first name.';
          _lastError = last.length >= 2 ? null : 'Enter your last name.';
        });
        if (_numberError != null ||
            _firstError != null ||
            _lastError != null ||
            !_confirmedName) {
          setState(() => _busy = false);
          return;
        }
        next = widget.initialStatus == null
            ? await ref
                  .read(kycControllerProvider.notifier)
                  .verify(
                    KycCheck(
                      method: _ninOnly ? KycMethod.nin : _method,
                      number: number,
                      firstName: first,
                      lastName: last,
                    ),
                  )
            : await ref
                  .read(kycServiceProvider)
                  .verify(
                    KycCheck(
                      method: _ninOnly ? KycMethod.nin : _method,
                      number: number,
                      firstName: first,
                      lastName: last,
                    ),
                  );
      } else if (status.nextCheck == KycCheckKind.bankMatch) {
        next = widget.initialStatus == null
            ? await ref.read(kycControllerProvider.notifier).refresh()
            : await ref.read(kycServiceProvider).status();
        next ??= status;
      } else {
        final file = _evidence;
        if (file == null) {
          setState(() => _busy = false);
          return;
        }
        next = widget.initialStatus == null
            ? await ref
                  .read(kycControllerProvider.notifier)
                  .upload(status.nextCheck, file)
            : await ref.read(kycServiceProvider).upload(status.nextCheck, file);
      }
      if (!mounted) return;
      if (next == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _status = next;
        _error = null;
        _evidence = null;
        _busy = false;
      });
      if (!next.needsCheck) widget.onComplete?.call(next);
    } on KycRefused catch (error) {
      if (mounted) setState(() => _error = error);
    } on Object {
      if (mounted) {
        setState(() => _error = const KycRefused(KycProblem.unavailable));
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (widget.initialStatus != null) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final status = await ref.read(kycServiceProvider).status();
        if (mounted) {
          setState(() {
            _status = status;
            _error = null;
          });
        }
      } on KycRefused catch (error) {
        if (mounted) setState(() => _error = error);
      } on Object {
        if (mounted) {
          setState(() => _error = const KycRefused(KycProblem.unavailable));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      final status = await ref.read(kycControllerProvider.notifier).refresh();
      if (status != null && mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(meProvider, (_, next) {
      final name = next.value?.name.trim() ?? '';
      if (name.isEmpty || _first.text.isNotEmpty || _last.text.isNotEmpty) {
        return;
      }
      final split = name.split(RegExp(r'\s+'));
      setState(() {
        _first.text = split.first;
        _last.text = split.skip(1).join(' ');
      });
    });
    final status = _current;
    final loading = widget.initialStatus == null && (_live?.loading ?? true);
    final refused = _refused;
    final notConfigured = refused?.problem == KycProblem.notConfigured;
    final fields = status == null
        ? _loading()
        : status.nextCheck == KycCheckKind.identity
        ? _identity(status)
        : _evidenceStep(status);
    return WalletSheet(
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: 'Verify your account',
          onClose: _close,
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(IqSpace.s6),
            child: Center(child: IqSpinner(color: IqColors.brand, size: 24)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              0,
              IqSpace.s4,
              IqSpace.s3,
            ),
            child: _brand(
              status: status,
              failed: refused != null,
              notConfigured: notConfigured,
            ),
          ),
          if (refused != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s4,
                0,
                IqSpace.s4,
                IqSpace.s3,
              ),
              child: IqBanner(
                kind: notConfigured ? IqBannerKind.urgent : IqBannerKind.error,
                title: kycError(refused),
                action: notConfigured ? 'Check again' : 'Try again',
                onAction: _refresh,
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              child: fields,
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.all(IqSpace.s4),
              child: IqButton(
                label: !status.needsCheck
                    ? 'Done'
                    : _waiting(status)
                    ? 'Refresh status'
                    : status.nextCheck == KycCheckKind.identity &&
                          _identityStep == 'name'
                    ? 'Verify identity'
                    : 'Continue',
                showIcon: false,
                width: double.infinity,
                loading: _busy,
                disabled:
                    status.nextCheck == KycCheckKind.identity &&
                    _identityStep == 'name' &&
                    (!_confirmedName ||
                        _first.text.trim().length < 2 ||
                        _last.text.trim().length < 2),
                onTap: !status.needsCheck
                    ? () => widget.onComplete?.call(status)
                    : _waiting(status)
                    ? _refresh
                    : _submit,
              ),
            ),
        ],
      ],
    );
  }

  bool _waiting(KycStatus status) =>
      status.inReview ||
      status.nextCheck == KycCheckKind.none ||
      status.checks[status.nextCheck] == KycCheckState.review ||
      status.checks[status.nextCheck] == KycCheckState.pending;

  Widget _brand({
    required KycStatus? status,
    required bool failed,
    required bool notConfigured,
  }) => Container(
    padding: const EdgeInsets.all(IqSpace.s4),
    decoration: BoxDecoration(
      color: notConfigured
          ? IqColors.warnSoft
          : failed
          ? IqColors.errSoft
          : IqColors.brandSoft,
      borderRadius: BorderRadius.circular(IqRadius.xl2),
    ),
    child: Row(
      children: [
        const IqBrandLogo(mark: IqBrandMark.logomark, width: 44, height: 44),
        const SizedBox(width: IqSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account verification',
                style: IqText.title.copyWith(color: IqColors.fg),
              ),
              const SizedBox(height: IqSpace.s1),
              Text(
                status == null
                    ? notConfigured
                          ? 'Verification isn’t set up yet.'
                          : 'Checking your details.'
                    : 'Tier ${status.tier} of ${status.requiredTier}. ${_copy(status.nextCheck)}',
                style: IqText.small.copyWith(color: IqColors.fg2),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _illustration(KycStatus status) {
    final complete = status.required && status.canWithdraw;
    final identity =
        status.nextCheck == KycCheckKind.identity ||
        status.nextCheck == KycCheckKind.bankMatch;
    final asset = complete
        ? 'assets/illustrations/contributor-verification-success.png'
        : identity
        ? 'assets/illustrations/contributor-identity-check.png'
        : 'assets/illustrations/contributor-document-selfie.png';
    final key = complete
        ? 'kyc-illustration-success'
        : identity
        ? 'kyc-illustration-identity'
        : 'kyc-illustration-evidence';
    return SizedBox(
      height: complete || identity ? 148 : 164,
      child: Image.asset(
        asset,
        key: ValueKey(key),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }

  Widget _loading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(IqSpace.s6),
      child: IqSpinner(color: IqColors.brand, size: 24),
    ),
  );

  Widget _identity(KycStatus status) {
    if (_identityStep == 'name') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm your legal name',
            style: IqText.title.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            'Is this the name shown on your $_methodLabel? Edit it if needed.',
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          const SizedBox(height: IqSpace.s3),
          IqField(
            label: 'First name',
            controller: _first,
            state: _firstError == null ? null : IqFieldState.error,
            help: _firstError ?? '',
            showNote: false,
            autofillHints: const [AutofillHints.givenName],
            keyboardType: TextInputType.name,
            onChanged: (_) => setState(() => _confirmedName = false),
          ),
          const SizedBox(height: IqSpace.s2),
          IqField(
            label: 'Last name',
            controller: _last,
            state: _lastError == null ? null : IqFieldState.error,
            help: _lastError ?? '',
            showNote: false,
            autofillHints: const [AutofillHints.familyName],
            keyboardType: TextInputType.name,
            onChanged: (_) => setState(() => _confirmedName = false),
          ),
          const SizedBox(height: IqSpace.s2),
          CheckboxListTile(
            value: _confirmedName,
            onChanged: (value) =>
                setState(() => _confirmedName = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I confirm this is the legal name shown on my $_methodLabel.',
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _illustration(status),
        Text(
          _ninOnly
              ? 'Before you submit or withdraw, we match your name to your NIN.'
              : 'Before you submit or withdraw, we match your name to your NIN or BVN.',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        if (!_ninOnly) ...[
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
        ],
        const SizedBox(height: IqSpace.s3),
        IqField(
          label: _methodLabel,
          controller: _number,
          state: _numberError == null ? null : IqFieldState.error,
          help: _numberError ?? '11 digits.',
          showNote: false,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: IqSpace.s3),
        Text(
          'We keep the last 4 digits, not the full number.',
          style: IqText.small.copyWith(color: IqColors.fg3),
        ),
      ],
    );
  }

  Widget _evidenceStep(KycStatus status) {
    final document = status.nextCheck == KycCheckKind.document;
    final review =
        status.checks[status.nextCheck] == KycCheckState.review ||
        status.checks[status.nextCheck] == KycCheckState.pending ||
        status.inReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _illustration(status),
        Text(
          _copy(status.nextCheck),
          style: IqText.title.copyWith(color: IqColors.fg),
        ),
        const SizedBox(height: IqSpace.s2),
        Text(
          review
              ? 'Your details are being reviewed. Check back soon.'
              : document
              ? 'Add a clear photo or PDF of your government ID.'
              : status.nextCheck == KycCheckKind.liveness
              ? 'Take a live selfie to complete the liveness check.'
              : _ninOnly
              ? 'Take a selfie so we can match it to your NIN photo.'
              : 'Take a selfie so we can match it to your NIN or BVN photo.',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        if (!review && status.nextCheck != KycCheckKind.bankMatch) ...[
          const SizedBox(height: IqSpace.s4),
          IqField(
            kind: IqFieldKind.picker,
            pickerLabel: document ? 'Government ID' : 'Selfie',
            pickerValue: _evidence?.filename ?? '',
            pickerPlaceholder: document ? 'Choose file' : 'Open camera',
            state: _evidence == null ? IqFieldState.empty : IqFieldState.valid,
            help: document ? 'JPEG, PNG, WebP or PDF.' : 'Use good lighting.',
            showNote: false,
            showStatus: false,
            onTap: () => _pick(status.nextCheck),
          ),
        ],
      ],
    );
  }
}

String _copy(KycCheckKind check) => switch (check) {
  KycCheckKind.identity => 'Confirm your identity',
  KycCheckKind.bankMatch => 'Confirm your bank account',
  KycCheckKind.document => 'Add your government ID',
  KycCheckKind.selfie => 'Match your photo',
  KycCheckKind.liveness => 'Complete a liveness check',
  KycCheckKind.none => 'Your account is verified',
  _ => 'Complete account verification',
};
