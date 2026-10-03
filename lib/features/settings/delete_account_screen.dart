import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/profile_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/top_bar.dart';
import '../onboarding/onboarding_draft.dart';
import '../profile/profile_motion.dart' as motion;
import '../profile/profile_state.dart';
import 'settings_state.dart';

/// B14 · Delete account (194:9964) and its typed state (194:10046), behind
/// Flags.deleteAccount. The store asks for a typed confirmation, a 30-day
/// undo and withdrawing first: the consequence rows show the available
/// balance to withdraw (it opens the Wallet) and what is already on its
/// way, both from walletTotals, and hide when they are zero. "Delete my
/// account" stays disabled until the field reads DELETE (typing is
/// uppercased); then the field turns Valid and the Danger button takes its
/// sticker. Deleting forgets the account on the device and hands off to
/// Account closing.
///
/// The consequence rows settle in with the push; no chevrons, as in the
/// frame.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const confirmWord = 'DELETE';

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _typed = TextEditingController();
  bool _deleting = false;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _confirmed => _typed.text.trim() == DeleteAccountScreen.confirmWord;

  Future<void> _delete() async {
    if (!_confirmed || _deleting) return;
    FocusScope.of(context).unfocus();
    setState(() => _deleting = true);
    try {
      await ref.read(profileServiceProvider).deleteAccount();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _failures++;
      });
      errorHaptic();
      return;
    }
    final email = ref.read(onboardingUserProvider).value?.email;
    await forgetAccount(ref);
    if (mounted) context.go(Routes.accountClosing, extra: email);
  }

  void _keep() => context.canPop() ? context.pop() : context.go(Routes.profile);

  @override
  Widget build(BuildContext context) {
    ref.watch(onboardingUserProvider);
    final wallet = ref.watch(accountWalletProvider).value;
    final available = wallet?.withdrawableKobo ?? 0;
    final onItsWay = wallet?.pendingWithdrawalsKobo ?? 0;
    final rows = [
      if (available > 0)
        (
          'Withdraw ${naira(available)} first',
          IqIcons.bank,
          () => context.go(Routes.wallet),
        ),
      if (onItsWay > 0) ('${naira(onItsWay)} on its way', IqIcons.bank, null),
      ('Submissions stay with the business', IqIcons.submissions, null),
    ];

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
                  title: 'Delete account',
                  onBack: _keep,
                ),
                Expanded(
                  child: motion.Entrance(
                    length: motion.Entrance.listLength(rows.length + 2),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        IqSpace.s4,
                        IqSpace.s4,
                        IqSpace.s4,
                        IqSpace.s4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          motion.Cue.settle(
                            0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Delete your account?',
                                  style: IqText.display.copyWith(
                                    color: IqColors.fg,
                                  ),
                                ),
                                const SizedBox(height: IqSpace.s3),
                                Text(
                                  '30 days to change your mind.',
                                  style: IqText.body.copyWith(
                                    color: IqColors.fg2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: IqSpace.s3),
                          for (final (i, (label, icon, onTap)) in rows.indexed)
                            motion.Cue.settle(
                              i + 1,
                              child: _Consequence(
                                label: label,
                                icon: icon,
                                divider: i < rows.length - 1,
                                onTap: onTap,
                              ),
                            ),
                          const SizedBox(height: IqSpace.s3),
                          motion.Cue.settle(
                            rows.length + 1,
                            child: IqField(
                              label: 'Type DELETE to confirm',
                              value: '',
                              controller: _typed,
                              state: _confirmed ? IqFieldState.valid : null,
                              showNote: false,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              inputFormatters: const [_UpperCase()],
                              onSubmitted: (_) => _delete(),
                            ),
                          ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Shake(
                        trigger: _failures,
                        child: IqButton(
                          label: 'Delete my account',
                          kind: IqButtonKind.danger,
                          showIcon: false,
                          width: double.infinity,
                          disabled: !_confirmed,
                          loading: _deleting,
                          onTap: _delete,
                        ),
                      ),
                      const SizedBox(height: IqSpace.s2),
                      IqButton(
                        label: 'Keep my account',
                        kind: IqButtonKind.ghost,
                        showIcon: false,
                        width: double.infinity,
                        onTap: _keep,
                      ),
                    ],
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

/// Exp/ListRow with its description and chevron hidden. Only the withdraw
/// row acts; the others read as plain text to a screen reader.
class _Consequence extends StatelessWidget {
  const _Consequence({
    required this.label,
    required this.icon,
    required this.divider,
    this.onTap,
  });

  final String label;
  final IqIcons icon;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = IqListRow(
      label: label,
      icon: icon,
      showDescription: false,
      showChevron: false,
      divider: divider,
      onTap: onTap,
    );
    if (onTap != null) return row;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: row),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
