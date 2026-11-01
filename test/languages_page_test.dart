// The merged Languages page (#907): four skills a language, three states,
// one list. Behaviour a learner sees, at 1.4x text in light and dark.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/languages/skill_widgets.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/picker.dart';

AppLocalizations l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

/// An English speaker who reads Latin and learns Spanish, as the older
/// lists held it.
AppState learner() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es'],
    learningChosen: true,
  )..scriptsRead = <String, bool>{'en': true},
);

Future<AppState> pumpLanguages(
  WidgetTester tester, {
  AppState? state,
  ThemeMode mode = ThemeMode.light,
  double textScale = 1.4,
}) {
  usePhone(tester, textScale: textScale);
  return pumpScreen(
    tester,
    LanguagesPage(spokenList: pickerSpokenList),
    state: state ?? learner(),
    themeMode: mode,
  );
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the older lists show as skills: Spanish learning, English '
      'known, Learning first', (tester) async {
    await pumpLanguages(tester);
    final text = l10n(tester);
    expect(find.text(text.languagesSectionLearning(1)), findsOneWidget);
    expect(find.text(text.languagesSectionKnow(1)), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('language-es')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('language-en')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the sheet fits at 1.4x text in ${mode.name}, its pills 48 px '
        'tall', (tester) async {
      await pumpLanguages(tester, mode: mode);
      await tapKey(tester, 'language-es');
      final speak = find.byKey(const ValueKey<String>('skill-speak'));
      expect(speak, findsOneWidget);
      expect(tester.getSize(speak).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a long press on a skill pill shows its skill and state, and a '
      'tap still cycles it (#913)', (tester) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-es');
    final text = l10n(tester);
    final speak = find.byKey(const ValueKey<String>('skill-speak'));
    // Null until the learner edits Spanish on this page; the pill reads the
    // older lists (Learn, from the learner fixture) until then.
    final before = state.settings.languageSkillsOf('es');
    await tester.ensureVisible(speak);
    await tester.pumpAndSettle();
    await tester.longPress(speak);
    await tester.pumpAndSettle();
    expect(
      find.text(
        text.languagesSkillState(
          SkillKind.speak.label(text),
          SkillState.learn.label(text),
        ),
      ),
      findsOneWidget,
    );
    expect(state.settings.languageSkillsOf('es'), before, reason: 'no cycle');
    await tapKey(tester, 'skill-speak');
    expect(state.settings.languageSkillsOf('es'), isNot(before));
  });

  testWidgets('the sheet and page icons show a one-word hint on a long '
      'press (#913)', (tester) async {
    await pumpLanguages(tester);
    final text = l10n(tester);
    await tester.longPress(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    expect(find.text(text.hintReport), findsOneWidget);
    await tapKey(tester, 'language-es');
    await tester.longPress(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.text(text.hintInfo), findsOneWidget);
  });

  testWidgets('English is fixed: all four skills show the double tick and a '
      'tap changes nothing', (tester) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-en');
    final text = l10n(tester);
    expect(find.text(text.languagesEnglishLocked), findsOneWidget);
    for (final id in <String>['speak', 'hear', 'read:latin', 'write:latin']) {
      await tapKey(tester, 'skill-$id');
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('skill-$id')),
          matching: find.byIcon(Icons.done_all),
        ),
        findsOneWidget,
        reason: id,
      );
    }
    final skills = state.skillsOf(
      pickerSpokenList.firstWhere((l) => l.code == 'en'),
    );
    expect(skills, englishKnownByDefault());
    expect(find.byKey(const ValueKey<String>('language-en')), findsOneWidget);
  });

  testWidgets('the skill chips are as wide as their icons and share lines, at '
      '1.4x text', (tester) async {
    await pumpLanguages(tester);
    final row = find.byKey(const ValueKey<String>('language-es'));
    final chips = find.descendant(of: row, matching: find.byType(SkillBadge));
    expect(chips, findsNWidgets(4));
    final rowWidth = tester.getSize(row).width;
    final tops = <double>{};
    for (var i = 0; i < 4; i++) {
      final size = tester.getSize(chips.at(i));
      expect(size.width, lessThan(rowWidth / 3), reason: 'chip $i');
      tops.add(tester.getTopLeft(chips.at(i)).dy);
    }
    expect(tops.length, lessThan(4), reason: 'chips wrap, not stack');
  });

  testWidgets('Learn on a skill downloads nothing here but leaves the button '
      'reading Check; a failed sound test keeps it', (tester) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-es');
    final text = l10n(tester);
    // Spanish speak is Learn already; set it to Leave, Know, then Learn.
    await tapKey(tester, 'skill-speak');
    await tapKey(tester, 'skill-speak');
    await tapKey(tester, 'skill-speak');
    expect(
      state
          .skillsOf(pickerSpokenList.firstWhere((l) => l.code == 'es'))
          .anyLearn,
      isTrue,
    );
    expect(find.text(text.languagesCheck), findsOneWidget);
    await tester.tap(find.text(text.languagesCheck));
    await tester.pumpAndSettle();
    // The test phone has no Spanish voice.
    expect(find.text(text.languagesCheckSoundBad), findsOneWidget);
    await tester.tap(find.text(text.commonClose));
    await tester.pumpAndSettle();
    expect(find.text(text.languagesCheck), findsOneWidget);
  });

  testWidgets('minutes a day step by 5 and show just "20 mins"', (
    tester,
  ) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-es');
    final text = l10n(tester);
    expect(find.text(text.languagesMinutesMins(15)), findsOneWidget);
    await tapKey(tester, 'minutes-more');
    expect(state.settings.dailyMinutesFor('es'), 20);
    expect(find.text(text.languagesMinutesMins(20)), findsOneWidget);
  });

  testWidgets('a script known from another language starts as Know when '
      'adding', (tester) async {
    final state = learner()
      ..settings.setLanguageSkills('hi', <String, String>{
        'read:devanagari': 'know',
      });
    await pumpLanguages(tester, state: state);
    final text = l10n(tester);
    await tester.tap(find.byTooltip(text.hintAdd));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('languages-add-search')),
      'Marathi',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'add-mr');
    expect(
      find.text(text.languagesKnownFrom(text.languagesSkillRead, 'Hindustani')),
      findsOneWidget,
    );
    await tapKey(tester, 'skill-speak');
    await tester.tap(find.text(text.languagesAddLanguage('Marathi')));
    await tester.pumpAndSettle();
    expect(
      state.settings.languageSkillsOf('mr'),
      containsPair('speak', 'know'),
    );
    expect(state.settings.spokenLanguages, contains('mr'));
  });

  testWidgets('opened with a course name (the deck search shortcut), Add a '
      'language shows that course (#918)', (tester) async {
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      LanguagesPage(spokenList: pickerSpokenList, initialQuery: 'Marathi'),
      state: learner(),
    );
    await tester.pumpAndSettle();
    final search = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('languages-add-search')),
    );
    expect(search.controller!.text, 'Marathi');
    expect(find.byKey(const ValueKey<String>('add-mr')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('add-hi')), findsNothing);
  });

  testWidgets('a filter pill keeps only the languages with that state', (
    tester,
  ) async {
    await pumpLanguages(tester);
    await tapKey(tester, 'filter-learning');
    expect(find.byKey(const ValueKey<String>('language-es')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('language-en')), findsNothing);
    await tapKey(tester, 'filter-learning');
    expect(find.byKey(const ValueKey<String>('language-en')), findsOneWidget);
  });

  testWidgets('a sign language has one skill, Gestures, with its own icon, '
      'and its cycle is stored and restored (owner, 2026-11-01)', (
    tester,
  ) async {
    final state = AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
      )..scriptsRead = <String, bool>{'en': true},
    );
    await pumpLanguages(tester, state: state);
    var text = l10n(tester);
    await tester.tap(find.byTooltip(text.hintAdd));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('languages-add-search')),
      'American Sign',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'add-ase');
    text = l10n(tester);
    Finder pill(String id) => find.byKey(ValueKey<String>('skill-$id'));
    expect(pill('gesture'), findsOneWidget);
    expect(find.text(text.languagesGestures), findsWidgets);
    for (final id in <String>['speak', 'hear', 'read:latin', 'write:latin']) {
      expect(pill(id), findsNothing, reason: 'a sign language has no $id');
    }
    expect(find.text(text.languagesSpeakHear), findsNothing);
    expect(find.text(text.languagesScriptRW), findsNothing);
    expect(
      find.descendant(
        of: pill('gesture'),
        matching: find.byIcon(SkillKind.gesture.icon),
      ),
      findsOneWidget,
    );
    final used = <IconData>{for (final k in SkillKind.values) k.icon};
    expect(used.length, SkillKind.values.length, reason: 'each its own icon');

    // No course, so the cycle is Leave, Know, Leave.
    SkillState stored() {
      final restored = SettingsNotifier()..restore(state.settings.toStored());
      final map = restored.languageSkillsOf('ase');
      return map == null
          ? SkillState.leave
          : LanguageSkills.fromStored(map)
                .stateOf(const SkillKey(SkillKind.gesture));
    }

    await tapKey(tester, 'skill-gesture');
    await tester.tap(
      find.text(text.languagesAddLanguage('American Sign Language')),
    );
    await tester.pumpAndSettle();
    expect(stored(), SkillState.know);
    await tapKey(tester, 'language-ase');
    await tapKey(tester, 'skill-gesture');
    expect(stored(), SkillState.leave);
    expect(tester.takeException(), isNull);
  });

  group('the Gestures filter (owner, 2026-11-01)', () {
    AppState withSign(List<String> spoken) => AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: spoken,
        learningLanguages: const <String>['es'],
        learningChosen: true,
      )..scriptsRead = <String, bool>{'en': true},
    );
    Finder chip() => find.byKey(const ValueKey<String>('filter-gesture'));
    Finder row(String code) => find.byKey(ValueKey<String>('language-$code'));

    testWidgets('is absent with no sign language listed', (tester) async {
      await pumpLanguages(tester);
      expect(chip(), findsNothing);
    });

    testWidgets('shows with ASL listed, keeps only sign languages, and Speak '
        'and Hear leave them out', (tester) async {
      await pumpLanguages(tester, state: withSign(const <String>['en', 'ase']));
      expect(chip(), findsOneWidget);
      expect(row('ase'), findsOneWidget);
      await tapKey(tester, 'filter-gesture');
      expect(row('ase'), findsOneWidget);
      expect(row('es'), findsNothing);
      expect(row('en'), findsNothing);
      await tapKey(tester, 'filter-gesture');
      for (final f in <String>['speak', 'hear']) {
        await tapKey(tester, 'filter-$f');
        expect(row('ase'), findsNothing, reason: '$f leaves out signs');
        await tapKey(tester, 'filter-$f');
      }
      expect(tester.takeException(), isNull);
    });
  });
}
