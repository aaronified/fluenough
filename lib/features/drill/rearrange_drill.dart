import 'package:flutter/material.dart';

import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'going_on.dart';
import 'set_drill.dart';
import 'input_mode_choice.dart';
import 'taught_details.dart';

/// Rearrange (ADR-0024): the meaning, and the sentence's words shuffled
/// below. Tapping a word puts it next on the answer line; tapping it there
/// takes it back. Check, once every word is placed, records production: 5
/// if the words read as the sentence, 1 if not.
///
/// The words come in Latin letters while typed answers would, and the
/// Script or Latin letters choice switches them. Once answered, the card
/// shows what the sentence's lesson showed ([TaughtDetails]). Build one per
/// card (key it by the card's position).
class RearrangeDrill extends StatelessWidget {
  const RearrangeDrill({
    super.key,
    required this.session,
    required this.onClose,
  });

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = session.item.card;
    final language = session.deck.language;
    // The script the words are put in order in (#623).
    final writing = session.inputLanguage;
    final answer = session.answer;
    final latin = session.rearrangesReading;
    final tiles = session.tiles;
    final placed = session.placed;
    final reading = card.reading;
    // The tiles lay out in the direction of what they are written in, not
    // the interface's: an Urdu sentence reads from the right in an English
    // app (#619). Latin letters read from the left whatever the deck.
    final direction = !latin && writing.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      going: goingOn(session, answered: answer != null),
      card: <Widget>[
        Text(
          l10n.drillRearrangePrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          card.native,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        // The meaning is the prompt above. Only now: hearing it would give
        // the order away.
        if (answer != null)
          TaughtDetails(
            card: card,
            language: language,
            reading: TaughtReading.inReview(session),
            wordSize: 24,
            wordColor: scheme.primary,
            meaning: false,
            between: session.canPlay
                ? Speaker(onPlay: session.play, playing: session.playing)
                : null,
          ),
        ...answeredSetList(context, session, answered: answer != null),
      ],
      belowCard: <Widget>[
        if (answer == null && session.canTransliterate)
          InputModeChoice(session: session, onChanged: () {}),
        ...rearrangeBoard(
          context,
          tiles: tiles,
          placed: placed,
          language: latin ? null : writing,
          direction: direction,
          answered: answer != null,
          onPlace: session.place,
          onUnplace: session.unplace,
          // Answered, the right order and, when the learner arranged the
          // words wrong, their own arrangement too, marked wrong (owner,
          // 2026-10-31, doubt 13).
          rightOrder: answer == null ? null : session.answerWords,
          correct: answer?.graded?.outcome.isCorrect,
        ),
      ],
      feedback: answer == null
          ? null
          : alreadyAnswered(context, session) ??
                (answer.graded!.outcome.isCorrect
                    ? FeedbackBanner(
                        kind: FeedbackKind.correct,
                        title: l10n.feedbackCorrect,
                      )
                    : FeedbackBanner(
                        kind: FeedbackKind.wrong,
                        title: l10n.feedbackWrong,
                        detail: l10n.feedbackAnswer(
                          latin && reading != null
                              ? reading
                              : session.writtenTarget,
                        ),
                        quotes: <String>[if (!latin) session.writtenTarget],
                        language: latin ? null : writing,
                      )),
      // Check, while there is an order to check; once answered, going on is
      // the swipe and the chevron.
      actions: <Widget>[
        if (answer == null)
          FilledButton(
            onPressed: placed.length == tiles.length
                ? session.checkOrder
                : null,
            style: AppButtonStyles.tall(context),
            child: Text(l10n.drillCheck),
          ),
      ],
    );
  }
}

