import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';

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

/// A project whose data the decks may use, credited on the Sources page
/// when a deck names it (ADR-0040).
enum ContentCredit {
  /// Word data, CC BY-SA 4.0 (#518).
  wiktionary(<String>['wiktionary']),

  /// Recordings and images, each under its own licence and credit (#518,
  /// #523).
  commons(<String>['wikimedia commons', 'commons.wikimedia.org']),

  /// Drawings of what words mean, CC BY-SA 4.0 (#523).
  openmoji(<String>['openmoji']),

  /// Frequency, counted from each language's Wikipedia, CC BY-SA (#516).
  wikipedia(<String>['wikipedia']),

  /// Sentences, CC BY 2.0 FR.
  tatoeba(<String>['tatoeba']);

  const ContentCredit(this.marks);

  /// How a source names the project, in lower case: its name or its host.
  final List<String> marks;

  /// Whether [source] names this project.
  bool namedIn(String source) {
    final text = source.toLowerCase();
    return marks.any(text.contains);
  }
}

/// The sources [card]'s data names, item by item (#506, #518): its
/// examples', its items' and senses', its frequency's, and its recording's.
Iterable<String> cardSources(Card card) sync* {
  for (final example in card.examples) {
    if (example.source case final source?) yield source;
  }
  for (final items in <List<CardItem>>[
    card.synonyms,
    card.antonyms,
    card.collocations,
    card.confusables,
    card.forms,
  ]) {
    for (final item in items) {
      if (item.source case final source?) yield source;
    }
  }
  for (final sense in card.senses) {
    if (sense.source case final source?) yield source;
  }
  if (card.frequency case final frequency?) yield frequency.source;
  if (card.audioCredit case final credit?) yield credit.source;
  if (card.imageCredit case final credit?) yield credit.source;
}

/// The projects [decks] use, in [ContentCredit]'s order: those a deck's own
/// `source` names, or any item of its cards' data names (#518).
List<ContentCredit> creditsOf(List<DeckEntry> decks) {
  final sources = <String>{
    for (final entry in decks) ...<String>[
      ?entry.deck.source,
      for (final card in entry.deck.cards) ...cardSources(card),
    ],
  };
  return <ContentCredit>[
    for (final credit in ContentCredit.values)
      if (sources.any(credit.namedIn)) credit,
  ];
}

/// One credit of a language's recordings and pictures: whom, and the
/// licence.
typedef MediaCreditLine = ({String credit, String license});

/// The credits of the recordings and images that ship with [decks] (#518,
/// #523), by
/// language, each credit and licence once. Languages with none are left
/// out.
List<({LanguageInfo language, List<MediaCreditLine> lines})> mediaCreditsOf(
  List<DeckEntry> decks,
) {
  final byLanguage =
      <String, ({LanguageInfo language, Set<MediaCreditLine> lines})>{};
  for (final entry in decks) {
    for (final card in entry.deck.cards) {
      for (final credit in mediaCredits(card)) {
        byLanguage
            .putIfAbsent(
              entry.language.code,
              () => (language: entry.language, lines: <MediaCreditLine>{}),
            )
            .lines
            .add((credit: credit.credit, license: credit.license));
      }
    }
  }
  return <({LanguageInfo language, List<MediaCreditLine> lines})>[
    for (final (:language, :lines) in byLanguage.values)
      (language: language, lines: lines.toList()),
  ];
}

/// The credits of [card]'s own files: its recording's and its image's.
List<MediaCredit> mediaCredits(Card card) => <MediaCredit>[
  ?card.audioCredit,
  ?card.imageCredit,
];

/// The decks' licence and credits, then where their texts come from, a row
/// per language and a line per source, such as the books the Bengali
/// passages are taken from. Opened by Settings' Sources row (#98).
///
/// The licence row names CC BY-SA 4.0 for deck content, and a row credits
/// each project whose data the decks use (ADR-0040).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final decks = AppScope.of(context).decks;
    final sources = sourcesOf(decks);
    final media = mediaCreditsOf(decks);
    // The script fonts are credited once one is on the phone (ADR-0042).
    final fonts = AppScope.of(context).deckDownloads?.fonts.hasFonts ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsSources),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          4,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          GroupedList.settings(
            header: l10n.sourcesDeckContent,
            children: <Widget>[
              GroupedTile(
                leading: const Icon(Icons.copyright_outlined),
                title: l10n.sourcesLicence,
                subtitle: l10n.sourcesLicenceLine,
              ),
              if (fonts)
                GroupedTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: l10n.sourcesFonts,
                  subtitle: l10n.sourcesFontsLine,
                ),
              for (final credit in creditsOf(decks))
                GroupedTile(
                  leading: const Icon(Icons.public),
                  title: l10n.sourcesCreditName(credit.name),
                  subtitle: l10n.sourcesCreditLine(credit.name),
                ),
            ],
          ),
          if (media.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            GroupedList.settings(
              header: l10n.sourcesMedia,
              children: <Widget>[
                for (final (:language, :lines) in media)
                  GroupedTile(
                    leading: const Icon(Icons.perm_media_outlined),
                    title: language.name,
                    subtitle: <String>[
                      for (final line in lines)
                        l10n.sourcesMediaLine(line.credit, line.license),
                    ].join('\n'),
                  ),
              ],
            ),
          ],
          if (sources.isNotEmpty) const SizedBox(height: 16),
          if (sources.isNotEmpty)
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
