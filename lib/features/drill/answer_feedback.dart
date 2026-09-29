import 'package:flutter/material.dart' hide Card;

import '../../core/grading/answer_grader.dart';
import '../../core/models/card.dart';
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
  });

  final TypedAnswer answer;
  final Card card;

  /// The canonical answer: the card's target, or a generated number's digits
  /// when it was heard.
  final String expected;

  /// Whether the answer was typed in Latin letters: the answer is then shown
  /// as the reading with the target after it.
  final bool transliterating;

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

    if (graded == null) {
      return FeedbackBanner(
        kind: FeedbackKind.wrong,
        title: l10n.feedbackGaveUp,
        detail: l10n.feedbackAnswer(shown(null)),
      );
    }
    return switch (graded.outcome) {
      AnswerOutcome.exact => FeedbackBanner(
        kind: FeedbackKind.correct,
        title: l10n.feedbackCorrect,
        detail: shown(null),
      ),
      AnswerOutcome.closeDiacritics => FeedbackBanner(
        kind: FeedbackKind.close,
        title: graded.droppedArticle && graded.foldedDiacritics
            ? l10n.feedbackAccentAndArticle
            : graded.droppedArticle
            ? l10n.feedbackArticle
            : l10n.feedbackAccent,
        detail: l10n.feedbackTypedWritten(answer.typed, shown(graded.matched)),
      ),
      AnswerOutcome.closeTypo => FeedbackBanner(
        kind: FeedbackKind.nearMiss,
        title: l10n.feedbackTypo(shown(graded.matched)),
        detail: l10n.feedbackTypoDetail(answer.typed),
      ),
      AnswerOutcome.wrong => FeedbackBanner(
        kind: FeedbackKind.wrong,
        title: l10n.feedbackWrong,
        detail: l10n.feedbackAnswer(shown(null)),
      ),
    };
  }
}
