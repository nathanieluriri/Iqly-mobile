import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/transitions.dart';
import '../../data/assessment_service.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/button.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/cover_with_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/spinner.dart';
import '../kyc/kyc_controller.dart';
import 'start_requirements.dart';

/// Explains the first unmet start requirement without hiding the brief.
/// Completing qualification or KYC returns to this sheet and advances it.
Future<bool> showStartRequirementsSheet(
  BuildContext context,
  Brief brief,
) async {
  final ready = await showIqSheet<bool>(
    Navigator.of(context, rootNavigator: true).context,
    (sheetContext) => StartRequirementsSheet(
      brief: brief,
      onReady: () => Navigator.of(sheetContext).pop(true),
      onClose: () => Navigator.of(sheetContext).pop(false),
    ),
    scrim: IqScrim.sheet,
  );
  return ready ?? false;
}

class StartRequirementsSheet extends ConsumerStatefulWidget {
  const StartRequirementsSheet({
    super.key,
    required this.brief,
    this.onReady,
    this.onClose,
  });

  final Brief brief;
  final VoidCallback? onReady;
  final VoidCallback? onClose;

  @override
  ConsumerState<StartRequirementsSheet> createState() =>
      _StartRequirementsSheetState();
}

class _StartRequirementsSheetState
    extends ConsumerState<StartRequirementsSheet> {
  bool _completed = false;

  void _retry() {
    unawaited(ref.read(assessmentAccessProvider.notifier).refresh(force: true));
    unawaited(ref.read(kycControllerProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final assessment = ref.watch(assessmentAccessProvider);
    final kyc = ref.watch(kycControllerProvider);
    final requirement = resolveStartRequirements(assessment, kyc);
    if (requirement == StartRequirement.ready && !_completed) {
      _completed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
    }
    final copy = _copy(requirement);
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: IqColors.card,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(IqConfirmSheet.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: IqColors.line2,
                  borderRadius: BorderRadius.circular(IqRadius.full),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s5,
                IqSpace.s2,
                IqSpace.s5,
                IqSpace.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.brief.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: IqText.small.copyWith(color: IqColors.fg3),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  Center(child: _graphic(requirement)),
                  const SizedBox(height: IqSpace.s4),
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style: IqText.headline.copyWith(color: IqColors.fg),
                  ),
                  const SizedBox(height: IqSpace.s2),
                  Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: IqText.body.copyWith(color: IqColors.fg2),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              0,
            ),
            child: Column(
              children: [
                if (copy.action != null) ...[
                  IqButton(
                    label: copy.action!,
                    kind: copy.retry
                        ? IqButtonKind.secondary
                        : IqButtonKind.primary,
                    showIcon: false,
                    width: double.infinity,
                    onTap: () {
                      switch (requirement) {
                        case StartRequirement.qualification:
                        case StartRequirement.qualificationResume:
                          context.open(Routes.assessment);
                        case StartRequirement.kyc:
                          context.open(Routes.kyc);
                        case StartRequirement.kycUnavailable:
                          _retry();
                        case StartRequirement.checking:
                        case StartRequirement.qualificationUnavailable:
                        case StartRequirement.ready:
                          break;
                      }
                    },
                  ),
                  const SizedBox(height: IqSpace.s2),
                ],
                IqButton(
                  label: 'Not now',
                  kind: IqButtonKind.ghost,
                  showIcon: false,
                  width: double.infinity,
                  onTap: widget.onClose,
                ),
              ],
            ),
          ),
          SizedBox(height: math.max(inset, IqConfirmSheet.homeIndicator)),
        ],
      ),
    );
  }

  Widget _graphic(StartRequirement requirement) {
    if (requirement == StartRequirement.checking) {
      return const SizedBox(
        height: 112,
        child: Center(child: IqSpinner(color: IqColors.brand, size: 28)),
      );
    }
    if (requirement == StartRequirement.kyc ||
        requirement == StartRequirement.kycUnavailable) {
      return Image.asset(
        'assets/illustrations/contributor-identity-check.png',
        height: 112,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    }
    return CoverWithLogo(
      size: const Size.square(104),
      radius: IqRadius.xl,
      cover: const ColoredBox(
        color: IqColors.tintStrong,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.contain,
            child: IqFigure(IqFigures.writer, width: IqFigure.designWidth),
          ),
        ),
      ),
      logo: const IqBrandLogo(
        mark: IqBrandMark.logomark,
        width: 22,
        height: 22,
      ),
      logoOffset: const Offset(48, 48),
      logoSize: 26,
      logoInset: 2,
    );
  }
}

typedef _SheetCopy = ({String title, String body, String? action, bool retry});

_SheetCopy _copy(StartRequirement requirement) => switch (requirement) {
  StartRequirement.checking => (
    title: 'Checking requirements',
    body: 'One moment while we confirm what you need to start.',
    action: null,
    retry: false,
  ),
  StartRequirement.qualification => (
    title: 'Qualify to take on this brief',
    body: 'Twenty questions before new challenges. Pass once and you can keep taking on challenges.',
    action: 'Proceed to qualification',
    retry: false,
  ),
  StartRequirement.qualificationResume => (
    title: 'Pick up your qualification',
    body: 'Your test is still open. Finish it to start this brief.',
    action: 'Continue qualification',
    retry: false,
  ),
  StartRequirement.qualificationUnavailable => (
    title: 'New challenges aren’t available yet',
    body: 'Your qualification is cooling down. Check back soon.',
    action: null,
    retry: false,
  ),
  StartRequirement.kyc => (
    title: 'Verify your identity to submit',
    body: 'Confirm your NIN to unlock challenge submissions. It only takes a moment.',
    action: 'Proceed to verification',
    retry: false,
  ),
  StartRequirement.kycUnavailable => (
    title: 'Verification status unavailable',
    body: 'We couldn’t check your identity status. Try again before starting this brief.',
    action: 'Try again',
    retry: true,
  ),
  StartRequirement.ready => (
    title: 'You’re ready',
    body: 'Opening your submission.',
    action: null,
    retry: false,
  ),
};
