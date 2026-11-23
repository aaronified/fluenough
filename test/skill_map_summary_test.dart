// The skill map made from the language summaries (ADR-0062) is the map that
// every card of every deck gives, so that the review log is replayed under it
// at the start and loading a unit never replays it again.
import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/replay_isolate.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:flutter_test/flutter_test.dart';

String _words(String code, String iso, String name, String card) =>
    '''
schema: 1
id: $code-en-words
name: "words"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $code-0001, target: "a", native: "x"$card }
  - { id: $code-0002, target: "b", native: "y" }
''';

/// Hindustani with a script deck its path lists under `alphabet` and a letter,
/// and Spanish with a card marked as heard by its form.
Map<String, String> _files() => <String, String>{
  'decks/hi/hi-en-letters.yaml': '''
schema: 1
id: hi-en-letters
name: "letters"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: hi-0001, target: "क", native: "ka", reading: "ka", pos: letter }
  - { id: hi-0002, target: "ख", native: "kha", reading: "kha", pos: letter }
''',
  'decks/hi/hi-en-words.yaml': '''
schema: 1
id: hi-en-words
name: "words"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-0003, target: "कल", native: "yesterday", reading: "kal" }
''',
  'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
alphabet:
  - hi-letters
units:
  - [hi-letters]
  - [hi-words]
''',
  'decks/es/es-en-words.yaml': _words('es', 'spa', 'Spanish', ', hears: form'),
  'decks/fr/fr-en-words.yaml': _words('fr', 'fra', 'French', ''),
};

DeckCatalog _lazy(Map<String, String> files) => DeckCatalog(
  MemoryDeckSource(files),
  mode: CatalogMode.lazy,
  summaries: SummaryBook(MemorySnapshotStore()),
);

void main() {
  test('equals the map every card of every deck gives', () async {
    final whole = AppState.test(decks: MemoryDeckSource(_files()));
    addTearDown(whole.dispose);
    await whole.load();
    final lazy = AppState.test(catalog: _lazy(_files()));
    addTearDown(lazy.dispose);
    await lazy.load();
    await pumpEventQueue();

    final want = whole.progress.skills;
    expect(want.formHeardCards, containsAll(<String>['hi-0001', 'es-0001']));
    expect(want.scriptDecks, <String>{'hi-en-letters'});
    expect(want.primaryScripts['hi'], 'devanagari');
    expect(lazy.progress.skills, want);
  });

  test('loading a unit leaves the map, and replays nothing', () async {
    final state = AppState.test(catalog: _lazy(_files()));
    addTearDown(state.dispose);
    await state.load();
    await pumpEventQueue();
    final skills = state.progress.skills;
    final before = MemoryProgress.replaces;
    for (final code in <String>['es', 'fr', 'hi']) {
      await state.ensureLoaded(code);
    }
    final loaded = state.deckCatalog.catalogSet.loadedCodes;
    expect(loaded, <String>['es', 'fr', 'hi']);
    expect(state.progress.skills, skills);
    expect(MemoryProgress.replaces, before);
  });

  test('the log is replayed under it, not on the UI isolate', () async {
    final progress = DatabaseProgress.opening(
      AppDatabase(NativeDatabase.memory()),
      replayer: replayInPlace,
      snapshotter: snapshotInPlace,
      skillsRunner: skillsInPlace,
      awaitSkills: true,
      app: 'x',
    );
    addTearDown(progress.close);
    final before = MemoryProgress.replaces;
    final state = AppState.test(catalog: _lazy(_files()), progress: progress);
    addTearDown(state.dispose);
    await state.load();
    await pumpEventQueue();
    expect(progress.skills, isNot(const SkillMap()));
    expect(
      MemoryProgress.replaces,
      before,
      reason: 'the map came before the replay, so none was made in place',
    );
  });
}
