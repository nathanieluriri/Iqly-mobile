import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/deadline.dart';
import '../../data/drafts_data.dart';
import '../../data/submit_data.dart';
import '../../data/submit_service.dart';
import '../drafts/drafts_state.dart';

enum SubmitStep { answer, questions, sent }

/// Trimmed, as iqly.net counts the title, so spaces never reach a minimum.
int titleLength(Draft draft) => draft.title.trim().length;
int answerLength(Draft draft) => draft.answer.trim().length;

bool titleReady(Draft draft) => titleLength(draft) >= SubmitLimits.titleMin;
bool answerReady(Draft draft) => answerLength(draft) >= SubmitLimits.answerMin;

/// "4 more characters" (34:24, after Continue) and "4 more characters to
/// go" (313:13631, while writing).
String moreCharacters(int missing) =>
    '$missing more ${missing == 1 ? 'character' : 'characters'}';
String moreCharactersToGo(int missing) => '${moreCharacters(missing)} to go';

bool answered(Draft draft, SurveyQuestion question) =>
    (draft.answers[question.id] ?? const []).any((a) => a.trim().isNotEmpty);

/// The first question still without an answer, or null.
int? firstUnanswered(SubmitForm form, Draft draft) {
  for (final (i, q) in form.questions.indexed) {
    if (!answered(draft, q)) return i;
  }
  return null;
}

/// "Question 2 needs an answer", from Figma 34:186.
String needsAnswer(int index) => 'Question ${index + 1} needs an answer';

class SubmitFlow {
  const SubmitFlow({
    required this.draft,
    this.step = SubmitStep.answer,
    this.files = const [],
    this.fileError,
    this.answerTries = 0,
    this.sending = false,
    this.failed = false,
    this.receipt,
    this.back = false,
    this.restored,
  });

  final SubmitStep step;
  final Draft draft;
  final List<Attachment> files;

  /// iqly.net's words for a file it turns away.
  final String? fileError;

  /// Continue tapped with something missing; each try shakes.
  final int answerTries;
  final bool sending;

  /// The last send did not reach the API.
  final bool failed;
  final SubmitReceipt? receipt;

  /// The last step change went back.
  final bool back;

  /// When the draft this flow opened on was last saved (313:13650).
  final DateTime? restored;

  bool get uploading =>
      files.any((f) => f.status == AttachmentStatus.uploading);

  SubmitFlow copyWith({
    SubmitStep? step,
    Draft? draft,
    List<Attachment>? files,
    String? Function()? fileError,
    int? answerTries,
    bool? sending,
    bool? failed,
    bool? back,
  }) => SubmitFlow(
    step: step ?? this.step,
    draft: draft ?? this.draft,
    files: files ?? this.files,
    fileError: fileError == null ? this.fileError : fileError(),
    answerTries: answerTries ?? this.answerTries,
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    receipt: receipt,
    back: back ?? this.back,
    restored: restored,
  );
}

/// One brief's submit flow: the draft it autosaves, the step, the
/// attachments and the send. It opens on the brief's saved draft at the
/// step that draft reached; the screen builds it once the drafts and the
/// brief's form have loaded.
class SubmitFlowNotifier extends Notifier<SubmitFlow> {
  SubmitFlowNotifier(this.briefId);

  final String briefId;

  DateTime _now() => ref.read(clockProvider)();

  SubmitForm get _form =>
      ref.read(submitOpeningProvider(briefId)).value?.form ??
      const SubmitForm();

  @override
  SubmitFlow build() {
    final saved = ref
        .read(draftsProvider)
        .value
        ?.where((d) => d.briefId == briefId)
        .firstOrNull;
    if (saved == null || saved.isEmpty) {
      return SubmitFlow(draft: Draft(briefId: briefId, editedAt: _now()));
    }
    final questions = saved.step >= DraftSteps.questions && _form.hasQuestions;
    return SubmitFlow(
      draft: saved,
      step: questions ? SubmitStep.questions : SubmitStep.answer,
      restored: saved.editedAt,
    );
  }

  void _save(Draft draft) {
    final reached = _reached(draft);
    final next = draft.copyWith(
      step: math.max(reached, draft.step),
      editedAt: _now(),
    );
    state = state.copyWith(draft: next);
    ref.read(draftsProvider.notifier).save(next);
  }

  int _reached(Draft draft) {
    if (state.step == SubmitStep.answer) return DraftSteps.answer;
    return firstUnanswered(_form, draft) == null
        ? DraftSteps.ready
        : DraftSteps.questions;
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

  /// Takes what fits, as iqly.net does: five files at most, 10 MB each,
  /// then sends each one up.
  void addFiles(List<AttachmentFile> picked) {
    final files = [...state.files];
    final added = <AttachmentFile>[];
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
      files.add(Attachment(file));
      added.add(file);
    }
    state = state.copyWith(files: files, fileError: () => error);
    added.forEach(_upload);
  }

  static const _mb = 1024 * 1024;

  /// A failed row tapped: it goes up again.
  void retry(AttachmentFile file) {
    _update(file, (a) => a.copyWith(status: AttachmentStatus.uploading));
    _upload(file);
  }

  Future<void> _upload(AttachmentFile file) async {
    final ok = await ref
        .read(attachmentUploaderProvider)
        .upload(
          file,
          (progress) => _update(file, (a) => a.copyWith(progress: progress)),
        );
    if (!ref.mounted) return;
    _update(
      file,
      (a) => a.copyWith(
        status: ok ? AttachmentStatus.done : AttachmentStatus.failed,
        progress: ok ? 1 : 0,
      ),
    );
  }

  void _update(AttachmentFile file, Attachment Function(Attachment) change) {
    if (!ref.mounted) return;
    state = state.copyWith(
      files: [
        for (final a in state.files) identical(a.file, file) ? change(a) : a,
      ],
    );
  }

  void removeFile(int index) => state = state.copyWith(
    files: [...state.files]..removeAt(index),
    fileError: () => null,
  );

  /// Continue on the answer step: true when it moved on to the questions;
  /// otherwise the answer step shows what is missing.
  bool next() {
    if (!_answerStepReady()) return false;
    state = state.copyWith(step: SubmitStep.questions, back: false);
    _save(state.draft);
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

  /// Submit is live once every question is answered and nothing is still
  /// uploading (#37).
  bool canSend(SubmitForm form) =>
      !state.sending &&
      !state.uploading &&
      firstUnanswered(form, state.draft) == null;

  /// "Discard draft" on the leave sheet.
  Future<void> discard() =>
      ref.read(draftsProvider.notifier).discard([briefId]);

  /// Sends once every required answer is in. Null when something is missing
  /// or a send is already on its way.
  Future<SubmitResult?> send(SubmitForm form) async {
    if (!form.hasQuestions && !_answerStepReady()) return null;
    if (!canSend(form)) return null;
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
            files: [
              for (final a in state.files)
                if (a.status == AttachmentStatus.done) a.file,
            ],
          ),
        );
    if (!ref.mounted) return result;
    final receipt = result.receipt;
    if (receipt == null) {
      state = state.copyWith(sending: false, failed: true);
    } else {
      await discard();
      if (!ref.mounted) return result;
      state = SubmitFlow(
        draft: Draft(briefId: briefId, editedAt: _now()),
        step: SubmitStep.sent,
        receipt: receipt,
      );
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

/// Sign out and account deletion leave no drafts on the device: the ones
/// the earlier builds autosaved under submit.draft.<brief>.
Future<void> forgetSubmitDrafts(SharedPreferences prefs) async {
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith('submit.draft.')) await prefs.remove(key);
  }
}
