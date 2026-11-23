// The screens that list or name languages read the language directory, not
// the decks (ADR-0062, Plan-Lazy-Language-Loading, work package P-C1): with
// three languages in the directory and no unit loaded they list, describe and
// name them, and what they show equals what the whole catalog gives.
import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/decks/language_summary.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/features/profiles/profile_text.dart';
import 'package:fluenough/features/settings/restore_sheet.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/language_glyph.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/picker.dart';

const String _esLang = 'code: es, iso639_3: spa, name: Spanish, script: latin';
const String _frLang = 'code: fr, iso639_3: fra, name: French, script: latin';
const String _teLang =
    'code: te, iso639_3: tel, name: Telugu, script: telugu, icon: "తె"';
const String _reading = ', reading: "r1"';

List<String> _cards(String id, String letter, int count, [String read = '']) {
  return <String>[
    for (var i = 1; i <= count; i++)
      '  - { id: $id-000$i, target: "$letter$i", native: "n$i"$read }',
  ];
}

String _deck(String id, String lang, List<String> cards, [String tags = '']) {
  return '''
schema: 1
id: $id
name: "$id"
language: { $lang }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
${tags}cards:
${cards.join('\n')}
''';
}

String _es(String id, int count) {
  final deck = 'es-en-$id';
  return _deck(deck, _esLang, _cards(deck, 'w', count));
}

String _fr(String id, int count) {
  final deck = 'fr-en-$id';
  return _deck(deck, _frLang, _cards(deck, 'w', count));
}

String _te(String id, int count, {bool script = false}) {
  final deck = 'te-en-$id';
  final tags = script ? 'tags: [script]\n' : '';
  return _deck(deck, _teLang, _cards(deck, 'క', count, _reading), tags);
}

/// Spanish's B1 plan: A1, A2 and B1, each one deck.
const String _esPath = '''
schema: 1
kind: path
id: es-path
language: es
units:
  - decks: ["es-a"]
    words: 3
    milestone: "A1"
  - decks: ["es-b"]
    words: 2
    milestone: "A2"
  - decks: ["es-c"]
    words: 2
    milestone: "B1"
''';

const String _tePath = '''
schema: 1
kind: path
id: te-path
language: te
alphabet:
  - te-letters
units:
  - [te-letters]
  - [te-words]
''';

/// Spanish with a three-unit B1 plan, French with no path, and Telugu with
/// an alphabet deck, an icon and a path.
Map<String, String> _files() => <String, String>{
  'decks/es/es-en-a.yaml': _es('a', 3),
  'decks/es/es-en-b.yaml': _es('b', 2),
  'decks/es/es-en-c.yaml': _es('c', 2),
  'decks/es/es-path.yaml': _esPath,
  'decks/fr/fr-en-words.yaml': _fr('words', 2),
  'decks/te/te-en-letters.yaml': _te('letters', 3, script: true),
  'decks/te/te-en-words.yaml': _te('words', 2),
  'decks/te/te-path.yaml': _tePath,
};

/// One phone: its summaries file and every language job that ran on it.
class _Phone {
  final MemorySnapshotStore summaryFile = MemorySnapshotStore();
  final List<String> jobs = <String>[];

  Future<LanguageOutcome> _run(LanguageJob job) async {
    jobs.add(job.code);
    return runLanguageJob(job);
  }

  DeckCatalog catalog() => DeckCatalog(
    MemoryDeckSource(_files()),
    mode: CatalogMode.lazy,
    summaries: SummaryBook(summaryFile),
    languageRunner: _run,
  );

  int jobsOf(String code) => jobs.where((c) => c == code).length;
}

SettingsNotifier _settings() => SettingsNotifier(
  spokenLanguages: const <String>['en'],
  learningLanguages: const <String>[],
  learningChosen: true,
);

