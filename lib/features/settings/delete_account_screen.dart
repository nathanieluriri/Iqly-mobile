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
import '../more/more_widgets.dart';
import '../profile/profile_state.dart';
import 'settings_state.dart';

/// B14 · Delete account (194:9964), typed (194:10046) and at ₦0.00
/// (484:23450), behind Flags.deleteAccount. Delete stays disabled until
/// the wallet is at ₦0.00 (designer answer 35) and the field reads DELETE;
/// until then the page says to withdraw first and the Withdraw row opens
/// the Wallet. Keep my account goes back to the opener. Deleting forgets
/// the account on the device and hands off to Account closing.
///
/// Conflict left open: 194:10046 drops the consequence rows once DELETE is
/// typed; answer 35 keeps the Withdraw row above as the way out, which this
/// follows. The frame's disabled Danger is a faded red; the kit's Disabled
/// is the panel grey.
///
/// The consequence rows settle in with the push. The Danger press gives the
/// destructive haptic and hands off to Account closing (spec 7.10). A
/// delete that fails shakes the button, plays the error haptic and says why
/// under it (new copy for the owner to sign off; the frames have no failed
/// state).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const confirmWord = 'DELETE';
  static const failedText =
      'Couldn’t delete your account. Check your connection and try again.';

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
    final available = ref.read(accountWalletProvider).value?.withdrawableKobo;
    if (!_confirmed || _deleting || available != 0) return;
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
    await forgetAccount(ref, closed: true);
    if (mounted) context.go(Routes.accountClosing, extra: email);
  }

  void _keep() => goBack(context);

  @override
  Widget build(BuildContext context) {
    ref.watch(onboardingUserProvider);
    final wallet = ref.watch(accountWalletProvider).value;
    final available = wallet?.withdrawableKobo ?? 0;
    final onItsWay = wallet?.pendingWithdrawalsKobo ?? 0;
    final locked = wallet == null || available > 0;
    final rows = [
      if (available > 0) ...[
        (
          'Withdraw ${naira(available)} first',
          IqIcons.bank,
          () => context.go(Routes.wallet),
        ),
        if (onItsWay > 0) ('${naira(onItsWay)} on its way', IqIcons.bank, null),
        ('Submissions stay with the business', IqIcons.submissions, null),
      ],
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
                  title: '',
                  onBack: _keep,
                ),
                Expanded(
                  child: Stagger(
                    move: StaggerMove.settle,
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
                          StaggerItem(
                            index: 0,
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
                                  available > 0
                                      ? 'Withdraw your ${naira(available)} '
                                            'first. Delete unlocks at '
                                            '${naira(0)}, then you have 30 '
                                            'days to change your mind.'
                                      : 'Your wallet is at ${naira(0)}. '
                                            'Delete now and you have 30 days '
                                            'to change your mind.',
                                  style: IqText.body.copyWith(
                                    color: IqColors.fg2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: IqSpace.s3),
                          if (rows.isNotEmpty) ...[
                            StaggerItem(
                              index: 1,
                              child: RowGroup(
                                outlined: true,
                                children: [
                                  for (final (i, (label, icon, onTap))
                                      in rows.indexed)
                                    _Consequence(
                                      label: label,
                                      icon: icon,
                                      divider: i < rows.length - 1,
                                      onTap: onTap,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: IqSpace.s3),
                          ],
                          StaggerItem(
                            index: 2,
                            child: IqField(
                              label: 'Type delete to confirm',
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
                          disabled: !_confirmed || locked,
                          loading: _deleting,
                          onTap: _delete,
                        ),
                      ),
                      _FailedLine(
                        failures: _deleting ? 0 : _failures,
                        text: DeleteAccountScreen.failedText,
                      ),
                      const SizedBox(height: IqSpace.s2),
                      SizedBox(
                        height: 44,
                        child: IqButton(
                          label: 'Keep my account',
                          kind: IqButtonKind.ghost,
                          showIcon: false,
                          width: double.infinity,
                          onTap: _keep,
                        ),
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

/// The words under a failed button: they rise in like a field's help line
/// (spec 5.8) and make room as they come; a new attempt clears them. At
/// once under reduced motion.
class _FailedLine extends StatelessWidget {
  const _FailedLine({required this.failures, required this.text});

  /// Failed attempts so far; zero shows nothing.
  final int failures;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Widget line = failures == 0
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: IqSpace.s1p5),
            child: Reveal(
              key: ValueKey(failures),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: IqText.small.copyWith(color: IqColors.errStrong),
                ),
              ),
            ),
          );
    if (MediaQuery.disableAnimationsOf(context)) return line;
    return AnimatedSize(
      duration: IqDurations.tick,
      curve: IqCurves.easeOut,
      alignment: Alignment.topCenter,
      child: line,
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
