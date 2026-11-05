// Helpers and fixtures that more than one of the files split out of
// languages_and_scripts_test.dart use, moved here unchanged.

import 'dart:io';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/placement/placement_questions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'two_script_course.dart';

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

/// Answers "I don't know" to each question until the check ends in its
/// result.
Future<void> giveUp(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  var guard = 0;
  while (guard++ < 60) {
    if (find.text(l10n.placementDontKnow).evaluate().isNotEmpty ||
        find.byType(PlacementFrame).evaluate().isNotEmpty) {
      await tapInFrame(tester, find.text(l10n.placementDontKnow));
      await goOn(tester);
    } else {
      return;
    }
  }
}

/// Goes on from the feedback a word question shows once answered, as in a
/// review: the chevron on the end edge, as a swipe does (there is no Continue
/// button, #509); nothing to do after a script check's question, which goes
/// on at once.
Future<void> goOn(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  final frame = find.byType(PlacementFrame);
  if (frame.evaluate().isEmpty) return;
  final next = find.descendant(
    of: frame,
    matching: find.byTooltip(l10n.drillNextCard),
  );
  if (next.evaluate().isEmpty) return;
  await tester.tap(next.first);
  await tester.pumpAndSettle();
}

Map<String, (int?, int?)> coverage(AppState state) => <String, (int?, int?)>{
  for (final o in state.nativeOptions('hi'))
    o.native.code: (o.covered, o.total),
};

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

const String persoArabic = 'perso_arabic';

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
const Set<String> urdu = <String>{'perso_arabic'};

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

// From ipa_course_test.dart.
List<String> ids(Iterable<dynamic> cards) => <String>[
  for (final c in cards) c.id as String,
];

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
