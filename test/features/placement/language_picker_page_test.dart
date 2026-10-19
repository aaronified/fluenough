import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart' show decksBeforeReady;
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/placement/course_line.dart';
import 'package:fluenough/features/placement/language_row.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/picker_fixtures.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/page_parts.dart';

import '../../support/deck_remote.dart';
import '../../support/harness.dart';
import '../../support/picker.dart';

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

/// "12% · 3 of 58 decks", as the card shows [d].
String decksLine(AppLocalizations l10n, LanguageDownload d) =>
    l10n.pickerDownloadDecks(
      B1Progress.percentOf(d.totalBytes == 0 ? 0 : d.bytes / d.totalBytes),
      d.decks,
      d.totalDecks,
    );

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

void main() {
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

    testWidgets('results are grouped by family, with how many of the family '
        'match', (tester) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      final l10n = l10nOf(tester);
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pumpAndSettle();
      expect(find.text(l10n.knownFamily('indo_aryan')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('check-updates')), findsNothing);
    });

    testWidgets('with no match, says so; clearing brings every group '
        'back', (tester) async {
      final handle = tester.ensureSemantics();
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      final l10n = l10nOf(tester);
      await tester.enterText(find.byType(TextField), 'tamil');
      await tester.pumpAndSettle();
      expect(cardOrder(tester), isEmpty);
      expect(find.text(l10n.pickerNoMatchTitle('tamil')), findsOneWidget);
      expect(find.text(l10n.pickerNoMatchBody), findsOneWidget);
      // Announced as it appears, title and body together.
      final notice = tester.getSemantics(find.byType(EmptyState));
      expect(notice, isSemantics(isLiveRegion: true));
      expect(notice.label, contains(l10n.pickerNoMatchBody));

      await tester.tap(find.byTooltip(l10n.pickerClearSearch));
      await tester.pumpAndSettle();
      expect(find.text(l10n.knownAllLanguages), findsOneWidget);
      expect(find.byTooltip(l10n.pickerClearSearch), findsNothing);
      handle.dispose();
    });

    testWidgets('the search bar stays at the top as the list scrolls, and '
        'the update button scrolls away', (tester) async {
      usePhone(tester);
      await pumpPicker(
        tester,
        PickerFixtures.onPhone,
        page: LanguagePickerPage(spokenList: pickerSpokenList),
      );
      final search = find.byType(SearchBar);
      final button = find.byKey(const ValueKey<String>('check-updates'));
      final before = tester.getTopLeft(search).dy;
      expect(button, findsOneWidget);
      expect(tester.getTopLeft(button).dy, lessThan(before));

      await tester.drag(pickerList().first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(search, findsOneWidget);
      expect(tester.getTopLeft(search).dy, lessThan(before));
      expect(tester.getRect(search).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(search).bottom, lessThan(200));
      // The button went off the top; the search did not.
      expect(
        button.evaluate().isEmpty ||
            tester.getRect(button).bottom <= tester.getRect(search).top,
        isTrue,
      );
      // It still takes a search.
      await tester.enterText(find.byType(TextField), 'kan');
      await tester.pumpAndSettle();
      expect(cardOrder(tester), <String>['kn']);
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

    testWidgets('a language chosen moves to Learning; one stopped leaves it', (
      tester,
    ) async {
      await pumpFresh(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pickerGroupLearning(1)), findsNothing);
      await pickLanguage(tester, 'es');
      await tester.drag(pickerList().first, const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pickerGroupLearning(1)), findsOneWidget);
      expect(cardOrder(tester).first, 'es');
      expect(isPicked(tester, 'es'), isTrue);
      expect(
        tester.getTopLeft(find.text(l10n.pickerGroupLearning(1))).dy,
        lessThan(tester.getTopLeft(languageCard('es')).dy),
      );

      await pickLanguage(tester, 'es');
      await tester.drag(pickerList().first, const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pickerGroupLearning(1)), findsNothing);
      expect(find.byType(AlertDialog), findsNothing, reason: 'just chosen');
    });

    testWidgets('a row chosen far down the list is in view in Learning', (
      tester,
    ) async {
      await pumpFresh(tester);
      await pickLanguage(tester, 'es');
      expect(isPicked(tester, 'es'), isTrue);
      final row = languageCard('es');
      expect(tester.getRect(row).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(row).bottom, lessThan(844));
    });
  });

  group('the row', () {
    const units = <B1Unit>[
      B1Unit(words: 100, has: 50, grammar: <String>['g1']),
      B1Unit(
        words: 100,
        has: 120,
        grammar: <String>['g2'],
        milestone: Milestone.a1,
      ),
      B1Unit(
        words: 200,
        planned: true,
        grammar: <String>['g3'],
        milestone: Milestone.b1,
      ),
    ];

    CatalogLanguage telugu({List<B1Unit> course = units}) => CatalogLanguage(
      code: 'te',
      name: 'Telugu',
      ownName: 'తెలుగు',
      icon: 'తె',
      script: 'telugu',
      scriptDecks: true,
      natives: <CatalogNative>[
        (code: 'en', name: 'English', progress: B1Progress.of(course)),
      ],
    );

    Future<void> pumpRow(
      WidgetTester tester,
      CatalogLanguage language, {
      bool chosen = false,
      double? you,
      int? youWords,
      String query = '',
    }) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: <Widget>[
              LanguageRow(
                language: language,
                chosen: chosen,
                onTap: () {},
                progress: language.progressFor(const <String>['en']),
                you: you,
                youWords: youWords,
                query: query,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('is plain: the names, the tag and the learner\'s own '
        'progress, with no B1 line', (tester) async {
      await pumpRow(tester, telugu(), chosen: true, you: 0.18);
      final l10n = l10nOf(tester);
      expect(find.byType(LanguageRow), findsOneWidget);
      expect(find.text(l10n.pickerBeta), findsOneWidget);
      expect(find.text(l10n.pickerYouShort(18)), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // The A1, A2, B1 and culture line is in the language's sheet (owner,
      // 2026-10-18), not on the row.
      expect(find.byType(CourseLine), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a language not learned shows a chevron and no progress', (
      tester,
    ) async {
      await pumpRow(tester, telugu());
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.textContaining('% of B1'), findsNothing);
    });

    testWidgets('a course with no B1 plan shows the words learned instead', (
      tester,
    ) async {
      await pumpRow(
        tester,
        telugu(course: const <B1Unit>[B1Unit(has: 300)]),
        chosen: true,
        youWords: 40,
      );
      expect(find.text(l10nOf(tester).pickerYouWords(40)), findsOneWidget);
    });

    testWidgets('Alpha until A1 is written, Beta until B1 is, then '
        'Complete', (tester) async {
      Future<void> expectTag(List<B1Unit> course, String which) async {
        await pumpRow(tester, telugu(course: course));
        final l10n = l10nOf(tester);
        final tags = <String>[
          l10n.pickerAlpha,
          l10n.pickerBeta,
          l10n.pickerComplete,
        ];
        for (final t in tags) {
          expect(find.text(t), t == which ? findsOneWidget : findsNothing);
        }
        expect(find.textContaining('started'), findsNothing);
      }

      await pumpRow(tester, telugu());
      final l10n = l10nOf(tester);
      // A1's unit written: Beta.
      await expectTag(units, l10n.pickerBeta);
      // A1's unit still planned: Alpha.
      await expectTag(const <B1Unit>[
        B1Unit(words: 100, has: 50),
        B1Unit(words: 100, planned: true, milestone: Milestone.a1),
        B1Unit(words: 200, planned: true, milestone: Milestone.b1),
      ], l10n.pickerAlpha);
      // Every unit to B1 written: Complete.
      await expectTag(const <B1Unit>[
        B1Unit(words: 100, has: 100, milestone: Milestone.a1),
        B1Unit(words: 200, has: 150, milestone: Milestone.b1),
      ], l10n.pickerComplete);
      // A path with no level plan is Alpha.
      await expectTag(const <B1Unit>[
        B1Unit(has: 300),
        B1Unit(has: 340),
      ], l10n.pickerAlpha);
    });

    testWidgets('is one button to a screen reader, with its names, its '
        'stage and its progress in one label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, telugu(), chosen: true, you: 0.18);
      final l10n = l10nOf(tester);
      final node = tester.getSemantics(find.byType(LanguageRow));
      final label = node.getSemanticsData().label;
      for (final part in <String>[
        'Telugu',
        'తెలుగు',
        l10n.pickerBetaLabel,
        l10n.pickerWritten(37),
        l10n.pickerYouShort(18),
      ]) {
        expect(label, contains(part));
      }
      handle.dispose();
    });
  });

  group('a language\'s sheet', () {
    testWidgets('holds the course with the A1, A2, B1 and culture line, and '
        'Learn this language fixed below the scroll', (tester) async {
      await pumpFresh(tester);
      await openSheet(tester, 'hi');
      final l10n = l10nOf(tester);
      expect(sheetIsOpen(), isTrue);
      expect(
        find.descendant(
          of: sheetKey('sheet-scroll'),
          matching: find.byType(CourseLine),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.pickerSectionCourse), findsOneWidget);
      // Fixed: in the sheet, outside what scrolls.
      final learn = sheetKey('sheet-learn');
      expect(learn, findsOneWidget);
      expect(
        find.descendant(of: sheetKey('sheet-scroll'), matching: learn),
        findsNothing,
      );
      expect(sheetKey('sheet-stop'), findsNothing);
    });

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

    testWidgets('a language with no script decks goes straight to where to '
        'start', (tester) async {
      await pumpFresh(tester);
      final l10n = l10nOf(tester);
      await openSheet(tester, 'es');
      await tapSheet(tester, 'sheet-learn');
      expect(find.text(l10n.pickerStepStartOnly), findsOneWidget);
      expect(find.textContaining('Step 1 of'), findsNothing);
      await tapSheet(tester, 'sheet-back');
      expect(sheetKey('sheet-learn'), findsOneWidget);
      await tapSheet(tester, 'sheet-learn');
      await tapSheet(tester, 'sheet-done');
      expect(isPicked(tester, 'es'), isTrue);
    });

    testWidgets('a language chosen and not saved reopens with Stop learning', (
      tester,
    ) async {
      await pumpFresh(tester);
      await pickLanguage(tester, 'es', begin: true);
      await openSheet(tester, 'es');
      expect(sheetKey('sheet-stop'), findsOneWidget);
      expect(sheetKey('sheet-learn'), findsNothing);
    });

    testWidgets('a language learned: Find my level, its scripts, and Stop '
        'learning fixed below, which asks first', (tester) async {
      final state = await pumpFresh(
        tester,
        learning: const <String>['hi'],
        firstRun: false,
      );
      final l10n = l10nOf(tester);
      await openSheet(tester, 'hi');
      expect(sheetKey('sheet-find'), findsOneWidget);
      expect(sheetKey('sheet-learned-devanagari'), findsOneWidget);
      expect(sheetKey('sheet-learn'), findsNothing);
      final stop = sheetKey('sheet-stop');
      expect(
        find.descendant(of: sheetKey('sheet-scroll'), matching: stop),
        findsNothing,
      );

      await tapSheet(tester, 'sheet-stop');
      expect(find.text(l10n.pickerStopTitle('Hindustani')), findsOneWidget);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(sheetIsOpen(), isTrue, reason: 'Cancel keeps it');

      await tapSheet(tester, 'sheet-stop');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.pickerStopConfirm),
        ),
      );
      await tester.pumpAndSettle();
      expect(sheetIsOpen(), isFalse);
      expect(isPicked(tester, 'hi'), isFalse);
      expect(state.settings.learningLanguages, <String>[
        'hi',
      ], reason: 'saved on Continue');
    });

    testWidgets('Find my level opens the placement check for a language '
        'learned', (tester) async {
      await pumpFresh(tester, learning: const <String>['hi'], firstRun: false);
      await openSheet(tester, 'hi');
      await tapSheet(tester, 'sheet-find');
      expect(find.byType(PlacementPage), findsOneWidget);
      expect(find.text(l10nOf(tester).placementQuestion), findsOneWidget);
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

    testWidgets('closing the page unsaved stops the downloads it started', (
      tester,
    ) async {
      useTallPhone(tester);
      final downloads = PendingDownloads(PickerFixtures.index());
      await pumpPicker(tester, withDownloads(downloads));
      await pickLanguage(tester, 'kn');
      await pickLanguage(tester, 'es');
      await tester.pumpWidget(const SizedBox());
      expect(downloads.cancelled..sort(), <String>['es', 'kn']);
    });

    testWidgets('first launch has no way back', (tester) async {
      usePhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(FluenoughApp(state: state));
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePickerPage), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LanguagePickerPage))).canPop(),
        isFalse,
      );
    });

    testWidgets('a language already learned opens at once; only a new one '
        'goes through placement', (tester) async {
      useTallPhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
        ),
      );
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        LanguagePickerPage(spokenList: pickerSpokenList),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        state: state,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pickerSettingsTitle), findsOneWidget);
      expect(isPicked(tester, 'hi'), isTrue);
      await tester.tap(continueButton(l10n));
      await tester.pumpAndSettle();
      expect(find.byType(PlacementPage), findsNothing);
      expect(find.byType(LanguagePickerPage), findsNothing);
      expect(state.settings.learningLanguages, <String>['hi']);
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
      await tester.pumpWidget(FluenoughApp(state: state));
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

    testWidgets('the bar and its deck count advance; Continue waits for the '
        'first five decks; each step is announced once', (tester) async {
      final handle = tester.ensureSemantics();
      final state = await start(tester);
      final l10n = l10nOf(tester);
      final downloads = state.deckDownloads!;
      LanguageDownload now() =>
          downloads.languageDownload('hi', const <String>['en'])!;
      tester.takeAnnouncements();

      await pickLanguage(tester, 'hi');
      expect(now().decks, 0);
      expect(inCard('hi', find.text(decksLine(l10n, now()))), findsOneWidget);
      expect(
        inCard('hi', find.text(l10n.pickerReadyAfter(decksBeforeReady))),
        findsOneWidget,
      );
      expect(canContinue(tester, l10n), isFalse);
      expect(
        find.text(l10n.pickerHintWaiting(decksBeforeReady, 'Hindustani')),
        findsOneWidget,
      );
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement(l10n.pickerAnnounceChosen('Hindustani')),
        isAccessibilityAnnouncement(
          l10n.deckDownloadsProgressLabel('Hindustani'),
        ),
      ]);
      // Its Cancel says whose download it stops.
      expect(
        inCard(
          'hi',
          find.bySemanticsLabel(l10n.pickerCancelDownloadLabel('Hindustani')),
        ),
        findsOneWidget,
      );

      remote.release(firstFiles(state));
      await tester.pumpAndSettle();
      expect(now().ready, isTrue);
      expect(now().decks, greaterThanOrEqualTo(decksBeforeReady));
      expect(inCard('hi', find.text(l10n.pickerReady)), findsOneWidget);
      expect(canContinue(tester, l10n), isTrue);
      expect(find.text(l10n.pickerHintNext('Hindustani')), findsOneWidget);
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement(l10n.pickerAnnounceReady('Hindustani')),
      ]);

      final before = now().decks;
      remote.release(12);
      await tester.pumpAndSettle();
      expect(now().decks, greaterThan(before));
      expect(now().decks, lessThan(now().totalDecks));
      expect(inCard('hi', find.text(decksLine(l10n, now()))), findsOneWidget);
      expect(tester.takeAnnouncements(), isEmpty, reason: 'no percents');

      remote.releaseAll();
      await tester.pumpAndSettle();
      expect(now().decks, now().totalDecks);
      expect(inCard('hi', find.text(l10n.pickerDownloaded)), findsOneWidget);
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement(l10n.pickerAnnounceDone('Hindustani')),
      ]);

      await tester.tap(continueButton(l10n));
      await tester.pumpAndSettle();
      expect(find.byType(PlacementPage), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Cancel after the first decks keeps what is in, and the rest '
        'waits on its card in Languages I\'m learning', (tester) async {
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
      while (find.text(l10n.placementDontKnow).evaluate().isNotEmpty) {
        await tester.tap(find.text(l10n.placementDontKnow));
        await tester.pumpAndSettle();
      }
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
    });

    testWidgets('Cancel before the first decks are in un-chooses the '
        'language', (tester) async {
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
    });

    testWidgets('leaving without saving stops a new language\'s download', (
      tester,
    ) async {
      final state = await start(tester);
      final downloads = state.deckDownloads!;
      await pickLanguage(tester, 'hi');
      remote.release(firstFiles(state));
      await tester.pumpAndSettle();
      expect(downloads.hasJob('hi'), isTrue, reason: 'the rest is coming');

      // First launch has no Back: the page goes as an abandoned flow would.
      await tester.pumpWidget(const SizedBox());
      remote.releaseAll();
      await tester.pumpAndSettle();
      expect(downloads.isPaused('hi'), isTrue);
      expect(downloads.missing('hi', const <String>['en']), isNotEmpty);
    });

    testWidgets('a failure stops the bar and says why; Try again resumes; '
        'each is announced once', (tester) async {
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
        isAccessibilityAnnouncement(l10n.pickerAnnounceChosen('Hindustani')),
        isAccessibilityAnnouncement(
          l10n.deckDownloadsProgressLabel('Hindustani'),
        ),
        isAccessibilityAnnouncement(l10n.downloadsOffline),
      ]);
      expect(
        inCard(
          'hi',
          find.bySemanticsLabel(l10n.pickerRetryDownloadLabel('Hindustani')),
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
    });
  });

  group('accessibility', () {
    final pickerEntries = allGalleryEntries
        .where((e) => e.id.startsWith('picker-') || e.id == 'learn-languages')
        .toList();

    Future<void> pumpEntry(
      WidgetTester tester,
      String id,
      ThemeMode mode,
    ) async {
      final entry = pickerEntries.singleWhere((e) => e.id == id);
      final app = AppState.test();
      addTearDown(app.dispose);
      await app.load();
      final state = (entry.state ?? GalleryFixtures.state)(app);
      await pumpScreen(
        tester,
        KeyedSubtree(
          key: UniqueKey(),
          child: Builder(builder: entry.builder),
        ),
        state: state,
        themeMode: mode,
      );
    }

    test('the gallery shows the picker in each state the mockup draws', () {
      expect(
        pickerEntries.map((e) => e.id),
        containsAll(<String>[
          'learn-languages',
          'picker-settings',
          'picker-search',
          'picker-no-match',
          'picker-script',
          'picker-alpha',
          'picker-taught-from',
          'picker-taught-from-three',
          'picker-taught-from-list',
          'picker-on-phone',
          'picker-downloading',
          'picker-ready',
          'picker-offline',
          'picker-cancelled',
        ]),
      );
    });

    /// The phone, at [scale], tall enough for every card to be built.
    void useTallPhoneAt(WidgetTester tester, double scale) {
      usePhone(tester, textScale: scale);
      tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
    }

    /// The theme [mode] asks for is the one the page is drawn in.
    void expectTheme(WidgetTester tester, ThemeMode mode, String id) {
      expect(
        Theme.of(tester.element(find.byType(LanguagePickerPage))).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        reason: id,
      );
    }

    Future<void> expectGuidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('nothing overflows at 1.4x text, light and dark, scrolled '
        'through', (tester) async {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        for (final entry in pickerEntries) {
          usePhone(tester, textScale: 1.4);
          await pumpEntry(tester, entry.id, mode);
          expect(tester.takeException(), isNull, reason: entry.id);
          expectTheme(tester, mode, entry.id);
          final list = pickerList();
          if (list.evaluate().isNotEmpty) {
            for (var i = 0; i < 4; i++) {
              await tester.drag(list.first, const Offset(0, -700));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: entry.id);
            }
          }
        }
      }
    });

    testWidgets('every screen of a language\'s sheet and the "Stop learning" '
        'dialog fit and meet the guidelines at 1.4x text, light and dark', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        await pumpFresh(tester, textScale: 1.4, themeMode: mode);
        final l10n = l10nOf(tester);
        await openSheet(tester, 'hi');
        expect(tester.takeException(), isNull, reason: 'course');
        await expectGuidelines(tester);
        await tapSheet(tester, 'sheet-learn');
        expect(tester.takeException(), isNull, reason: 'scripts');
        await expectGuidelines(tester);
        await tapSheet(tester, 'sheet-next');
        expect(tester.takeException(), isNull, reason: 'start');
        await expectGuidelines(tester);
        await closeSheet(tester);

        // A language learned, from Settings: its sheet, and the dialog.
        await pumpFresh(
          tester,
          learning: const <String>['hi'],
          firstRun: false,
          textScale: 1.4,
          themeMode: mode,
        );
        await openSheet(tester, 'hi');
        expect(tester.takeException(), isNull, reason: 'learned');
        await expectGuidelines(tester);
        await tapSheet(tester, 'sheet-stop');
        expect(find.text(l10n.pickerStopTitle('Hindustani')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'dialog');
        await expectGuidelines(tester);
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        await closeSheet(tester);
      }
      handle.dispose();
    });

    testWidgets('the taught-from choice sits in the sheet: a list over it '
        'from four languages', (tester) async {
      await pumpEntry(tester, 'picker-taught-from-list', ThemeMode.light);
      final l10n = l10nOf(tester);
      await openSheet(tester, 'te');
      final change = find.text(l10n.pickerChangeNative);
      await tester.ensureVisible(change);
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<String>), findsWidgets);
      await tester.tap(find.widgetWithText(RadioListTile<String>, 'Gujarati'));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(sheetIsOpen(), isTrue, reason: 'the language\'s sheet stays');
    });

    for (final scale in <double>[1.0, 1.4]) {
      testWidgets('every state meets the tap-target, label and contrast '
          'guidelines, light and dark, at text size ${scale}x', (tester) async {
        final handle = tester.ensureSemantics();
        for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
          for (final entry in pickerEntries) {
            useTallPhoneAt(tester, scale);
            await pumpEntry(tester, entry.id, mode);
            expectTheme(tester, mode, entry.id);
            await expectGuidelines(tester);
          }
        }
        handle.dispose();
      });
    }
  });
}
