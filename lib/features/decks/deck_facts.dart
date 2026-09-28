import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/target_text.dart';
import 'deck_content.dart';

/// "Cards": the first few cards of a deck, target, meaning and reading. Deck
/// content only — never a card id (AGENTS.md rule 1).
class CardPreview extends StatelessWidget {
  const CardPreview({super.key, required this.entry});

  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppScope.of(context).settings;
    final lines = previewOf(entry, l10n);
    if (lines.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => GroupedList(
        header: l10n.deckCards,
        outerRadius: AppRadii.card,
        children: <Widget>[
          for (final line in lines)
            _PreviewRow(
              line: line,
              entry: entry,
              showReading: settings.showRomanisation,
            ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.line,
    required this.entry,
    required this.showReading,
  });

  final PreviewLine line;
  final DeckEntry entry;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = line.reading;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 72),
                child: TargetText(
                  line.target,
                  language: entry.language,
                  fontSize: 22,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    line.native,
                    style: theme.textTheme.bodyLarge!.copyWith(fontSize: 15),
                  ),
                  if (showReading && reading != null && reading.isNotEmpty)
                    Text(
                      reading,
                      style: theme.textTheme.bodySmall!.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Licence, source, authors, voice and deck id, in an outlined box.
class DeckFacts extends StatelessWidget {
  const DeckFacts({super.key, required this.entry});

  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final deck = entry.deck;
    final tag = entry.language.ttsTag;
    final origin = deck.source;
    final authors = deck.authors;

    final facts = <(String, String, bool)>[
      (l10n.deckLicence, deck.license, false),
      (
        l10n.deckSource,
        <String>[
          entry.bundled ? l10n.deckSourceBundled : entry.fileName,
          ?origin,
        ].join('\n'),
        false,
      ),
      if (authors.isNotEmpty)
        (
          l10n.deckAuthors,
          authors.map((a) => a.name).join(l10n.commonListSeparator),
          false,
        ),
      (
        l10n.deckVoice,
        switch (state.voiceStatus(entry.language)) {
          VoiceStatus.available => l10n.deckVoiceInstalled(tag),
          VoiceStatus.missing => l10n.deckVoiceMissing(tag),
          VoiceStatus.checking => l10n.deckVoiceChecking(tag),
        },
        false,
      ),
      (l10n.deckId, deck.id, true),
    ];

    final style = theme.textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      height: 18 / 13,
    );
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        children: <TableRow>[
          for (var i = 0; i < facts.length; i++)
            TableRow(
              children: <Widget>[
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    top: i == 0 ? 0 : 8,
                    end: 16,
                  ),
                  child: Text(
                    facts[i].$1,
                    style: style.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 8),
                  child: Text(
                    facts[i].$2,
                    style: facts[i].$3
                        ? style.copyWith(fontFamily: 'monospace')
                        : style,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
