/// The file the daily questions' answers are sent as, one per language,
/// attached to one mail to Fluenough (#519), the same route as a review.
///
/// Like a review's file it stands on its own: the rater code, the language,
/// the app version and when it was made are inside, so the mail's subject
/// and body may be changed. `tools/mail_to_issues.py` knows one by
/// [format]; `tools/review_bot.py` counts the answers.
library;

import 'dart:convert';

import 'question_log.dart';
import 'rater_code.dart';

abstract final class QuestionsFile {
  /// What a questions file says it is, under `format`.
  static const String format = 'fluenough-questions';

  /// The file format's version, under `version`. Raised only when a field
  /// changes meaning; a new field does not need it.
  static const int version = 1;

  static const String mimeType = 'application/json';

  static String name(String language) => 'fluenough-questions-$language.json';

  /// The languages of [answers], in the order they first come.
  static List<String> languagesOf(Iterable<LoggedAnswer> answers) =>
      <String>{for (final a in answers) a.language}.toList();

  /// [language]'s part of [answers] as the file's text, made at [made] by
  /// [code] with app [appVersion].
  static String encode(
    Iterable<LoggedAnswer> answers, {
    required String language,
    required RaterCode code,
    required String appVersion,
    required DateTime made,
  }) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'format': format,
      'version': version,
      'rater_code': '$code',
      'language': language,
      'app_version': appVersion,
      'made': made.toUtc().toIso8601String(),
      'answers': <Object?>[
        for (final a in answers)
          if (a.language == language)
            <String, Object?>{
              'card': a.card,
              'point': a.point,
              'kind': a.kind.wire,
              'answer': a.answer.wire,
              'reason': ?a.reason,
              if (a.why.isNotEmpty) 'why': a.why,
            },
      ],
    });
  }
}

/// The mail the answers go in.
abstract final class QuestionsMail {
  /// What the subject starts with. English, whatever the app's language, as
  /// the mail workflow reads it.
  static const String subjectPrefix = '[Fluenough questions]';

  /// `[Fluenough questions] FL-7K3M-Q9TD-6 (hi, bn)`.
  static String subject(RaterCode code, Iterable<String> languages) =>
      '$subjectPrefix $code (${languages.join(', ')})';
}
