import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/dock.dart';

/// The app shell draws the dock; goldens add it so the frame matches Figma.
class DockFrame extends StatelessWidget {
  const DockFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: IqColors.bg,
      child: Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: child,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              IqSpace.s4,
              0,
              IqSpace.s4,
              IqSpace.s2 + bottom,
            ),
            child: const IqDock(active: IqDockActive.submissions),
          ),
        ],
      ),
    );
  }
}

class EmptySubmissionsRepository extends DemoRepository {
  EmptySubmissionsRepository() : super(DemoData());

  @override
  Future<List<Submission>> submissions() async => const [];
}

class FailingSubmissionsRepository extends DemoRepository {
  FailingSubmissionsRepository() : super(DemoData());

  int calls = 0;
  bool fail = true;

  @override
  Future<List<Submission>> submissions() async {
    calls++;
    if (fail) throw Exception('offline');
    return super.submissions();
  }
}

class PendingSubmissionsRepository extends DemoRepository {
  PendingSubmissionsRepository() : super(DemoData());

  final _never = Completer<List<Submission>>();

  @override
  Future<List<Submission>> submissions() => _never.future;
}