/// A learner whose profile learns nothing yet, so that no language is shown
/// and no unit is read at the start.
AppState _lazyState(_Phone phone) {
  final nobody = Profile.defaultProfile.copyWith(languages: <String>{});
  final state = AppState.test(
    catalog: phone.catalog(),
    settings: _settings(),
    profiles: <Profile>[nobody],
  );
  addTearDown(state.dispose);
  return state;
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

Future<AppState> _lazyLoaded(_Phone phone) async {
  final state = _lazyState(phone);
  await state.load();
  await _settle();
  return state;
}

Future<AppState> _wholeLoaded() async {
  final state = AppState.test(
    decks: MemoryDeckSource(_files()),
    settings: _settings(),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

/// One answer in the first Spanish deck.
void _answer(AppState state) {
  state.progress.record(
    deckId: 'es-en-a',
    cardId: 'es-en-a-0001',
    mode: DrillMode.recognition,
    grade: 4,
    now: DateTime(2026, 9, 28, 9),
  );
}

String _unitsText(List<B1Unit> units) => <String>[
  for (final u in units)
    '${u.planned}/${u.words}/${u.milestone}/${u.grammar.join(',')}/${u.has}',
].join(' ');

String _withoutStamp(LanguageSummary summary) {
  final json = summary.toJson()..remove('stamp');
  return jsonEncode(json);
}

void main() {
  test('three languages are listed and described with no unit', () async {
    final phone = _Phone();
    final state = await _lazyLoaded(phone);
    final set = state.deckCatalog.catalogSet;
    expect(set.loadedCodes, isEmpty);
    final all = state.languages;
    expect(<String>[for (final l in all) l.code], <String>['es', 'fr', 'te']);
    // The bar's glyph: the icon, else the first deck's first letter.
    final glyphs = <String>[for (final l in all) languageGlyph(l, state)];
    expect(glyphs, <String>['w', 'w', 'తె']);
    // The native languages and the course's coverage, from the summary.
    final options = state.nativeOptions('es');
    expect(options.single.native.code, 'en');
    expect(options.single.native.name, 'English');
    expect(options.single.covered, 3);
    expect(options.single.total, 3);
    expect(state.nativeOptions('fr').single.covered, isNull);
    expect(state.courseNative('es'), 'en');
    // The picker's lines: completeness, the script preview, the deck ids.
    final es = state.catalogLanguageFromDirectory('es');
    expect(es.name, 'Spanish');
    expect(es.natives.single.progress.percent, 100);
    expect(es.scriptDecks, isFalse);
    expect(state.catalogLanguageFromDirectory('te').scriptDecks, isTrue);
    final preview = state.scriptPreview('te')!;
    expect(preview.decks, 1);
    final letters = <String>[for (final l in preview.letters) l.letter];
    expect(letters, <String>['క1', 'క2', 'క3']);
    expect(preview.letters.first.reading, 'r1');
    expect(state.scriptPreview('es'), isNull);
    expect(state.deckIdsOf('es'), <String>{'es-en-a', 'es-en-b', 'es-en-c'});
    expect(state.ownDeckCount, 0);
    expect(state.hasAlphabet('te'), isTrue);
    expect(state.hasAlphabet('es'), isFalse);
    expect(set.loadedCodes, isEmpty, reason: 'none of it read a unit');
  });

  test('the directory matches the whole catalog', () async {
    final lazy = await _lazyLoaded(_Phone());
    final whole = await _wholeLoaded();
    final lazyCodes = <String>[for (final l in lazy.languages) l.code];
    final wholeCodes = <String>[for (final l in whole.languages) l.code];
    expect(lazyCodes, wholeCodes);
    for (final code in <String>['es', 'fr', 'te']) {
      final fromUnit = _withoutStamp(lazy.summaryOf(code)!);
      final fromCatalog = _withoutStamp(whole.summaryOf(code)!);
      expect(fromUnit, fromCatalog, reason: '$code summaries differ');
    }
    // The units the picker counts are the ones counted from the decks.
    final fromSummary = _unitsText(lazy.b1Units('es', 'en'));
    final fromDecks = _unitsText(b1UnitsOf(whole.catalogView, 'es', 'en'));
    expect(fromSummary, fromDecks);
    final has = <int?>[for (final u in lazy.b1Units('es', 'en')) u.has];
    expect(has, <int?>[3, 2, 2]);
    expect(lazy.b1Units('es', 'zz'), isEmpty);
    expect(lazy.b1Units('xx', 'en'), isEmpty);
  });

  test('a summary of format 1 still names its language', () async {
    final lazy = await _lazyLoaded(_Phone());
    final summary = lazy.summaryOf('te')!;
    expect(summary.glyph, 'తె');
    expect(summary.scriptCount, 1);
    final decoded = jsonDecode(jsonEncode(summary.toJson()));
    final json = decoded as Map<String, Object?>;
    json.remove('glyph');
    json.remove('scriptCount');
    final stamp = json['stamp']! as Map<String, Object?>;
    stamp['format'] = 1;
    final old = LanguageSummary.tryFromJson(json)!;
    expect(old.info.name, 'Telugu');
    expect(old.glyph, '');
    final digest = old.stamp.filesDigest;
    final freshness = freshnessOf(old, filesDigest: digest, app: '');
    expect(freshness, SummaryFreshness.untrusted);
    expect(LanguageSummary.format, 3);
  });

  test('learned figures are stamped and refreshed lazily', () async {
    final phone = _Phone();
    final state = await _lazyLoaded(phone);
    final set = state.deckCatalog.catalogSet;
    final before = phone.jobsOf('es');
    // Nothing answered: nothing learned, which the directory says alone.
    expect(state.learnedShare('es'), 0.0);
    expect(state.learnedWords('es'), 0);
    expect(state.learnedShare('fr'), isNull, reason: 'no B1 plan');
    expect(phone.jobsOf('es'), before, reason: 'no unit was read');
    // One answer makes the kept figure stale: it shows as it was while one
    // background read of the unit works the new one out.
    _answer(state);
    expect(state.learnedShare('es'), 0.0);
    expect(state.learnedShare('es'), 0.0);
    await _settle();
    expect(state.learnedShare('es'), closeTo(1 / 7, 1e-9));
    expect(state.learnedWords('es'), 1);
    expect(phone.jobsOf('es'), before + 1, reason: 'read once, not twice');
    expect(set.loadedCodes, isEmpty, reason: 'the unit was let go again');
    // Now fresh: no further read.
    expect(state.learnedShare('es'), closeTo(1 / 7, 1e-9));
    await _settle();
    expect(phone.jobsOf('es'), before + 1);
  });

  test('read whole, learned figures follow the decks at once', () async {
    final state = await _wholeLoaded();
    expect(state.learnedShare('es'), 0.0);
    _answer(state);
    expect(state.learnedShare('es'), closeTo(1 / 7, 1e-9));
    expect(state.learnedWords('es'), 1);
  });

  testWidgets('the Languages page and names read no unit', (tester) async {
    usePhone(tester, textScale: 1.4);
    final phone = _Phone();
    // pumpEventQueue waits on real timers, which the test clock never fires:
    // the start runs in the real zone.
    final loaded = await tester.runAsync(() => _lazyLoaded(phone));
    final state = loaded!;
    final before = phone.jobs.length;
    final page = LanguagesPage(spokenList: pickerSpokenList);
    await pumpScreen(tester, page, state: state);
    expect(find.byType(LanguagesPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(LanguagesPage));
    final l10n = AppLocalizations.of(context)!;
    final names = languageNames(context, l10n, <String>['es', 'te', 'xx']);
    expect(names, contains('Spanish'));
    expect(names, contains('Telugu'));
    expect(names, contains('xx'), reason: 'an unknown code is its own name');
    final profile = profileLanguages(l10n, state, Profile.defaultProfile);
    expect(profile, contains('French'));
    expect(state.deckCatalog.catalogSet.loadedCodes, isEmpty);
    expect(phone.jobs.length, before, reason: 'no language job ran');
  });
}
