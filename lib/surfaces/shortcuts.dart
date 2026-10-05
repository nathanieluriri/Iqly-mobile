import '../core/deep_links.dart';
import '../data/polls_data.dart';
import 'surface_copy.dart';

/// One entry of the app icon long press (347:16322, 350:17788). [type]
/// carries the route, so the tap needs no lookup. [icon] names the Android
/// drawable and the iOS asset catalog image.
class SurfaceShortcut {
  const SurfaceShortcut({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final String icon;
  final String route;

  String get type => DeepLinks.uri(route).toString();
}

/// In frame order. An entry with nothing behind it is left out: no poll
/// left to answer, no draft to continue.
List<SurfaceShortcut> appShortcuts({
  required List<PollBusiness> polls,
  required String? draftBriefId,
  bool showPolls = true,
}) {
  final pollBusiness = showPolls
      ? polls.where((p) => !p.allAnswered).firstOrNull
      : null;
  return [
    if (pollBusiness != null)
      SurfaceShortcut(
        label: SurfaceCopy.answerQuickPoll,
        icon: 'ic_shortcut_polls',
        route: DeepLinks.poll(pollBusiness.id),
      ),
    if (draftBriefId != null)
      SurfaceShortcut(
        label: SurfaceCopy.continueDraft,
        icon: 'ic_shortcut_forward',
        route: DeepLinks.submit(draftBriefId),
      ),
    const SurfaceShortcut(
      label: SurfaceCopy.mySubmissions,
      icon: 'ic_shortcut_submissions',
      route: DeepLinks.submissions,
    ),
  ];
}
