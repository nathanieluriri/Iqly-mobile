import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session.dart';
import '../../data/submit_data.dart';
import '../../data/submit_service.dart';

/// What autosaves until the response goes ("Drafts autosave until you
/// send."): the title, the answer and the quick answers, per brief, as
/// iqly.net keeps them. Attachments are not kept.
class SubmitDraft {
  const SubmitDraft({
    this.title = '',
    this.answer = '',
    this.answers = const {},
  });

  final String title;
  final String answer;

  /// Question id to the options picked, or the typed answer as one entry.
  final Map<String, List<String>> answers;

  bool get isEmpty => title.isEmpty && answer.isEmpty && answers.isEmpty;

  SubmitDraft copyWith({
    String? title,
    String? answer,
    Map<String, List<String>>? answers,
  }) => SubmitDraft(
    title: title ?? this.title,
    answer: answer ?? this.answer,
    answers: answers ?? this.answers,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'answer': answer,
    'answers': answers,
  };

  static SubmitDraft fromJson(Map<String, Object?> json) => SubmitDraft(
    title: json['title'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
    answers: {
      for (final MapEntry(:key, :value)
          in (json['answers'] as Map<String, Object?>? ?? const {}).entries)
        key: [...(value as List<Object?>? ?? const [])].cast<String>(),
    },
  );
}

enum SubmitStep { answer, questions, sent }

/// Trimmed, as iqly.net counts the title, so spaces never reach a minimum.
int titleLength(SubmitDraft draft) => draft.title.trim().length;
int answerLength(SubmitDraft draft) => draft.answer.trim().length;

bool titleReady(SubmitDraft draft) =>
    titleLength(draft) >= SubmitLimits.titleMin;
bool answerReady(SubmitDraft draft) =>
    answerLength(draft) >= SubmitLimits.answerMin;

/// "4 more characters", from Figma 34:24.
String moreCharacters(int missing) =>
    '$missing more ${missing == 1 ? 'character' : 'characters'}';

bool answered(SubmitDraft draft, SurveyQuestion question) =>
    (draft.answers[question.id] ?? const []).any((a) => a.trim().isNotEmpty);

/// The first question still without an answer, or null.
int? firstUnanswered(SubmitForm form, SubmitDraft draft) {
  for (final (i, q) in form.questions.indexed) {
    if (!answered(draft, q)) return i;
  }
  return null;
}

/// "Question 2 needs an answer", from Figma 34:186.
String needsAnswer(int index) => 'Question ${index + 1} needs an answer';

class SubmitFlow {
  const SubmitFlow({
    this.step = SubmitStep.answer,
    this.draft = const SubmitDraft(),
    this.files = const [],
    this.fileError,
    this.answerTries = 0,
    this.questionTries = 0,
    this.sending = false,
    this.failed = false,
    this.receipt,
    this.back = false,
  });

  final SubmitStep step;
  final SubmitDraft draft;
  final List<AttachmentFile> files;

  /// iqly.net's words for a file it turns away.
  final String? fileError;

  /// Continue or Send tapped with something missing; each try shakes.
  final int answerTries;
  final int questionTries;
  final bool sending;

  /// The last send did not reach the API.
  final bool failed;
  final SubmitReceipt? receipt;

  /// The last step change went back.
  final bool back;

  SubmitFlow copyWith({
    SubmitStep? step,
    SubmitDraft? draft,
    List<AttachmentFile>? files,
    String? Function()? fileError,
    int? answerTries,
    int? questionTries,
    bool? sending,
    bool? failed,
    bool? back,
  }) => SubmitFlow(
    step: step ?? this.step,
    draft: draft ?? this.draft,
    files: files ?? this.files,
    fileError: fileError == null ? this.fileError : fileError(),
    answerTries: answerTries ?? this.answerTries,
    questionTries: questionTries ?? this.questionTries,
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    receipt: receipt,
    back: back ?? this.back,
  );
}

/// One brief's submit flow: the autosaved draft, the step, the attachments
/// and the send.
class SubmitFlowNotifier extends Notifier<SubmitFlow> {
  SubmitFlowNotifier(this.briefId);

  final String briefId;

  static const _prefix = 'submit.draft.';

