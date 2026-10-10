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
import 'package:fluenough/features/placement/language_card.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/picker_fixtures.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/page_parts.dart';

import '../../support/deck_remote.dart';
import '../../support/harness.dart';
import '../../support/picker.dart';

/// The language picker (#211, `docs/plans/language-picker.md` and its
/// approved mockup): search, the order of its groups, what a card says,
/// what an opened card asks, removal, the download on a card, and its
/// accessibility. Choosing and placement through the whole app are in
/// `placement_flow_test.dart`; the catalog's arithmetic in
/// `test/core/decks/language_catalog_test.dart`.

/// The picker on [fixture], one of [PickerFixtures]' states, on the deck
/// index of the eight courses: a first launch unless it learns something.
Future<AppState> pumpPicker(
  WidgetTester tester,
  AppState Function(AppState) fixture, {
  LanguagePickerPage page = const LanguagePickerPage(firstRun: true),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final app = AppState.test();
  addTearDown(app.dispose);
  final state = fixture(app);
  addTearDown(state.dispose);
  await pumpScreen(tester, page, state: state, themeMode: themeMode);
  return state;
}

/// Whether [finder] is under [code]'s card.
Finder inCard(String code, Finder finder) =>
    find.descendant(of: languageCard(code), matching: finder);

/// The codes of the cards built, in the list's order.
List<String> cardOrder(WidgetTester tester) => <String>[
  for (final card in tester.widgetList<LanguageCard>(
    find.byType(LanguageCard, skipOffstage: false),
  ))
    card.language.code,
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
      expect(cardOrder(tester), <String>['te', 'gu'], reason: 'Telugu too');

      await tester.enterText(field, 'kn ');
      await tester.pumpAndSettle();
      expect(cardOrder(tester), <String>['kn'], reason: 'code, trimmed');
    });

    testWidgets('with no match, says so; clearing brings every language '
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
      expect(cardOrder(tester), hasLength(8));
      expect(find.byTooltip(l10n.pickerClearSearch), findsNothing);
      handle.dispose();
    });
  });

  group('order', () {
    testWidgets('chosen first, then taught from a language the learner '
        'speaks, then A to Z', (tester) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pickerGroupAvailable(8)), findsOneWidget);
      expect(find.text(l10n.pickerGroupLearning(1)), findsNothing);
      // The learner speaks Bengali and Hindi: only Telugu is taught from
      // them.
      expect(cardOrder(tester), <String>[
        'te',
        'as',
        'bn',
        'gu',
        'hi',
        'kn',
        'mr',
        'es',
      ]);

      await pickLanguage(tester, 'kn');
      expect(find.text(l10n.pickerGroupLearning(1)), findsOneWidget);
      expect(find.text(l10n.pickerGroupAvailable(7)), findsOneWidget);
      expect(cardOrder(tester).first, 'kn');
      expect(
        tester.getTopLeft(find.text(l10n.pickerGroupLearning(1))).dy,
        lessThan(tester.getTopLeft(languageCard('kn')).dy),
      );
    });

    testWidgets('a card ticked far down the list stays in view as it '
        'moves up', (tester) async {
      usePhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      await pickLanguage(tester, 'es');
      final box = inCard('es', find.byType(Checkbox));
      expect(box, findsOneWidget);
      expect(tester.getRect(box).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(box).bottom, lessThan(844));
    });
  });

  group('the card', () {
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

    CatalogLanguage telugu({
      List<B1Unit> course = units,
      List<String> natives = const <String>['en'],
    }) => CatalogLanguage(
      code: 'te',
      name: 'Telugu',
      ownName: 'తెలుగు',
      icon: 'తె',
      script: 'telugu',
      scriptDecks: true,
      natives: <CatalogNative>[
        for (final code in natives)
          (
            code: code,
            name: const <String, String>{
              'en': 'English',
              'bn': 'Bengali',
              'hi': 'Hindi',
            }[code]!,
            progress: B1Progress.of(course),
          ),
      ],
    );

    Future<void> pumpCard(
      WidgetTester tester,
      CatalogLanguage language, {
      List<String> spoken = const <String>['en'],
      double? you,
      int? youWords,
      ({bool onPhone, String size})? storage,
    }) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: <Widget>[
              LanguageCard(
                language: language,
                ticked: false,
                onToggle: () {},
                spoken: spoken,
                progress: language.progressFor(spoken),
                you: you,
                youWords: youWords,
                storage: storage,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('shows how much of B1 is written, a unit over its plan '
        'capped, with the grammar topics', (tester) async {
      await pumpCard(tester, telugu());
      final l10n = l10nOf(tester);
      // (50 + min(120, 100) + 0) of 400 words.
      expect(find.textContaining(l10n.pickerWritten(37)), findsOneWidget);
      expect(
        find.textContaining(l10n.pickerGrammarTopics(2, 3)),
        findsOneWidget,
      );
      expect(find.text(l10n.pickerScript('telugu')), findsOneWidget);
      expect(find.text('Telugu · తెలుగు'), findsOneWidget);
    });

    testWidgets('a path with no B1 plan shows the course size instead', (
      tester,
    ) async {
      await pumpCard(
        tester,
        telugu(course: const <B1Unit>[B1Unit(has: 300), B1Unit(has: 340)]),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pickerCourseSize(640)), findsOneWidget);
      expect(find.textContaining('% of B1'), findsNothing);
    });

    testWidgets('Alpha until A1 is written, Beta until B1 is, then no tag; '
        'never "Just started"', (tester) async {
      Future<void> expectTag(List<B1Unit> course, String? tag) async {
        await pumpCard(tester, telugu(course: course));
        final l10n = l10nOf(tester);
        for (final t in <String>[l10n.pickerAlpha, l10n.pickerBeta]) {
          expect(find.text(t), t == tag ? findsOneWidget : findsNothing);
        }
        expect(find.textContaining('started'), findsNothing);
      }

      final l10n = await () async {
        await pumpCard(tester, telugu());
        return l10nOf(tester);
      }();
      // A1's unit written: Beta.
      await expectTag(units, l10n.pickerBeta);
      // A1's unit still planned: Alpha.
      await expectTag(const <B1Unit>[
        B1Unit(words: 100, has: 50),
        B1Unit(words: 100, planned: true, milestone: Milestone.a1),
        B1Unit(words: 200, planned: true, milestone: Milestone.b1),
      ], l10n.pickerAlpha);
      // Every unit to B1 written: no tag.
      await expectTag(const <B1Unit>[
        B1Unit(words: 100, has: 100, milestone: Milestone.a1),
        B1Unit(words: 200, has: 150, milestone: Milestone.b1),
      ], null);
    });

    testWidgets('a path with no level plan is Alpha, without saying that A1 '
        'is unfinished', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        telugu(course: const <B1Unit>[B1Unit(has: 300), B1Unit(has: 340)]),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pickerAlpha), findsOneWidget);
      final label = tester
          .getSemantics(find.byType(Checkbox))
          .getSemanticsData()
          .label;
      expect(label, contains(l10n.pickerAlphaUnplannedLabel));
      expect(label, isNot(contains(l10n.pickerAlphaLabel)));
      handle.dispose();
    });

    testWidgets('taught from: the learner\'s own first, and a line when none '
        'is theirs', (tester) async {
      await pumpCard(
        tester,
        telugu(natives: const <String>['en', 'hi', 'bn']),
        spoken: const <String>['hi', 'bn'],
      );
      final l10n = l10nOf(tester);
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(l10n.pickerTaughtFromLine('Hindi, Bengali, English')),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.pickerNotYours), findsNothing);

      await pumpCard(tester, telugu(), spoken: const <String>['bn']);
      expect(find.text(l10n.pickerNotYours), findsOneWidget);
    });

    testWidgets('both progresses, and whether it is on the phone', (
      tester,
    ) async {
      await pumpCard(
        tester,
        telugu(),
        you: 0.18,
        storage: (onPhone: true, size: '259 KB'),
      );
      final l10n = l10nOf(tester);
      expect(find.textContaining(l10n.pickerWritten(37)), findsOneWidget);
      expect(find.text(l10n.pickerYou(18)), findsOneWidget);
      expect(find.text(l10n.pickerOnPhone('259 KB')), findsOneWidget);

      await pumpCard(
        tester,
        telugu(course: const <B1Unit>[B1Unit(has: 300)]),
        youWords: 40,
        storage: (onPhone: false, size: '259 KB'),
      );
      expect(find.text(l10n.pickerYouWords(40)), findsOneWidget);
      expect(find.text(l10n.pickerNotOnPhone('259 KB')), findsOneWidget);
    });

    testWidgets('is one checkbox to a screen reader, with its name, '
        'completeness and native languages in its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, telugu());
      final l10n = l10nOf(tester);
      final node = tester.getSemantics(find.byType(Checkbox));
      expect(node, isSemantics(hasCheckedState: true, isChecked: false));
      final label = node.getSemanticsData().label;
      for (final part in <String>[
        'Telugu',
        'తెలుగు',
        l10n.pickerWritten(37),
        l10n.pickerTaughtFromLine('English'),
        l10n.pickerBetaLabel,
      ]) {
        expect(label, contains(part));
      }
      handle.dispose();
    });
  });

  group('the opened card', () {
    testWidgets('"Learn the script" shows only for a course with script '
        'decks, on to start with', (tester) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      final l10n = l10nOf(tester);
      await pickLanguage(tester, 'kn');
      await pickLanguage(tester, 'es');
      expect(inCard('es', find.byType(Switch)), findsNothing);
      final toggle = inCard('kn', find.byType(Switch));
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(
        inCard('kn', find.text(l10n.pickerLearnScript('Kannada'))),
        findsOneWidget,
      );

      await flipScript(tester, 'kn');
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(inCard('kn', find.text(l10n.pickerScriptOff)), findsOneWidget);
    });

    testWidgets('an alpha course says so when it is chosen', (tester) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      final l10n = l10nOf(tester);
      await pickLanguage(tester, 'es');
      expect(
        inCard('es', find.text(l10n.pickerAlphaNotice('Spanish'))),
        findsOneWidget,
      );
    });

    testWidgets('taught from two of the learner\'s languages: a choice side '
        'by side; from one, none', (tester) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromTwo);
      await pickLanguage(tester, 'te');
      await pickLanguage(tester, 'kn');
      expect(inCard('kn', find.byType(SegmentedButton<String>)), findsNothing);
      final choice = inCard('te', find.byType(SegmentedButton<String>));
      final buttons = tester.widget<SegmentedButton<String>>(choice);
      expect(buttons.segments.map((s) => s.value), <String>['bn', 'hi']);
      expect(buttons.selected, <String>{'bn'});

      await tester.tap(
        find.descendant(of: choice, matching: find.text('Hindi')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<String>>(choice).selected, <String>{
        'hi',
      });
    });

    testWidgets('taught from three: still side by side, the most that are', (
      tester,
    ) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromThree);
      await pickLanguage(tester, 'te');
      final choice = inCard('te', find.byType(SegmentedButton<String>));
      expect(choice, findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<String>>(choice)
            .segments
            .map((s) => s.value),
        <String>['bn', 'hi', 'gu'],
      );
      expect(NativeChoiceField.sideBySide, 3);
    });

    testWidgets('taught from more than three: a radio list in a sheet, each '
        'with its coverage, the learner\'s own order', (tester) async {
      useTallPhone(tester);
      await pumpPicker(tester, PickerFixtures.taughtFromFour);
      final l10n = l10nOf(tester);
      await pickLanguage(tester, 'te');
      expect(find.byType(SegmentedButton<String>), findsNothing);
      final change = inCard('te', find.text(l10n.pickerChangeNative));
      expect(change, findsOneWidget);
      expect(inCard('te', find.widgetWithText(ListTile, 'Bengali')), findsOne);
      // To a screen reader, one node for one action, saying what changes.
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(
          RegExp('^${RegExp.escape(l10n.pickerNativeChoiceLabel('Bengali'))}'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.pickerChangeNative), findsNothing);
      handle.dispose();

      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(find.text(l10n.pickerLearnFrom('Telugu')), findsOneWidget);
      final tiles = tester
          .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
          .toList();
      expect(tiles.map((t) => t.value), <String>['bn', 'hi', 'gu', 'mr']);
      for (final tile in tiles) {
        expect((tile.subtitle! as Text).data, contains('% of B1 written'));
      }

      await tester.tap(find.widgetWithText(RadioListTile<String>, 'Gujarati'));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(inCard('te', find.widgetWithText(ListTile, 'Gujarati')), findsOne);
    });
  });

  group('leaving and removing', () {
    testWidgets('un-ticking a language whose download was asked for stops it, '
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

    testWidgets('un-ticking a language learned asks first, and Cancel keeps '
        'it; one just chosen goes without asking', (tester) async {
      useTallPhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
        ),
      );
      addTearDown(state.dispose);
      await pumpScreen(tester, const LanguagePickerPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pickerSettingsTitle), findsOneWidget);
      expect(isPicked(tester, 'hi'), isTrue);

      await pickLanguage(tester, 'hi');
      expect(find.text(l10n.pickerStopTitle('Hindi')), findsOneWidget);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(isPicked(tester, 'hi'), isTrue);

      await pickLanguage(tester, 'bn');
      await pickLanguage(tester, 'bn');
      expect(find.byType(AlertDialog), findsNothing);
      expect(isPicked(tester, 'bn'), isFalse);
      expect(state.settings.learningLanguages, <String>['hi']);
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
                    builder: (_) => const LanguagePickerPage(),
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
      expect(
        inCard('hi', find.byType(Switch)),
        findsNothing,
        reason: 'nothing to ask of a language learned',
      );
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
        find.text(l10n.pickerHintWaiting(decksBeforeReady, 'Hindi')),
        findsOneWidget,
      );
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement(l10n.pickerAnnounceChosen('Hindi')),
        isAccessibilityAnnouncement(l10n.deckDownloadsProgressLabel('Hindi')),
      ]);
      // Its Cancel says whose download it stops.
      expect(
        inCard(
          'hi',
          find.bySemanticsLabel(l10n.pickerCancelDownloadLabel('Hindi')),
        ),
        findsOneWidget,
      );
      // A course with no level plan yet: Alpha, without saying A1 is
      // unfinished.
      expect(
        inCard('hi', find.text(l10n.pickerAlphaUnplannedNotice('Hindi'))),
        findsOneWidget,
      );
      expect(find.text(l10n.pickerAlphaNotice('Hindi')), findsNothing);

      remote.release(firstFiles(state));
      await tester.pumpAndSettle();
      expect(now().ready, isTrue);
      expect(now().decks, greaterThanOrEqualTo(decksBeforeReady));
      expect(inCard('hi', find.text(l10n.pickerReady)), findsOneWidget);
      expect(canContinue(tester, l10n), isTrue);
      expect(find.text(l10n.pickerHintNext('Hindi')), findsOneWidget);
      expect(tester.takeAnnouncements(), <Matcher>[
        isAccessibilityAnnouncement(l10n.pickerAnnounceReady('Hindi')),
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
        isAccessibilityAnnouncement(l10n.pickerAnnounceDone('Hindi')),
      ]);

      await tester.tap(continueButton(l10n));
      await tester.pumpAndSettle();
      expect(find.byType(PlacementPage), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Cancel after the first decks keeps what is in, and the rest '
        'waits on Settings > Deck downloads', (tester) async {
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
      await tester.tap(find.text(l10n.placementNew('Hindi')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.placementDone));
      await tester.pumpAndSettle();
      expect(state.settings.learningLanguages, <String>['hi']);

      // At the next launch, the rest is not downloaded on its own.
      await downloads.resume(const <String>['hi'], const <String>['en']);
      expect(downloads.missing('hi', const <String>['en']), isNotEmpty);

      // It is, from Settings > Deck downloads.
      await tester.tap(find.text(l10n.navSettings));
      await tester.pumpAndSettle();
      final page = find.text(l10n.deckDownloadsTitle);
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
      expect(find.text(l10n.pickerCancelledUnchosen('Hindi')), findsOneWidget);
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
        isAccessibilityAnnouncement(l10n.pickerAnnounceChosen('Hindi')),
        isAccessibilityAnnouncement(l10n.deckDownloadsProgressLabel('Hindi')),
        isAccessibilityAnnouncement(l10n.downloadsOffline),
      ]);
      expect(
        inCard(
          'hi',
          find.bySemanticsLabel(l10n.pickerRetryDownloadLabel('Hindi')),
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
        isAccessibilityAnnouncement(l10n.pickerAnnounceReady('Hindi')),
        isAccessibilityAnnouncement(l10n.pickerAnnounceDone('Hindi')),
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

    testWidgets('nothing overflows at twice the text size, light and dark, '
        'scrolled through', (tester) async {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        for (final entry in pickerEntries) {
          usePhone(tester, textScale: 2.0);
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

    testWidgets('the taught-from sheet and the "Stop learning" dialog fit '
        'and meet the guidelines at twice the text size, light and dark', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        usePhone(tester, textScale: 2.0);
        await pumpEntry(tester, 'picker-taught-from-list', mode);
        expectTheme(tester, mode, 'sheet');
        final l10n = l10nOf(tester);
        final change = inCard('te', find.text(l10n.pickerChangeNative));
        await scrollToInPicker(tester, change);
        await tester.tap(change);
        await tester.pumpAndSettle();
        expect(find.byType(RadioListTile<String>), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'sheet');
        await expectGuidelines(tester);
        // Choosing another closes it.
        await tester.tap(
          find.widgetWithText(RadioListTile<String>, 'Gujarati'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RadioListTile<String>), findsNothing);

        // From Settings, learning Hindi, Spanish and Telugu.
        usePhone(tester, textScale: 2.0);
        await pumpEntry(tester, 'picker-on-phone', mode);
        expectTheme(tester, mode, 'dialog');
        await pickLanguage(tester, 'hi');
        expect(find.text(l10n.pickerStopTitle('Hindi')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'dialog');
        await expectGuidelines(tester);
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
      }
      handle.dispose();
    });

    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('every state meets the tap-target, label and contrast '
          'guidelines, light and dark, at text size $scale', (tester) async {
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
