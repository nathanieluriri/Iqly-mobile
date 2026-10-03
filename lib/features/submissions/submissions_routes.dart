import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/top_bar.dart';
import 'submission_detail_screen.dart';

String submissionPath(String id) => '/submissions/$id';
String resultPath(String id) => '/submissions/$id/result';

/// Brief detail belongs to the Discover row.
String briefPath(String id) => '/briefs/$id';

/// Detail and result open over the tabs (their frames have no dock), so
/// they are top-level routes beside the shell. Figma transitions are
/// Instant.
final submissionRoutes = <RouteBase>[
  GoRoute(
    path: Routes.submissionDetail,
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: SubmissionDetailScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: Routes.result,
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: _ResultPlaceholder(id: state.pathParameters['id']!),
    ),
  ),
];

/// Placeholder until row B13 (Result Winner, Result Not selected) is built.
class _ResultPlaceholder extends StatelessWidget {
  const _ResultPlaceholder({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IqColors.bg,
      body: SafeArea(
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IqTopBar(
                key: ValueKey('result-$id'),
                variant: IqTopBarVariant.page,
                title: 'Your result',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.submissions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
