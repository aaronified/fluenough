// Languages and scripts: the picker searches names, own names and codes,
// keeps Learning first, goes in steps, and stops a download when the learner
// stops the language or cancels; placement places known units, stops after
// two wrong, keeps what Stop here found and saves nothing when left; the
// taught-from language is asked once per course and a unit without a deck in
// it is Coming; without the alphabet, script decks are left out and words
// are typed in Latin letters; the script learned decides what a card shows
// and what Write offers; the script test; the IPA and braille courses; the
// language bar.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/language_choice.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/placement.dart';
import 'package:fluenough/app/placement_credit.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/script_test.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart' show decksBeforeReady;
import 'package:fluenough/core/decks/ipa_course.dart';
import 'package:fluenough/core/decks/notation.dart';
import 'package:fluenough/core/models/card.dart' as model;
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_picker.dart';
import 'package:fluenough/features/placement/language_row.dart';
import 'package:fluenough/features/placement/picker_fixtures.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/placement/placement_questions.dart';
import 'package:fluenough/features/placement/script_test_page.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/features/today/daily_card.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/script_name.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
import 'package:fluenough/ui/widgets/reading_first.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsAction;
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, SystemChannels, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'support/braille_course.dart';
import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/hindi_courses.dart';
import 'support/ipa_course.dart';
import 'support/picker.dart';
import 'support/two_script_course.dart';

// From language_picker_page_test.dart.
/// Languages I'm learning (#211, #626, `docs/plans/language-picker.md` and
/// its approved mockup): plain rows in groups, the pinned search, a
/// language's sheet in steps with Back, Remove, the download under a row, and
/// accessibility. Choosing and placement through the whole app are in
/// `placement_flow_test.dart`; the update button and Remove in
/// `deck_downloads_flow_test.dart`; the catalog's arithmetic in
/// `test/core/decks/language_catalog_test.dart`.

/// The picker on [fixture], one of [PickerFixtures]' states, on the deck
/// index of the eight courses: a first launch unless it learns something.
Future<AppState> pumpPicker(
  WidgetTester tester,
  AppState Function(AppState) fixture, {
  LanguagePickerPage? page,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final app = AppState.test();
  addTearDown(app.dispose);
  final state = fixture(app);
  addTearDown(state.dispose);
  await pumpScreen(
    tester,
    page ?? LanguagePickerPage(firstRun: true, spokenList: pickerSpokenList),
    state: state,
    themeMode: themeMode,
  );
  return state;
}

/// Whether [finder] is under [code]'s row.
Finder inCard(String code, Finder finder) =>
    find.descendant(of: languageCard(code), matching: finder);

/// The codes of the rows built, in the list's order.
List<String> cardOrder(WidgetTester tester) => <String>[
  for (final row in tester.widgetList<LanguageRow>(
    find.byType(LanguageRow, skipOffstage: false),
  ))
    row.language.code,
];

/// A phone tall enough for the whole list to be built.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
}

/// GitHub, faked, letting through only as many deck files as the test
/// releases: the deck index always comes at once.
class SteppedRemote extends FakeDeckRemote {
  SteppedRemote(super.files);

  int _allowed = 0;
  final List<Completer<void>> _waiting = <Completer<void>>[];

  /// Lets [count] more files through.
  void release(int count) {
    _allowed += count;
    while (_allowed > 0 && _waiting.isNotEmpty) {
      _allowed--;
      _waiting.removeAt(0).complete();
    }
  }

  void releaseAll() => release(1 << 30);

  @override
  Future<Fetched> fetch(String path) async {
    if (path != 'decks/index.json') {
      if (_allowed > 0) {
        _allowed--;
      } else {
        final wait = Completer<void>();
        _waiting.add(wait);
        await wait.future;
      }
    }
    return super.fetch(path);
  }
}

/// The app on its first launch, downloading its decks from [remote].
AppState downloadingApp(FakeDeckRemote remote, MemoryDownloadedDecks phone) {
  final now = DateTime(2026, 10, 9, 19);
  final state = AppState.test(
    decks: DeckSources(<DeckSource>[
      MemoryDeckSource(<String, String>{
        'decks/themes.yaml': File('decks/themes.yaml').readAsStringSync(),
      }),
      phone,
    ]),
    deckDownloads: DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => now,
    ),
    settings: SettingsNotifier(spokenLanguages: const <String>['en']),
    now: now,
  );
  addTearDown(state.dispose);
  return state;
}

/// Deck downloads whose jobs never get as far as their files: each
/// language asked for has a job ([hasJob]) but is not [isDownloading], as
/// in the moment before the index is read and its files are known. Records
/// what is cancelled.
class PendingDownloads extends DeckDownloads {
  PendingDownloads(String index)
    : super(
        fetcher: MemoryDeckFetcher(<String, String>{
          'decks/index.json': index,
        }, failure: FetchFailure.offline),
        files: MemoryDownloadedDecks()..notes['index.json'] = index,
        clock: DateTime.now,
      );

  final Set<String> pending = <String>{};
  final List<String> cancelled = <String>[];

  @override
  bool hasJob(String language) => pending.contains(language);

  @override
  bool isDownloading(String language) => false;

  @override
  Future<DeckDownloadFailure?> download(
    String language,
    List<String> spoken,
  ) async {
    pending.add(language);
    return null;
  }

  @override
  Future<void> cancel(String language) async {
    pending.remove(language);
    cancelled.add(language);
  }
}

/// A first launch, for a learner who speaks English, on [downloads].
AppState Function(AppState) withDownloads(DeckDownloads downloads) =>
    (app) => AppState(
      catalog: DeckCatalog(MemoryDeckSource(const <String, String>{})),
      progress: MemoryProgress(),
      tts: const NullTtsEngine(),
      clock: app.now,
      settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      deckDownloads: downloads,
    );

Finder continueButton(AppLocalizations l10n) =>
    find.widgetWithText(FilledButton, l10n.commonContinue);

bool canContinue(WidgetTester tester, AppLocalizations l10n) =>
    tester.widget<FilledButton>(continueButton(l10n)).onPressed != null;

/// The picker on the bundled decks, for a learner who speaks English: a first
/// launch unless [learning] says what is learned.
Future<AppState> pumpFresh(
  WidgetTester tester, {
  List<String> learning = const <String>[],
  bool firstRun = true,
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  final state = AppState.test(
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: learning,
      learningChosen: learning.isNotEmpty,
    ),
  );
  addTearDown(state.dispose);
  await pumpScreen(
    tester,
    // A new key: a second picture in one test starts a page of its own.
    KeyedSubtree(
      key: UniqueKey(),
      child: LanguagePickerPage(
        firstRun: firstRun,
        spokenList: pickerSpokenList,
      ),
    ),
    state: state,
    themeMode: themeMode,
  );
  return state;
}

Finder sheetKey(String key) => find.byKey(ValueKey<String>(key));

// From placement_flow_test.dart.
/// Choosing what to learn and placement (#117, ADR-0013), from first launch
/// and from Settings.

/// The app on first launch after the languages the learner speaks, on the
/// bundled decks unless [decks] is given.
Future<AppState> pumpFirstLaunch(
  WidgetTester tester, {
  DeckSource? decks,
}) async {
  final state = AppState.test(
    decks: decks,
    settings: SettingsNotifier(spokenLanguages: const <String>['en']),
  );
  addTearDown(state.dispose);
  await tester.pumpWidget(
    withLanguageList(FluenoughApp(key: UniqueKey(), state: state)),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final found = find.text(text);
  await tester.ensureVisible(found.first);
  await tester.pumpAndSettle();
  await tester.tap(found.first);
  await tester.pumpAndSettle();
}

/// Scrolls [target] into view in the placement question on screen. Each
/// question is a lazy list whose last child is "I don't know", so what sits
/// below the fold is not built, and `ensureVisible` cannot find it.
Future<void> scrollToInFrame(WidgetTester tester, Finder target) async {
  final frame = find.byType(PlacementFrame);
  if (frame.evaluate().isEmpty) {
    await tester.ensureVisible(target.first);
  } else {
    // Not `target.first`: a `.first` finder throws while nothing matches,
    // which is just when the list has not built the target yet.
    await tester.scrollUntilVisible(
      target,
      100,
      scrollable: find
          .descendant(of: frame.first, matching: find.byType(Scrollable))
          .first,
    );
  }
  await tester.pumpAndSettle();
}

/// Taps [target] in the placement question on screen, scrolling to it first.
Future<void> tapInFrame(WidgetTester tester, Finder target) async {
  await scrollToInFrame(tester, target);
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Answers "No" to each script and "I don't know" to each word until the
/// check ends in its result.
Future<void> giveUp(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  var guard = 0;
  while (guard++ < 60) {
    if (find.text(l10n.placementScriptNo).evaluate().isNotEmpty) {
      await tapText(tester, l10n.placementScriptNo);
    } else if (find.text(l10n.placementDontKnow).evaluate().isNotEmpty ||
        find.byType(PlacementFrame).evaluate().isNotEmpty) {
      await tapInFrame(tester, find.text(l10n.placementDontKnow));
    } else {
      return;
    }
  }
}

/// Answers the placement question on screen, of whatever kind: rightly,
/// or with "I don't know".
Future<void> answerShown(WidgetTester tester, {bool right = true}) async {
  final l10n = l10nOf(tester);
  if (!right) return tapInFrame(tester, find.text(l10n.placementDontKnow));
  Future<void> tap(Finder f) => tapInFrame(tester, f);

  final match = find.byType(PlacementMatch);
  if (match.evaluate().isNotEmpty) {
    final q = tester.widget<PlacementMatch>(match).question;
    for (final (i, card) in q.cards.indexed) {
      await tap(find.byKey(ValueKey<String>('match-left-$i')));
      final j = q.answers.indexOf(card.native);
      await tap(find.byKey(ValueKey<String>('match-right-$j')));
    }
    return tap(find.widgetWithText(FilledButton, l10n.placementCheck));
  }
  final typed = find.byType(PlacementType);
  if (typed.evaluate().isNotEmpty) {
    final q = tester.widget<PlacementType>(typed).question;
    await tester.enterText(
      find.byKey(const ValueKey<String>('placement-answer')),
      q.produce ? q.card.target : q.card.reading!,
    );
    await tester.pumpAndSettle();
    return tap(find.widgetWithText(FilledButton, l10n.placementCheck));
  }
  final hear = find.byType(PlacementHear);
  if (hear.evaluate().isNotEmpty) {
    final q = tester.widget<PlacementHear>(hear).question;
    return tap(find.byKey(ValueKey<String>('hear-option-${q.answer}')));
  }
  final q = tester
      .widget<PlacementChoice>(find.byType(PlacementChoice))
      .question;
  // The options are shuffled, so the right one may sit below the fold.
  return tap(find.widgetWithText(OutlinedButton, q.answer));
}

/// Whether a placement question is on screen.
bool questionShown() =>
    find.byType(PlacementChoice).evaluate().isNotEmpty ||
    find.byType(PlacementMatch).evaluate().isNotEmpty ||
    find.byType(PlacementType).evaluate().isNotEmpty ||
    find.byType(PlacementHear).evaluate().isNotEmpty ||
    find.byType(PlacementSay).evaluate().isNotEmpty;

String nameOf(AppState state, String code) =>
    state.languages.singleWhere((l) => l.code == code).name;

Set<String> decksOf(Iterable<List<DeckEntry>> units) => <String>{
  for (final unit in units)
    for (final entry in unit) entry.id,
};

// From placement_test.dart.
/// Placement (#117, ADR-0013) on the bundled Hindi course.

// From languages_learning_fixes_test.dart.
/// What the review of #633 asked for in Languages I'm learning (#626): a
/// language the learner speaks is placed, a learned language can stop a
/// script, "Find my level" keeps a passed script test, and a chosen
/// language's choices survive closing its sheet.

/// A learner who speaks [spoken], learning [learning] (none chosen yet when
/// empty).
Future<AppState> pumpPickerLanguagesLearningFixes(
  WidgetTester tester, {
  List<String> spoken = const <String>['en'],
  List<String> learning = const <String>[],
  Set<String> noAlphabet = const <String>{},
}) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
  final state = AppState.test(
    settings: SettingsNotifier(
      spokenLanguages: spoken,
      learningLanguages: learning,
      learningChosen: learning.isNotEmpty,
      noAlphabet: noAlphabet,
    ),
  );
  addTearDown(state.dispose);
  await pumpScreen(
    tester,
    KeyedSubtree(
      key: UniqueKey(),
      child: LanguagePickerPage(
        firstRun: learning.isEmpty,
        spokenList: pickerSpokenList,
      ),
    ),
    state: state,
  );
  return state;
}

// From native_choice_test.dart.
/// Which native language a learner is taught a language from (ADR-0036,
/// DECK-FORMAT.md, Paths): asked when more than one they speak teaches it,
/// each offered with its coverage, the best covered first; kept per course.

Future<AppState> learner(
  Map<String, String> files, {
  List<String> spoken = const <String>['bn', 'en'],
  SettingsNotifier? settings,
  MemoryProgress? progress,
}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(files),
    progress: progress,
    settings:
        settings ??
        SettingsNotifier(
          spokenLanguages: spoken,
          learningLanguages: const <String>['hi'],
        ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

List<List<String>> unitIds(AppState state, {String? native}) => <List<String>>[
  for (final unit in state.courseUnits('hi', native: native))
    <String>[for (final e in unit) e.id],
];

Map<String, (int?, int?)> coverage(AppState state) => <String, (int?, int?)>{
  for (final o in state.nativeOptions('hi'))
    o.native.code: (o.covered, o.total),
};

// From native_choice_test.dart.
/// The question of which native language to learn a course from (ADR-0036,
/// DECK-FORMAT.md, Paths): in placement, on Today, and in Settings.

AppState bengaliFirst({bool chosen = false, Map<String, String>? decks}) {
  final state = AppState.test(
    decks: MemoryDeckSource(decks ?? hindi(bengali: const <String>{'a'})),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['bn', 'en'],
      learningLanguages: chosen ? const <String>['hi'] : const <String>[],
      learningChosen: chosen,
    ),
  );
  addTearDown(state.dispose);
  return state;
}

Radio<String> radioOf(WidgetTester tester, String code) => tester
    .widgetList<Radio<String>>(find.byType(Radio<String>))
    .singleWhere((r) => r.value == code);

// From language_choice_test.dart.
/// One language for the whole app (#461), chosen in the language bar
/// (#528): the choice in Settings, the rules for what it shows, Progress's
/// All, and what Today counts under it.

AppState learning(
  List<String> languages, {
  MemoryProgress? progress,
  String? choice,
}) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
    languageChoice: choice,
  ),
  progress: progress,
);

