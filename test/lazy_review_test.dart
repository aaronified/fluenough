// The reviewer's pages and the placement flows, moved to one language at a
// time (ADR-0062, Plan-Lazy-Language-Loading, P-C3): the courses a reviewer
// reviews are listed from the language directory, the unit of a course is read
// when a page of it opens, a word's partner is looked for in its own language,
// the daily questions follow the units that are read, and placement of a
// language not read yet reads it first.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_files.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/review/daily_questions.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_waiting.dart';
import 'package:fluenough/features/review/review_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart';

String _deck(String code, String name, String iso, String extra) =>
    '''
schema: 1
id: $code-en-words
name: "$code words"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $code-1000, target: "w0", native: "n0"$extra }
  - { id: $code-1001, target: "w1", native: "n1" }
''';

class _LiveSource implements DeckSource {
  _LiveSource(this.files);

  final Map<String, String> files;

  @override
  Future<List<String>> list() async => files.keys.toList()..sort();

  @override
  Future<String> read(String path) async =>
      files[path] ?? (throw StateError('no deck file at $path'));
}

/// A phone with Spanish (shown), French and Telugu (the review course); the
/// first Spanish word sounds like the Telugu rude word.
class _Phone {
  _Phone() {
    files['decks/es/es-en-words.yaml'] = _deck(
      'es',
      'Spanish',
      'spa',
      ', pair: $rudeCard',
    );
    files['decks/fr/fr-en-words.yaml'] = _deck('fr', 'French', 'fra', '');
    files.addAll(reviewCourse());
  }

  final Map<String, String> files = <String, String>{};
  final Map<String, MemorySnapshotStore> snapshots =
      <String, MemorySnapshotStore>{};
  final MemorySnapshotStore summaryFile = MemorySnapshotStore();
  final List<String> jobs = <String>[];

  Future<LanguageOutcome> _run(LanguageJob job) async {
    jobs.add(job.code);
    return runLanguageJob(job);
  }

  Map<String, String> get _shas => <String, String>{
    for (final path in files.keys)
      path: '${path.length}-${files[path]!.length}'.padLeft(64, '0'),
  };

  DeckCatalog catalog() => DeckCatalog(
    _LiveSource(files),
    mode: CatalogMode.lazy,
    summaries: SummaryBook(summaryFile),
    languageSnapshots: LanguageSnapshots(
      storeFor: (code) => snapshots.putIfAbsent(code, MemorySnapshotStore.new),
      readerFor: (code) => MemorySnapshotReader(snapshots[code]?.text),
      app: '1.0.0',
      knownShas: () async => Map<String, String>.of(_shas),
    ),
    languageRunner: _run,
  );
}

SettingsNotifier _settings() =>
    SettingsNotifier(
        spokenLanguages: const <String>['en', 'es', 'fr', 'te'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      )
      ..reviewLanguages = const <String>{'te', 'fr'}
      ..scriptsRead = const <String, bool>{
        'en': true,
        'es': true,
        'fr': true,
        'te': true,
      };

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

Future<AppState> _launch(_Phone phone, {bool lazy = true}) async {
  final state = lazy
      ? AppState.test(catalog: phone.catalog(), settings: _settings())
      : AppState.test(
          decks: MemoryDeckSource(Map<String, String>.of(phone.files)),
          settings: _settings(),
        );
  addTearDown(state.dispose);
  await state.load();
  await _settle();
  state.reviewing.turnOn();
  return state;
}

/// The second launch, which starts from the caches the first made.
Future<AppState> _warm(_Phone phone) async {
  await _launch(phone);
  phone.jobs.clear();
  return _launch(phone);
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

void main() {
  test('the courses to review come from the directory', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    final whole = await _launch(phone, lazy: false);
    final jobs = List<String>.of(phone.jobs);
    expect(lazy.languageLoad('te').isLoaded, isFalse);
    expect(lazy.languageLoad('fr').isLoaded, isFalse);
    expect(pairsOnPhone(lazy), pairsOnPhone(whole));
    expect(languageNamesOf(lazy), languageNamesOf(whole));
    expect(offeredPairs(lazy), offeredPairs(whole));
    expect(reviewPairsOf(lazy), reviewPairsOf(whole));
    expect(reviewPairsOf(lazy), isNotEmpty);
    expect(phone.jobs, jobs, reason: 'no unit was read');
  });

  testWidgets('a reviewer opens each course and its unit loads on entry', (
    tester,
  ) async {
    usePhone(tester);
    final phone = _Phone();
    final state = (await tester.runAsync(() => _warm(phone)))!;
    expect(state.deckCatalog.catalogSet.loadedCodes, <String>['es']);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: state,
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _loaded(tester, state, 'te');
    expect(state.languageLoad('te').isLoaded, isTrue);
    expect(state.languageLoad('fr').isLoaded, isFalse, reason: 'not asked');
    await pumpScreen(
      tester,
      const ReviewPage(deckId: 'fr-en-words'),
      state: state,
      settle: false,
    );
    await _loaded(tester, state, 'fr');
    expect(state.languageLoad('fr').isLoaded, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('a word like a rude one is paired in its own language', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    final whole = await _launch(phone, lazy: false);
    final card = lazy.decksOf('es').single.cards.first;
    expect(lazy.languageLoad('te').isLoaded, isFalse);
    expect(rudeAlikesOf(lazy, card), isEmpty, reason: 'not read yet');
    await _settle();
    expect(lazy.languageLoad('te').isLoaded, isTrue);
    final found = rudeAlikesOf(lazy, card).map((a) => a.partner.id);
    expect(found, <String>[rudeCard]);
    final wholeCard = whole.decksOf('es').single.cards.first;
    expect(rudeAlikesOf(whole, wholeCard).map((a) => a.partner.id), found);
  });

  test('the daily questions of a course are made once it is loaded', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    List<String> languages() =>
        <String>{for (final q in dailyQuestionsOf(lazy)) q.language}.toList();
    expect(languages(), isEmpty, reason: 'no reviewed course is loaded');
    await lazy.ensureLoaded('te');
    expect(languages(), <String>['te']);
    await lazy.ensureLoaded('fr');
    expect(languages(), unorderedEquals(<String>['te', 'fr']));
  });

  test('the reviewer decks of a language are that unit\'s', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    expect(lazy.allDecksOf('te'), isEmpty);
    expect(lazy.reviewDecksOf('te'), isEmpty);
    await lazy.ensureLoaded('te');
    expect(lazy.allDecksOf('te').map((d) => d.id), contains(rudeDeck));
    expect(lazy.reviewDeckById(wordsDeck), isNotNull);
    expect(lazy.reviewDeckById('fr-en-words'), isNull, reason: 'not loaded');
    await lazy.ensureLoaded('fr');
    expect(lazy.reviewDeckById('fr-en-words'), isNotNull);
  });

  testWidgets('placement of a language not read yet reads it first', (
    tester,
  ) async {
    usePhone(tester);
    final phone = _Phone();
    final state = (await tester.runAsync(() => _warm(phone)))!;
    expect(state.languageLoad('fr').isLoaded, isFalse);
    await pumpScreen(
      tester,
      PlacementPage(languages: const <String>['fr'], onFinished: (_) {}),
      state: state,
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _loaded(tester, state, 'fr');
    expect(state.languageLoad('fr').isLoaded, isTrue);
    expect(tester.takeException(), isNull);
  });
}
