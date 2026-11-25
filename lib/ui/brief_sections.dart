import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/theme.dart';

/// The brief's reading structure, shared by brief detail, submission detail,
/// and the in-place submission viewer.
class BriefSections extends StatelessWidget {
  const BriefSections({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final overview = brief.overview ?? brief.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.trim().isNotEmpty)
          _Section(title: 'Overview', body: briefPlainText(overview)),
        if (brief.problemStatement case final problem?
            when problem.trim().isNotEmpty)
          _Section(title: 'The problem', body: briefPlainText(problem)),
        if (brief.deliverables.isNotEmpty)
          _Section(
            title: 'Deliverables',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in brief.deliverables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: IqSpace.s2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 7, right: 12),
                          decoration: const BoxDecoration(
                            color: IqColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: IqText.body.copyWith(color: IqColors.fg),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.body, this.child});

  final String title;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IqSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: IqText.bodyStrong.copyWith(color: IqColors.fg)),
          const SizedBox(height: IqSpace.s2),
          if (body case final body?)
            Text(body, style: IqText.body.copyWith(color: IqColors.fg))
          else if (child case final child?)
            child,
        ],
      ),
    );
  }
}

/// Portable Text arrives as small HTML fragments. Keep the words and their
/// paragraph breaks without pulling an HTML renderer into the app.
String briefPlainText(String html) {
  final paragraphs = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return paragraphs
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