/// Learning [languages], with a few words of each taught three days ago,
/// so that each has reviews due today and a lesson to come.
Future<AppState> withReviews(List<String> languages) async {
  final base = learning(languages);
  await base.load();
  final progress = MemoryProgress();
  for (final code in languages) {
    for (final card in base.untaughtCards(code).take(4)) {
      progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: base.now().subtract(const Duration(days: 3)),
      );
    }
  }
  base.dispose();
  final state = learning(languages, progress: progress);
  await state.load();
  return state;
}

Set<String> languagesIn(AppState state, DrillRequest request) => <String>{
  for (final item in state.buildSession(request).items)
    state.deckOf(item.card)!.language.code,
};

// From language_bar_test.dart.
/// The language bar at the top of Today, Decks and Progress (#528,
/// its approved mockup, in git history), on the design's Aro, who learns Hindi
/// and Spanish, with twelve days of Spanish (and Marathi, which Aro does
/// not learn) reviews.

Future<AppState> aro({String? choice}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: FeatureRegistry.all(),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      languageChoice: choice,
    ),
  );
}

/// A learner of [languages], in that order, with no reviews.
AppState learnerLanguageBar(List<String> languages, {String? choice}) =>
    AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: languages,
        learningChosen: true,
        languageChoice: choice,
      ),
    );

/// Eight languages, as the mockup's edge mask draws them.
const List<String> eight = <String>[
  'hi',
  'bn',
  'te',
  'mr',
  'gu',
  'kn',
  'as',
  'es',
];

/// The bar on screen: the tab's, where the shell holds all three.
Finder bar() => find.byType(LanguageBar).hitTestable();

/// The selection at the centre of the wheel on the bar on screen. Not
/// `hitTestable`: the centre language's glyph is drawn over it and takes
/// the hit.
Finder pill() => find.descendant(
  of: bar(),
  matching: find.byKey(const ValueKey<String>('language-bar-selection')),
);

/// Whether the selection is filled, as it is unless All is on, when it is
/// an outline.
bool pillFilled(WidgetTester tester) =>
    (tester.widget<Container>(pill()).decoration! as BoxDecoration).color !=
    null;

/// The languages on the bar on screen, for a drag or a tap.
Finder zone() => find
    .descendant(
      of: find.byType(LanguageBar),
      matching: find.byType(GestureDetector),
    )
    .hitTestable()
    .first;

Finder allButton() =>
    find.descendant(of: bar(), matching: find.text('All')).hitTestable();

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(zone());
  await tester.pumpAndSettle();
}

/// One language is 44 dp of the wheel: a drag of [detents] languages to the
/// next ones, or the previous with a negative number.
Future<void> swipe(WidgetTester tester, int detents) async {
  await tester.drag(zone(), Offset(-44.0 * detents, 0));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

// From no_alphabet_test.dart.
/// Learning a language without its alphabet (#47): its path leaves out the
/// decks that need it, cards show the reading first, and answers in Latin
/// letters count in full.

AppState hindiWithout() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi', 'es'],
    learningChosen: true,
    noAlphabet: const <String>{'hi'},
  ),
);

// From scripts_learned_test.dart.
/// The scripts a language is learned in, one set per language (#623): kept,
/// restored, and read from the old yes or no.

const String devanagari = 'devanagari';
const String persoArabic = 'perso_arabic';

Future<AppState> hindustani(Set<String>? scripts) async {
  final state = AppState.test(
    decks: MemoryDeckSource(twoScriptCourse()),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      scriptsLearned: <String, Set<String>>{'hi': ?scripts},
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

// From scripts_drill_test.dart.
/// Drills in the scripts a language is learned in (#623): a card shown in
/// Perso-Arabic, and Write offering one option for each script learned.

AppState learningScriptsDrill(Set<String> scripts) => AppState.test(
  decks: MemoryDeckSource(twoScriptCourse()),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi'],
    learningChosen: true,
    scriptsLearned: <String, Set<String>>{'hi': scripts},
  ),
);

const String devanagariScriptsDrill = 'किताब';
const String persoArabicScriptsDrill = 'کتاب';
const Set<String> urdu = <String>{'perso_arabic'};
const Set<String> both = <String>{'devanagari', 'perso_arabic'};

Future<AppState> pump(
  WidgetTester tester,
  Set<String> scripts,
  Skill skill,
) async {
  usePhone(tester);
  final state = learningScriptsDrill(scripts);
  await state.load();
  final entry = state.deckById('hi-en-words')!;
  await pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.deck(entry.id, skill: skill),
      preset: const DrillPreset(target: devanagariScriptsDrill),
    ),
    state: state,
  );
  return state;
}

// From script_switch_test.dart.
/// The scripts of a language learned, in its sheet in Languages I'm learning
/// (#555, #626): named for the script, the one learned with its progress,
/// the others with "Add this script".

AppState learningScriptSwitch({Set<String> noAlphabet = const <String>{}}) =>
    AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['hi', 'bn', 'es'],
        learningChosen: true,
        noAlphabet: noAlphabet,
      ),
    );

// From shared_script_test.dart.
/// A script read through one language is read for every language written in
/// it (#554).

// From script_test_test.dart.
/// "How well do you know the script" (#554), on the bundled decks.

// From script_test_offer_test.dart.
/// The script test's offer in a language's sheet (#554, #626): for a learner
/// who reads the language's script through another language they know.

final List<SpokenLanguage> spokenList = parseSpokenLanguages(
  File('assets/languages.yaml').readAsStringSync(),
);

/// A learner who speaks English and Bengali, reading both, learning
/// [learning] (none chosen yet when empty).
AppState bengaliReader({
  List<String> learning = const <String>[],
  bool reads = true,
}) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en', 'bn'],
    learningLanguages: learning,
    learningChosen: learning.isNotEmpty,
  )..scriptsRead = <String, bool>{'en': true, 'bn': reads},
);

Finder offerOf(String code) =>
    find.byKey(ValueKey<String>('script-test-$code'));

/// Answers every question of the script test on screen: rightly, but for
/// [wrong], which are answered "I don't know".
Future<void> takeTest(
  WidgetTester tester,
  AppState state, {
  Set<String> wrong = const <String>{},
}) async {
  final l10n = l10nOf(tester);
  final meanings = <String, String>{
    for (final entry in state.scriptLessons('as'))
      for (final card in entry.cards) card.target: card.native,
  };
  while (find.text(l10n.scriptTestQuestion).evaluate().isNotEmpty) {
    final target = tester
        .widget<TargetText>(
          find.descendant(
            of: find.byType(ScriptTestPage),
            matching: find.byType(TargetText),
          ),
        )
        .text;
    final choice = wrong.contains(target)
        ? find.text(l10n.placementDontKnow)
        : find.widgetWithText(OutlinedButton, meanings[target]!);
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }
}

/// Taps [finder] in the open sheet, scrolling it into view first.
Future<void> tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Learns [code] in its sheet as far as its scripts screen, with its own
/// script ticked: where the offer of the test is.
Future<void> toScripts(WidgetTester tester, String code, String script) async {
  await openSheet(tester, code);
  await tapSheet(tester, 'sheet-learn');
  final box = find.byKey(ValueKey<String>('sheet-script-$script'));
  if (!tester.widget<CheckboxListTile>(box).value!) {
    await tapIn(tester, box);
  }
}

// From script_per_script_test.dart.
/// A language written in two scripts has a script guide for each (ADR-0016):
/// a deck's Tips, and the drill, show the guide of the deck's own script, and
/// the language's default guide where the script has none.

String guideOf(String id, String name) =>
    '''
schema: 1
kind: script
id: $id
language: bn
name: "$name"
intro: "A few ideas come back again and again."
features:
  - id: headline
    name: "Feature of $id"
    example: "ক"
    text: "Most letters hang from a line along the top."
''';

String deck(String id, String writing) =>
    '''
schema: 1
id: $id
name: "Probe"
language: { code: bn, iso639_3: ben, name: Bengali, script: $writing, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: $id-0001, target: "ক", native: "k (ko)", reading: "ko" }
  - { id: $id-0002, target: "খ", native: "kh (kho)", reading: "kho" }
''';

final String bengaliGuide = guideOf('bn-script', 'How Bengali works');
final String sylhetiGuide = guideOf('bn-sylheti-script', 'How Sylheti works');

AppState twoScripts({bool withSylheti = true}) {
  return AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/bn/bn-en-letters.yaml': deck('bn-en-letters', 'bengali'),
      'decks/bn/bn-en-syloti.yaml': deck('bn-en-syloti', 'sylheti'),
      'decks/bn/bn-script.yaml': bengaliGuide,
      if (withSylheti) 'decks/bn/bn-sylheti-script.yaml': sylhetiGuide,
    }),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
    ),
  );
}

Future<void> tapTextScriptPerScript(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

// From ipa_course_test.dart.
List<String> ids(Iterable<dynamic> cards) => <String>[
  for (final c in cards) c.id as String,
];

// From ipa_entries_test.dart.
Future<AppState> pumpPickerIpaEntries(
  WidgetTester tester,
  List<String> learning, {
  IpaScope? scope,
}) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
  final state = ipaApp(learning, scope: scope);
  addTearDown(state.dispose);
  await pumpScreen(tester, const LanguagePickerPage(), state: state);
  return state;
}

Future<void> proceed(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

// From braille_course_test.dart.
const LanguageInfo ipa = LanguageInfo(
  code: 'ipa',
  iso639_3: 'zxx',
  name: 'IPA',
  script: 'ipa',
  typed: false,
);

const LanguageInfo braille = LanguageInfo(
  code: 'qbe',
  iso639_3: 'eng',
  name: 'English Braille',
  script: 'braille',
);

const LanguageInfo telugu = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Telugu',
  script: 'telugu',
);

