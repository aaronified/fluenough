import 'package:flutter/material.dart' hide Card;

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/speaker.dart';
import 'drill_session.dart';
import 'taught_details.dart';

/// A lesson teaching a word (ADR-0024): the word and its reading, its
/// meaning, its note and an example, played aloud as it shows where the
/// phone has a voice and sound is on. Continue goes on to its first question; nothing is
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = widget.session;
    final card = session.item.card;
    final language = session.deck.language;

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
        TaughtDetails(
          card: card,
          language: language,
          // Reading first until the script is expected of the learner; else
          // under the word, whatever Show romanisation says.
          reading: session.expectsScript
              ? TaughtReading.always
              : TaughtReading.first,
          // Played as it shows, whatever Play words automatically says.
          between: session.canPlay
              ? Speaker(
                  onPlay: session.play,
                  playing: session.playing,
                  size: 136,
                  playOnAppear: true,
                )
              : null,
        ),
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
