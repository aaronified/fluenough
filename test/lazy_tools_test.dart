// Search, culture, topics, the IPA course and the script and sound tools,
// moved to one language at a time (ADR-0062, Plan-Lazy-Language-Loading,
// P-C4): a search and the culture of a language read that language's unit, a
// page of a language not read yet reads it first, the IPA course is a
// dependency read when "The sounds of this word" is wanted, and the IPA
// keyboard's symbols are in the directory.
import 'dart:async';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/culture.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_files.dart';
import 'package:fluenough/app/item_search.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/app/recommendation_feed.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/features/culture/culture_deck_page.dart';
import 'package:fluenough/features/drill/sounds_of_word.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';
import 'support/harness.dart';

const String _esWords = '''
schema: 1
id: es-en-words
name: "es words"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-0001, target: "papa", native: "potato", ipa: "pʰɒ" }
''';

const String _ipaDeck = '''
schema: 1
id: ipa-en-basics
name: "IPA: basics"
language: { code: ipa, iso639_3: zxx, name: IPA, script: ipa, icon: "ə" }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: ipa-0001, target: "ɒ", native: "open back rounded vowel" }
  - { id: ipa-0002, target: "pʰ", native: "aspirated p" }
  - { id: ipa-0003, target: "ʈ", native: "voiceless retroflex plosive" }
  - { id: ipa-0004, target: "voicing", native: "the vocal folds" }
''';

const String _ipaPath = '''
schema: 1
kind: path
id: ipa-path
language: ipa
units:
  - [ipa-basics]
  - ["*"]
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

/// A phone with Spanish (shown), the IPA course and the culture world's
/// languages `zz` and `yy`, none of which is read until it is asked for.
class _Phone {
  _Phone() {
    files['decks/es/es-en-words.yaml'] = _esWords;
    files['decks/ipa/ipa-en-basics.yaml'] = _ipaDeck;
    files['decks/ipa/ipa-path.yaml'] = _ipaPath;
    files.addAll(cultureWorld());
  }

  final Map<String, String> files = <String, String>{};
  final Map<String, MemorySnapshotStore> snapshots =
      <String, MemorySnapshotStore>{};
  final MemorySnapshotStore summaryFile = MemorySnapshotStore();

  Future<LanguageOutcome> _run(LanguageJob job) async => runLanguageJob(job);

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

SettingsNotifier _settings() => SettingsNotifier(
  spokenLanguages: const <String>['en'],
  learningLanguages: const <String>['es'],
  learningChosen: true,
);

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
  return state;
}

/// The second launch, which starts from the caches the first made.
Future<AppState> _warm(_Phone phone) async {
  await _launch(phone);
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
  test('the IPA keyboard has its symbols with no ipa unit', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    final whole = await _launch(phone, lazy: false);
    const symbols = <String>['ɒ', 'pʰ', 'ʈ', 'voicing'];
    expect(lazy.languageLoad('ipa').isLoaded, isFalse);
    expect(lazy.ipaAnswerTargets(), unorderedEquals(symbols));
    expect(lazy.summaryOf('ipa')!.ipaSymbols, unorderedEquals(symbols));
    expect(whole.ipaAnswerTargets(), unorderedEquals(symbols));
    expect(lazy.languageLoad('ipa').isLoaded, isFalse, reason: 'still not');
  });

  test('the sounds of a word read the ipa unit', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    final card = lazy.decksOf('es').single.cards.first;
    expect(card.ipa, isNotNull);
    expect(lazy.ipaReady, isFalse);
    expect(lazy.soundsOfWord(card), isEmpty, reason: 'not read yet');
    await lazy.ensureIpaReady();
    expect(lazy.ipaReady, isTrue);
    expect(lazy.languageLoad('ipa').isLoaded, isTrue);
    final ids = lazy.soundsOfWord(card).map((c) => c.id);
    expect(ids, <String>['ipa-0001', 'ipa-0002']);
    final whole = await _launch(phone, lazy: false);
    final wholeCard = whole.decksOf('es').single.cards.first;
    expect(whole.ipaReady, isTrue);
    expect(whole.soundsOfWord(wholeCard).map((c) => c.id), ids);
  });

  test('a search on a language runs on its unit', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    expect(lazy.languageLoad('zz').isLoaded, isFalse);
    expect(lazy.itemSearchFor('zz').path, isNull, reason: 'nothing read yet');
    await lazy.ensureLoaded('zz');
    final index = lazy.itemSearchFor('zz');
    expect(index.path, isNotNull);
    expect(index.source.topics, isNotNull);
    await lazy.ensureLoaded('yy');
    expect(identical(lazy.itemSearchFor('zz'), index), isTrue);
    final whole = await _launch(phone, lazy: false);
    List<String> ids(AppState state) {
      final found = state.searchItems('zz', 'house').outcome.results;
      return <String>[for (final r in found) r.row.id];
    }

    expect(ids(lazy), ids(whole));
  });

  test('creators and recommendations come from the unit', () async {
    final phone = _Phone();
    final lazy = await _warm(phone);
    expect(lazy.creatorsOf('zz'), isNull, reason: 'not read yet');
    expect(lazy.recommendationsFor('zz'), isEmpty);
    await lazy.ensureLoaded('zz');
    await lazy.ensureLoaded('yy');
    final whole = await _launch(phone, lazy: false);
    List<String> people(AppState state) => <String>[
      for (final c in state.creatorsOf('zz')!.creators) c.id,
    ];
    expect(people(lazy), contains('zz-cervantes'));
    expect(people(lazy), people(whole));
    final unit = lazy.catalogOf('zz');
    final works = unit.recommendations['zz']!.recommendations;
    expect(works.map((r) => r.id), contains('zz-rec-camino'));
    expect(unit.decks.every((d) => d.language.code == 'zz'), isTrue);
    expect(lazy.catalogOf('yy').creators, isEmpty);
    expect(
      lazy.recommendationsFor('zz').map((r) => r.id),
      whole.recommendationsFor('zz').map((r) => r.id),
    );
    expect(lazy.hasNumberRules('zz'), whole.hasNumberRules('zz'));
  });

  testWidgets('the culture page of a language reads its unit on entry', (
    tester,
  ) async {
    usePhone(tester);
    final phone = _Phone();
    final state = (await tester.runAsync(() => _warm(phone)))!;
    expect(state.languageLoad('zz').isLoaded, isFalse);
    await pumpScreen(tester, const SizedBox(), state: state, settle: false);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed(AppRoutes.culture, arguments: 'zz'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CultureDeckPage), findsNothing);
    await _loaded(tester, state, 'zz');
    await tester.pump(const Duration(seconds: 1));
    expect(state.languageLoad('zz').isLoaded, isTrue);
    expect(find.byType(CultureDeckPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sounds button enables once the ipa unit is read', (
    tester,
  ) async {
    usePhone(tester);
    final phone = _Phone();
    final state = (await tester.runAsync(() => _warm(phone)))!;
    final card = state.decksOf('es').single.cards.first;
    await pumpScreen(
      tester,
      Scaffold(body: SoundsOfWordButton(card: card)),
      state: state,
      settle: false,
    );
    expect(state.languageLoad('ipa').isLoaded, isFalse);
    final waiting = tester.widget<IconButton>(find.byType(IconButton));
    expect(waiting.onPressed, isNull);
    await _loaded(tester, state, 'ipa');
    expect(state.languageLoad('ipa').isLoaded, isTrue);
    final ready = tester.widget<IconButton>(find.byType(IconButton));
    expect(ready.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