// Placement in the learner's scripts (owner, 2026-10-20).
/// A Marathi speaker who reads its script, Devanagari, learning the tiny
/// two-script Hindustani course in [scripts] (none: without its alphabet),
/// or as [reads] says when they do not read it.
AppState devanagariReader(Set<String> scripts, {bool reads = true}) =>
    AppState.test(
      decks: MemoryDeckSource(<String, String>{
        ...twoScriptCourse(),
        'decks/mr/mr-en-words.yaml': '''
schema: 1
id: mr-en-words
name: "Words"
language: { code: mr, iso639_3: mar, name: Marathi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: mr-en-words-0001, target: "घर", native: "house", reading: "ghar" }
''',
      }),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en', 'mr'],
        learningLanguages: const <String>['hi'],
        learningChosen: true,
        noAlphabet: <String>{if (scripts.isEmpty) 'hi'},
        scriptsLearned: <String, Set<String>>{'hi': scripts},
      )..scriptsRead = <String, bool>{'en': true, 'mr': reads},
    );

/// Answers each placement question on screen rightly, after [check] has
/// looked at the card each word question shows; says Yes to each script,
/// or No without [readsScripts].
Future<void> placeAll(
  WidgetTester tester,
  void Function(model.Card card) check, {
  bool readsScripts = true,
}) async {
  final l10n = l10nOf(tester);
  var guard = 0;
  var words = 0;
  while (guard++ < 40) {
    if (find.text(l10n.placementScriptYes).evaluate().isNotEmpty) {
      await tapText(
        tester,
        readsScripts ? l10n.placementScriptYes : l10n.placementScriptNo,
      );
      continue;
    }
    if (!questionShown()) break;
    if (find.text(l10n.placementQuestion).evaluate().isNotEmpty) {
      words++;
      check(tester.widget<TargetText>(find.byType(TargetText)).card!);
    }
    await answerShown(tester);
  }
  expect(words, greaterThan(0), reason: 'placement asked a word');
}

/// The [word] on screen as written: a long word on a drill card is drawn
/// with breaks between its aksharas (#515), and keeps the word as its
/// semantics label.
Finder shownWord(String word) => find.byWidgetPredicate(
  (w) => w is Text && (w.data == word || w.semanticsLabel == word),
);

