import 'package:flutter/material.dart' hide Card;

import '../../core/grading/answer_grader.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/feedback_banner.dart';
import 'drill_session.dart';

/// The feedback banner for a typed answer: which of the design's five
/// outcomes it was, said in words as well as colour.
///
/// | Outcome | Kind | Title | Detail |
/// | --- | --- | --- | --- |
/// | exact | correct | Correct | the answer |
/// | accent, article or both | close | Right, but mind… | You typed “x”. Written: y |
/// | near miss | nearMiss | Almost. Did you mean y? | You typed “x”. Near misses… |
/// | wrong | wrong | Not quite | Answer: y |
/// | Don't know | wrong | Here it is | Answer: y |
///
/// For a missed accent or article the grade is 4 whichever it was; the
/// grader's flags only choose the words.
class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({
    super.key,
    required this.answer,
    required this.card,
    required this.expected,
    required this.transliterating,
    this.language,
    this.spoken = false,
  });

  final TypedAnswer answer;
  final Card card;

  /// The canonical answer: the card's target, or a generated number's digits
  /// when it was heard.
  final String expected;

  /// Whether the answer was typed in Latin letters: the answer is then shown
  /// as the reading with the target after it.
  final bool transliterating;

  /// The deck's language, in which a screen reader reads the answer and what
  /// was typed. Null when they are not in it: a heard number's digits.
  final LanguageInfo? language;

  /// Whether the answer was said, not typed: the detail says what was heard
  /// (#89).
  final bool spoken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final graded = answer.graded;

    String shown(String? matched) {
      final reading = card.reading;
      if (transliterating && reading != null) {
        return l10n.feedbackReadingWithTarget(reading, card.target);
      }
      return matched ?? expected;
    }

    // Latin letters typed for a transliteration are not the deck's script.
    final quotes = <String>[
      card.target,
      expected,
      ?graded?.matched,
      if (!transliterating) answer.typed,
    ];
    FeedbackBanner banner(FeedbackKind kind, String title, String detail) =>
        FeedbackBanner(
          kind: kind,
          title: title,
          detail: detail,
          quotes: quotes,
          language: language,
        );

    if (graded == null) {
      return banner(
        FeedbackKind.wrong,
        l10n.feedbackGaveUp,
        l10n.feedbackAnswer(shown(null)),
      );
    }
    return switch (graded.outcome) {
      AnswerOutcome.exact => banner(
        FeedbackKind.correct,
        l10n.feedbackCorrect,
        shown(null),
      ),
      AnswerOutcome.closeDiacritics => banner(
        FeedbackKind.close,
        graded.droppedArticle && graded.foldedDiacritics
            ? l10n.feedbackAccentAndArticle
            : graded.droppedArticle
            ? l10n.feedbackArticle
            : l10n.feedbackAccent,
        spoken
            ? l10n.feedbackSaidWritten(answer.typed, shown(graded.matched))
            : l10n.feedbackTypedWritten(answer.typed, shown(graded.matched)),
      ),
      AnswerOutcome.closeTypo => banner(
        FeedbackKind.nearMiss,
        l10n.feedbackTypo(shown(graded.matched)),
        l10n.feedbackTypoDetail(answer.typed),
      ),
      AnswerOutcome.wrong => banner(
        FeedbackKind.wrong,
        l10n.feedbackWrong,
        !spoken
            ? l10n.feedbackAnswer(shown(null))
            : switch ((answer.contrast, answer.heardCard)) {
                // The word heard is the answer with one sound changed:
                // name the sound, and what the other word means (#89).
                (final contrast?, final heard?) =>
                  l10n.feedbackSaidContrastMeaning(
                    answer.typed,
                    heard.native,
                    contrast.name,
                    shown(null),
                  ),
                (final contrast?, null) => l10n.feedbackSaidContrast(
                  answer.typed,
                  contrast.name,
                  shown(null),
                ),
                _ => l10n.feedbackSaidAnswer(answer.typed, shown(null)),
              },
      ),
    };
  }
}
