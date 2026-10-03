import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'vector.dart';

enum IqProgressThreadState { progress, ready, error }

/// Exp/ProgressThread: one line of plain words and a count over a rule, a
/// half-length orange brush while in progress, full green when ready (count
/// hidden), full red on an error. It judges the long text area; short
/// fields validate inline.
class IqProgressThread extends StatelessWidget {
  const IqProgressThread({
    super.key,
    this.status = 'Account number next',
    this.count = '1 OF 2',
    this.readyText = 'Ready to save',
    this.errorText = 'Fix the account number',
    this.state = IqProgressThreadState.progress,
  });

  final String status;
  final String count;
  final String readyText;
  final String errorText;
  final IqProgressThreadState state;

  @override
  Widget build(BuildContext context) {
    final (text, ink, icon, iconInk) = switch (state) {
      IqProgressThreadState.progress => (status, IqColors.fg, null, null),
      IqProgressThreadState.ready => (
        readyText,
        IqColors.ok,
        IqIcons.success,
        IqColors.ok,
      ),
      IqProgressThreadState.error => (
        errorText,
        IqColors.errStrong,
        IqIcons.error,
        IqColors.err,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: icon == null
                  ? null
                  : IqIcon(icon, size: 18, color: iconInk!),
            ),
            const SizedBox(width: IqSpace.s1p5),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: IqText.smallStrong.copyWith(color: ink),
              ),
            ),
            if (state != IqProgressThreadState.ready) ...[
              const SizedBox(width: IqSpace.s2),
              Text(
                count.toUpperCase(),
                style: IqText.mono.copyWith(color: IqColors.fg2),
              ),
            ],
          ],
        ),
        const SizedBox(height: IqSpace.s2),
        SizedBox(
          height: 6,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 3,
                  height: 1,
                  child: ColoredBox(color: IqColors.line),
                ),
                switch (state) {
                  IqProgressThreadState.progress => Positioned(
                    left: -1.66,
                    top: 1.25,
                    width: box.maxWidth * 181.25 / 358,
                    height: 3.65,
                    child: const IqVector(
                      'assets/vectors/progress-thread-progress.svg',
                      color: IqColors.accent,
                    ),
                  ),
                  IqProgressThreadState.ready => const Positioned(
                    left: 0,
                    right: 0,
                    top: 1.02,
                    height: 3.88,
                    child: IqVector(
                      'assets/vectors/progress-thread-ready.svg',
                      color: IqColors.ok,
                    ),
                  ),
                  IqProgressThreadState.error => const Positioned(
                    left: 0,
                    right: 0,
                    top: 1.25,
                    height: 3.65,
                    child: IqVector(
                      'assets/vectors/progress-thread-error.svg',
                      color: IqColors.err,
                    ),
                  ),
                },
              ],
            ),
          ),
        ),
      ],
    );
  }
}
