import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/kyc_service.dart';
import '../../theme/theme.dart';
import '../../ui/banner.dart';
import '../../ui/spinner.dart';
import '../../ui/top_bar.dart';
import '../kyc/kyc_sheet.dart';
import '../kyc/kyc_controller.dart';
import 'wallet_sheet.dart';
import 'withdraw_sheet.dart';

/// Rechecks the server's required tier before opening the withdrawal form.
class WithdrawEntry extends ConsumerStatefulWidget {
  const WithdrawEntry({super.key, this.amountKobo, this.account});

  final int? amountKobo;
  final String? account;

  @override
  ConsumerState<WithdrawEntry> createState() => _WithdrawEntryState();
}

enum _Step { checking, failed, kyc, withdraw }

class _WithdrawEntryState extends ConsumerState<WithdrawEntry> {
  KycStatus? _status;
  KycRefused? _error;
  var _step = _Step.checking;
  var _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _step = _Step.checking;
      _error = null;
    });
    try {
      final status = await ref.read(kycServiceProvider).status();
      if (!mounted || request != _request) return;
      setState(() {
        _status = status;
        _step = status.canWithdraw ? _Step.withdraw : _Step.kyc;
      });
      if (ref.exists(kycControllerProvider)) {
        await ref.read(kycControllerProvider.notifier).refresh(force: true);
      }
    } on KycRefused catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _step = _Step.failed;
      });
    } on Object {
      if (!mounted || request != _request) return;
      setState(() {
        _error = const KycRefused(KycProblem.unavailable);
        _step = _Step.failed;
      });
    }
  }

  Future<void> _complete(KycStatus _) async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.withdraw) {
      return WithdrawSheet(
        amountKobo: widget.amountKobo,
        account: widget.account,
      );
    }
    if (_step == _Step.kyc && _status != null) {
      return KycSheet(
        initialStatus: _status,
        onComplete: _complete,
        onClose: () => context.pop(),
      );
    }
    return WalletSheet(
      children: [
        IqTopBar(
          variant: IqTopBarVariant.sheet,
          title: 'Confirm your identity',
          onClose: () => context.pop(),
        ),
        Padding(
          padding: const EdgeInsets.all(IqSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                IqBanner(
                  kind: IqBannerKind.error,
                  title: kycError(_error!),
                  action: 'Try again',
                  onAction: _load,
                )
              else ...[
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
}
