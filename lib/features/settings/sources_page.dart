import 'package:flutter/material.dart' hide Card;

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart' show AppState;
import '../../app/culture.dart' show CultureState;
import '../../app/deck_catalog.dart';
import '../../app/links.dart';
import '../../core/models/card.dart';
import '../../core/models/creator.dart';
import '../../core/models/deck.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
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
  tatoeba(<String>['tatoeba']),

  /// Signs written in SignWriting, pictures drawn with the Sutton fonts under
  /// SIL OFL 1.1.
  signwriting(<String>['signwriting']);

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
///
/// [pictures] are the credits of the portraits and posters of the language's
/// people and works (approved mockup `culture-media`, screen 5): they join the
/// language's row, one line each.
List<({LanguageInfo language, List<MediaCreditLine> lines})> mediaCreditsOf(
  List<DeckEntry> decks, {
  Iterable<({LanguageInfo language, MediaCreditLine line})> pictures =
      const <({LanguageInfo language, MediaCreditLine line})>[],
}) {
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
  for (final (:language, :line) in pictures) {
    byLanguage
        .putIfAbsent(
          language.code,
          () => (language: language, lines: <MediaCreditLine>{}),
        )
        .lines
        .add(line);
  }
  return <({LanguageInfo language, List<MediaCreditLine> lines})>[
    for (final (:language, :lines) in byLanguage.values)
      (language: language, lines: lines.toList()),
  ];
}

/// The credit lines of the pictures of every language's people and works that
/// have one: the author (else the credit) and the licence, as the creator card
/// writes them.
List<({LanguageInfo language, MediaCreditLine line})> pictureCreditsOf(
  AppState state,
  AppLocalizations l10n,
) {
  final out = <({LanguageInfo language, MediaCreditLine line})>[];
  for (final language in state.languages) {
    final creators =
        state.creatorsOf(language.code)?.creators ?? const <Creator>[];
    final works =
        state.catalogView.recommendations[language.code]?.recommendations ??
        const <Recommendation>[];
    final images = <CreatorImage>[
      for (final creator in creators) ?creator.image,
      for (final work in works) ?work.image,
    ];
    for (final image in images) {
      final credit = image.author ?? image.credit;
      final licence = image.licence == 'public-domain'
          ? l10n.cultureImagePublicDomain
          : image.licence;
      if (credit == null || licence == null) continue;
      out.add((language: language, line: (credit: credit, license: licence)));
    }
  }
  return out;
}

/// The credits of [card]'s own files: its recording's and its image's.
List<MediaCredit> mediaCredits(Card card) => <MediaCredit>[
  ?card.audioCredit,
  ?card.imageCredit,
];

