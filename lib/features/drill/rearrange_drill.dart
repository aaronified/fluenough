import 'package:flutter/material.dart';

import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'input_mode_choice.dart';

/// Rearrange (ADR-0024): the meaning, and the sentence's words shuffled
/// below. Tapping a word puts it next on the answer line; tapping it there
/// takes it back. Check, once every word is placed, records production: 5
/// if the words read as the sentence, 1 if not.
///
/// The words come in Latin letters while typed answers would, and the
/// Script or Latin letters choice switches them. Build one per card (key it
/// by the card's position).
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
    final answer = session.answer;
    final latin = session.rearrangesReading;
    final tiles = session.tiles;
    final placed = session.placed;
    final reading = card.reading;

    Widget word(int index, {required bool inAnswer}) => _WordTile(
      text: tiles[index],
      language: latin ? null : language,
      hint: inAnswer ? l10n.drillRearrangeTakeBack : null,
      onTap: answer != null
          ? null
          : inAnswer
          ? () => session.unplace(index)
          : () => session.place(index),
    );

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
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
        if (answer != null)
          reading != null && !session.learnsAlphabet
              ? ReadingFirst(
                  reading: reading,
                  target: card.target,
                  language: language,
                  fontSize: 24,
                  color: scheme.primary,
                )
              : TargetText.card(
                  card.target,
                  language: language,
                  fontSize: 24,
                  color: scheme.primary,
                ),
      ],
      belowCard: <Widget>[
        if (answer == null && session.canTransliterate)
          InputModeChoice(session: session, onChanged: () {}),
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
              border: Border(
                bottom: BorderSide(color: scheme.outline, width: 2),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final index in placed) word(index, inAnswer: true),
              ],
            ),
          ),
        ),
        if (answer == null)
          Semantics(
            container: true,
            label: l10n.drillRearrangeWords,
            child: Wrap(
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
      ],
      feedback: answer == null
          ? null
          : answer.graded!.outcome.isCorrect
          ? FeedbackBanner(
              kind: FeedbackKind.correct,
              title: l10n.feedbackCorrect,
            )
          : FeedbackBanner(
              kind: FeedbackKind.wrong,
              title: l10n.feedbackWrong,
              detail: l10n.feedbackAnswer(
                latin && reading != null ? reading : card.target,
              ),
              quotes: <String>[if (!latin) card.target],
              language: latin ? null : language,
            ),
      actions: <Widget>[
        if (answer == null)
          FilledButton(
            onPressed: placed.length == tiles.length
                ? session.checkOrder
                : null,
            style: AppButtonStyles.tall(context),
            child: Text(l10n.drillCheck),
          )
        else
          FilledButton(
            onPressed: session.next,
            style: AppButtonStyles.tall(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(child: Text(l10n.commonContinue)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward, size: 22),
              ],
            ),
          ),
      ],
    );
  }
}

/// One word to place: in the deck's [language], or in Latin letters when
/// that is null.
class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.text,
    required this.language,
    required this.onTap,
    this.hint,
  });

  final String text;
  final LanguageInfo? language;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = this.language;
    return Semantics(
      button: true,
      hint: hint,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
          side: BorderSide(color: scheme.outline),
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
                      ),
                    )
                  : TargetText.card(
                      text,
                      language: language,
                      fontSize: 18,
                      color: scheme.onSurface,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
