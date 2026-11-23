// The screens and services that read a language's content, moved to one
// language at a time (ADR-0062, Plan-Lazy-Language-Loading, P-C2): the due
// forecast of a language not loaded comes from the log, a session waits for
// its language, the unlock gate and what is kept about a language are its own,
// and nothing here reads a unit that was not asked for.
import 'dart:ui' show Locale;

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_files.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/app/language_work.dart';
import 'package:fluenough/app/reminder_service.dart';
import 'package:fluenough/app/reminder_words.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/progress_index.dart' show kLeechLapses;
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/progress_numbers.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_reminder_scheduler.dart';

String _deck(String code, String name, String iso, int from, int count) =>
    '''
schema: 1
id: $code-en-words
name: "$code words"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 0; i < count; i++) '  - { id: $code-${from + i}, target: "w$i", native: "n$i" }'].join('\n')}
''';

/// A source that reads the files as they are now.
class _LiveSource implements DeckSource {
  _LiveSource(this.files);

  final Map<String, String> files;

  @override
  Future<List<String>> list() async => files.keys.toList()..sort();

  @override
  Future<String> read(String path) async =>
      files[path] ?? (throw StateError('no deck file at $path'));
}

/// One phone: its files, the caches kept between launches and every language
/// job that ran.
class _Phone {
  _Phone() {
    put('es', 'Spanish', 'spa', 1000, 2);
    put('fr', 'French', 'fra', 2000, 2);
    put('hi', 'Hindustani', 'hin', 3000, 2);
  }

  final Map<String, String> files = <String, String>{};
  final Map<String, String> shas = <String, String>{};
  final Map<String, MemorySnapshotStore> snapshots =
      <String, MemorySnapshotStore>{};
  final MemorySnapshotStore summaryFile = MemorySnapshotStore();
  final List<String> jobs = <String>[];

  void put(String code, String name, String iso, int from, int count) {
    final path = 'decks/$code/$code-en-words.yaml';
    files[path] = _deck(code, name, iso, from, count);
    shas[path] = '$code-$from-$count'.padLeft(64, '0');
  }

  Future<LanguageOutcome> _run(LanguageJob job) async {
    jobs.add(job.code);
    return runLanguageJob(job);
  }

