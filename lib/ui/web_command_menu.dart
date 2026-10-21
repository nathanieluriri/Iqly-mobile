import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

class IqWebCommandResult {
  const IqWebCommandResult({
    required this.title,
    required this.meta,
    required this.logo,
    this.onTap,
  });

  final String title;
  final String meta;

  /// The business logo, drawn 28 across.
  final Widget logo;
  final VoidCallback? onTap;
}

class IqWebCommandGroup {
  const IqWebCommandGroup({required this.label, required this.results});

  final String label;
  final List<IqWebCommandResult> results;
}

/// Exp/Web/CommandMenu (local, sync to DS; 1727:14558): the search card,
/// radius 14, the query over the results grouped by kind. The first result
/// is lit; there are no key hints on tablets (spec, Shell).
class IqWebCommandMenu extends StatelessWidget {
  const IqWebCommandMenu({
    super.key,
    required this.groups,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.placeholder = 'Search briefs, polls and activations',
    this.empty = 'Nothing matches that yet.',
    this.onChanged,
    this.onSubmitted,
  });

  final List<IqWebCommandGroup> groups;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final String placeholder;

  /// Shown under a query that matches nothing.
  final String empty;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const double width = 640;

  @override
  Widget build(BuildContext context) {
    final results = groups.where((g) => g.results.isNotEmpty).toList();
    final typed = controller?.text.trim().isNotEmpty ?? false;
    final lit = results.isEmpty ? null : results.first.results.first;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.xl),
        border: Border.all(color: IqColors.line),
        boxShadow: IqShadows.lg,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IqSpace.s5,
                IqSpace.s4,
                IqSpace.s4,
                IqSpace.s4,
              ),
              child: Row(
                children: [
                  const IqIcon(IqIcons.search, size: 18, color: IqColors.fg2),
                  const SizedBox(width: IqSpace.s3),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: autofocus,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      cursorColor: IqColors.primary,
                      style: IqText.body.copyWith(color: IqColors.fg),
                      decoration: InputDecoration.collapsed(
                        hintText: placeholder,
                        hintStyle: IqText.body.copyWith(color: IqColors.fg3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (results.isNotEmpty || typed)
              const SizedBox(
                height: 1,
                child: ColoredBox(color: IqColors.line),
              ),
            if (results.isEmpty && typed)
              Padding(
                padding: const EdgeInsets.all(IqSpace.s5),
                child: Text(
                  empty,
                  style: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
                ),
              ),
            if (results.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(IqSpace.s2),
                  children: [
                    for (final group in results) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          IqSpace.s3,
                          IqSpace.s2,
                          IqSpace.s3,
                          IqSpace.s1,
                        ),
                        child: Text(
                          group.label,
                          style: IqWebText.metaCaption.copyWith(
                            color: IqColors.fg3,
                          ),
                        ),
                      ),
                      for (final result in group.results)
                        _Result(result, lit: identical(result, lit)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result(this.result, {required this.lit});

  final IqWebCommandResult result;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: result.onTap,
      tactile: false,
      semanticLabel: result.title,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s3,
          vertical: IqSpace.s2p5,
        ),
        decoration: BoxDecoration(
          color: lit || pressed ? IqColors.secondary : null,
          borderRadius: BorderRadius.circular(IqRadius.md),
        ),
        child: Row(
          children: [
            SizedBox.square(dimension: 28, child: result.logo),
            const SizedBox(width: IqSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqWebText.bodySmallStrong.copyWith(
                      color: IqColors.fg,
                    ),
                  ),
                  const SizedBox(height: IqSpace.s0p5),
                  Text(
                    result.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqWebText.metaCaption.copyWith(
                      color: lit ? IqColors.fg2 : IqColors.fg3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
