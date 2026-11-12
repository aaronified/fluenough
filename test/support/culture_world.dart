/// The culture course of the culture and recommendations tests (wiki
/// Plan-Deck-Kinds-And-Topics.md, T20, T26): language `zz` with a path of
/// three units marked A1, A2 and B1, and woven into it a proverb at A1, a
/// stanza by a poet at A2 and a passage by a novelist at B1, each with its
/// source block; the two creators (one with a licensed image the tests never
/// serve, so it draws the placeholder, one with a legacy), and three
/// recommended works: a book quoted in the stanza's deck, a film at A2 and a
/// book at B1. Everything is invented for the tests.
library;

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/recommendation_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';

import 'kinds_world.dart';

const String _language =
    '{ code: "zz", iso639_3: "zzz", name: "Testlang", script: "latin", tts: "es-ES" }';

const String _sourceProverb = '''
    source:
      author: "anonymous"
      collection: "Refranes de prueba"
      date: "c. 1600"
      edition: "Colección de prueba"
      basis: "oral-tradition"
      jurisdiction: "ES"
      rights_checked: "2026-11-12"''';

const String _sourceStanza = '''
    creator: "zz-machado"
    source:
      author: "Antonio Machado"
      work: "Proverbios y cantares"
      date: 1912
      edition: "Edición de prueba"
      basis: "public-domain"
      author_died: 1939
      jurisdiction: "ES"
      rights_checked: "2026-11-12"''';

/// The culture decks, as files by path.
Map<String, String> cultureDecks() => <String, String>{
  'decks/zz/zz-proverbs-lugar.yaml':
      '''
schema: 1
id: "zz-proverbs-lugar"
part: "core"
kind: "vocab"
language: $_language
license: "CC-BY-SA-4.0"
genre: "proverbs"
level: "A1"
cards:
  - id: "zz-7101"
    target: "Más vale tarde que nunca."
    pos: "phrase"
    register: "neutral"
    modes: ["recognition", "listening"]
$_sourceProverb
''',
  'decks/zz/en/zz-en-proverbs-lugar.yaml': '''
schema: 1
id: "zz-en-proverbs-lugar"
kind: "layer"
core: "zz-proverbs-lugar"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Proverbs: place"
license: "CC-BY-SA-4.0"
cards:
  "zz-7101": { native: "Better late than never." }
''',
  'decks/zz/zz-culture-verso.yaml':
      '''
schema: 1
id: "zz-culture-verso"
part: "core"
kind: "vocab"
language: $_language
license: "CC-BY-SA-4.0"
genre: "culture"
level: "A2"
tags: ["unreviewed"]
cards:
  - id: "zz-7201"
    target: "Caminante, no hay camino, se hace camino al andar."
    pos: "phrase"
    modes: ["recognition", "listening"]
$_sourceStanza
''',
  'decks/zz/en/zz-en-culture-verso.yaml': '''
schema: 1
id: "zz-en-culture-verso"
kind: "layer"
core: "zz-culture-verso"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Culture: verse"
license: "CC-BY-SA-4.0"
cards:
  "zz-7201": { native: "Traveller, there is no road; you make the road by walking." }
''',
  'decks/zz/zz-en-culture-pasaje.yaml':
      '''
schema: 1
id: "zz-en-culture-pasaje"
name: "Culture: a passage"
kind: "reading"
language: $_language
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
genre: "culture"
level: "B1"
tags: ["unreviewed"]
passages:
  - id: "zz-pasaje-1"
    title: "El lugar"
    level: "B1"
    creator: "zz-cervantes"
    source:
      author: "Miguel de Cervantes"
      work: "Don Quijote"
      date: 1605
      edition: "Edición de prueba"
      basis: "public-domain"
      author_died: 1616
      jurisdiction: "ES"
      rights_checked: "2026-11-12"
    glossary:
      - word: "lugar"
        modern: "pueblo"
        meaning: { en: "village" }
    sentences:
      - { text: "En un lugar de la Mancha." }
    questions:
      - id: "zz-7301"
        prompt: { en: "Where does it begin?" }
        options: [{ en: "In a village" }, { en: "At sea" }]
        answer: 1
      - id: "zz-7302"
        prompt: { en: "Is it a real village?" }
        options: [{ en: "No" }, { en: "Yes" }]
        answer: 1
''',
};

/// The creators file: a poet with a legacy and a bio at A2, and a novelist
/// with a licensed picture.
const String cultureCreators = '''
schema: 1
kind: "creators"
id: "creators-zz"
language: "zz"
license: "CC-BY-SA-4.0"
eras:
  - id: "oro"
    name: { zz: "Siglo de Oro", en: "Golden Age" }
    from: 1550
    to: 1650
  - id: "plata"
    name: { zz: "Edad de Plata", en: "Silver Age" }
    from: 1868
    to: 1939
creators:
  - id: "zz-machado"
    name:
      zz: { text: "Antonio Machado" }
      en: { text: "Antonio Machado" }
    born: 1875
    died: 1939
    era: "plata"
    bio:
      en: "A teacher and poet who wrote plain, thoughtful verse."
    bio_target:
      A2: { text: "Machado fue poeta y maestro." }
    legacy:
      text: { en: "His lines are quoted by walkers on pilgrim roads." }
      items:
        - kind: "music"
          year: 1969
          text: { en: "A singer recorded an album of his poems." }
          source: { url: "https://example.org/album", accessed: "2026-11-12" }
  - id: "zz-cervantes"
    name:
      zz: { text: "Miguel de Cervantes" }
      en: { text: "Miguel de Cervantes" }
    born: 1547
    died: 1616
    era: "oro"
    bio:
      en: "The first modern novelist, some say."
    image:
      file: "decks/creators/images/zz-cervantes.png"
      credit: "Test fixture"
      author: "The Fluenough tests"
      licence: "CC-BY-4.0"
      licence_url: "https://creativecommons.org/licenses/by/4.0/"
      source_url: "https://example.org/cervantes"
      retrieved: "2026-11-12"
''';

