// Split out of languages_and_scripts_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the language picker, the language a course is taught from, choosing it, the language shown, the language bar.

import 'dart:async';
import 'dart:io';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/language_choice.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart' show decksBeforeReady;
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/language_row.dart';
import 'package:fluenough/features/placement/picker_fixtures.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/today/daily_card.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
import 'package:fluenough/ui/widgets/report_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsAction;
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, SystemChannels, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/hindi_courses.dart';
import 'support/picker.dart';
import 'support/languages_and_scripts_shared.dart';

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

String nameOf(AppState state, String code) =>
    state.languages.singleWhere((l) => l.code == code).name;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The picker reads assets/languages.yaml through the asset bundle, which
  // keeps what it read, and a widget test does not wait for real time. So
  // whether a test got the list depended on which tests ran before it in its
  // CI shard: a read left half done by an earlier test, or the 100 ms a
  // helper waits for a read of its own. Read once here, in real time, and
  // every test finds the finished read in the cache, in any order.
  setUpAll(() => rootBundle.loadString(spokenLanguagesAsset));

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
        // Settings opens the merged Languages page (#907); this is the older
        // page, which first launch still uses.
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    LanguagePickerPage(spokenList: pickerSpokenList),
              ),
            );
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
    testWidgets(
      'the taught-from choice is asked on the course\'s card, and never in '
      'placement',
      (tester) async {
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
        expect(
          tester.widget<SegmentedButton<String>>(choice).selected,
          <String>{'bn'},
        );
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
          // Placement asks nothing the sheet has not: the course is taught from
          // the language the sheet chose, or else its own best covered.
          expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsNothing);
          expect(find.byType(DrillFrame), findsOneWidget);
        }
      },
    );
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
          // The page opens at the unit up next, which may be far down the
          // path; the course card is built only while near the screen
          // (#853), so go back to the top to read it.
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(DecksPage),
                      matching: find.byWidgetPredicate(
                        (w) =>
                            w is Scrollable &&
                            w.axisDirection == AxisDirection.down,
                      ),
                    )
                    .first,
              )
              .position
              .jumpTo(0);
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
      double textScale = 1.0,
      String choice = 'hi',
      double width = 390,
    }) {
      usePhone(tester, textScale: textScale);
      tester.view.physicalSize = Size(width * 3, 844 * 3);
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
        state: learnerLanguageBar(eight, choice: choice),
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

    // The settled, expanded wheel (#774), as the owner saw it on a phone.
    Finder glyphs() => find.descendant(
      of: find.byType(LanguageBar),
      matching: find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('language-bar-glyph-');
      }),
    );

    Rect rectOf(WidgetTester tester, Finder finder) => Rect.fromPoints(
      tester.getTopLeft(finder),
      tester.getBottomRight(finder),
    );

    /// The glyphs drawn on the wheel (not the one hidden under the pill),
    /// as their rect on screen, which the wheel's scale shrinks, and their
    /// opacity.
    List<({Rect rect, double opacity})> drawnGlyphs(WidgetTester tester) {
      final out = <({Rect rect, double opacity})>[];
      for (var i = 0; i < glyphs().evaluate().length; i++) {
        final glyph = glyphs().at(i);
        final opacity = tester
            .widget<Opacity>(
              find.ancestor(of: glyph, matching: find.byType(Opacity)).first,
            )
            .opacity;
        if (opacity > 0) {
          out.add((rect: rectOf(tester, glyph), opacity: opacity));
        }
      }
      return out;
    }

    testWidgets('at launch, with no gesture, the selection shows the '
        'language\'s name', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = learnerLanguageBar(eight, choice: 'hi');
      await pumpApp(tester, state: state);
      expect(
        find.descendant(of: bar(), matching: find.text(nameOf(state, 'hi'))),
        findsOneWidget,
      );
    });

    testWidgets('a farther glyph is smaller and fainter than a nearer one, '
        'at rest too', (tester) async {
      await pumpBar(tester, choice: 'es', width: 600);
      await tester.pumpAndSettle();
      final centre = tester.getCenter(pill()).dx;
      final drawn = drawnGlyphs(tester)
        ..sort(
          (a, b) => (a.rect.center.dx - centre).abs().compareTo(
            (b.rect.center.dx - centre).abs(),
          ),
        );
      expect(drawn.length, greaterThanOrEqualTo(4));
      for (var i = 1; i < drawn.length; i++) {
        // A glyph either side at the same distance is as big, to the pixel.
        expect(
          drawn[i].rect.width,
          lessThanOrEqualTo(drawn[i - 1].rect.width + 0.01),
        );
        expect(
          drawn[i].opacity,
          lessThanOrEqualTo(drawn[i - 1].opacity + 0.01),
        );
      }
      expect(drawn.last.rect.width, lessThan(drawn.first.rect.width));
      expect(drawn.last.opacity, lessThan(drawn.first.opacity));
    });

    testWidgets('nothing on the wheel overlaps the bug button, at 1.4x text', (
      tester,
    ) async {
      await pumpBar(tester, textScale: 1.4);
      await tester.pumpAndSettle();
      final report = rectOf(
        tester,
        find.descendant(
          of: find.byType(LanguageBar),
          matching: find.byType(ReportButton),
        ),
      );
      expect(rectOf(tester, pill()).overlaps(report), isFalse);
      for (final glyph in drawnGlyphs(tester)) {
        expect(glyph.rect.overlaps(report), isFalse);
      }
    });

    testWidgets('once settled, the glyphs sit evenly either side of the '
        'expanded pill', (tester) async {
      // On a phone, and on a wide screen where more glyphs fit.
      for (final width in <double>[390, 600]) {
        await pumpBar(tester, textScale: 1.4, choice: 'es', width: width);
        await tester.pumpAndSettle();
        final centre = tester.getCenter(pill()).dx;
        final offsets = <double>[
          for (final glyph in drawnGlyphs(tester))
            glyph.rect.center.dx - centre,
        ];
        final left = <double>[
          for (final o in offsets)
            if (o < 0) -o,
        ]..sort();
        final right = <double>[
          for (final o in offsets)
            if (o > 0) o,
        ]..sort();
        if (width > 500) expect(left.length, greaterThanOrEqualTo(2));
        expect(left.length, right.length);
        for (var i = 0; i < left.length; i++) {
          expect(left[i], closeTo(right[i], 0.5));
          if (i > 0) {
            expect(left[i] - left[i - 1], closeTo(LanguageBar.detent, 0.5));
          }
        }
      }
    });

    // The swipe works the same wherever it starts on the bar (owner,
    // 2026-10-17: "It should be consistent").
  });
}