  String get _key => '$_prefix$briefId';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  SubmitFlow build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const SubmitFlow();
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return SubmitFlow(draft: SubmitDraft.fromJson(json));
    } on FormatException {
      return const SubmitFlow();
    }
  }

  void _save(SubmitDraft draft) {
    state = state.copyWith(draft: draft);
    if (draft.isEmpty) {
      _prefs.remove(_key);
    } else {
      _prefs.setString(_key, jsonEncode(draft.toJson()));
    }
  }

  void setTitle(String title) => _save(state.draft.copyWith(title: title));

  void setAnswer(String answer) => _save(state.draft.copyWith(answer: answer));

  /// A single choice keeps the one picked; a multiple choice toggles it.
  void pick(SurveyQuestion question, String option) {
    final given = state.draft.answers[question.id] ?? const <String>[];
    final next = !question.multi
        ? [option]
        : given.contains(option)
        ? [...given.where((o) => o != option)]
        : [...given, option];
    _answer(question, next);
  }

  void type(SurveyQuestion question, String text) =>
      _answer(question, text.isEmpty ? const [] : [text]);

  void _answer(SurveyQuestion question, List<String> given) {
    final answers = {...state.draft.answers};
    if (given.isEmpty) {
      answers.remove(question.id);
    } else {
      answers[question.id] = given;
    }
    _save(state.draft.copyWith(answers: answers));
  }

  /// Takes what fits, as iqly.net does: five files at most, 10 MB each.
  void addFiles(List<AttachmentFile> picked) {
    final files = [...state.files];
    String? error;
    for (final file in picked) {
      if (files.length >= SubmitLimits.files) {
        error = 'Max ${SubmitLimits.files} files.';
        break;
      }
      if (file.bytes > SubmitLimits.fileBytes) {
        error = '${file.name} exceeds ${SubmitLimits.fileBytes ~/ _mb} MB.';
        continue;
      }
      files.add(file);
    }
    state = state.copyWith(files: files, fileError: () => error);
  }

  static const _mb = 1024 * 1024;

  void removeFile(int index) => state = state.copyWith(
    files: [...state.files]..removeAt(index),
    fileError: () => null,
  );

  /// Continue on the answer step: true when it moved on to the questions;
  /// otherwise the answer step shows what is missing.
  bool next() {
    if (!_answerStepReady()) return false;
    state = state.copyWith(step: SubmitStep.questions, back: false);
    return true;
  }

  void back() {
    if (state.step != SubmitStep.questions) return;
    state = state.copyWith(step: SubmitStep.answer, back: true);
  }

  bool _answerStepReady() {
    final draft = state.draft;
    if (titleReady(draft) && answerReady(draft)) return true;
    state = state.copyWith(answerTries: state.answerTries + 1);
    return false;
  }

  /// Sends once every required answer is in. Null when something is missing
  /// (the step shows it) or a send is already on its way.
  Future<SubmitResult?> send(SubmitForm form) async {
    if (state.sending) return null;
    if (!form.hasQuestions && !_answerStepReady()) return null;
    if (firstUnanswered(form, state.draft) != null) {
      state = state.copyWith(questionTries: state.questionTries + 1);
      return null;
    }
    state = state.copyWith(sending: true, failed: false);
    final draft = state.draft;
    final result = await ref
        .read(submitServiceProvider)
        .submit(
          SubmitRequest(
            briefId: briefId,
            title: draft.title.trim(),
            answer: draft.answer.trim(),
            answers: {
              for (final q in form.questions)
                q.id: [
                  for (final a in draft.answers[q.id] ?? const <String>[])
                    a.trim(),
                ],
            },
            files: state.files,
          ),
        );
    if (!ref.mounted) return result;
    final receipt = result.receipt;
    if (receipt == null) {
      state = state.copyWith(sending: false, failed: true);
    } else {
      await _prefs.remove(_key);
      if (!ref.mounted) return result;
      state = SubmitFlow(step: SubmitStep.sent, receipt: receipt);
    }
    return result;
  }
}

final submitFlowProvider = NotifierProvider.autoDispose
    .family<SubmitFlowNotifier, SubmitFlow, String>(SubmitFlowNotifier.new);

/// The brief, its form, or why it cannot take a response.
final submitOpeningProvider = FutureProvider.autoDispose
    .family<SubmitOpening, String>(
      retry: (_, _) => null,
      (ref, briefId) => ref.watch(submitServiceProvider).open(briefId),
    );

/// Sign out and account deletion leave no drafts on the device.
Future<void> forgetSubmitDrafts(SharedPreferences prefs) async {
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith(SubmitFlowNotifier._prefix)) await prefs.remove(key);
  }
}