/// Three recommended works.
const String cultureRecommendations = '''
schema: 1
kind: "recommendations"
id: "recommendations-zz"
language: "zz"
license: "CC-BY-SA-4.0"
recommendations:
  - id: "zz-rec-camino"
    medium: "book"
    title: { text: "Campos de prueba" }
    creator: ["zz-machado"]
    year: 1912
    level: "A1"
    script: "latin"
    briefing: { en: "A short book of verse about roads. Plain words." }
    questions:
      - { id: "q1", prompt: { en: "What is the book about?" }, options: { en: ["Roads", "Ships"] }, answer: 1 }
      - { id: "q2", prompt: { en: "Who wrote it?" }, options: { en: ["A poet", "A doctor"] }, answer: 1 }
      - { id: "q3", prompt: { en: "Is it long?" }, options: { en: ["No", "Yes"] }, answer: 1 }
    legal:
      - { kind: "library", url: "https://example.org/biblioteca/campos", note: { en: "Free: public domain" } }
    quoted_in: "zz-culture-verso"
  - id: "zz-rec-pelicula"
    medium: "film"
    title: { text: "Una película de prueba" }
    creator: ["zz-machado"]
    year: 1980
    level: "A2"
    briefing: { en: "A made-up film about a poet." }
    questions:
      - { id: "q1", prompt: { en: "Who is the film about?" }, options: { en: ["A poet", "A doctor"] }, answer: 1 }
      - { id: "q2", prompt: { en: "Is it a real film?" }, options: { en: ["No", "Yes"] }, answer: 1 }
      - { id: "q3", prompt: { en: "What is it for?" }, options: { en: ["Tests", "Cinemas"] }, answer: 1 }
  - id: "zz-rec-novela"
    medium: "book"
    title: { text: "Una novela de prueba" }
    creator: ["zz-cervantes"]
    year: 1605
    level: "B1"
    script: "latin"
    briefing: { en: "A long made-up novel." }
    questions:
      - { id: "q1", prompt: { en: "Is it long?" }, options: { en: ["Yes", "No"] }, answer: 1 }
      - { id: "q2", prompt: { en: "Is it real?" }, options: { en: ["No", "Yes"] }, answer: 1 }
      - { id: "q3", prompt: { en: "Who wrote it?" }, options: { en: ["Nobody", "Someone"] }, answer: 1 }
''';

/// The culture world's files: the deck-kinds course without its own culture
/// and proverbs decks, plus the decks, creators and recommendations above.
Map<String, String> cultureWorld() {
  final base = kindsWorld();
  const dropped = <String>[
    'zz-culture-a1',
    'zz-culture-b1',
    'zz-proverbs-a2',
    'zz-en-culture-a1',
    'zz-en-culture-b1',
    'zz-en-proverbs-a2',
  ];
  base.removeWhere(
    (path, _) => dropped.any((id) => path.endsWith('/$id.yaml')),
  );
  return <String, String>{
    ...base,
    ...cultureDecks(),
    'decks/creators/zz.yaml': cultureCreators,
    'decks/recommendations/zz.yaml': cultureRecommendations,
  };
}

/// Marks [card] of [deck] studied, three days back, so that its unit is
/// reached and the learner's level moves up.
void studyCard(
  MemoryProgress progress,
  AppState base,
  String deck,
  String card, {
  DrillMode mode = DrillMode.recognition,
}) => progress.record(
  deckId: deck,
  cardId: card,
  mode: mode,
  grade: 4,
  now: base.now().subtract(const Duration(days: 3)),
);

/// The app on the culture world, loaded and showing `zz`. [reach] is the level
/// the learner has reached: `a2` or `b1` study a card of that unit.
Future<AppState> cultureApp({
  SettingsNotifier? settings,
  String reach = 'a1',
  Map<String, String>? files,
  BackupStore? backupStore,
  RecommendationMarkStore? marks,
  MemoryProgress? progress,
}) async {
  progress ??= MemoryProgress();
  final all = files ?? cultureWorld();
  final s = settings ?? SettingsNotifier(spokenLanguages: const <String>['en']);
  final state = AppState.test(
    decks: MemoryDeckSource(all),
    settings: s,
    progress: progress,
    backupStore: backupStore,
    recommendationMarks: marks,
  );
  await state.load();
  if (reach != 'a1') {
    studyCard(progress, state, 'zz-en-more', 'zz-0101');
    if (reach == 'b1') studyCard(progress, state, 'zz-en-last', 'zz-0201');
  }
  state.showLanguage('zz');
  return state;
}
