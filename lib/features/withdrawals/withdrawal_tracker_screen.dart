import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deadline.dart';
import '../../core/motion.dart';
import '../../core/responsive.dart';
import '../../data/models.dart';
import '../../data/share_service.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/top_bar.dart';
import 'withdrawal_screen.dart';
import 'withdrawal_widgets.dart';

/// B14 · Withdrawal · tracker (194:9752): the hero amount, the receipt
/// (To, Reference, Date and the status tag) and the four steps. Share
/// receipt exports the receipt card as an image to the system share sheet.
///
/// Motion (spec 7.9): the amount comes with the page, no count; the receipt
/// arrives and draws its tear line; the steps stand still and Awaiting
/// approval breathes its ring while it holds the screen's pulse.
///
/// Figma: Share receipt has no reaction in the prototype; the app shares
/// the card, as the ReceiptCard description says ("Share receipt exports
/// this card").
class WithdrawalTrackerScreen extends ConsumerStatefulWidget {
  const WithdrawalTrackerScreen({super.key, required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  ConsumerState<WithdrawalTrackerScreen> createState() =>
      _WithdrawalTrackerScreenState();
}

class _WithdrawalTrackerScreenState
    extends ConsumerState<WithdrawalTrackerScreen> {
  final _receipt = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    final boundary =
        _receipt.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    final share = ref.read(shareServiceProvider);
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes != null) {
      final w = widget.withdrawal;
      await share.shareImage(
        bytes.buffer.asUint8List(),
        name: 'iqly-receipt-${w.reference ?? w.id}.png',
      );
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final withdrawal = widget.withdrawal;
    final now = ref.watch(clockProvider)();
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
                  title: 'Withdrawal',
                  onBack: () => leaveWithdrawal(context),
                ),
                Expanded(
                  child: Stagger(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(IqSpace.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WithdrawalAmount(withdrawal: withdrawal),
                          const SizedBox(height: IqSpace.s3),
                          StaggerItem(
                            index: 0,
                            child: RepaintBoundary(
                              key: _receipt,
                              child: WithdrawalReceipt(
                                withdrawal: withdrawal,
                                now: now,
                              ),
                            ),
                          ),
                          const SizedBox(height: IqSpace.s3),
                          WithdrawalTimeline(withdrawal: withdrawal, now: now),
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
                  child: IqButton(
                    label: 'Share receipt',
                    kind: IqButtonKind.ghost,
                    showIcon: false,
                    width: double.infinity,
                    loading: _sharing,
                    onTap: _share,
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
