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
    // A synonym of the answer: the card's own answer, then what else counted.
    String withHint(String detail, String word) =>
        '$detail\n${_alsoHint(l10n, word)}';
    return switch (graded.outcome) {
      AnswerOutcome.exact when graded.viaSynonym => banner(
        FeedbackKind.correct,
        l10n.feedbackCorrect,
        withHint(shown(graded.matched), answer.typed),
      ),
      AnswerOutcome.exact => banner(
        FeedbackKind.correct,
        l10n.feedbackCorrect,
        // Said: what the phone heard is in the box under the card, so the
        // banner only says it was as said (#509).
        spoken ? l10n.feedbackSpokenRight : shown(null),
      ),
      AnswerOutcome.closeDiacritics when spoken && answer.contrast != null =>
        banner(
          FeedbackKind.close,
          l10n.feedbackLengthClose,
          '${l10n.feedbackSaidContrast(answer.typed, answer.contrast!.name)}'
          '\n${l10n.feedbackAnswer(shown(graded.matched))}',
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
        graded.viaSynonym
            ? withHint(
                l10n.feedbackTypoDetail(answer.typed),
                graded.synonym ?? answer.typed,
              )
            : l10n.feedbackTypoDetail(answer.typed),
      ),
      AnswerOutcome.wrong => banner(
        FeedbackKind.wrong,
        l10n.feedbackWrong,
        spoken
            ? _spokenWrong(l10n, answer, shown(null))
            : l10n.feedbackAnswer(shown(null)),
      ),
    };
  }

  /// "Also: take care" for one or two words, "Also right" for more
  /// (ADR-0050): a hint is a word or two, so a long answer is not repeated.
  static String _alsoHint(AppLocalizations l10n, String word) {
    final shown = word.trim().replaceAll(RegExp(r'[\s.!?,;:]+$'), '');
    final words = shown.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length > 2
        ? l10n.feedbackAlsoRight
        : l10n.feedbackAlsoTyped(
            words.length == 1 ? shown.toLowerCase() : shown,
          );
  }

  /// The answer, and, when what was heard differs from it by one named
  /// sound, the difference (#89). What was heard is in the box under the
  /// card, with its reading or IPA (#509), not here.
  String _spokenWrong(AppLocalizations l10n, TypedAnswer answer, String shown) {
    final answerLine = l10n.feedbackAnswer(shown);
    final contrast = answer.contrast;
    return contrast == null
        ? answerLine
        : '$answerLine\n${l10n.feedbackSaidDifference(contrast.name)}';
  }
}
