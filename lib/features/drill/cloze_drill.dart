import 'package:flutter/material.dart';

import '../../core/feedback/content_report.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'going_on.dart';
import 'input_mode_choice.dart';
import 'rearrange_drill.dart' show WordMark, WordTile;
import 'set_drill.dart';
import 'taught_details.dart';

/// Cloze (#321): the meaning on top, the sentence under it with one word the
/// learner knows left out, and a few words to choose it from. Tapping a word
/// records production: Hard if it is the missing word, 1 if not, as every
/// right choice in Write counts (ADR-0034).
///
/// The sentence and the words come in the script the learner writes in or, by
/// the Script or Latin letters choice, in Latin letters, as the word order
/// drill's tiles do. Once answered, the sentence is shown whole. Build one per
/// card (key it by the card's position).
class ClozeDrill extends StatelessWidget {
  const ClozeDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  /// What stands in the sentence where the word is missing.
  static const String blank = '____';

  @override
  Widget build(BuildContext context) {
    final view = session.clozeView;
    final made = session.cloze;
    if (view == null || made == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = session.item.card;
    final language = session.deck.language;
    // What the sentence and the words are written in: null for Latin
    // letters.
    final LanguageInfo? writing = view.reading
        ? null
        : view.script == language.script
        ? language
        : language.inScript(view.script);
    final picked = session.clozePicked;
    final answered = picked != null;
    final right = picked != null && view.isRight(picked);
    final direction = (writing?.rightToLeft ?? false)
        ? TextDirection.rtl
        : TextDirection.ltr;
    // The card's own sentence is the one asked; for an example, the word the
    // card teaches is shown under it once answered.
    final ownSentence = made.source.target == card.target;
    final sentence = view.filled(answered ? view.answer : blank);

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      report: ContentTarget.card(card.id, deck: session.deck.deck),
      progress: session.progress,
      onClose: onClose,
      going: goingOn(session, answered: answered),
      card: <Widget>[
        Text(
          l10n.drillClozePrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          made.source.native,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (writing == null)
          Text(
            sentence,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
        else
          TargetText.card(sentence, language: writing, fontSize: 28),
        if (answered)
          TaughtDetails(
            card: card,
            language: language,
            reading: TaughtReading.inReview(session),
            word: !ownSentence,
            wordSize: 24,
            wordColor: scheme.primary,
            meaning: false,
            between: ownSentence && session.canPlay
                ? Speaker(onPlay: session.play, playing: session.playing)
                : null,
          ),
        ...answeredSetList(context, session, answered: answered),
      ],
      belowCard: <Widget>[
        if (!answered && session.clozeSwitchable)
          InputModeChoice(session: session, onChanged: () {}),
        Semantics(
          container: true,
          label: l10n.drillClozeOptions,
          child: Wrap(
            textDirection: direction,
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              // Answered, only the right word and, when the learner chose
              // wrong, the one they chose, marked wrong.
              for (final option in view.options)
                if (!answered || view.isRight(option) || option == picked)
                  WordTile(
                    text: option,
                    language: writing,
                    onTap: answered ? null : () => session.pickCloze(option),
                    mark: !answered
                        ? null
                        : view.isRight(option)
                        ? WordMark.right
                        : WordMark.wrong,
                  ),
            ],
          ),
        ),
      ],
      feedback: !answered
          ? null
          : alreadyAnswered(context, session) ??
                (right
                    ? FeedbackBanner(
                        kind: FeedbackKind.correct,
                        title: l10n.feedbackCorrect,
                      )
                    : FeedbackBanner(
                        kind: FeedbackKind.wrong,
                        title: l10n.feedbackWrong,
                        detail: l10n.feedbackAnswer(view.answer),
                        quotes: <String>[if (writing != null) view.answer],
                        language: writing,
                      )),
    );
  }
}
