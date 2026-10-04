import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/play_button.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';

/// A lesson teaching a word (ADR-0024): the word and its reading, its
/// meaning, its note and an example, played aloud as it shows where the
/// phone has a voice. Continue goes on to its first question; nothing is
/// recorded.
///
/// Build one per card (key it by the card's position).
class TeachDrill extends StatefulWidget {
  const TeachDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  @override
  State<TeachDrill> createState() => _TeachDrillState();
}

class _TeachDrillState extends State<TeachDrill> {
  @override
  void initState() {
    super.initState();
    if (widget.session.canPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.session.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = widget.session;
    final card = session.item.card;
    final language = session.deck.language;
    final reading = card.reading;
    final notes = card.notes;

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: widget.onClose,
      card: <Widget>[
        Text(
          l10n.drillTeachTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (reading != null && !session.expectsScript)
          ReadingFirst(
            reading: reading,
            target: card.target,
            language: language,
            fontSize: 48,
          )
        else ...<Widget>[
          TargetText.hero(card.target, language: language),
          if (reading != null)
            Text(
              reading,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                fontSize: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
        Text(
          card.native,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        if (session.canPlay)
          PlayButton(onPressed: session.play, playing: session.playing),
        if (notes != null)
          // Padding, not a max-width box: DrillFrame measures the card's
          // intrinsic height (see RecognitionDrill).
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
      actions: <Widget>[
        FilledButton(
          onPressed: session.learnt,
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

/// An example sentence under the meaning, as recognition shows it.
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
