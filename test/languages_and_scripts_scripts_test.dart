// Split out of languages_and_scripts_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: without the alphabet, the scripts learned, scripts in a drill, changing scripts, the scripts line, a script read in another language, the script test, the script test offered, a guide per script, the IPA course, choosing the IPA, the braille course.

import 'dart:io';
import 'dart:math';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/script_test.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/notation.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/script_test_page.dart';
import 'package:fluenough/ui/script_name.dart';
import 'package:fluenough/ui/widgets/reading_first.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'support/braille_course.dart';
import 'support/harness.dart';
import 'support/ipa_course.dart';
import 'support/picker.dart';
import 'support/two_script_course.dart';
import 'support/languages_and_scripts_shared.dart';

Set<String> decksOf(Iterable<List<DeckEntry>> units) => <String>{
  for (final unit in units)
    for (final entry in unit) entry.id,
};

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
const String persoArabicScriptsDrill = 'کتاب';
const Set<String> both = <String>{'devanagari', 'perso_arabic'};

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

// From ipa_entries_test.dart.
Future<AppState> pumpPickerIpaEntries(
  WidgetTester tester,
  List<String> learning,
) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
  final state = ipaApp(learning);
  addTearDown(state.dispose);
  await pumpScreen(tester, const LanguagePickerPage(), state: state);
  return state;
}

Future<void> proceed(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
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
  setUpAll(() => rootBundle.loadString(spokenLanguagesAsset));

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
        find.byKey(const ValueKey<String>('sheet-change-scripts')),
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

  group('the scripts line', () {
    testWidgets('names the scripts learnt with how many of the language\'s '
        'scripts that is', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
      await pumpScreen(
        tester,
        LanguagePickerPage(spokenList: pickerSpokenList),
        state: learningScriptSwitch(),
      );
      final l10n = l10nOf(tester);
      await openSheet(tester, 'hi');
      expect(
        find.text(l10n.pickerScriptsLearnt('Devanagari', 1, 2)),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('sheet-change-scripts')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('sheet-script-perso_arabic')),
      );
      await tester.pumpAndSettle();
      await finishSheet(tester);
      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      await openSheet(tester, 'hi');
      expect(
        find.text(l10n.pickerScriptsLearnt('Devanagari, Perso-Arabic', 2, 2)),
        findsOneWidget,
      );
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
            // Found by search: whether a language is in Popular, or in a
            // family that is folded, changes with the courses written, and
            // the list grows with every language a starter deck is added for.
            await tester.enterText(find.byType(TextField), 'Assamese');
            await tester.pumpAndSettle();
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
            await tester.enterText(find.byType(TextField), 'Telugu');
            await tester.pumpAndSettle();
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
      test('the IPA course is the whole chart, whatever languages are '
          'learned, and its production is chosen, not typed', () async {
        final state = ipaApp(<String>['hi', 'ipa']);
        addTearDown(state.dispose);
        await state.load();
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
        expect(state.deckById('ipa-en-rare'), isNotNull);

        {
          final state = ipaApp(<String>['ipa']);
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
    testWidgets('choosing the IPA learns it, as the one whole course', (
      tester,
    ) async {
      final state = await pumpPickerIpaEntries(tester, <String>['hi']);
      await pickLanguage(tester, 'ipa');
      expect(isPicked(tester, 'ipa'), isTrue);
      await proceed(tester);
      expect(state.learningCodes, {'hi', 'ipa'});
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
}
