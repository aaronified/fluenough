import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';

/// One source a deck names, and what kind of deck names it.
typedef DeckSourceLine = ({String source, DeckKind kind});

/// The sources [decks] name, by language, in the order the decks come:
/// each deck's own `source`, then its passages' (#98), each named once per
/// language. Languages whose decks name none are left out.
///
/// The lines are data, from the deck files, so a new source needs no code:
/// Sahaj Path is credited because its deck says so.
List<({LanguageInfo language, List<DeckSourceLine> lines})> sourcesOf(
  List<DeckEntry> decks,
) {
  final byLanguage =
      <String, ({LanguageInfo language, List<DeckSourceLine> lines})>{};
  for (final entry in decks) {
    final deck = entry.deck;
    // The deck's own source names the book; a passage's names its page,
    // which the drill shows with the passage.
    final named = <String>[?deck.source];
    for (final source in named) {
      final language = byLanguage.putIfAbsent(
        entry.language.code,
        () => (language: entry.language, lines: <DeckSourceLine>[]),
      );
      if (language.lines.every((line) => line.source != source)) {
        language.lines.add((source: source, kind: deck.kind));
      }
    }
  }
  return byLanguage.values.toList();
}

/// Where the decks' texts come from, a row per language and a line per
/// source, such as the books the Bengali passages are taken from. Opened by
/// Settings' Sources row (#98), which is not shown when no deck names a
/// source.
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sources = sourcesOf(AppScope.of(context).decks);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsSources),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
        children: <Widget>[
          GroupedList.settings(
            children: <Widget>[
              for (final (:language, :lines) in sources)
                GroupedTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: language.name,
                  subtitle: <String>[
                    for (final line in lines)
                      l10n.settingsSourceLine(line.source, line.kind.name),
                  ].join('\n'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
