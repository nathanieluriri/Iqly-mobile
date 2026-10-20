import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';

import 'app_harness.dart';

/// The Figma answers of rows B3 and B17 (34:24, 34:121, 490:24270).
abstract final class SubmitCopy {
  static const briefTitle = 'A tagline for a solar kiosk network';
  static const title = 'Charge up, stay connected';
  static const shortAnswer = 'No light? We dey';
  static const answer =
      'No light? We dey. Sunline keeps your phone charged and your airtime '
      'close.';
  static const language = 'Both, side by side';
  static const placement =
      'On the kiosk roof sign, big enough to read from '
      'the road';
}

/// The sample dataset at the Figma 9:41 with [drafts] in place of the two
/// sample drafts (none by default).
DemoRepository draftsRepository([List<Draft> drafts = const []]) {
  final data = DemoData(now: figmaNow);
  data.drafts
    ..clear()
    ..addAll(drafts);
  return DemoRepository(data);
}

/// A device holding one Sunline (c5) draft, saved 5 hours before 9:41.
DemoRepository withDraft({
  String title = '',
  String answer = '',
  Map<String, List<String>> answers = const {},
  int step = DraftSteps.answer,
  String briefId = 'c5',
  Duration age = const Duration(hours: 5),
}) => draftsRepository([
  Draft(
    briefId: briefId,
    title: title,
    answer: answer,
    answers: answers,
    step: step,
    editedAt: figmaNow.subtract(age),
  ),
]);

/// Every answer of the Sunline brief in, at the questions step.
DemoRepository readyToSend() => withDraft(
  title: SubmitCopy.title,
  answer: SubmitCopy.answer,
  answers: {
    'language': [SubmitCopy.language],
    'placement': [SubmitCopy.placement],
  },
  step: DraftSteps.ready,
);

/// Uploads that hold where a test wants them: a name in [failing] fails,
/// one in [holding] stops at [at] and never lands, the rest land at once.
class ScriptedUploader implements AttachmentUploader {
  ScriptedUploader({
    this.failing = const {},
    this.holding = const {},
    this.at = .6,
  });

  final Set<String> failing;
  final Set<String> holding;
  final double at;

  @override
  Future<bool> upload(AttachmentFile file, void Function(double) progress) {
    if (holding.contains(file.name)) {
      progress(at);
      return Completer<bool>().future;
    }
    if (failing.contains(file.name)) return Future.value(false);
    progress(1);
    return Future.value(true);
  }
}

/// The submit service answering at once at the Figma 9:41, writing into the
/// dataset the repository serves.
List<Override> instantSubmit({
  DemoAttachmentPicker? picker,
  AttachmentUploader? uploader,
  void Function(DemoSubmitService service)? created,
}) => [
  submitServiceProvider.overrideWith((ref) {
    final repository = ref.watch(repositoryProvider) as DemoRepository;
    final service = DemoSubmitService(
      repository.data,
      delay: Duration.zero,
      clock: () => figmaNow,
    );
    created?.call(service);
    return service;
  }),
  attachmentPickerProvider.overrideWithValue(picker ?? DemoAttachmentPicker()),
  attachmentUploaderProvider.overrideWithValue(uploader ?? ScriptedUploader()),
];
