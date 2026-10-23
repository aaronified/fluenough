import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

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
    final backup = state.backupVoice(entry.language);
    final origin = deck.source;
    final authors = deck.authors;
    // Each recording's credit (#518): whom, and its licence.
    final recordings = <String>[
      for (final card in deck.cards)
        if (card.audioCredit case final credit?)
          l10n.deckMediaCredit(card.target, credit.credit, credit.license),
    ];
    // Each image's credit (#523): whom, and its licence.
    final images = <String>[
      for (final card in deck.cards)
        if (card.imageCredit case final credit?)
          l10n.deckMediaCredit(card.target, credit.credit, credit.license),
    ];

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
      if (recordings.isNotEmpty)
        (l10n.deckRecordings, recordings.join('\n'), false),
      if (images.isNotEmpty) (l10n.deckImages, images.join('\n'), false),
      (
        l10n.deckVoice,
        switch (state.voiceStatus(entry.language)) {
          VoiceStatus.available => l10n.deckVoiceInstalled(tag),
          VoiceStatus.missing =>
            backup == null
                ? l10n.deckVoiceMissing(tag)
                : l10n.deckVoiceBackup(tag, backup.ttsTag),
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
