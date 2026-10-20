import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/updates.dart';
import 'package:iqly_mobile/data/app_version.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/discover/discover_state.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'discover_harness.dart';

Future<void> _golden(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/discover_$name.png',
  );
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  String location, {
  ScriptedRepository? repository,
  Map<String, Object>? prefs,
  List<Override> overrides = const [],
}) => pumpApp(
  tester,
  location,
  repository: repository,
  prefs: prefs,
  overrides: [...discoverOverrides(), ...overrides],
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('31:24 For you (192:8644, 161:16226, 161:16247)', (tester) async {
    await _pump(tester, Routes.home);
    await _golden(tester, 'for_you');
  });

  testWidgets('1311:26531 a newer build offered', (tester) async {
    final container = await _pump(
      tester,
      Routes.home,
      overrides: [
        appVersionServiceProvider.overrideWithValue(
          DemoAppVersionService(
            AppRelease(
              installed: '0.1.0+1',
              status: UpdateStatus.available,
              latest: '0.1.0+2',
              updateUrl: Uri.parse(
                'https://staging.api.iqly.net/mobile/download/android',
              ),
            ),
          ),
        ),
      ],
    );
    await container.read(updatesProvider.notifier).check();
    await tester.pumpAndSettle();
    await _golden(tester, 'update_available');
  });

  testWidgets('480:20532 All', (tester) async {
    await _pump(tester, Routes.home);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await _golden(tester, 'all');
  });

  testWidgets('165:8171 loading, polls and activations in', (tester) async {
    await _pump(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.hang]),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await _golden(tester, 'loading');
  });

  testWidgets('192:8909 refreshing', (tester) async {
    final container = await _pump(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.data, BriefsCall.hang]),
    );
    container.read(discoverFeedProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await _golden(tester, 'refreshing');
  });

  testWidgets('192:9179 loading more', (tester) async {
    await _pump(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.data, BriefsCall.hang]),
    );
    await _scrollToEnd(tester);
    await _golden(tester, 'loading_more');
  });

  testWidgets('192:9334 end of list', (tester) async {
    await _pump(tester, Routes.home);
    await _scrollToEnd(tester);
    await _golden(tester, 'end_of_list');
  });

  testWidgets('165:8285 no briefs', (tester) async {
    await _pump(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.empty]),
    );
    await _golden(tester, 'no_briefs');
  });

  testWidgets('165:8401 failed to load', (tester) async {
    await _pump(
      tester,
      Routes.home,
      repository: ScriptedRepository([BriefsCall.fail]),
    );
    await _golden(tester, 'failed');
  });

  testWidgets('31:397 Filters (192:9763 order by interests)', (tester) async {
    await _pump(tester, Routes.filters);
    await _golden(tester, 'filters');
  });

  testWidgets('476:17315 Brief detail', (tester) async {
    await _pump(
      tester,
      Routes.brief('c5'),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
    );
    await _golden(tester, 'brief_detail');
  });

  testWidgets('192:9707 Brief detail, saved', (tester) async {
    await _pump(tester, Routes.brief('c5'));
    await _golden(tester, 'brief_detail_saved');
  });

  testWidgets('480:22463 Brief detail, submitted', (tester) async {
    final container = await _pump(
      tester,
      Routes.brief('c5'),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
    );
    final brief = DemoData(now: figmaNow).briefs
        .firstWhere((b) => b.id == 'c5');
    container
        .read(sentSubmissionsProvider.notifier)
        .add(
          SubmissionItem(
            submission: Submission(
              id: 's9',
              briefId: 'c5',
              title: 'Light that pays for itself',
              body: 'Charge here, glow everywhere.',
              status: SubmissionStatus.pending,
              createdAt: figmaNow,
            ),
            brief: brief,
          ),
        );
    await tester.pumpAndSettle();
    await _golden(tester, 'brief_detail_submitted');
  });

  testWidgets('480:22572 Brief detail, closed', (tester) async {
    await _pump(
      tester,
      Routes.brief('c5'),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
      repository: _ClosedRepository(),
    );
    await _golden(tester, 'brief_detail_closed');
  });

  testWidgets('Brief detail, outside its audience (no frame)', (tester) async {
    await _pump(
      tester,
      Routes.brief('c5'),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
      repository: _OutsideRepository(),
    );
    await _golden(tester, 'brief_detail_outside');
  });

  testWidgets('250:12333 Saved briefs', (tester) async {
    await _pump(tester, Routes.savedBriefs);
    await _golden(tester, 'saved');
  });

  testWidgets('250:12609 Saved briefs offline', (tester) async {
    final demo = DemoData(now: figmaNow);
    final saved = [
      for (final id in ['c5', 'c4'])
        demo.briefs.firstWhere((b) => b.id == id).toJson(),
    ];
    await _pump(
      tester,
      Routes.savedBriefs,
      repository: ScriptedRepository([BriefsCall.fail]),
      prefs: {...signedInPrefs(), 'discover.savedBriefs': jsonEncode(saved)},
    );
    await _golden(tester, 'saved_offline');
  });

  testWidgets('250:12880 Saved briefs empty', (tester) async {
    await _pump(
      tester,
      Routes.savedBriefs,
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
    );
    await _golden(tester, 'saved_empty');
  });
}

/// Sunline's brief once it has closed.
/// The API's brief detail saying the person is outside its audience.
class _OutsideRepository extends ScriptedRepository {
  @override
  Future<Brief?> brief(String id) async {
    final brief = await super.brief(id);
    if (brief == null) return null;
    return Brief.fromJson({...brief.toJson(), 'inAudience': false});
  }
}

class _ClosedRepository extends ScriptedRepository {
  @override
  Future<Brief?> brief(String id) async {
    final brief = await super.brief(id);
    if (brief == null) return null;
    return Brief.fromJson({...brief.toJson(), 'status': 'closed'});
  }
}
