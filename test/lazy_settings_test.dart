// The Settings pages that scanned the decks, moved to the language directory
// and to one language at a time (ADR-0062, Plan-Lazy-Language-Loading,
// P-C5): Sources lists every language's credits from the directory with no
// unit read and equals what the whole catalog gives, Your decks lists the
// learner's own decks from the directory, the Voices sample and the
// "Privately modified" tag are in the summary, and Your data reads no more
// than the languages of the rows it shows.
import 'dart:convert';

import 'package:fluenough/app/added_decks.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/own_decks.dart';
import 'package:fluenough/app/private_languages.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/core/decks/language_summary.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';
import 'support/harness.dart';

const String _esLang = 'code: es, iso639_3: spa, name: Spanish, script: latin';
const String _frLang = 'code: fr, iso639_3: fra, name: French, script: latin';
const String _commons = 'https://commons.wikimedia.org/wiki/File:';
const String _ranked = ', frequency: { rank: 3, source: "Wikipedia" }';
const String _example =
    ', examples: [{ target: "Hola", native: "Hello", source: "Tatoeba 1" }]';

String _deck(String id, String lang, List<String> cards, [String head = '']) {
  return '''
schema: 1
id: $id
name: "Deck $id"
language: { $lang }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
${head}cards:
${cards.join('\n')}
''';
}

String _card(String id, String target, [String extra = '']) =>
    '  - { id: $id, target: "$target", native: "n"$extra }';

/// What a card with a recording credits: the recording and who made it.
String _sung(String file) =>
    ', audio: "$file.ogg", audio_credit: { source: "$_commons$file.ogg", '
    'license: "CC-BY-SA-4.0", credit: "Ana" }';

/// Two Spanish decks that name sources and credit a recording, an adult deck
/// of its own, a French deck, and the culture world's `zz`, whose creator's
/// picture is public domain.
Map<String, String> _files() => <String, String>{
  'decks/es/es-en-words.yaml': _deck('es-en-words', _esLang, <String>[
    _card('es-0001', 'grosería', ', tags: [offensive]'),
    _card('es-0002', 'hola', _sung('hola') + _example),
    _card('es-0003', 'adiós', _ranked),
    _card('es-0004', 'gracias'),
  ], 'source: "Wiktionary"\n'),
  'decks/es/es-en-more.yaml': _deck('es-en-more', _esLang, <String>[
    _card('es-0101', 'mesa', _sung('mesa')),
  ], 'source: "Libro de prueba"\n'),
  'decks/es/es-en-slang.yaml': _deck('es-en-slang', _esLang, <String>[
    _card('es-0201', 'chungo'),
  ], 'tags: [offensive, rated]\nsource: "Libro de jerga"\n'),
  'decks/fr/fr-en-words.yaml': _deck('fr-en-words', _frLang, <String>[
    _card('fr-0001', 'bonjour'),
  ], 'source: "Livre de test"\n'),
  ...cultureWorld(),
  'decks/creators/zz.yaml': cultureCreators.replaceFirst(
    'licence: "CC-BY-4.0"',
    'licence: "public-domain"',
  ),
};

/// The deck a learner added.
Map<String, String> _added() => <String, String>{
  'es-en-mine': _deck('es-en-mine', _esLang, <String>[
    _card('es-0301', 'casa'),
    _card('es-0302', 'perro'),
  ]),
};

SettingsNotifier _settings({bool adult = false}) => SettingsNotifier(
  spokenLanguages: const <String>['en'],
  learningLanguages: const <String>[],
  learningChosen: true,
)..adultContent = adult;

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

/// A phone that reads one language at a time and learns nothing yet, so that
/// no language is shown and no unit is read at the start.
Future<AppState> _lazy({bool adult = false}) async {
  final nobody = Profile.defaultProfile.copyWith(languages: <String>{});
  final state = AppState.test(
    catalog: DeckCatalog(
      MemoryDeckSource(_files()),
      added: MemoryDeckStore(_added()),
      mode: CatalogMode.lazy,
      summaries: SummaryBook(MemorySnapshotStore()),
    ),
    settings: _settings(adult: adult),
    profiles: <Profile>[nobody],
  );
  addTearDown(state.dispose);
  await state.load();
  await _settle();
  return state;
}

