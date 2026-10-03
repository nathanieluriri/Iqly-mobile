import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_service.dart';

import 'app_harness.dart';

/// The Figma answers of row B3 (34:24, 34:121, 34:186).
abstract final class SubmitCopy {
  static const title = 'Charge up, stay connected';
  static const shortAnswer = 'Light wey no dey';
  static const answer =
      'Light wey no dey go, na Sunline. Power your phone, buy airtime, stay '
      'connected off-grid.';
  static const language = 'Both, side by side';
}

/// A signed-in device holding the Sunline (c5) draft.
Map<String, Object> submitDraftPrefs({
  String title = '',
  String answer = '',
  Map<String, List<String>> answers = const {},
  String briefId = 'c5',
}) => {
  ...signedInPrefs(),
  'submit.draft.$briefId': jsonEncode({
    'title': title,
    'answer': answer,
    'answers': answers,
  }),
};

/// The submit service answering at once at the Figma 9:41, writing into the
/// dataset the repository serves.
List<Override> instantSubmit({
  DemoAttachmentPicker? picker,
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
];
