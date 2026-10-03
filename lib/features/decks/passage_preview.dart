import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/reading.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/target_text.dart';

/// "Passages": a reading deck's passages (#98), each its title, first
/// sentence with its reading, how many questions it asks, and where it
/// comes from. Deck content only, never an id (AGENTS.md rule 1).
class PassagePreview extends StatelessWidget {
  const PassagePreview({super.key, required this.entry});

  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppScope.of(context).settings;
    final passages = entry.deck.passages;
    if (passages.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => GroupedList(
        header: l10n.deckPassages,
        outerRadius: AppRadii.card,
        children: <Widget>[
          for (final passage in passages)
            _PassageRow(
              passage: passage,
              entry: entry,
              showReading: settings.showRomanisation,
            ),
        ],
      ),
    );
  }
}

class _PassageRow extends StatelessWidget {
  const _PassageRow({
    required this.passage,
    required this.entry,
    required this.showReading,
  });

  final Passage passage;
  final DeckEntry entry;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall!.copyWith(
      fontSize: 13,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final first = passage.sentences.first;
    final reading = first.reading;
    final source = passage.source ?? entry.deck.source;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(passage.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            TargetText(
              first.text,
              language: entry.language,
              fontSize: 20,
              textAlign: TextAlign.start,
            ),
            if (showReading && reading != null) Text(reading, style: secondary),
            const SizedBox(height: 4),
            Text(
              l10n.deckPassageQuestions(passage.questions.length),
              style: secondary,
            ),
            if (source != null)
              Text(l10n.readingSource(source), style: secondary),
          ],
        ),
      ),
    );
  }
}
