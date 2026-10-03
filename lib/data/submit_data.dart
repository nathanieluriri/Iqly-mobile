import 'models.dart';

/// The submit form's limits, as iqly.net enforces them.
abstract final class SubmitLimits {
  static const titleMin = 5;
  static const titleMax = 120;
  static const answerMin = 20;
  static const answerMax = 5000;
  static const questionMax = 500;
  static const files = 5;
  static const fileBytes = 10 * 1024 * 1024;
}

/// One of the business's audience questions (iqly.net audienceSurvey): a
/// choice when it has [options], free text otherwise. Every one is required.
class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.text,
    this.options = const [],
    this.multi = false,
  });

  final String id;
  final String text;
  final List<String> options;

  /// Several options may be picked.
  final bool multi;

  bool get choice => options.isNotEmpty;
}

/// What a brief asks for beyond the title and the answer.
class SubmitForm {
  const SubmitForm({this.questions = const [], this.acceptsFiles = false});

  final List<SurveyQuestion> questions;
  final bool acceptsFiles;

  /// The quick questions step (34:186) only exists when there is something
  /// to put on it.
  bool get hasQuestions => questions.isNotEmpty || acceptsFiles;
}

class AttachmentFile {
  const AttachmentFile({required this.name, required this.bytes});

  final String name;
  final int bytes;
}

class SubmitRequest {
  const SubmitRequest({
    required this.briefId,
    required this.title,
    required this.answer,
    this.answers = const {},
    this.files = const [],
  });

  final String briefId;
  final String title;
  final String answer;

  /// Question id to the options picked, or the typed answer as one entry.
  final Map<String, List<String>> answers;
  final List<AttachmentFile> files;
}

/// A sent submission and how many entries the brief holds with it, when the
/// API says.
class SubmitReceipt {
  const SubmitReceipt({required this.submission, this.entries});

  final Submission submission;
  final int? entries;
}

/// Demo values from the B3 frames. Only Sunline (c5) asks quick questions
/// and takes attachments (34:186); every other brief is the answer step
/// alone. The picked file stands in for the photo library.
abstract final class SubmitDemo {
  static const forms = <String, SubmitForm>{
    'c5': SubmitForm(
      questions: [
        SurveyQuestion(
          id: 'language',
          text: 'Which language should lead?',
          options: ['English', 'Pidgin', 'Both, side by side'],
        ),
        SurveyQuestion(
          id: 'placement',
          text: 'Where would you put this line first?',
        ),
      ],
      acceptsFiles: true,
    ),
  };

  static const pickedFile = AttachmentFile(name: 'IMG_0412.jpg', bytes: 245760);
}