/// The same phone with the whole catalog read.
Future<AppState> _whole({bool adult = false}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(_files()),
    addedDecks: MemoryDeckStore(_added()),
    settings: _settings(adult: adult),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

/// Lets the unit of [code] finish reading: real time, which the test clock
/// never gives, then a frame to draw it.
Future<void> _loaded(WidgetTester tester, AppState state, String code) async {
  for (var i = 0; i < 50 && !state.languageLoad(code).isLoaded; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pump();
}

/// [credits] as text, so that two of them can be compared.
String _text(DeckCredits credits) {
  final out = <String>[];
  for (final (:language, :lines) in credits.sources) {
    final books = <String>[for (final l in lines) '${l.source}/${l.kind}'];
    out.add('source ${language.code}: ${books.join(', ')}');
  }
  for (final (:language, :lines) in credits.media) {
    final each = <String>[for (final l in lines) '${l.credit}/${l.license}'];
    out.add('media ${language.code}: ${each.join(', ')}');
  }
  out.add('projects ${credits.projects.map((p) => p.name).join(', ')}');
  return out.join('\n');
}

/// Every book [credits] names, whichever language's.
List<String> _books(DeckCredits credits) => <String>[
  for (final (language: _, :lines) in credits.sources)
    for (final line in lines) line.source,
];

void main() {
  final l10n = AppLocalizationsEn();

  test('Sources reads every credit from the directory', () async {
    final lazy = await _lazy();
    final whole = await _whole();
    final set = lazy.deckCatalog.catalogSet;
    expect(set.loadedCodes, isEmpty, reason: 'no unit is read at the start');
    final fromDirectory = deckCreditsOf(lazy, l10n);
    expect(set.loadedCodes, isEmpty, reason: 'and none is read for Sources');
    // The parity: the directory gives what the decks give.
    expect(_text(fromDirectory), _text(deckCreditsOf(whole, l10n)));
    expect(_books(fromDirectory), contains('Wiktionary'));
    expect(_books(fromDirectory), contains('Libro de prueba'));
    expect(_books(fromDirectory), contains('Livre de test'));
    final media = <String, List<MediaCreditLine>>{
      for (final (:language, :lines) in fromDirectory.media)
        language.code: lines,
    };
    final recording = media['es']!.single;
    expect(recording.credit, 'Ana');
    expect(recording.license, 'CC-BY-SA-4.0');
    final picture = media['zz']!.single;
    expect(picture.credit, 'The Fluenough tests');
    expect(picture.license, l10n.cultureImagePublicDomain);
    final projects = fromDirectory.projects;
    expect(projects, contains(ContentCredit.wiktionary));
    expect(projects, contains(ContentCredit.commons));
    expect(projects, contains(ContentCredit.wikipedia));
    expect(projects, contains(ContentCredit.tatoeba));
  });

  test('a line only an adult deck gives needs Adult content on', () async {
    final off = deckCreditsOf(await _lazy(), l10n);
    expect(_text(off), _text(deckCreditsOf(await _whole(), l10n)));
    expect(_books(off), isNot(contains('Libro de jerga')));
    final on = deckCreditsOf(await _lazy(adult: true), l10n);
    expect(_text(on), _text(deckCreditsOf(await _whole(adult: true), l10n)));
    expect(_books(on), contains('Libro de jerga'));
  });

  test('Your decks lists the added decks from the directory', () async {
    final lazy = await _lazy();
    final whole = await _whole();
    String text(AppState state) => <String>[
      for (final d in state.ownDecks)
        '${d.id}|${d.name}|${d.cards}|${d.language}|${d.native}',
    ].join('\n');
    expect(text(lazy), 'es-en-mine|Deck es-en-mine|2|Spanish|English');
    expect(text(whole), text(lazy));
    expect(lazy.deckCatalog.catalogSet.loadedCodes, isEmpty);
  });

  test('the Voices sample comes from the summary', () async {
    final lazy = await _lazy();
    final whole = await _whole();
    final sample = lazy.summaryOf('es')!.voiceSample;
    expect(sample, hasLength(3));
    expect(sample, isNot(contains('grosería')));
    expect(sample, isNot(contains('chungo')));
    for (final code in <String>['es', 'fr']) {
      final inLazy = lazy.languages.firstWhere((l) => l.code == code);
      final inWhole = whole.languages.firstWhere((l) => l.code == code);
      final said = VoicesPage.sampleFor(lazy, inLazy);
      expect(said, VoicesPage.sampleFor(whole, inWhole), reason: code);
      expect(said, lazy.summaryOf(code)!.voiceSample.first, reason: code);
    }
    expect(lazy.deckCatalog.catalogSet.loadedCodes, isEmpty);
  });

  test('the summary keeps what the settings pages read', () async {
    final lazy = await _lazy();
    final summary = lazy.summaryOf('es')!;
    expect(summary.privatelyModified, isFalse);
    expect(lazy.isPrivatelyModified('es'), isFalse);
    expect(lazy.isPrivateLanguage('es'), isFalse);
    expect(summary.decks.map((d) => d.name), contains('Deck es-en-mine'));
    final text = jsonEncode(summary.toJson());
    final back = LanguageSummary.tryFromJson(jsonDecode(text));
    expect(jsonEncode(back!.toJson()), text);
  });

  testWidgets('Your data loads only the languages shown', (tester) async {
    usePhone(tester);
    final state = (await tester.runAsync(_lazy))!;
    final set = state.deckCatalog.catalogSet;
    expect(set.loadedCodes, isEmpty);
    state.progress.record(
      deckId: 'es-en-words',
      cardId: 'es-0002',
      mode: DrillMode.recognition,
      grade: 4,
      now: DateTime(2026, 9, 28, 9),
    );
    await pumpScreen(tester, const YourDataPage(), state: state, settle: false);
    await _loaded(tester, state, 'es');
    expect(state.languageLoad('es').isLoaded, isTrue);
    expect(state.languageLoad('fr').isLoaded, isFalse);
    expect(state.languageLoad('zz').isLoaded, isFalse);
    expect(set.loadedCodes, <String>['es']);
    expect(tester.takeException(), isNull);
  });
}
