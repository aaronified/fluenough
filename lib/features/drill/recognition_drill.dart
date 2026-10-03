import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'rating_buttons.dart';

/// Recognition: the target, big, with its reading; "Show answer"; then the
/// meaning, the note and an example, and the four self-ratings.
///
/// Design screens `drill-recognition` and `drill-recognition-revealed`.
class RecognitionDrill extends StatelessWidget {
  const RecognitionDrill({
    super.key,
    required this.session,
    required this.onClose,
  });

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = AppScope.read(context).settings;
    final card = session.item.card;
    final language = session.deck.language;
    final revealed = session.phase == DrillPhase.revealed;
    final reading = card.reading;
    final notes = card.notes;

    return DrillFrame(
      skill: session.skill,
      deckName: session.recorded || session.revising
          ? session.deck.deck.name
          : l10n.numbersPracticeTitle,
      position: session.position,
      total: session.total,
      reportDetail: '${session.item.card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      card: <Widget>[
        if (reading != null && !session.learnsAlphabet)
          ReadingFirst(
            reading: reading,
            target: card.target,
            language: language,
            fontSize: 48,
          )
        else
          TargetText.hero(card.target, language: language),
        if (reading != null &&
            settings.showRomanisation &&
            session.learnsAlphabet)
          Text(
            reading,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(
              fontSize: 18,
              height: 24 / 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        if (revealed) ...<Widget>[
          Container(
            width: 64,
            height: 4,
            margin: const EdgeInsetsDirectional.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            card.native,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          if (notes != null)
            // Padding, not a max-width box: DrillFrame measures the card's
            // intrinsic height, and a ConstrainedBox reports its child's
            // height at the full width, so wrapped notes would overflow.
            // 19 each side is the design's 280 on a phone's 318 card.
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 19),
              child: Text(
                notes,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontSize: 15,
                  height: 22 / 15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (card.examples.isNotEmpty)
            _Example(example: card.examples.first, language: language),
        ],
      ],
      actions: revealed
          ? <Widget>[
              Text(
                l10n.drillRatePrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              RatingButtons(
                intervalFor: session.recorded ? session.intervalFor : null,
                onRate: session.rate,
              ),
            ]
          : <Widget>[
              FilledButton(
                onPressed: session.reveal,
                style: AppButtonStyles.tall(context),
                child: Text(l10n.drillShowAnswer),
              ),
            ],
    );
  }
}

/// An example sentence under the meaning: the target sentence, bold, over
/// its translation.
class _Example extends StatelessWidget {
  const _Example({required this.example, required this.language});

  final CardExample example;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.drillExample,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TargetText.card(
              example.target,
              language: language,
              fontSize: 16,
              color: scheme.onSurface,
            ),
            const SizedBox(height: 2),
            Text(
              example.native,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
