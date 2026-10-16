import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/transitions.dart';
import '../../data/help_data.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/faq_row.dart';
import '../../ui/faq_sheet.dart';
import '../../ui/icon.dart';
import '../../ui/list_row.dart';
import '../../ui/search_box.dart';
import '../../ui/section_title.dart';
import '../more/more_widgets.dart';

/// B21 · Help centre (431:19394): search, the common questions and the way
/// to a person (Chat with us, Report an issue). Typing filters the questions
/// (436:19729) or says there is no answer (485:39411); a question rises its
/// answer sheet (436:19673), whose "Still stuck? Chat with us" opens the
/// support inbox.
///
/// The bar title is the frame's "Help"; More's row names it Help centre.
class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({super.key, this.query = ''});

  /// What the search box starts with (a deep link or a test).
  final String query;

  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  late final _search = TextEditingController(text: widget.query);

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Puts the keyboard away before the search leads elsewhere, so coming
  /// back does not bring it up again.
  void _leave() => FocusManager.instance.primaryFocus?.unfocus();

  void _push(String location) {
    _leave();
    context.open(location);
  }

  void _open(Faq faq) {
    _leave();
    showIqSheet<void>(
      context,
      (sheet) => Material(
        type: MaterialType.transparency,
        child: _AnswerSheet(
          faq: faq,
          onChat: () {
            Navigator.of(sheet).pop();
            context.open(Routes.support);
          },
        ),
      ),
      scrim: IqScrim.sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final matches = query.isEmpty
        ? DemoHelp.faqs.take(DemoHelp.commonFaqs).toList()
        : [
            for (final faq in DemoHelp.faqs)
              if (faq.question.toLowerCase().contains(query.toLowerCase())) faq,
          ];
    final children = <Widget>[
      IqSearchBox(placeholder: 'Search help', controller: _search),
      if (matches.isEmpty) ...[
        Text(
          'No answers for “$query”. Chat with us and we’ll sort it out.',
          style: IqText.body.copyWith(color: IqColors.fg2),
        ),
        const SizedBox(height: 56),
      ] else ...[
        IqSectionTitle(
          title: query.isEmpty
              ? 'Common questions'
              : '${matches.length} ${matches.length == 1 ? 'result' : 'results'} for "$query"',
          showCount: false,
          showLink: false,
        ),
        Column(
          children: [
            for (final (i, faq) in matches.indexed)
              IqFaqRow(
                question: faq.question,
                divider: i < matches.length - 1,
                onTap: () => _open(faq),
              ),
          ],
        ),
      ],
      RowGroup(
        children: [
          IqListRow(
            label: 'Chat with us',
            description: DemoHelp.replyLine,
            icon: IqIcons.chat,
            onTap: () => _push(Routes.support),
          ),
          IqListRow(
            label: 'Report an issue',
            description: 'Payments, a brief, or the app',
            icon: IqIcons.flag,
            divider: false,
            onTap: () => _push(Routes.reportIssue),
          ),
        ],
      ),
    ];
    return SubPage(
      title: 'Help',
      body: SubPageList(gap: IqSpace.s2p5, children: children),
    );
  }
}

class _AnswerSheet extends StatefulWidget {
  const _AnswerSheet({required this.faq, required this.onChat});

  final Faq faq;
  final VoidCallback onChat;

  @override
  State<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends State<_AnswerSheet> {
  bool? _helpful;

  @override
  Widget build(BuildContext context) {
    return IqFaqSheet(
      question: widget.faq.question,
      answer: widget.faq.answer,
      helpful: _helpful,
      onHelpful: (yes) => setState(() => _helpful = yes),
      onChat: widget.onChat,
    );
  }
}
