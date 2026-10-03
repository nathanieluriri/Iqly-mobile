import 'dart:async';

import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';

import 'app_harness.dart';

class EmptySubmissionsRepository extends DemoRepository {
  EmptySubmissionsRepository() : super(DemoData(now: figmaNow));

  @override
  Future<List<Submission>> submissions() async => const [];
}

class FailingSubmissionsRepository extends DemoRepository {
  FailingSubmissionsRepository() : super(DemoData(now: figmaNow));

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
  PendingSubmissionsRepository() : super(DemoData(now: figmaNow));

  final _never = Completer<List<Submission>>();

  @override
  Future<List<Submission>> submissions() => _never.future;
}
