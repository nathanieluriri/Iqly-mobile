import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../data/referrals_service.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../more/more_widgets.dart';
import 'referrals_state.dart';

/// B20 · Enter invite code (430:19186) and its outcomes (designer answer
/// 22): invalid (485:38903), expired (485:38958), own code (485:39013),
/// each an Error field with Apply code off until the code changes, and
/// success (485:39068), the Valid field with who invited the person and
/// Done.
class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  static const errors = {
    InviteCodeOutcome.invalid:
        'That code doesn’t exist. Check it with your friend.',
    InviteCodeOutcome.expired:
        'This code has expired. Codes work for 30 days after sign-up.',
    InviteCodeOutcome.ownCode: 'That’s your own code. Share it instead.',
  };

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  final _code = TextEditingController();
  InviteCodeResult? _result;
  String? _tried;
  bool _applying = false;

  /// The owner of the code as typed, once the code is known to work.
  String? _inviter;

  @override
  void initState() {
    super.initState();
    _code.addListener(_typing);
  }

  Future<void> _typing() async {
    setState(() {});
    final typed = _typed;
    final inviter = await ref.read(referralsServiceProvider).inviterOf(typed);
    if (mounted && typed == _typed) setState(() => _inviter = inviter);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _typed => _code.text.trim().toUpperCase();

  Future<void> _apply() async {
    if (_applying) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _applying = true);
    final result = await ref.read(referralsProvider.notifier).apply(_typed);
    if (!mounted) return;
    setState(() {
      _applying = false;
      _result = result;
      _tried = _typed;
    });
    if (result.outcome == InviteCodeOutcome.applied) {
      await IqHaptics.success.play();
    } else {
      await errorHaptic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final applied = result?.outcome == InviteCodeOutcome.applied;
    final error = result == null || applied || _typed != _tried
        ? null
        : InviteCodeScreen.errors[result.outcome];
    final inviter = applied ? result?.inviter : _inviter;
    return SubPage(
      title: 'Invite code',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        children: [
          IqField(
            label: 'Invite code',
            value: '',
            controller: _code,
            state: error != null
                ? IqFieldState.error
                : inviter != null
                ? IqFieldState.valid
                : null,
            help: error ?? '',
            note: '$inviter invited you',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _typed.isEmpty ? null : _apply(),
          ),
          const SizedBox(height: IqSpace.s2),
          Text(
            applied
                ? 'You’re in. You both get ₦500 when you win your first brief.'
                : 'Add a code before your first brief. You both get ₦500 when '
                      'you win one.',
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
      actions: [
        applied
            ? IqButton(
                label: 'Done',
                showIcon: false,
                width: double.infinity,
                onTap: () => goBack(context),
              )
            : IqButton(
                label: 'Apply code',
                showIcon: false,
                width: double.infinity,
                disabled: _typed.isEmpty || error != null,
                loading: _applying,
                onTap: _apply,
              ),
      ],
    );
  }
}