Future<void> pumpPlacement(WidgetTester tester, AppState state) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    // As Find my level opens it, from Languages I'm learning.
    PlacementPage(
      languages: const <String>['hi'],
      asked: const <String>{'hi'},
      alphabet: <String, bool>{'hi': state.settings.learnsAlphabet('hi')},
      random: Random(1),
      onFinished: (_) {},
    ),
    state: state,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The picker reads assets/languages.yaml through the asset bundle, which
  // keeps what it read, and a widget test does not wait for real time. So
  // whether a test got the list depended on which tests ran before it in its
  // CI shard: a read left half done by an earlier test, or the 100 ms a
  // helper waits for a read of its own. Read once here, in real time, and
  // every test finds the finished read in the cache, in any order.
  setUpAll(() => rootBundle.loadString(SpokenLanguagesPicker.asset));

  group('the language picker', () {
    group('search', () {
      testWidgets('matches names, own names and codes, ignoring case and '
          'accents', (tester) async {
        useTallPhone(tester);
        await pumpPicker(tester, PickerFixtures.taughtFromTwo);
        final field = find.byType(TextField);

        await tester.enterText(field, 'HI');
        await tester.pumpAndSettle();
        expect(cardOrder(tester), <String>['hi', 'mr'], reason: 'Marathi too');

        await tester.enterText(field, 'espanol');
        await tester.pumpAndSettle();
        expect(cardOrder(tester), <String>['es'], reason: 'own name, accents');

        await tester.enterText(field, 'ಕನ್ನ');
        await tester.pumpAndSettle();
        expect(cardOrder(tester), <String>['kn'], reason: 'own name');

        await tester.enterText(field, 'gu');
        await tester.pumpAndSettle();
        expect(
          cardOrder(tester),
          unorderedEquals(<String>['gu', 'te']),
          reason: 'Telugu too',
        );

        await tester.enterText(field, 'kn ');
        await tester.pumpAndSettle();
        expect(cardOrder(tester), <String>['kn'], reason: 'code, trimmed');
      });
    });

    group('the groups', () {
      testWidgets('Learning first, then Popular, then every language by '
          'family, each family folded', (tester) async {
        useTallPhone(tester);
        await pumpPicker(
          tester,
          PickerFixtures.onPhone,
          page: LanguagePickerPage(spokenList: pickerSpokenList),
        );
        final l10n = l10nOf(tester);
        final learning = find.text(l10n.pickerGroupLearning(3));
        expect(learning, findsOneWidget);
        expect(
          cardOrder(tester).take(3),
          unorderedEquals(<String>['hi', 'es', 'te']),
        );
        expect(
          tester.getTopLeft(learning).dy,
          lessThan(tester.getTopLeft(languageCard('hi')).dy),
        );

        // Every family is folded until it is opened.
        await tester.drag(pickerList().first, const Offset(0, -6000));
        await tester.pumpAndSettle();
        expect(find.text(l10n.knownAllLanguages), findsOneWidget);
        final folded = find.byIcon(Icons.expand_more);
        expect(folded, findsWidgets);
        final rows = find.byType(LanguageRow).evaluate().length;
        await tester.ensureVisible(folded.first);
        await tester.pumpAndSettle();
        await tester.tap(folded.first);
        await tester.pumpAndSettle();
        expect(find.byType(LanguageRow).evaluate().length, greaterThan(rows));
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        // And folds again.
        await tester.tap(find.byIcon(Icons.expand_less));
        await tester.pumpAndSettle();
        expect(find.byType(LanguageRow).evaluate().length, rows);
      });
    });

    group('a language\'s sheet', () {
      testWidgets('learning goes in steps, each with Back: scripts, then where '
          'to start, and nothing is saved until Continue', (tester) async {
        final state = await pumpFresh(tester);
        final l10n = l10nOf(tester);
        await openSheet(tester, 'hi');
        await tapSheet(tester, 'sheet-learn');

        // Step 1: one option for each script Hindustani is written in.
        expect(find.text(l10n.pickerStepScripts(1, 2)), findsOneWidget);
        CheckboxListTile script(String code) =>
            tester.widget<CheckboxListTile>(sheetKey('sheet-script-$code'));
        expect(script('devanagari').value, isTrue);
        expect(script('perso_arabic').value, isTrue);
        await tapSheet(tester, 'sheet-script-perso_arabic');
        expect(script('perso_arabic').value, isFalse);

        // Back to the course and in again: the choice is kept.
        await tapSheet(tester, 'sheet-back');
        expect(find.text(l10n.pickerStepScripts(1, 2)), findsNothing);
        expect(sheetKey('sheet-learn'), findsOneWidget);
        await tapSheet(tester, 'sheet-learn');
        expect(script('perso_arabic').value, isFalse);

        // Step 2: where to start.
        await tapSheet(tester, 'sheet-next');
        expect(find.text(l10n.pickerStepStart(2, 2)), findsOneWidget);
        expect(sheetKey('sheet-find-language'), findsOneWidget);
        expect(sheetKey('sheet-begin-language'), findsOneWidget);
        await tapSheet(tester, 'sheet-back');
        expect(find.text(l10n.pickerStepScripts(1, 2)), findsOneWidget);
        await tapSheet(tester, 'sheet-next');
        await tapSheet(tester, 'sheet-done');

        expect(sheetIsOpen(), isFalse);
        expect(isPicked(tester, 'hi'), isTrue);
        expect(state.settings.learningLanguages, isEmpty);
        expect(find.byType(PlacementPage), findsNothing);
      });
    });

    group('leaving and removing', () {
      testWidgets('stopping a language whose download was asked for stops it, '
          'even before its files are known', (tester) async {
        useTallPhone(tester);
        final downloads = PendingDownloads(PickerFixtures.index());
        await pumpPicker(tester, withDownloads(downloads));
        await pickLanguage(tester, 'kn');
        expect(downloads.hasJob('kn'), isTrue);
        expect(downloads.isDownloading('kn'), isFalse);
        await pickLanguage(tester, 'kn');
        expect(downloads.cancelled, <String>['kn']);
      });
    });

    group('downloading', () {
      late SteppedRemote remote;
      late MemoryDownloadedDecks phone;

      setUp(() {
        remote = SteppedRemote(repoFiles(const <String>['hi']));
        phone = MemoryDownloadedDecks();
      });

      Future<AppState> start(WidgetTester tester) async {
        useTallPhone(tester);
        final state = downloadingApp(remote, phone);
        await tester.pumpWidget(
          withLanguageList(FluenoughApp(key: UniqueKey(), state: state)),
        );
        await tester.pumpAndSettle();
        return state;
      }

      int firstFiles(AppState state) {
        final entry = state.deckDownloads!.index!.language('hi')!;
        return entry
            .firstFiles(
              entry.nativesFor(const <String>['en']),
              count: decksBeforeReady,
            )
            .length;
      }

      testWidgets('Cancel, before or after the first decks, keeps whole decks; a '
          'failure says why and Try again resumes', (tester) async {
        final state = await start(tester);
        final l10n = l10nOf(tester);
        final downloads = state.deckDownloads!;
        await pickLanguage(tester, 'hi');
        remote.release(firstFiles(state) + 4);
        await tester.pumpAndSettle();

        final cancel = inCard('hi', find.text(l10n.commonCancel));
        await scrollToInPicker(tester, cancel);
        await tester.tap(cancel);
        remote.releaseAll();
        await tester.pumpAndSettle();
        final d = downloads.languageDownload('hi', const <String>['en'])!;
        expect(downloads.isPaused('hi'), isTrue);
        expect(downloads.isDownloading('hi'), isFalse);
        expect(d.ready, isTrue);
        expect(d.decks, lessThan(d.totalDecks));
        expect(inCard('hi', find.text(l10n.pickerCancelled)), findsOneWidget);
        expect(isPicked(tester, 'hi'), isTrue, reason: 'it works with those');
        expect(canContinue(tester, l10n), isTrue);

        // The course starts with what arrived.
        await tester.tap(continueButton(l10n));
        await tester.pumpAndSettle();
        await giveUp(tester);
        await tester.tap(find.text(l10n.placementDone));
        await tester.pumpAndSettle();
        expect(state.settings.learningLanguages, <String>['hi']);

        // At the next launch, the rest is not downloaded on its own.
        await downloads.resume(const <String>['hi'], const <String>['en']);
        expect(downloads.missing('hi', const <String>['en']), isNotEmpty);

        // It is, from its card in Languages I'm learning (#467).
        await tester.tap(find.text(l10n.navSettings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settingsRowLanguages));
        await tester.pumpAndSettle();
        final page = find.text(l10n.settingsLearn);
        await tester.ensureVisible(page);
        await tester.pumpAndSettle();
        await tester.tap(page);
        await tester.pumpAndSettle();
        final rest = find.text(l10n.deckDownloadsGetRest);
        await tester.ensureVisible(rest);
        await tester.pumpAndSettle();
        await tester.tap(rest);
        await tester.pumpAndSettle();
        expect(downloads.isPaused('hi'), isFalse);
        expect(downloads.missing('hi', const <String>['en']), isEmpty);

        {
          remote = SteppedRemote(repoFiles(const <String>['hi']));
          phone = MemoryDownloadedDecks();
          final state = await start(tester);
          final l10n = l10nOf(tester);
          await pickLanguage(tester, 'hi');
          final cancel = inCard('hi', find.text(l10n.commonCancel));
          await scrollToInPicker(tester, cancel);
          await tester.tap(cancel);
          remote.releaseAll();
          await tester.pumpAndSettle();
          expect(isPicked(tester, 'hi'), isFalse);
          expect(state.deckDownloads!.isPaused('hi'), isTrue);
          expect(canContinue(tester, l10n), isFalse);
          // Its card closed, so a toast, which a screen reader announces, says
          // where the rest comes from.
          expect(
            find.text(l10n.pickerCancelledUnchosen('Hindustani')),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }

        {
          remote = SteppedRemote(repoFiles(const <String>['hi']));
          phone = MemoryDownloadedDecks();
          final handle = tester.ensureSemantics();
          final state = await start(tester);
          final l10n = l10nOf(tester);
          remote.failAll = FetchFailure.offline;
          tester.takeAnnouncements();
          await pickLanguage(tester, 'hi');
          remote.releaseAll();
          await tester.pumpAndSettle();
          expect(
            inCard(
              'hi',
              find.text(
                l10n.pickerDownloadFailed(
                  l10n.pickerNoConnection,
                  l10n.pickerDecksOnPhone(0),
                ),
              ),
            ),
            findsOneWidget,
          );
          expect(canContinue(tester, l10n), isFalse);
          expect(tester.takeAnnouncements(), <Matcher>[
            isAccessibilityAnnouncement(
              l10n.pickerAnnounceChosen('Hindustani'),
            ),
            isAccessibilityAnnouncement(
              l10n.deckDownloadsProgressLabel('Hindustani'),
            ),
            isAccessibilityAnnouncement(l10n.downloadsOffline),
          ]);
          expect(
            inCard(
              'hi',
              find.bySemanticsLabel(
                l10n.pickerRetryDownloadLabel('Hindustani'),
              ),
            ),
            findsOneWidget,
          );

          remote.failAll = null;
          final retry = inCard('hi', find.text(l10n.commonRetry));
          await scrollToInPicker(tester, retry);
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(state.deckDownloads!.failureOf('hi'), isNull);
          expect(canContinue(tester, l10n), isTrue);
          expect(tester.takeAnnouncements(), <Matcher>[
            isAccessibilityAnnouncement(l10n.pickerAnnounceReady('Hindustani')),
            isAccessibilityAnnouncement(l10n.pickerAnnounceDone('Hindustani')),
          ]);
          handle.dispose();
        }
      });
    });
  });

  group('placement', () {
    testWidgets(
      'first launch asks what to learn; Find my level asks whether each '
      'script is read, No asking nothing more of it, and the walk places the '
      'decks known',
      (tester) async {
        usePhone(tester);
        final state = await pumpFirstLaunch(tester);
        final l10n = l10nOf(tester);

        expect(find.text(l10n.learnTitle), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        final go = find.widgetWithText(FilledButton, l10n.commonContinue);
        expect(tester.widget<FilledButton>(go).onPressed, isNull);

        // Where to start is asked in the language's sheet (#626): from the
        // beginning, so placement has nothing to ask.
        await pickLanguage(tester, 'hi', begin: true);
        expect(isPicked(tester, 'hi'), isTrue);
        await tester.tap(go);
        await tester.pumpAndSettle();
        expect(find.byType(PlacementPage), findsNothing);
        expect(find.byType(AppShell), findsOneWidget);
        expect(state.settings.learningLanguages, <String>['hi']);
        expect(state.settings.learningChosen, isTrue);
        expect(state.settings.placedDecks, isEmpty);
        expect(state.currentProfile.learns('bn'), isFalse);

        {
          usePhone(tester);
          final state = await pumpFirstLaunch(tester);
          final l10n = l10nOf(tester);
          final decks = state.walkDecks('hi');
          final askable = DeckWalk(decks).askableDecks;

          await pickLanguage(tester, 'hi');
          await tapText(tester, l10n.commonContinue);
          // Each of the course's scripts is asked about, and No places it
          // as new with no questions.
          expect(
            find.text(
              l10n.placementScriptAskTitle(l10n.scriptName(devanagari)),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.placementScriptAskBody), findsOneWidget);
          await tapText(tester, l10n.placementScriptNo);
          expect(
            find.text(
              l10n.placementScriptAskTitle(l10n.scriptName(persoArabic)),
            ),
            findsOneWidget,
          );
          await tapText(tester, l10n.placementScriptNo);

          // The walk: each question numbered, with no total.
          expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);
          await answerShown(tester);
          await answerShown(tester, right: false);
          // A miss gets a second question from the same deck.
          expect(find.text(l10n.placementQuestionNumber(3)), findsOneWidget);
          await answerShown(tester, right: false);

          for (final script in <String>[devanagari, persoArabic]) {
            expect(
              find.text(l10n.placementScriptNew(l10n.scriptName(script))),
              findsOneWidget,
            );
          }
          expect(
            find.text(
              l10n.placementWordsMissed(
                decks[askable[1] - 1].deck.name,
                decks[askable[1]].deck.name,
              ),
            ),
            findsOneWidget,
          );
          await tapText(tester, l10n.placementDone);
          expect(state.settings.placedDecks, <String>{
            for (final e in decks.take(askable[1])) e.id,
          });
          // The scripts chosen to learn stay learned, though new.
          expect(
            state.settings.scriptsLearned('hi', primary: devanagari),
            <String>{devanagari, persoArabic},
          );
        }
      },
    );

    testWidgets('Stop here keeps what placement found; leaving part-way saves '
        'nothing', (tester) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      final l10n = l10nOf(tester);
      final script = state.placementScripts('hi').first;

      await pickLanguage(tester, 'hi');
      await tapText(tester, l10n.commonContinue);
      await tapText(tester, l10n.placementScriptYes);
      await answerShown(tester);
      await tapText(tester, l10n.placementStop);
      expect(
        find.text(l10n.placementScriptLetters(l10n.scriptName(devanagari))),
        findsOneWidget,
      );
      expect(find.text(l10n.placementTryAgain), findsNothing);
      await tapText(tester, l10n.placementDone);
      expect(
        state.settings.placedDecks,
        ScriptCheck.placedFor(script.decks, ScriptStanding.letters),
      );
      expect(state.settings.placedDecks, isNotEmpty);

      {
        usePhone(tester);
        final state = await pumpFirstLaunch(tester);
        final l10n = l10nOf(tester);
        await pickLanguage(tester, 'hi');
        await tapText(tester, l10n.commonContinue);
        await tapText(tester, l10n.placementScriptYes);
        await answerShown(tester);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(LanguagePickerPage), findsOneWidget);
        expect(state.settings.learningChosen, isFalse);
        expect(state.settings.learningLanguages, isEmpty);
        expect(state.settings.placedDecks, isEmpty);
      }
    });

    testWidgets('Try again from here starts the walk where it landed, and is '
        'offered again only while a try gets at least a deck further', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      final l10n = l10nOf(tester);
      final decks = state.walkDecks('hi');
      final askable = DeckWalk(decks).askableDecks;
      Set<String> before(int deck) => <String>{
        for (final e in decks.take(deck)) e.id,
      };

      await pickLanguage(tester, 'hi');
      await tapText(tester, l10n.commonContinue);
      await tapText(tester, l10n.placementScriptNo);
      await tapText(tester, l10n.placementScriptNo);
      await answerShown(tester);
      await answerShown(tester, right: false);
      await answerShown(tester, right: false);
      expect(
        find.text(l10n.placementTryAgainNote(decks[askable[1]].deck.name)),
        findsOneWidget,
      );

      // From there: one deck further.
      await tapText(tester, l10n.placementTryAgain);
      expect(find.text(l10n.placementQuestionNumber(4)), findsOneWidget);
      await answerShown(tester);
      await answerShown(tester, right: false);
      await answerShown(tester, right: false);
      expect(find.text(l10n.placementNoFurther), findsNothing);
      expect(find.text(l10n.placementTryAgain), findsOneWidget);

      // From there again: no further, so this is where the learner starts.
      await tapText(tester, l10n.placementTryAgain);
      await answerShown(tester, right: false);
      await answerShown(tester, right: false);
      expect(find.text(l10n.placementNoFurther), findsOneWidget);
      expect(find.text(l10n.placementTryAgain), findsNothing);
      await tapText(tester, l10n.placementDone);
      expect(state.settings.placedDecks, before(askable[2]));
    });

    testWidgets('two languages are placed one after the other', (tester) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      final l10n = l10nOf(tester);

      await pickLanguage(tester, 'hi');
      await pickLanguage(tester, 'bn');
      await tapText(tester, l10n.commonContinue);
      // In the catalog's order, asking at once: "Find my level" was chosen in
      // each sheet.
      expect(find.text(l10n.placementScriptYes), findsOneWidget);
      await giveUp(tester);
      await tapText(tester, l10n.placementNext);
      expect(find.text(l10n.placementScriptYes), findsOneWidget);
      await giveUp(tester);
      await tapText(tester, l10n.placementDone);
      expect(state.settings.learningLanguages, <String>['bn', 'hi']);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets(
      'the owner\'s example: learning Hindustani for its Perso-Arabic, '
      'reading Devanagari through Hindi and knowing every word, the learner '
      'is placed in under 20 questions: Devanagari read, Perso-Arabic taught, '
      'the words placed to the end',
      (tester) async {
        usePhone(tester);
        final state = AppState.test(
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en', 'hi'],
            learningLanguages: const <String>['hi'],
            learningChosen: true,
            scriptsLearned: <String, Set<String>>{
              'hi': <String>{persoArabic},
            },
          )..scriptsRead = <String, bool>{'en': true, 'hi': true},
        );
        addTearDown(state.dispose);
        PlacementFound? found;
        await pumpScreen(
          tester,
          PlacementPage(
            languages: const <String>['hi'],
            asked: const <String>{'hi'},
            alphabet: const <String, bool>{'hi': true},
            scripts: <String, Set<String>>{
              'hi': <String>{persoArabic},
            },
            languageNames: const <String, String>{'hi': 'Hindi'},
            random: Random(3),
            onFinished: (f) => found = f,
          ),
          state: state,
        );
        await tester.pumpAndSettle();
        final l10n = l10nOf(tester);
        final scripts = state.placementScripts('hi');
        final deva = scripts.firstWhere((s) => s.script == devanagari);
        final urdu = scripts.firstWhere((s) => s.script == persoArabic);

        // Asked though Languages I know says so, and said so.
        expect(
          find.text(
            l10n.placementScriptAskThrough(
              l10n.scriptName(devanagari),
              'Hindi',
            ),
          ),
          findsOneWidget,
        );
        await tapText(tester, l10n.placementScriptYes);
        var asked = 0;
        final kinds = <Type>[];
        while (questionShown()) {
          for (final type in <Type>[
            PlacementMatch,
            PlacementChoice,
            PlacementType,
            PlacementHear,
            PlacementSay,
          ]) {
            if (find.byType(type).evaluate().isNotEmpty) kinds.add(type);
          }
          await answerShown(tester);
          asked++;
        }
        // No voice and no recogniser: the heard and read-aloud words are
        // words to write in Latin letters.
        expect(kinds, <Type>[
          PlacementMatch,
          PlacementChoice,
          PlacementType,
          PlacementType,
          PlacementType,
        ]);
        expect(find.text(l10n.placementScriptAskBody), findsOneWidget);
        await tapText(tester, l10n.placementScriptNo);
        // The words are shown in the script the learner reads.
        final first = tester.widget<PlacementChoice>(
          find.byType(PlacementChoice),
        );
        expect(shownWord(first.question.card.target), findsOneWidget);
        while (questionShown()) {
          await answerShown(tester);
          asked++;
        }
        expect(asked, lessThanOrEqualTo(20));

        expect(
          find.text(l10n.placementScriptReads(l10n.scriptName(devanagari))),
          findsOneWidget,
        );
        expect(
          find.text(l10n.placementScriptNew(l10n.scriptName(persoArabic))),
          findsOneWidget,
        );
        expect(find.text(l10n.placementWordsAll), findsOneWidget);
        await tapText(tester, l10n.placementDone);
        final placed = found!.placed['hi']!;
        expect(placed, containsAll(<String>[for (final e in deva.decks) e.id]));
        for (final e in urdu.decks) {
          expect(placed, isNot(contains(e.id)));
        }
        expect(
          placed,
          containsAll(<String>[for (final e in state.walkDecks('hi')) e.id]),
        );
        expect(found!.scripts['hi'], <String, ScriptStanding>{
          devanagari: ScriptStanding.reads,
          persoArabic: ScriptStanding.newTo,
        });
      },
    );
  });

  group('placement in the learner\'s scripts', () {
    testWidgets('a Devanagari reader learning Perso-Arabic is placed on the '
        'Perso-Arabic spelling, never the reading first; learning both, on '
        'each, as drills show them', (tester) async {
      await pumpPlacement(tester, devanagariReader(<String>{persoArabic}));
      await placeAll(tester, (card) {
        expect(find.byType(ReadingFirst), findsNothing);
        final urdu = card.targetScripts[persoArabic];
        if (urdu != null) {
          expect(shownWord(urdu), findsOneWidget);
          expect(shownWord(card.target), findsNothing);
        }
      });

      await pumpPlacement(
        tester,
        devanagariReader(<String>{devanagari, persoArabic}),
      );
      await placeAll(tester, (card) {
        expect(find.byType(ReadingFirst), findsNothing);
        expect(shownWord(card.target), findsOneWidget);
        if (card.targetScripts[persoArabic] case final urdu?) {
          expect(shownWord(urdu), findsOneWidget);
        }
      });
    });

    testWidgets(
      'learned without its scripts, a language is shown in a script the '
      'check found the learner reads, and its reading first when they read '
      'none',
      (tester) async {
        await pumpPlacement(tester, devanagariReader(const <String>{}));
        await placeAll(tester, (card) {
          expect(find.byType(ReadingFirst), findsNothing);
          expect(shownWord(card.target), findsOneWidget);
        });

        await pumpPlacement(
          tester,
          devanagariReader(const <String>{}, reads: false),
        );
        final l10n = l10nOf(tester);
        await tapText(tester, l10n.placementScriptNo);
        await tapText(tester, l10n.placementScriptNo);
        expect(find.byType(ReadingFirst), findsOneWidget);
      },
    );
  });

  group('placement\'s form questions', () {
    late DeckEntry nouns;
    setUpAll(() async {
      final state = AppState.test();
      await state.load();
      nouns = state.decks.firstWhere(
        (e) => e.language.code == 'hi' && e.deck.pattern != null,
      );
    });

    test('a form of a table\'s word names the word once, in the question, '
        'and offers only its forms, of which one alone is right', () {
      final pattern = nouns.deck.pattern!;
      final slotOf = <String, String>{
        for (final slot in pattern.slots)
          pattern.slotLabels[slot] ?? slot: slot,
      };
      final walk = DeckWalk(<DeckEntry>[nouns], random: Random(3));
      var asked = 0;
      while (!walk.isFinished) {
        final q = walk.question! as PlacementQuestion;
        final word = q.formOf!;
        final row = pattern.entries.singleWhere((e) => e.lemma == word.lemma);
        expect(q.options.length, greaterThan(1));
        for (final option in q.options) {
          expect(option, isNot(contains(word.lemma)));
          expect(option, isNot(contains(word.gloss)));
          final slot = slotOf[option]!;
          // Only the right option's form is the one shown.
          expect(row.forms[slot] == q.card.target, option == q.answer);
          expect(q.isRight(option), option == q.answer);
        }
        walk.answer(true);
        asked++;
      }
      expect(asked, greaterThan(0));
      expect(walk.placedDeckIds, <String>{nouns.id});
    });
  });

  group('placement\'s read-aloud question', () {
    testWidgets('a speech miss does not answer it: the learner hears that '
        'nothing was heard, and can speak again', (tester) async {
      usePhone(tester);
      final speech = FixedSpeechEngine(onDevice: <String>{'hi'})
        ..failing = const SpeechHeard.failed(SpeechFailure.noMatch);
      final state = AppState.test(
        speech: speech,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      await state.startSpeech();
      final entry = state.decks.firstWhere((e) => e.language.code == 'hi');
      final card = entry.deck.cards.first;
      final answers = <bool>[];
      await pumpScreen(
        tester,
        Scaffold(
          body: PlacementSay(
            question: SayQuestion(
              card: card,
              shown: card.target,
              language: entry.language,
            ),
            number: 1,
            onAnswer: answers.add,
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);

      await tapText(tester, l10n.placementSayStart);
      expect(answers, isEmpty);
      expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);

      // Speak again: still not answered, then heard right.
      await tapText(tester, l10n.placementSayStart);
      expect(answers, isEmpty);
      speech
        ..failing = null
        ..next = <SpeechAlternative>[SpeechAlternative(card.target)];
      await tapText(tester, l10n.placementSayStart);
      expect(answers, <bool>[true]);
      expect(speech.listens, hasLength(3));
    });
  });

  group('the script check', () {
    late PlacementScript devanagariScript;
    setUpAll(() async {
      final state = AppState.test();
      await state.load();
      devanagariScript = state
          .placementScripts('hi')
          .firstWhere((s) => s.script == devanagari);
    });

    ScriptCheck check({bool sound = false}) => ScriptCheck(
      script: devanagari,
      decks: devanagariScript.decks,
      words: devanagariScript.words,
      canHear: sound,
      canSay: sound,
      random: Random(2),
    );

    Set<String> decksNamed(List<String> endings) => <String>{
      for (final e in devanagariScript.decks)
        if (endings.any(e.id.endsWith)) e.id,
    };
    final letters = <String>[
      'script-vowels',
      'script-consonants',
      'script-digits',
    ];
    final joined = <String>[
      ...letters,
      'script-vowel-signs',
      'script-conjuncts',
    ];

    test(
      'a miss gets another question of the same level, and right, the '
      'check goes on; a second miss ends it, placed by the level reached',
      () {
        final c = check();
        expect(c.question, isA<MatchQuestion>());
        c.answer(true);
        final missed = c.question!;
        expect(missed, isA<PlacementQuestion>());
        c.answer(false);
        expect(c.isFinished, isFalse);
        expect(c.question, isA<PlacementQuestion>());
        expect(c.question!.card.id, isNot(missed.card.id));
        c.answer(true);
        expect(c.question, isA<TypeQuestion>());
        c
          ..answer(false)
          ..answer(false);
        expect(c.isFinished, isTrue);
        expect(c.asked, 5);
        expect(c.standing, ScriptStanding.joined);
        expect(c.placedDeckIds, decksNamed(joined));

        final atLetters = check()
          ..answer(false)
          ..answer(false);
        expect(atLetters.standing, ScriptStanding.newTo);
        expect(atLetters.placedDeckIds, isEmpty);

        final atJoined = check()
          ..answer(true)
          ..answer(false)
          ..answer(false);
        expect(atJoined.standing, ScriptStanding.letters);
        expect(atJoined.placedDeckIds, decksNamed(letters));
      },
    );

    test('without a voice or a recogniser, the heard and read-aloud levels '
        'are harder words to write in Latin letters; with them, a word heard '
        'and one read aloud; every level right skips the script\'s decks', () {
      for (final sound in <bool>[false, true]) {
        final c = check(sound: sound);
        final kinds = <Type>[];
        while (!c.isFinished) {
          kinds.add(c.question.runtimeType);
          c.answer(true);
        }
        expect(kinds, <Type>[
          MatchQuestion,
          PlacementQuestion,
          TypeQuestion,
          if (sound) HearQuestion else TypeQuestion,
          if (sound) SayQuestion else TypeQuestion,
        ]);
        expect(c.standing, ScriptStanding.reads);
        expect(c.placedDeckIds, <String>{
          for (final e in devanagariScript.decks) e.id,
        });
      }
    });
  });

  group('the deck walk', () {
    late List<DeckEntry> decks;
    late List<DeckEntry> telugu;
    late List<int> askable;
    setUpAll(() async {
      final state = AppState.test();
      await state.load();
      decks = state.walkDecks('hi');
      telugu = state.walkDecks('te');
      askable = DeckWalk(decks).askableDecks;
    });

    DeckWalk walk() => DeckWalk(decks, random: Random(7));

    test('three decks right at the first try skip the next, and five jump to '
        'the end', () {
      final w = walk();
      final asked = <int>[];
      while (w.phase == WalkPhase.forward) {
        asked.add(w.asking!);
        w.answer(true);
      }
      expect(asked, <int>[
        askable[0],
        askable[1],
        askable[2],
        askable[4],
        askable[5],
      ]);
      expect(w.phase, WalkPhase.end);
      expect(w.asking, askable.last);
    });

    test('a miss gets a second question from the same deck: right, the walk '
        'goes on, its run counted again; wrong, it stops before that deck', () {
      final w = walk()..answer(true);
      final missed = w.question!;
      w.answer(false);
      expect(w.asking, askable[1]);
      expect(w.question!.card.id, isNot(missed.card.id));
      w.answer(true);
      final asked = <int>[];
      for (var i = 0; i < 3; i++) {
        asked.add(w.asking!);
        w.answer(true);
      }
      expect(asked, <int>[askable[2], askable[3], askable[4]]);
      expect(w.asking, askable[6], reason: 'three in a row skip one');
      w
        ..answer(false)
        ..answer(false);
      expect(w.isFinished, isTrue);
      expect(w.landing, askable[6]);
      expect(w.missed, askable[6]);
      expect(w.placedDeckIds, <String>{
        for (final e in decks.take(askable[6])) e.id,
      });
    });

    test('wrong at the end, the walk steps back by 2, then 3 more, then 5, '
        'until right; then two or three typed questions from the decks after '
        'decide where it lands', () {
      for (final typedRight in <bool>[true, false]) {
        final w = walk();
        for (var i = 0; i < 5; i++) {
          w.answer(true);
        }
        final end = askable.length - 1;
        expect(w.asking, askable[end]);
        w.answer(false);
        expect(w.asking, askable[end - 2]);
        w.answer(false);
        expect(w.asking, askable[end - 5]);
        w.answer(false);
        expect(w.asking, askable[end - 10]);
        w.answer(true);
        expect(w.phase, WalkPhase.produce);
        final typed = <int>[];
        while (w.phase == WalkPhase.produce) {
          expect(w.question, isA<TypeQuestion>());
          typed.add(w.asking!);
          w.answer(typedRight);
        }
        for (final deck in typed) {
          expect(deck, greaterThan(askable[end - 10]));
          expect(deck, lessThan(askable[end - 5]));
        }
        if (typedRight) {
          expect(typed.length, inInclusiveRange(2, 3));
          expect(w.landing, greaterThan(typed.last));
          expect(w.landing, lessThanOrEqualTo(askable[end - 5]));
        } else {
          expect(typed.length, 1);
          expect(w.landing, typed.single, reason: 'lands on the deck missed');
        }
      }
    });

    test('on the longest path, no way of answering asks more than about 20 '
        'questions of the words, so placement stays well under 40 with a '
        'script check at its longest (owner, 2026-10-20: "I cannot be '
        'expected to answer 100+ questions")', () {
      expect(telugu.length, greaterThan(100));
      var worst = 0;
      void run(bool Function(int n) right) {
        final w = DeckWalk(telugu, random: Random(1));
        var n = 0;
        while (!w.isFinished && n < 1000) {
          w.answer(right(n++));
        }
        expect(w.isFinished, isTrue);
        worst = max(worst, w.asked);
      }

      run((_) => true);
      run((_) => false);
      run((n) => n.isOdd);
      run((n) => n.isEven);
      run((n) => n < 5);
      for (final p in <double>[0.3, 0.5, 0.7, 0.85, 0.95]) {
        for (var seed = 0; seed < 100; seed++) {
          final random = Random(seed);
          run((_) => random.nextDouble() < p);
        }
      }
      expect(worst, lessThanOrEqualTo(24));
      // A script check asks at most two questions at each of five levels.
      expect(worst + 2 * 5, lessThan(36));
    });
  });

  group('Find my level', () {
    group('a language the learner speaks', () {
      testWidgets(
        'a language goes through placement when Find my level is chosen, '
        'and starting at the beginning places nothing',
        (tester) async {
          await pumpPickerLanguagesLearningFixes(
            tester,
            spoken: const <String>['en', 'hi'],
          );
          final l10n = l10nOf(tester);
          await pickLanguage(tester, 'hi');
          await tester.tap(find.text(l10n.commonContinue));
          await tester.pumpAndSettle();
          expect(find.byType(PlacementPage), findsOneWidget);

          {
            final state = await pumpPickerLanguagesLearningFixes(
              tester,
              spoken: const <String>['en', 'es'],
            );
            final l10n = l10nOf(tester);
            await pickLanguage(tester, 'es', begin: true);
            await tester.tap(find.text(l10n.commonContinue));
            await tester.pumpAndSettle();
            expect(find.byType(PlacementPage), findsNothing);
            expect(state.settings.learningLanguages, contains('es'));
          }
        },
      );
    });
  });

  group('the language a course is taught from', () {
    test('the learner is asked once which language a course is taught from, '
        'and a unit with no deck in it is Coming', () async {
      final state = await learner(
        hindi(bengali: const <String>{'a', 'b', 'c'}),
      );
      expect(state.needsNativeChoice('hi'), isTrue);
      state.chooseNative('hi', 'en');
      expect(state.needsNativeChoice('hi'), isFalse);
      expect(state.courseNative('hi'), 'en', reason: 'the choice, not the tie');
      expect(unitIds(state).first, <String>['hi-en-a']);

      final restored = SettingsNotifier()..restore(state.settings.toStored());
      expect(restored.courseNative('hi'), 'en');
      expect(restored.nativesOffered('hi'), <String>{'bn', 'en'});

      {
        final state = await learner(hindi(bengali: const <String>{'a'}));
        state.chooseNative('hi', 'bn');
        expect(unitIds(state), <List<String>>[
          <String>['hi-bn-a'],
        ]);
        final path = state.pathOf(state.deckById('hi-bn-a')!)!;
        expect(path.plan.map((u) => u.isComing), <bool>[false, true, true]);
      }
    });

    test('changing the language a course is learned from keeps what '
        'placement found', () async {
      final state = await learner(
        hindi(bengali: const <String>{'a', 'b', 'c'}),
      );
      state.chooseNative('hi', 'en');
      state.settings.placedDecks = const <String>{'hi-en-a', 'hi-en-b'};
      expect(state.pendingUnits.map((u) => [for (final e in u) e.id]), [
        ['hi-en-c'],
      ]);

      state.chooseNative('hi', 'bn');
      expect(
        state.isPlaced(state.deckById('hi-bn-a')!),
        isTrue,
        reason: 'core',
      );
      expect(state.isPlaced(state.deckById('hi-bn-b')!), isTrue);
      expect(state.isPlaced(state.deckById('hi-bn-c')!), isFalse);
      expect(state.pendingUnits.map((u) => [for (final e in u) e.id]), [
        ['hi-bn-c'],
      ]);
      // Saved as placement saved it: by the decks of the course placed.
      expect(state.settings.placedDecks, {'hi-en-a', 'hi-en-b'});
    });
  });

  group('choosing it', () {
    testWidgets('the taught-from choice is asked on the course\'s card, and in '
        'placement', (tester) async {
      usePhone(tester);
      final state = bengaliFirst();
      await tester.pumpWidget(
        withLanguageList(FluenoughApp(key: UniqueKey(), state: state)),
      );
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);

      // The choice is on the first screen of the language's sheet (#626).
      await openSheet(tester, 'hi');
      final choice = find.byType(SegmentedButton<String>);
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final buttons = tester.widget<SegmentedButton<String>>(choice);
      expect(buttons.segments.map((s) => s.value), <String>['bn', 'en']);
      expect(buttons.selected, <String>{'en'}, reason: 'the best covered');

      await tester.tap(
        find.descendant(of: choice, matching: find.text('Bengali')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<String>>(choice).selected, <String>{
        'bn',
      });
      await tapSheet(tester, 'sheet-learn');
      while (sheetIsOpen()) {
        final next = find.byKey(const ValueKey<String>('sheet-next'));
        await tapSheet(
          tester,
          next.evaluate().isNotEmpty ? 'sheet-next' : 'sheet-done',
        );
      }
      await tapText(tester, l10n.commonContinue);
      expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsNothing);
      expect(find.text(l10n.placementQuestion), findsOneWidget);
      expect(
        state.settings.courseNative('hi'),
        isNull,
        reason: 'not yet saved',
      );

      await giveUp(tester);
      await tapText(tester, l10n.placementDone);
      expect(state.settings.courseNative('hi'), 'bn');
      expect(state.settings.nativesOffered('hi'), <String>{'bn', 'en'});
      expect(state.needsNativeChoice('hi'), isFalse);
      expect(state.courseUnits('hi').single.single.id, 'hi-bn-a');

      {
        usePhone(tester);
        final state = bengaliFirst();
        await pumpScreen(
          tester,
          PlacementPage(languages: const <String>['hi'], onFinished: (_) {}),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsOneWidget);
        expect(find.text(l10n.nativeChoiceCoverageAll(3)), findsOneWidget);
        expect(find.text(l10n.nativeChoiceCoverage(1, 3)), findsOneWidget);
        final group = tester.widget<RadioGroup<String>>(
          find.byType(RadioGroup<String>),
        );
        expect(group.groupValue, 'en', reason: 'the best covered');
        expect(radioOf(tester, 'bn').value, 'bn');
      }
    });
  });

  group('the language shown', () {
    group('LanguageChoice', () {
      test('offers the languages chosen, in their order; a language no longer '
          'learned goes back to the default', () {
        expect(
          LanguageChoice.options(
            learning: const <String>['te', 'hi', 'fr'],
            available: const <String>['es', 'hi', 'te'],
          ),
          <String>['te', 'hi', 'es'],
          reason: 'fr has no deck on the phone, so nothing to show',
        );

        final s = SettingsNotifier()
          ..learningLanguages = const <String>['hi', 'te']
          ..languageChoice = 'te';
        s.learningLanguages = const <String>['hi', 'te', 'bn'];
        expect(s.languageChoice, 'te', reason: 'still learned');
        s.learningLanguages = const <String>['hi', 'bn'];
        expect(s.languageChoice, isNull);

        s.languageChoice = LanguageChoice.all;
        s.learningLanguages = const <String>['bn'];
        expect(s.languageChoice, LanguageChoice.all, reason: 'All stays All');
      });
    });

    group('the app', () {
      test('quick revision revises only the shown language', () async {
        final state = await withReviews(const <String>['bn', 'hi']);
        addTearDown(state.dispose);
        state.showLanguage('hi');
        final hindi = state.revisableCount;
        expect(hindi, greaterThan(0));
        expect(languagesIn(state, const DrillRequest.revision(4)), <String>{
          'hi',
        });
      });
    });
  });

  group('the language bar', () {
    testWidgets(
      'a swipe or a tap on the bar switches language; All is on Progress '
      'only',
      (tester) async {
        usePhone(tester);
        final state = learnerLanguageBar(const <String>[
          'hi',
          'bn',
          'te',
        ], choice: 'hi');
        await pumpApp(tester, state: state);

        // Left: the next language.
        await swipe(tester, 1);
        expect(state.shownLanguage, 'bn');
        await swipe(tester, 1);
        expect(state.shownLanguage, 'te');
        // The wheel has no ends: after the last comes the first.
        await swipe(tester, 1);
        expect(state.shownLanguage, 'hi');
        expect(tester.takeException(), isNull);

        // Right: the previous one, round the other way.
        await swipe(tester, -1);
        expect(state.shownLanguage, 'te');
        await swipe(tester, -1);
        expect(state.shownLanguage, 'bn');

        // A drag of a few dp and a slow one changes nothing.
        await tester.timedDrag(
          zone(),
          const Offset(-20, 0),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(state.shownLanguage, 'bn');

        // Today follows it: Bengali's day alone.
        final plans = tester.widget<DailyCard>(find.byType(DailyCard)).plans;
        expect(plans.map((p) => p.language.code), <String>['bn']);

        {
          usePhone(tester);
          final state = await pumpApp(tester, state: await aro(choice: 'hi'));
          final hindi = nameOf(state, 'hi');
          final spanish = nameOf(state, 'es');
          await openMenu(tester);
          final items = find.byType(MenuItemButton);
          expect(items, findsNWidgets(2));
          for (final name in <String>[hindi, spanish]) {
            expect(
              find.descendant(
                of: items,
                matching: find.byWidgetPredicate(
                  (w) => w is LanguageBarChip && w.language.name == name,
                ),
              ),
              findsOneWidget,
            );
          }
          expect(
            find.descendant(of: items, matching: find.text('All')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: find.widgetWithText(MenuItemButton, hindi),
              matching: find.byIcon(Icons.check),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.widgetWithText(MenuItemButton, spanish),
              matching: find.byIcon(Icons.check),
            ),
            findsNothing,
          );
          await tester.tap(
            find.descendant(of: items, matching: find.text(spanish)),
          );
          await tester.pumpAndSettle();
          expect(state.shownLanguage, 'es');
          expect(find.byType(MenuItemButton), findsNothing);
        }

        {
          usePhone(tester);
          final state = await pumpApp(tester, state: await aro(choice: 'es'));
          final l10n = l10nOf(tester);
          for (final tab in <ShellTab>[ShellTab.today, ShellTab.decks]) {
            state.shellTab.value = tab;
            await tester.pumpAndSettle();
            expect(allButton(), findsNothing, reason: tab.name);
          }
          state.shellTab.value = ShellTab.progress;
          await tester.pumpAndSettle();
          // One language: the Level tile.
          expect(find.text(l10n.progressLevelTitle), findsOneWidget);
          await tester.tap(allButton());
          await tester.pumpAndSettle();
          expect(state.settings.progressAll, isTrue);
          // Every language: the start date alone, as levels differ by course.
          expect(find.text(l10n.progressStartedTitle), findsOneWidget);
          expect(find.text(l10n.progressLevelTitle), findsNothing);
          // The wheel keeps its place, the selection an outline only.
          expect(pillFilled(tester), isFalse);
          expect(state.shownLanguage, 'es');

          // Today and Decks still show Spanish alone.
          state.shellTab.value = ShellTab.today;
          await tester.pumpAndSettle();
          final plans = tester.widget<DailyCard>(find.byType(DailyCard)).plans;
          expect(plans.map((p) => p.language.code), <String>['es']);
          expect(pillFilled(tester), isTrue);
          state.shellTab.value = ShellTab.decks;
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<CourseCard>(find.byType(CourseCard))
                .view
                .language
                .code,
            'es',
          );

          // On Progress, a swipe or the menu turns All off.
          state.shellTab.value = ShellTab.progress;
          await tester.pumpAndSettle();
          // With two languages, either way round is the other one.
          await swipe(tester, 1);
          expect(state.shownLanguage, 'hi');
          expect(state.settings.progressAll, isFalse);
          await tester.tap(allButton());
          await tester.pumpAndSettle();
          expect(state.settings.progressAll, isTrue);
          await openMenu(tester);
          await tester.tap(
            find.descendant(
              of: find.byType(MenuItemButton),
              matching: find.text(nameOf(state, 'es')),
            ),
          );
          await tester.pumpAndSettle();
          expect(state.settings.progressAll, isFalse);
          expect(find.text(l10n.progressLevelTitle), findsOneWidget);
        }
      },
    );

    // The wheel's keys, reduced motion, slots, direction and screen reader
    // (#703).
    Future<AppState> pumpBar(
      WidgetTester tester, {
      LanguageBarScreen screen = LanguageBarScreen.today,
      TextDirection direction = TextDirection.ltr,
    }) {
      usePhone(tester);
      return pumpScreen(
        tester,
        Directionality(
          textDirection: direction,
          child: Scaffold(
            body: LanguageBarFrame(
              screen: screen,
              reportDetail: 'Test',
              child: const SizedBox.expand(),
            ),
          ),
        ),
        state: learnerLanguageBar(eight, choice: eight.first),
      );
    }

    Future<void> focusWheel(WidgetTester tester) async {
      // The Focus on the wheel itself, not the swipe's detector above it.
      final wheelFocus = find.descendant(
        of: find.byType(LanguageBar),
        matching: find.byWidgetPredicate(
          (w) => w is Focus && w.onKeyEvent != null,
        ),
      );
      final inside = find.descendant(
        of: wheelFocus,
        matching: find.byType(GestureDetector),
      );
      Focus.of(tester.element(inside.first)).requestFocus();
      await tester.pump();
    }

    testWidgets('the arrow keys move one language, round the wheel, and a '
        'quick second press adds to the first', (tester) async {
      final state = await pumpBar(tester);
      await focusWheel(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'bn');

      // Two presses before the wheel has turned: two languages, not one.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'es');
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reduce motion a swipe lands on its language at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final state = await pumpBar(tester);
      await tester.drag(zone(), const Offset(-44, 0));
      await tester.pump();
      await tester.pump();
      expect(state.shownLanguage, 'bn');
      expect(
        find.descendant(of: bar(), matching: find.text(nameOf(state, 'bn'))),
        findsOneWidget,
      );
    });

    testWidgets('the wheel is centred whether or not the All slot holds All, '
        'which only Progress shows', (tester) async {
      await pumpBar(tester);
      final today = tester.getCenter(zone()).dx;
      expect(allButton(), findsNothing);
      final slot = find.byKey(const ValueKey<String>('language-bar-all-slot'));
      expect(tester.getSize(slot).width, 48);

      await pumpBar(tester, screen: LanguageBarScreen.progress);
      expect(allButton(), findsOneWidget);
      expect(tester.getSize(slot).width, 48);
      expect(tester.getCenter(zone()).dx, closeTo(today, 0.5));
      expect(today, closeTo(195, 1));
    });

    testWidgets('in a right to left layout the next language is to the '
        'right and the arrow keys are flipped', (tester) async {
      final state = await pumpBar(tester, direction: TextDirection.rtl);
      await tester.drag(zone(), const Offset(44, 0));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'bn');
      await tester.drag(zone(), const Offset(-44, 0));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'hi');

      await focusWheel(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'bn');
    });

    testWidgets('a screen reader hears the language and its place, and can '
        'step next and previous round the ends', (tester) async {
      final handle = tester.ensureSemantics();
      final state = await pumpBar(tester);
      final label = find.bySemanticsLabel(RegExp('^Language shown'));
      var node = tester.getSemantics(label);
      expect(
        node.label,
        'Language shown: ${nameOf(state, 'hi')}, 1 of 8 languages',
      );

      Map<String, int> actions() => <String, int>{
        for (final id in node.getSemanticsData().customSemanticsActionIds!)
          // The tap hint is an overriding action with no label.
          if (CustomSemanticsAction.getAction(id)!.label != null)
            CustomSemanticsAction.getAction(id)!.label!: id,
      };
      // On the first language there is still a previous: the last one.
      expect(
        actions().keys,
        containsAll(<String>[
          'Next language: ${nameOf(state, 'bn')}',
          'Previous language: ${nameOf(state, 'es')}',
        ]),
      );
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        actions()['Previous language: ${nameOf(state, 'es')}']!,
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'es');

      // And on the last, a next: the first.
      node = tester.getSemantics(label);
      expect(actions().keys, contains('Next language: ${nameOf(state, 'hi')}'));
      handle.dispose();
    });

    testWidgets('a cancelled touch that caught the coast settles on a '
        'language and shows its name', (tester) async {
      final state = await pumpBar(tester);
      await tester.fling(zone(), const Offset(-60, 0), 1200);
      await tester.pump(const Duration(milliseconds: 150));
      final touch = await tester.startGesture(tester.getCenter(zone()));
      await tester.pump(const Duration(milliseconds: 50));
      await touch.cancel();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(MenuItemButton), findsNothing);
      expect(
        find.descendant(
          of: bar(),
          matching: find.text(nameOf(state, state.shownLanguage!)),
        ),
        findsOneWidget,
      );
    });

    // Momentum (#682, #703).
    List<String> codesOf(AppState state) => <String>[
      for (final l in state.languageChoices) l.code,
    ];

    testWidgets('a faster fling goes further, and the same fling always goes '
        'the same distance', (tester) async {
      usePhone(tester);
      final state = learnerLanguageBar(eight, choice: eight.first);
      await pumpApp(tester, state: state);
      Future<int> flung(double speed) async {
        final before = codesOf(state).indexOf(state.shownLanguage!);
        await tester.fling(zone(), const Offset(-60, 0), speed);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final after = codesOf(state).indexOf(state.shownLanguage!);
        return (after - before + eight.length) % eight.length;
      }

      final slow = await flung(300);
      expect(slow, greaterThanOrEqualTo(1));
      expect(await flung(300), slow);
      expect(await flung(1200), greaterThan(slow));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a hard fling carries on round the wheel', (tester) async {
      usePhone(tester);
      final state = learnerLanguageBar(eight, choice: eight.first);
      await pumpApp(tester, state: state);
      final width = tester.getSize(zone()).width;
      // About 8 detents of drag and 5.7 of coast: past the last language and
      // on from the first again, short of a whole number of turns.
      await tester.fling(zone(), Offset(-width * 0.9, 0), 2000);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, isNot(eight.first));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a touch stops the coast where it is, and does not open the '
        'menu', (tester) async {
      usePhone(tester);
      final state = learnerLanguageBar(eight, choice: eight.first);
      await pumpApp(tester, state: state);
      await tester.fling(zone(), const Offset(-60, 0), 1200);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final full = codesOf(state).indexOf(state.shownLanguage!);
      state.showLanguage(eight.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.fling(zone(), const Offset(-60, 0), 1200);
      await tester.pump(const Duration(milliseconds: 150));
      final touch = await tester.startGesture(tester.getCenter(zone()));
      await touch.up();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(MenuItemButton), findsNothing);
      expect(codesOf(state).indexOf(state.shownLanguage!), lessThan(full));
    });

    testWidgets('each language passed is a detent with a tick', (tester) async {
      usePhone(tester);
      final state = learnerLanguageBar(eight, choice: eight.first);
      await pumpApp(tester, state: state);
      final ticks = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            ticks.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final finger = await tester.startGesture(tester.getCenter(zone()));
      for (var i = 0; i < 3; i++) {
        await finger.moveBy(const Offset(-44, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await finger.up();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(ticks, everyElement('HapticFeedbackType.selectionClick'));
      expect(ticks, hasLength(3));
      expect(codesOf(state).indexOf(state.shownLanguage!), 3);
    });

    testWidgets('at rest the selection shows the language\'s name; a touch '
        'folds it and lifting grows it again', (tester) async {
      usePhone(tester);
      final state = learnerLanguageBar(eight, choice: eight.first);
      await pumpApp(tester, state: state);
      await swipe(tester, 1);
      final name = nameOf(state, 'bn');
      Finder shown() => find.descendant(of: bar(), matching: find.text(name));
      expect(shown(), findsOneWidget);

      final touch = await tester.startGesture(tester.getCenter(zone()));
      // The touch is told after the press delay, in the first pump's timers;
      // the fold's clock starts at that pump's frame, and runs in the next.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shown(), findsNothing);
      await touch.cancel();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(shown(), findsOneWidget);
    });

    testWidgets('the language changes once, when the wheel stops', (
      tester,
    ) async {
      usePhone(tester);
      final state = learnerLanguageBar(eight, choice: eight.first);
      await pumpApp(tester, state: state);
      final seen = <String?>[];
      state.addListener(() => seen.add(state.shownLanguage));
      final width = tester.getSize(zone()).width;
      await tester.fling(zone(), Offset(-width * 0.9, 0), 2000);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.shownLanguage, eight.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, isNot(eight.first));
      expect(seen.where((l) => l != eight.first).toSet().length, 1);
    });

    // The swipe works the same wherever it starts on the bar (owner,
    // 2026-10-17: "It should be consistent").
  });

  group('without the alphabet', () {
    testWidgets(
      'without its alphabet, a course leaves its script decks out, and a '
      'word is typed in Latin letters',
      (tester) async {
        final state = hindiWithout();
        addTearDown(state.dispose);
        await state.load();
        final hindi = decksOf(state.courseUnits('hi'));
        final all = decksOf(state.courseUnits('hi', alphabet: true));
        final left = all.difference(hindi);
        expect(left, isNotEmpty);
        expect(
          left.every((id) => state.leavesOut(state.deckById(id)!)),
          isTrue,
        );
        expect(decksOf(state.pendingUnits).intersection(left), isEmpty);
        expect(
          state.courseUnits('bn'),
          state.courseUnits('bn', alphabet: true),
        );

        {
          usePhone(tester);
          final state = hindiWithout();
          await state.load();
          final entry = state.courseUnits('hi').first.first;
          final card = entry.cards.firstWhere((c) => c.reading != null);
          await pumpScreen(
            tester,
            DrillPage(
              request: DrillRequest.deck(entry.id, skill: Skill.production),
              preset: DrillPreset(target: card.target),
            ),
            state: state,
          );
          final l10n = l10nOf(tester);
          expect(find.text(l10n.drillInputTranslit), findsOneWidget);
          await tester.enterText(find.byType(TextField), card.reading!);
          await tester.pump();
          await tester.tap(find.text(l10n.drillCheck));
          await tester.pumpAndSettle();
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          expect(state.progress.log.single.grade, 5);
          expect(
            state.progress.log.single.grade,
            isNot(DrillSession.romanisedGrade),
          );
          expect(find.byType(ReadingFirst), findsOneWidget);
        }
      },
    );
  });

  group('the scripts learned', () {
    group('script decks', () {
      test('by default the primary script is learned; Perso-Arabic only shows '
          'right to left', () async {
        final state = await hindustani(null);
        expect(decksOf(state.courseUnits('hi')), <String>{
          'hi-en-letters',
          'hi-en-words',
        });

        {
          final state = await hindustani(<String>{persoArabic});
          final words = state.deckById('hi-en-words')!;
          final book = state.targetShown(words.cards.first, words.language);
          expect(book.text, 'کتاب');
          expect(book.language.rtl, isTrue);
          expect(book.language.script, persoArabic);
          expect(
            state.otherSpellings(words.cards.first, words.language),
            isEmpty,
          );
          final house = state.targetShown(words.cards.last, words.language);
          expect(house.text, 'घर');
          expect(house.language.rtl, isFalse);
        }
      });
    });
  });

  group('scripts in a drill', () {
    testWidgets(
      'a card shows in the script learned, and Write offers one option per '
      'script learned',
      (tester) async {
        await pump(tester, urdu, Skill.recognition);
        expect(find.text(persoArabicScriptsDrill), findsOneWidget);
        expect(find.text(devanagariScriptsDrill), findsNothing);

        await pump(tester, both, Skill.production);
        final l10n = l10nOf(tester);
        String label(String script) =>
            l10n.drillInputScript(l10n.scriptNameOr(script, 'Hindustani'));
        expect(find.text(label('devanagari')), findsOneWidget);
        expect(find.text(label('perso_arabic')), findsOneWidget);
        expect(find.text(l10n.drillInputTranslit), findsOneWidget);
      },
    );
  });

  group('changing scripts', () {
    testWidgets('adding Perso-Arabic and stopping Devanagari saves the '
        'Perso-Arabic choice, not a yes or no about Devanagari', (
      tester,
    ) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
      final state = await pumpScreen(
        tester,
        LanguagePickerPage(spokenList: pickerSpokenList),
        state: learningScriptSwitch(),
      );
      final l10n = l10nOf(tester);
      expect(state.settings.hasScriptsChosen('hi'), isFalse);

      await openSheet(tester, 'hi');
      await tester.tap(
        find.byKey(const ValueKey<String>('sheet-add-script')).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('sheet-script-perso_arabic')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('sheet-script-devanagari')),
      );
      await tester.pumpAndSettle();
      await finishSheet(tester);
      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      expect(
        state.settings.scriptsLearned('hi', primary: 'devanagari'),
        <String>{'perso_arabic'},
      );
      expect(state.settings.learnsAlphabet('hi'), isTrue);
      expect(state.settings.learnsAlphabet('bn'), isTrue);
    });
  });

  group('a script read in another language', () {
    final all = parseSpokenLanguages(
      File('assets/languages.yaml').readAsStringSync(),
    );
    String scriptOf(String code) =>
        all.singleWhere((l) => l.code == code).script!;

    test(
      'a Bengali reader reads Eastern Nagari, so Assamese is script-known',
      () {
        final readers = scriptReaders(all, const <String, bool>{
          'en': true,
          'bn': true,
        });
        expect(scriptOf('as'), 'bengali');
        expect(readers[scriptOf('as')], <String>['bn']);
        expect(readers['latin'], <String>['en']);
      },
    );
  });

  group('the script test', () {
    late AppState state;

    setUpAll(() async {
      state = AppState.test(
        settings: SettingsNotifier(spokenLanguages: const <String>['en', 'bn']),
      );
      await state.load();
    });

    List<DeckEntry> lessons(String code) =>
        state.scriptLessons(code, native: 'en');

    test(
      'an own letter wrong fails; passed, the script lessons are skipped',
      () {
        final test = ScriptTest(lessons('as'), random: Random(5));
        while (!test.isFinished) {
          final q = test.question!;
          test.answer(q.card.target == 'ৱ' ? null : q.card.native);
        }
        expect(test.right, 7);
        expect(test.passed, isFalse);

        expect(state.scriptLessonsSkipped('as', native: 'en'), isFalse);
        state.skipScriptLessons('as', true, native: 'en');
        expect(state.scriptLessonsSkipped('as', native: 'en'), isTrue);
        for (final entry in lessons('as')) {
          expect(state.isPlaced(entry), isTrue);
        }
        expect(state.scriptLearned('as'), isTrue);
        state.skipScriptLessons('as', false, native: 'en');
        expect(state.scriptLessonsSkipped('as', native: 'en'), isFalse);
        expect(state.settings.placedDecks, isEmpty);
        // Neither touches whether the course is learned in its script.
        expect(state.settings.learnsAlphabet('as'), isTrue);
      },
    );
  });

  group('the script test offered', () {
    for (final scale in <double>[1.0, 1.4]) {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
          'a Bengali reader choosing Assamese is offered the script test; '
          'passed, its script lessons are skipped',
          (tester) async {
            usePhone(tester, textScale: scale);
            await pumpScreen(
              tester,
              LanguagePickerPage(spokenList: spokenList),
              state: bengaliReader(),
              themeMode: mode,
            );
            final l10n = l10nOf(tester);
            await toScripts(tester, 'as', 'bengali');
            await tester.ensureVisible(offerOf('as'));
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: offerOf('as'),
                matching: find.text(
                  l10n.scriptTestOffer('Eastern Nagari', 'Bengali', 'Assamese'),
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                l10n.scriptTestOwnLetters('Assamese', 'ৰ (rô), ৱ (wô)'),
              ),
              findsOneWidget,
            );
            await closeSheet(tester);
            await toScripts(tester, 'te', 'telugu');
            expect(offerOf('te'), findsNothing);
            expect(tester.takeException(), isNull);

            {
              usePhone(tester);
              final state = bengaliReader(learning: const <String>['as']);
              await pumpScreen(
                tester,
                LanguagePickerPage(spokenList: spokenList),
                state: state,
              );
              final l10n = l10nOf(tester);
              expect(state.scriptLessonsSkipped('as'), isFalse);

              await openSheet(tester, 'as');
              await tapIn(tester, find.text(l10n.scriptTestTake));
              await takeTest(tester, state);
              expect(
                find.text(l10n.scriptTestPassed(8, 8, 'Assamese')),
                findsOneWidget,
              );
              await tester.tap(find.text(l10n.scriptTestDone));
              await tester.pumpAndSettle();
              expect(state.scriptLessonsSkipped('as'), isTrue);
              expect(state.settings.learnsAlphabet('as'), isTrue);
              await tester.ensureVisible(
                find.text(l10n.scriptTestSkippedNote('Assamese')),
              );
              expect(
                find.text(l10n.scriptTestSkippedNote('Assamese')),
                findsOneWidget,
              );

              await tapIn(tester, find.text(l10n.scriptTestRetake));
              await takeTest(tester, state, wrong: const <String>{'ৱ'});
              await tester.tap(find.text(l10n.scriptTestDone));
              await tester.pumpAndSettle();
              expect(state.scriptLessonsSkipped('as'), isFalse);
              expect(find.text(l10n.scriptTestTake), findsOneWidget);
            }
          },
        );
      }
    }
  });

  group('a guide per script', () {
    testWidgets('the drill shows the guide of its own script', (tester) async {
      usePhone(tester);
      final state = twoScripts();
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.untaught('bn-en-syloti')),
        state: state,
      );
      expect(find.text('How Sylheti works'), findsOneWidget);
      expect(find.text('How Bengali works'), findsNothing);
      await tapTextScriptPerScript(tester, l10nOf(tester).scriptGuideStart);
      expect(state.settings.hasSeenScriptGuide('bn-sylheti'), isTrue);
      expect(state.settings.hasSeenScriptGuide('bn'), isFalse);
    });
  });

  group('the IPA course', () {
    group('the IPA course for the languages learned', () {
      test('the IPA course follows the languages learned, and its production '
          'is chosen, not typed', () async {
        final state = ipaApp(<String>['hi', 'ipa']);
        addTearDown(state.dispose);
        await state.load();
        expect(state.deckById('ipa-en-rare'), isNull);
        state.settings.ipaScope = IpaScope.whole;
        expect(state.deckById('ipa-en-rare'), isNotNull);
        state.settings.ipaScope = IpaScope.mine;
        state.setLearningLanguages(<String>['hi', 'es', 'ipa']);
        expect(ids(state.deckById('ipa-en-basics')!.cards), [
          'ipa-0001',
          'ipa-0002',
          'ipa-0003',
          'ipa-0004',
        ]);
        expect(ids(state.deckById('ipa-en-places')!.cards), [
          'ipa-0005',
          'ipa-0006',
          'ipa-0007',
        ]);

        {
          final state = ipaApp(<String>['ipa'], scope: IpaScope.whole);
          addTearDown(state.dispose);
          await state.load();
          expect(
            state.isTyped(state.deckById('ipa-en-basics')!.cards.first),
            isFalse,
          );
          final lesson = state.lessonFor(DrillRequest.lesson(language: 'ipa'));
          expect(
            lesson.where((i) => i.mode == DrillMode.production),
            everyElement(
              predicate<SessionItem>((i) => i.ask.chooses || i.ask.onlyShows),
            ),
          );
          // Once a symbol is taught, its production joins the reviews, chosen.
          final check = lesson.firstWhere((i) => i.ask != Ask.teach);
          state.record(check, 4);
          final today = state.sessionItems(const DrillRequest.today());
          final production = today.where((i) => i.mode == DrillMode.production);
          expect(production, isNotEmpty);
          expect(production.map((i) => i.ask), everyElement(Ask.chooseWord));
        }
      });
    });
  });

  group('choosing the IPA', () {
    testWidgets('choosing "my languages" learns the IPA with that scope, and '
        'places nothing', (tester) async {
      final state = await pumpPickerIpaEntries(tester, <String>[
        'hi',
      ], scope: IpaScope.whole);
      await pickLanguage(tester, 'ipa:mine');
      expect(isPicked(tester, 'ipa:mine'), isTrue);
      expect(isPicked(tester, 'ipa:whole'), isFalse);
      await proceed(tester);
      expect(state.learningCodes, {'hi', 'ipa'});
      expect(state.settings.ipaScope, IpaScope.mine);
    });
  });

  group('the braille course', () {
    group('who learns braille', () {
      test(
        'the braille course is learned only when chosen, has no voice, and its '
        'production is typed as its own answer',
        () async {
          expect(
            const Profile(id: 'p', languages: {'es', 'qbe'}).learns('qbe'),
            isTrue,
          );
          expect(
            const Profile(id: 'p', languages: {'es'}).learns('qbe'),
            isFalse,
          );

          final state = brailleApp(<String>['es', 'qbe']);
          addTearDown(state.dispose);
          await state.load();
          final letters = state.deckById('qbe-en-letters')!.language;
          final spanish = state.deckById('es-en-words')!.language;
          expect(state.voiceStatus(spanish), VoiceStatus.available);
          expect(state.voiceStatus(letters), VoiceStatus.missing);
          expect(state.hasVoice(letters), isFalse);
          expect(state.canSpeak(letters), isFalse);
          expect(
            state.voiceLanguages.where((l) => l.code == brailleLanguageCode),
            isEmpty,
          );

          {
            final state = brailleApp(<String>['qbe']);
            addTearDown(state.dispose);
            await state.load();
            final cards = state.deckById('qbe-en-letters')!.cards;
            expect(state.isTyped(cards.first), isTrue);
            final lesson = state.lessonFor(
              DrillRequest.lesson(language: 'qbe'),
            );
            final check = lesson.firstWhere((i) => i.ask != Ask.teach);
            state.record(check, 4);
            final today = state.sessionItems(const DrillRequest.today());
            final production = today.where(
              (i) => i.mode == DrillMode.production,
            );
            expect(production, isNotEmpty);
            expect(production.map((i) => i.ask), everyElement(Ask.own));
            // Nothing to listen to: braille is not said.
            expect(today.where((i) => i.mode == DrillMode.listening), isEmpty);
          }
        },
      );
    });
  });
  group('placement credits what it found', () {
    late AppState state;
    late PlacementScript deva;
    setUp(() async {
      state = AppState.test();
      await state.load();
      deva = state
          .placementScripts('hi')
          .firstWhere((s) => s.script == devanagari);
    });

    Set<String> cardsOf(Iterable<DeckEntry> decks) => <String>{
      for (final e in decks)
        for (final c in e.cards) c.id,
    };

    test('a script read credits Read and Write, as Easy answers today', () {
      final placed = ScriptCheck.placedFor(deva.decks, ScriptStanding.reads);
      final written = state.creditPlacement(
        'hi',
        placed: placed,
        standings: <String, ScriptStanding>{devanagari: ScriptStanding.reads},
      );
      expect(written, greaterThan(0));
      final cards = cardsOf(deva.decks.where((e) => e.isScript));
      final scripts = state.progress.scriptStates;
      for (final id in cards) {
        for (final mode in <DrillMode>[
          DrillMode.readScript,
          DrillMode.writeScript,
        ]) {
          expect(
            scripts.containsKey((cardId: id, mode: mode, script: devanagari)),
            isTrue,
            reason: '$id $mode',
          );
        }
        final due = state.progress.stateOf(id, DrillMode.recognition)!;
        final easy = Fsrs.next(null, 5, now: state.now(), rated: true);
        expect(due.dueAt, easy.dueAt, reason: 'the Easy interval, from today');
        expect(due.lastReviewAt, state.now());
      }
      final numbers = StatsNumbers.of(
        state.progress,
        now: state.now(),
        range: StatsRange.all,
        cardOf: cardLookupOf(state),
      );
      expect(
        numbers.scriptSkills.keys,
        containsAll(<ScriptSkill>[
          (script: devanagari, mode: DrillMode.readScript),
          (script: devanagari, mode: DrillMode.writeScript),
        ]),
      );
    });

    test('a script stopped part-way credits Read for the letters and '
        'composites only', () {
      final placed = ScriptCheck.placedFor(deva.decks, ScriptStanding.joined);
      state.creditPlacement(
        'hi',
        placed: placed,
        standings: <String, ScriptStanding>{devanagari: ScriptStanding.joined},
      );
      final credited = cardsOf(
        deva.decks.where((e) => placed.contains(e.id) && e.isScript),
      );
      final reading = cardsOf(
        deva.decks.where((e) => !placed.contains(e.id) && e.isScript),
      ).difference(credited);
      final scripts = state.progress.scriptStates;
      expect(credited, isNotEmpty);
      expect(reading, isNotEmpty);
      for (final id in credited) {
        expect(
          scripts.containsKey((
            cardId: id,
            mode: DrillMode.readScript,
            script: devanagari,
          )),
          isTrue,
        );
        expect(
          scripts.containsKey((
            cardId: id,
            mode: DrillMode.writeScript,
            script: devanagari,
          )),
          isFalse,
        );
      }
      for (final id in reading) {
        expect(state.progress.stateOf(id, DrillMode.recognition), isNull);
      }
    });

    test('placed word decks are credited, and a retake changes nothing', () {
      final walked = state.walkDecks('hi').take(2).toList();
      final placed = <String>{for (final e in walked) e.id};
      expect(state.creditPlacement('hi', placed: placed), greaterThan(0));
      final ids = cardsOf(walked);
      final states = <ProgressKey, FsrsState>{
        for (final entry in state.progress.states.entries)
          if (ids.contains(entry.key.cardId)) entry.key: entry.value,
      };
      expect(states, isNotEmpty);
      expect(state.creditPlacement('hi', placed: placed), 0);
      expect(state.progress.log.length, states.length);
    });
  });
}