/// The answer line and the words left to place, the two parts of a
/// rearrange question's answer area, shared by the review's [RearrangeDrill]
/// and placement's sentence question: tapping a word puts it next on the
/// line, and tapping it there takes it back. [language] is the words'
/// language, or null for Latin letters; [direction] lays them out; once
/// [answered] the words are no longer tappable.
List<Widget> rearrangeBoard(
  BuildContext context, {
  required List<String> tiles,
  required List<int> placed,
  required LanguageInfo? language,
  required TextDirection direction,
  required bool answered,
  required ValueChanged<int> onPlace,
  required ValueChanged<int> onUnplace,
  List<String>? rightOrder,
  bool? correct,
}) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  Widget word(int index, {required bool inAnswer}) => WordTile(
    text: tiles[index],
    language: language,
    hint: inAnswer ? l10n.drillRearrangeTakeBack : null,
    onTap: answered
        ? null
        : inAnswer
        ? () => onUnplace(index)
        : () => onPlace(index),
  );
  // Answered with the right order known: it is drawn as the answer, in the
  // colour of Correct, and a wrong arrangement is drawn under it, in the
  // error colour, under a line saying it is wrong.
  if (answered && rightOrder != null && correct != null) {
    Widget line(List<String> words, WordMark mark, String label) => Semantics(
      container: true,
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
        child: Wrap(
          textDirection: direction,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final text in words)
              WordTile(text: text, language: language, onTap: null, mark: mark),
          ],
        ),
      ),
    );
    final theme = Theme.of(context);
    final caption = theme.textTheme.labelLarge!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Text(l10n.drillRearrangeRight, style: caption),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outline, width: 2),
              ),
            ),
            child: line(rightOrder, WordMark.right, l10n.drillRearrangeRight),
          ),
          if (!correct) ...<Widget>[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.highlight_off, size: 18, color: scheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(l10n.drillRearrangeYours, style: caption),
                  ),
                ],
              ),
            ),
            line(
              <String>[for (final index in placed) tiles[index]],
              WordMark.wrong,
              l10n.drillRearrangeYours,
            ),
          ],
        ],
      ),
    ];
  }
  return <Widget>[
    Semantics(
      container: true,
      label: l10n.drillRearrangeAnswer,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outline, width: 2)),
        ),
        child: Wrap(
          textDirection: direction,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final index in placed) word(index, inAnswer: true),
          ],
        ),
      ),
    ),
    if (!answered)
      Semantics(
        container: true,
        label: l10n.drillRearrangeWords,
        child: Wrap(
          textDirection: direction,
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (var i = 0; i < tiles.length; i++)
              placed.contains(i)
                  // Its place kept, so the others don't move.
                  ? ExcludeSemantics(
                      child: Visibility.maintain(
                        visible: false,
                        child: word(i, inAnswer: false),
                      ),
                    )
                  : word(i, inAnswer: false),
          ],
        ),
      ),
  ];
}

/// How a word tile is drawn once the order is checked.
enum WordMark { right, wrong }

/// One word to place: in the deck's [language], or in Latin letters when
/// that is null.
class WordTile extends StatelessWidget {
  const WordTile({
    super.key,
    required this.text,
    required this.language,
    required this.onTap,
    this.hint,
    this.mark,
  });

  final String text;
  final LanguageInfo? language;
  final VoidCallback? onTap;
  final String? hint;

  /// Set once the order is checked: the tile is in the right order or in the
  /// learner's wrong one, in the colours of Correct and Not quite.
  final WordMark? mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = this.language;
    final (Color bg, Color fg, Color? edge) = switch (mark) {
      WordMark.right => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        null,
      ),
      WordMark.wrong => (scheme.errorContainer, scheme.onErrorContainer, null),
      null => (scheme.surfaceContainerLow, scheme.onSurface, scheme.outline),
    };
    return Semantics(
      button: mark == null,
      hint: hint,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          side: edge == null ? BorderSide.none : BorderSide(color: edge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: language == null
                  ? Text(
                      text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: mark == null ? null : fg,
                      ),
                    )
                  : TargetText.card(
                      text,
                      language: language,
                      fontSize: 18,
                      color: fg,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