  DeckCatalog catalog() => DeckCatalog(
    _LiveSource(files),
    mode: CatalogMode.lazy,
    summaries: SummaryBook(summaryFile),
    languageSnapshots: LanguageSnapshots(
      storeFor: (code) => snapshots.putIfAbsent(code, MemorySnapshotStore.new),
      readerFor: (code) => MemorySnapshotReader(snapshots[code]?.text),
      app: '1.0.0',
      knownShas: () async => Map<String, String>.of(shas),
    ),
    languageRunner: _run,
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

const Set<String> _voices = <String>{'en', 'es', 'fr', 'hi'};

/// A launch of the app over [phone], one language at a time.
Future<AppState> _launch(_Phone phone) async {
  final state = AppState.test(
    catalog: phone.catalog(),
    tts: FixedTtsEngine(_voices),
  );
  addTearDown(state.dispose);
  await state.load();
  await _settle();
  return state;
}

/// The second launch: the first made the caches, and the log of jobs starts
/// again, so that it holds what this launch read.
Future<AppState> _warm(_Phone phone) async {
  await _launch(phone);
  phone.jobs.clear();
  return _launch(phone);
}

/// The same phone with every language read together.
Future<AppState> _whole(_Phone phone) async {
  final state = AppState.test(
    decks: MemoryDeckSource(Map<String, String>.of(phone.files)),
    tts: FixedTtsEngine(_voices),
  );
  addTearDown(state.dispose);
  await state.load();
  await _settle();
  return state;
}

void _answer(
  AppState state,
  String deckId,
  String cardId, {
  int daysAgo = 30,
  int grade = 3,
}) => state.progress.record(
  deckId: deckId,
  cardId: cardId,
  mode: DrillMode.recognition,
  grade: grade,
  now: state.now().subtract(Duration(days: daysAgo)),
);

/// What the learner has done: one card due in each of three languages, and
/// two in French.
void _learn(AppState state) {
  _answer(state, 'es-en-words', 'es-1000');
  _answer(state, 'fr-en-words', 'fr-2000');
  _answer(state, 'fr-en-words', 'fr-2001');
  _answer(state, 'hi-en-words', 'hi-3000');
}

void main() {
  group('the due forecast of a language that is not loaded', () {
    test('is counted from the log and equals the exact count', () async {
      final phone = _Phone();
      final lazy = await _warm(phone);
      final whole = await _whole(phone);
      _learn(lazy);
      _learn(whole);
      expect(lazy.languageLoad('fr').isLoaded, isFalse);
      expect(lazy.languageLoad('hi').isLoaded, isFalse);
      final jobs = List<String>.of(phone.jobs);
      final exact = whole.dueForecast();
      expect(exact.first, 4, reason: 'one card in es and hi, two in fr');
      expect(lazy.dueForecast(), exact);
      expect(lazy.dueTomorrow(), whole.dueTomorrow());
      expect(phone.jobs, jobs, reason: 'no unit was read for the forecast');
    });

    test('counts a card a deck update removed until it is loaded', () async {
      final phone = _Phone();
      final lazy = await _warm(phone);
      final whole = await _whole(phone);
      _learn(lazy);
      _learn(whole);
      _answer(lazy, 'fr-en-words', 'fr-9999');
      _answer(whole, 'fr-en-words', 'fr-9999');
      expect(
        lazy.dueForecast().first,
        whole.dueForecast().first + 1,
        reason: 'the log alone cannot tell the card is gone',
      );
      await lazy.ensureLoaded('fr');
      await lazy.ensureLoaded('hi');
      expect(lazy.dueForecast(), whole.dueForecast());
    });

    test('shows the dot and the next language without a read', () async {
      final phone = _Phone();
      final lazy = await _warm(phone);
      _learn(lazy);
      final jobs = List<String>.of(phone.jobs);
      expect(lazy.hasDueInLog('fr'), isTrue);
      expect(lazy.hasDueInLog('es'), isTrue);
      expect(lazy.languageHasWork('fr'), isTrue);
      expect(<String>[
        for (final language in lazy.nextTodayLanguages('es')) language.code,
      ], <String>['fr', 'hi']);
      expect(phone.jobs, jobs);
    });

    test('leaves out a language the log has nothing due for', () async {
      final phone = _Phone();
      final lazy = await _warm(phone);
      _answer(lazy, 'fr-en-words', 'fr-2000');
      expect(lazy.hasDueInLog('hi'), isFalse);
      expect(<String>[
        for (final language in lazy.nextTodayLanguages('es')) language.code,
      ], <String>['fr']);
    });
  });

  group('a session for a language that is not loaded', () {
    const fr = DrillRequest.today(language: 'fr');

    test('is empty and not kept until its language is read', () async {
      final phone = _Phone();
      final state = await _warm(phone);
      _learn(state);
      expect(state.isSessionLoading(fr), isTrue);
      expect(state.buildSession(fr).isNotEmpty, isFalse);
      expect(state.sessionBuilds['fr'], isNull, reason: 'nothing was built');
      await state.ensureRequestLoaded(fr);
      expect(state.isSessionLoading(fr), isFalse);
      expect(state.buildSession(fr).isNotEmpty, isTrue);
      expect(state.sessionBuilds['fr'], 1);
    });

    test('reads the language of the decks it names', () async {
      final phone = _Phone();
      final state = await _warm(phone);
      final deck = DrillRequest.deck('hi-en-words');
      expect(state.isSessionLoading(deck), isTrue);
      await state.ensureRequestLoaded(deck);
      expect(state.languageLoad('hi').isLoaded, isTrue);
      expect(state.languageLoad('fr').isLoaded, isFalse);
      expect(state.isSessionLoading(deck), isFalse);
    });

    test('is never waited for when every language is read together', () async {
      final whole = await _whole(_Phone());
      expect(whole.isSessionLoading(fr), isFalse);
      expect(whole.isLanguageReading('fr'), isFalse);
      await whole.ensureRequestLoaded(fr);
    });

    test('a reminder tap reads the shown language, then Today plans', () async {
      final phone = _Phone();
      final state = await _warm(phone);
      _learn(state);
      state.shellTab.value = ShellTab.decks;
      state.showLanguage('hi');
      const today = DrillRequest.today();
      expect(state.isSessionLoading(today), isTrue);
      expect(state.buildSession(today).isNotEmpty, isFalse);
      await state.reminderOpened();
      expect(state.shellTab.value, ShellTab.today);
      expect(state.isSessionLoading(today), isFalse);
      expect(state.buildSession(today).isNotEmpty, isTrue);
    });

    test('the request names its languages', () {
      expect(const DrillRequest.today().languages, isEmpty);
      expect(const DrillRequest.today(language: 'fr').languages, <String>{
        'fr',
      });
      expect(DrillRequest.deck('hi-en-words').languages, <String>{'hi'});
      expect(DrillRequest.practice('es-en-words').languages, <String>{'es'});
      expect(const DrillRequest.sounds(<String>{'ipa-1'}).languages, <String>{
        'ipa',
      });
      expect(
        DrillRequest.lesson(language: 'es', deckId: 'fr-x').languages,
        <String>{'es'},
        reason: 'the language a request names comes first',
      );
    });
  });

  test('the reminder replan reads no unit', () async {
    final phone = _Phone();
    final state = await _warm(phone);
    _learn(state);
    final scheduler = FakeReminderScheduler();
    final service = ReminderService(
      scheduler: scheduler,
      settings: state.settings,
      available: () => true,
      forecast: state.dueForecast,
      words: () => reminderWordsFor(const Locale('en')),
      clock: state.now,
    );
    addTearDown(service.dispose);
    final jobs = List<String>.of(phone.jobs);
    await service.setOn(true);
    await service.appPaused();
    expect(scheduler.pending, isNotEmpty);
    expect(phone.jobs, jobs);
  });

  group('the unlock gate of a language', () {
    test('equals the whole gate restricted to that language', () async {
      final phone = _Phone();
      final lazy = await _warm(phone);
      final whole = await _whole(phone);
      _learn(lazy);
      _learn(whole);
      expect(lazy.unlockCountsFor('es'), whole.unlockCountsFor('es'));
      expect(whole.unlockCountsFor('es').wordsTaught, 1);
      await lazy.ensureLoaded('fr');
      expect(lazy.unlockCountsFor('fr'), whole.unlockCountsFor('fr'));
      expect(whole.unlockCountsFor('fr').wordsTaught, 2);
      expect(lazy.unlockCountsFor('es'), whole.unlockCountsFor('es'));
      expect(lazy.inProgressIn('fr'), whole.inProgressIn('fr'));
    });

    test('reads only the language it is asked for', () async {
      final phone = _Phone();
      final state = await _warm(phone);
      _learn(state);
      final jobs = List<String>.of(phone.jobs);
      state.unlocksFor('es');
      state.unlockCountsFor('es');
      expect(phone.jobs, jobs);
      expect(state.unlockCountsFor('fr').wordsTaught, 0, reason: 'not loaded');
    });
  });

  group('what is kept about a language', () {
    test('stays while another language loads, and goes with its own', () async {
      final phone = _Phone();
      final state = await _warm(phone);
      _learn(state);
      final decks = state.decksOf('es');
      final lookup = cardLookupOf(state, language: 'es');
      final gate = state.unlocksFor('es');
      final counts = state.unlockCountsFor('es');
      final tags = cardTagsOf(state, 'es');
      final numbers = state.progressNumbers.of('es');
      expect(numbers, isNotNull);
      await state.ensureLoaded('fr');
      await _settle();
      expect(identical(state.decksOf('es'), decks), isTrue, reason: 'decks');
      expect(identical(state.decksKeyOf('es'), decks), isTrue);
      expect(
        identical(cardLookupOf(state, language: 'es'), lookup),
        isTrue,
        reason: 'the card lookup',
      );
      expect(identical(state.unlocksFor('es'), gate), isTrue, reason: 'gate');
      expect(identical(state.unlockCountsFor('es'), counts), isTrue);
      expect(identical(cardTagsOf(state, 'es'), tags), isTrue, reason: 'tags');
      expect(
        identical(state.progressNumbers.of('es'), numbers),
        isTrue,
        reason: "Progress's numbers",
      );
      phone.put('es', 'Spanish', 'spa', 1000, 4);
      await state.reloadDecks();
      expect(identical(state.decksOf('es'), decks), isFalse);
      expect(identical(cardLookupOf(state, language: 'es'), lookup), isFalse);
      expect(identical(cardTagsOf(state, 'es'), tags), isFalse);
      expect(identical(state.unlocksFor('es'), gate), isFalse);
      expect(
        identical(state.progressNumbers.of('es'), numbers),
        isFalse,
        reason: 'worked out again from the new cards',
      );
    });

    test('is the language part of the decks when read whole', () async {
      final whole = await _whole(_Phone());
      expect(whole.decksOf('fr').map((d) => d.id), <String>['fr-en-words']);
      expect(identical(whole.decksOf('fr'), whole.decksOf('fr')), isTrue);
      expect(whole.decksOf('xx'), isEmpty);
      expect(identical(whole.decksKeyOf(null), whole.decks), isTrue);
    });

    test('is empty for a language that is not loaded', () async {
      final state = await _warm(_Phone());
      expect(state.decksOf('fr'), isEmpty);
      expect(cardLookupOf(state, language: 'fr')('fr-2000'), isNull);
      expect(
        state.decksOf('es').single.cards.map((c) => c.id),
        <String>['es-1000', 'es-1001'],
      );
    });
  });

  test('Progress and Stats of the shown language read no other unit', () async {
    final phone = _Phone();
    final state = await _warm(phone);
    _learn(state);
    final jobs = List<String>.of(phone.jobs);
    final language = state.shownLanguage;
    expect(language, 'es');
    state.progressNumbers.of(language);
    final cardOf = cardLookupOf(state, language: language);
    languageLookupOf(state, language: language);
    state.unlockCountsFor(language!);
    findLeeches(state.progress, cardOf: cardOf);
    expect(phone.jobs, jobs);
    expect(state.deckCatalog.catalogSet.loadedCodes, <String>['es']);
  });

  group('the leeches of a language that is not loaded', () {
    void leech(AppState state) {
      // A pass then a miss, five times: five lapses.
      for (var i = 0; i < kLeechLapses; i++) {
        final back = 200 - 30 * i;
        _answer(state, 'fr-en-words', 'fr-2000', daysAgo: back);
        _answer(state, 'fr-en-words', 'fr-2000', daysAgo: back - 15, grade: 1);
      }
    }

    test('are counted by language, then listed once it is read', () async {
      final phone = _Phone();
      final state = await _warm(phone);
      leech(state);
      bool unread(String code) =>
          !state.languageLoad(code).isLoaded && state.summaryOf(code) != null;
      final shown = cardLookupOf(state, language: 'es');
      expect(findLeeches(state.progress, cardOf: shown), isEmpty);
      expect(
        unreadLeeches(state.progress, cardOf: shown, isUnread: unread),
        <String, int>{'fr': 1},
      );
      await state.ensureLoaded('fr');
      final all = cardLookupOf(state);
      expect(findLeeches(state.progress, cardOf: all), hasLength(1));
      expect(
        unreadLeeches(state.progress, cardOf: all, isUnread: unread),
        isEmpty,
      );
    });

    test('a language is reading until its unit is there', () async {
      final state = await _warm(_Phone());
      expect(state.isLanguageReading('fr'), isTrue);
      expect(state.isLanguageReading('es'), isFalse);
      expect(state.isLanguageReading('xx'), isFalse, reason: 'not on phone');
      await state.ensureLoaded('fr');
      expect(state.isLanguageReading('fr'), isFalse);
    });
  });
}