/// A thank you to everyone the app stands on, then the decks' licence and
/// credits, then where their texts come from, a row
/// per language and a line per source, such as the books the Bengali
/// passages are taken from. Opened by Settings' Sources row (#98).
///
/// The licence row names CC BY-SA 4.0 for deck content, and a row credits
/// each project whose data the decks use (ADR-0040).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  /// One thank-you row, found by its [id].
  static Widget _thanks(
    String id,
    IconData icon,
    String title,
    String line, {
    List<String> more = const <String>[],
  }) => GroupedTile(
    key: ValueKey<String>('thanks-$id'),
    leading: Icon(icon),
    title: title,
    subtitleLines: <String>[line, ...more],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final decks = state.decks;
    final sources = sourcesOf(decks);
    final media = mediaCreditsOf(
      decks,
      pictures: pictureCreditsOf(state, l10n),
    );
    // The script fonts are credited once one is on the phone (ADR-0042).
    final scriptFonts = AppScope.of(context).deckDownloads?.fonts;
    final fonts = scriptFonts?.hasFonts ?? false;
    final credits = creditsOf(decks);
    // SignWriting is thanked once its font is on the phone or a deck names
    // it, as the Noto line is shown once a font is (ADR-0042, ADR-0056).
    final signWriting =
        (scriptFonts?.hasScript('signwriting') ?? false) ||
        credits.contains(ContentCredit.signwriting);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSources)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          4,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          GroupedList.settings(
            header: l10n.sourcesThanks,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Text(
                  l10n.sourcesThanksIntro,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              _thanks(
                'wikimedia',
                Icons.public,
                l10n.sourcesThanksWikimedia,
                l10n.sourcesThanksWikimediaLine,
              ),
              _thanks(
                'tatoeba',
                Icons.forum_outlined,
                l10n.sourcesThanksTatoeba,
                l10n.sourcesThanksTatoebaLine,
              ),
              _thanks(
                'wordnet',
                Icons.compare_arrows,
                l10n.sourcesThanksWordnet,
                l10n.sourcesThanksWordnetLine,
              ),
              _thanks(
                'fonts',
                Icons.font_download_outlined,
                l10n.sourcesThanksFonts,
                l10n.sourcesThanksFontsLine,
              ),
              if (signWriting)
                _thanks(
                  'signwriting',
                  Icons.sign_language_outlined,
                  l10n.sourcesThanksSignWriting,
                  l10n.sourcesThanksSignWritingLine,
                  more: <String>[
                    l10n.sourcesThanksSignWritingLicence,
                    l10n.sourcesThanksSignWritingCopyright,
                  ],
                ),
              _thanks(
                'pictures',
                Icons.emoji_emotions_outlined,
                l10n.sourcesThanksPictures,
                l10n.sourcesThanksPicturesLine,
              ),
              _thanks(
                'listener',
                Icons.memory_outlined,
                l10n.sourcesThanksListener,
                l10n.sourcesThanksListenerLine,
              ),
              _thanks(
                'packages',
                Icons.code,
                l10n.sourcesThanksPackages,
                l10n.sourcesThanksPackagesLine,
              ),
              GroupedTile(
                key: const ValueKey<String>('thanks-licences'),
                leading: const Icon(Icons.description_outlined),
                title: l10n.sourcesOpenLicences,
                subtitle: l10n.sourcesOpenLicencesLine,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: AppInfo.version,
                ),
              ),
              _thanks(
                'writers',
                Icons.menu_book_outlined,
                l10n.sourcesThanksWriters,
                l10n.sourcesThanksWritersLine,
              ),
              _thanks(
                'people',
                Icons.favorite_outline,
                l10n.sourcesThanksPeople,
                l10n.sourcesThanksPeopleLine,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupedList.settings(
            header: l10n.sourcesDeckContent,
            children: <Widget>[
              GroupedTile(
                leading: const Icon(Icons.copyright_outlined),
                title: l10n.sourcesLicence,
                subtitle: l10n.sourcesLicenceLine,
                onTap: () => openLink(
                  context,
                  AppLinks.ccBySa,
                  copied: l10n.sourcesLinkCopied,
                ),
              ),
              GroupedTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: l10n.sourcesPhonetic,
                subtitle: l10n.sourcesPhoneticLine,
                onTap: () => openLink(
                  context,
                  AppLinks.wiktionary,
                  copied: l10n.sourcesLinkCopied,
                ),
              ),
              GroupedTile(
                leading: const Icon(Icons.compare_arrows),
                title: l10n.sourcesSynonyms,
                subtitle: l10n.sourcesSynonymsLine,
                onTap: () => openLink(
                  context,
                  AppLinks.wiktionary,
                  copied: l10n.sourcesLinkCopied,
                ),
              ),
              if (fonts)
                GroupedTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: l10n.sourcesFonts,
                  subtitle: l10n.sourcesFontsLine,
                ),
              for (final credit in credits)
                GroupedTile(
                  leading: const Icon(Icons.public),
                  title: l10n.sourcesCreditName(credit.name),
                  subtitle: l10n.sourcesCreditLine(credit.name),
                ),
            ],
          ),
          // The on-device AI listener's software and data (#1004).
          const SizedBox(height: 16),
          GroupedList.settings(
            header: l10n.sourcesListener,
            children: <Widget>[
              GroupedTile(
                leading: const Icon(Icons.memory_outlined),
                title: l10n.sourcesListenerOnnx,
                subtitle: l10n.sourcesListenerOnnxLine,
              ),
              GroupedTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: l10n.sourcesListenerModel,
                subtitle: l10n.sourcesListenerModelLine,
              ),
              GroupedTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: l10n.sourcesListenerData,
                subtitle: l10n.sourcesListenerDataLine,
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
                    subtitleLines: <String>[
                      for (final line in lines)
                        l10n.sourcesMediaLine(line.credit, line.license),
                    ],
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
                    subtitleLines: <String>[
                      for (final line in lines)
                        l10n.settingsSourceLine(line.source, line.kind.name),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
