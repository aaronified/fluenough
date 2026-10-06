import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/log_files.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/fluenough_mark.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

Finder _slider(String title) => find.descendant(
  of: find.ancestor(
    of: find.text(title),
    matching: find.byType(SettingsSlider),
  ),
  matching: find.byType(Slider),
);

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(GroupedTile));

/// The settings group headed [header]: its heading and every row under it.
Finder _section(String header) => find.byWidgetPredicate(
  (widget) => widget is GroupedList && widget.header == header,
);

/// Saves into [saved] and opens [picked], in place of the phone's dialogs.
class _FakeLogFiles implements LogFiles {
  _FakeLogFiles({this.picked});

  final Map<String, String> saved = <String, String>{};
  String? picked;
  String? title;

  @override
  Future<bool> save(String fileName, String contents) async {
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<String?> open({required String title}) async {
    this.title = title;
    return picked;
  }
}

void main() {
  group('live settings change SettingsNotifier', () {
    test('there is no daily cap on new cards: new words come in lessons '
        '(ADR-0024)', () {
      expect(
        SettingsNotifier().toStored(),
        isNot(contains('new_cards_per_day')),
      );
    });

    testWidgets('each live skill switch, and romanisation', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final settings = state.settings;

      for (final skill in <Skill>[
        Skill.recognition,
        Skill.production,
        Skill.listening,
      ]) {
        final row = _row(skill.label(l10n));
        await scrollTo(tester, row);
        expect(settings.isEnabled(skill), isTrue);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(settings.isEnabled(skill), isFalse, reason: '$skill');
        expect(
          tester
              .widget<Switch>(
                find.descendant(of: row, matching: find.byType(Switch)),
              )
              .value,
          isFalse,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(settings.isEnabled(skill), isTrue, reason: '$skill');
      }

      final romanisation = _row(l10n.settingsRomanisation);
      await scrollTo(tester, romanisation);
      await tester.tap(romanisation);
      await tester.pumpAndSettle();
      expect(settings.showRomanisation, isFalse);
    });

    testWidgets('sound, and playing words automatically, which cannot '
        'change while sound is off', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final settings = state.settings;
      Switch switchOf(Finder row) => tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );

      final autoplay = _row(l10n.settingsAutoplay);
      await scrollTo(tester, autoplay);
      await tester.ensureVisible(autoplay);
      await tester.pumpAndSettle();
      expect(switchOf(autoplay).value, isFalse);
      await tester.tap(autoplay);
      await tester.pumpAndSettle();
      expect(settings.autoplay, isTrue);

      // The section is Sound too: the row is the one with a switch.
      final sound = _row(l10n.settingsSound);
      expect(sound, findsOneWidget);
      await tester.ensureVisible(sound);
      await tester.pumpAndSettle();
      expect(switchOf(sound).value, isTrue);
      await tester.tap(sound);
      await tester.pumpAndSettle();
      // Turning it off says what it does to the questions that need it.
      expect(find.text(l10n.settingsSoundOffSkipped), findsOneWidget);
      expect(settings.soundOn, isFalse);
      // Kept as it was, but greyed out and not to be changed.
      expect(switchOf(autoplay).value, isTrue);
      expect(switchOf(autoplay).onChanged, isNull);
      await tester.tap(autoplay);
      await tester.pumpAndSettle();
      expect(settings.autoplay, isTrue);

      await tester.tap(sound);
      await tester.pumpAndSettle();
      expect(settings.soundOn, isTrue);
      expect(switchOf(autoplay).onChanged, isNotNull);
    });

    testWidgets('speech rate, which sets the rate the voice is given', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final slider = _slider(l10n.settingsSpeechRate);
      await scrollTo(tester, slider);

      await tapSlider(tester, slider, 1);
      await tester.pumpAndSettle();
      expect(state.settings.speechRate, SettingsNotifier.maxSpeechRate);
      expect(state.settings.ttsRate(), closeTo(0.75, 1e-9));
      expect(find.text(l10n.settingsSpeechRateValue(1.5)), findsOne);

      await tapSlider(tester, slider, 0);
      await tester.pumpAndSettle();
      expect(state.settings.speechRate, SettingsNotifier.minSpeechRate);
      expect(state.settings.ttsRate(), closeTo(0.25, 1e-9));
      expect(
        state.settings.ttsRate(slower: true),
        closeTo(0.25 * SettingsNotifier.slowerFactor, 1e-9),
      );
    });

    testWidgets('the Voices row counts voiced languages and opens Voices', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(tts: FixedTtsEngine(const <String>{'es'})),
      );
      final l10n = l10nOf(tester);
      final voiced = state.languages.where(state.hasVoice).length;
      expect(voiced, 1);
      final summary = find.text(
        l10n.settingsVoicesSummary(voiced, state.languages.length),
      );
      await scrollTo(tester, summary);
      await tester.tap(summary);
      await tester.pumpAndSettle();
      expect(find.byType(VoicesPage), findsOneWidget);
    });
  });

  testWidgets(
    'the minimal-pairs switch is titled Phonemic contrasts, says what '
    'it lets you learn, and is still incoming',
    (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);

      final row = _row('Phonemic contrasts');
      await scrollTo(tester, row);
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            'Practise the sounds the languages you speak don\u2019t have',
          ),
        ),
        findsOneWidget,
      );
      // Neither the old title nor the old line.
      expect(find.text('Minimal pairs'), findsNothing);
      expect(find.text('Sounds your language may not have'), findsNothing);
      // Shown off and disabled, as an incoming feature is (ADR-0008).
      final toggle = tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);

      // Only Settings renames the skill; every other skill keeps its label.
      expect(Skill.pair.label(l10n), 'Minimal pairs');
      expect(Skill.pair.settingsLabel(l10n), 'Phonemic contrasts');
      for (final skill in Skill.values.where((s) => s != Skill.pair)) {
        expect(skill.settingsLabel(l10n), skill.label(l10n), reason: '$skill');
      }
    },
  );

  testWidgets('every disabled row reads as incoming and says so when tapped', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    final settings = state.settings;

    final labels = <String>[
      l10n.settingsSwitchProfile,
      l10n.skillPairSettingsTitle,
      l10n.settingsAppLanguage,
      l10n.settingsReminder,
      l10n.settingsPinLock,
      l10n.settingsDeleteProfile,
      l10n.settingsAppLog,
    ];
    for (final label in labels) {
      final node = find.bySemanticsLabel(l10n.incomingSemanticsLabel(label));
      await scrollTo(tester, node);
      expect(node, findsOneWidget, reason: label);
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: l10n.incomingSemanticsLabel(label),
          hint: l10n.incomingSemanticsHint,
          isButton: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
        reason: label,
      );
      await tester.tap(node, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.incomingSnackBar), findsOneWidget, reason: label);
      await clearSnackBars(tester);
    }

    // Nothing opened and nothing changed.
    expect(find.byType(ProfilesPage), findsNothing);
    expect(find.byType(AppearancePage), findsNothing);
    expect(settings.isEnabled(Skill.grammar), isTrue);
    expect(settings.reminder, isFalse);
    semantics.dispose();
  });

  testWidgets('Appearance is live and opens its screen', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    final row = find.text(l10n.settingsAppearance);
    await scrollTo(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(AppearancePage), findsOneWidget);
  });

  group('Languages I speak', () {
    testWidgets('is the first row of Learning, directly above the row for '
        'the languages you learn, and not in Look', (tester) async {
      usePhone(tester);
      // Tall enough to lay the whole page out at once, so that every
      // position below is measured in one frame and nothing is scrolled
      // out of the tree.
      tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);

      final learning = _section(l10n.settingsSectionLearning);
      final sound = _section(l10n.settingsSectionSound);
      final look = _section(l10n.settingsSectionLook);
      final spoken = _row(l10n.settingsSpoken);
      final learn = _row(l10n.settingsLearn);
      for (final finder in <Finder>[learning, sound, look, spoken, learn]) {
        expect(finder, findsOneWidget);
      }

      // In the Learning section, and in no other.
      expect(
        find.descendant(of: learning, matching: spoken),
        findsOneWidget,
        reason: 'under the Learning heading',
      );
      expect(
        find.descendant(of: look, matching: find.text(l10n.settingsSpoken)),
        findsNothing,
        reason: 'no longer under Look and language',
      );
      expect(
        find.descendant(of: sound, matching: find.text(l10n.settingsSpoken)),
        findsNothing,
      );

      // The first two rows of Learning, in that order.
      final rows = find.descendant(
        of: learning,
        matching: find.byType(GroupedTile),
      );
      expect(
        find.descendant(
          of: rows.at(0),
          matching: find.text(l10n.settingsSpoken),
        ),
        findsOneWidget,
        reason: 'the first row of Learning',
      );
      expect(
        find.descendant(
          of: rows.at(1),
          matching: find.text(l10n.settingsLearn),
        ),
        findsOneWidget,
        reason: 'the row after it',
      );

      // As laid out: below the Learning heading, directly above the learn
      // row, and the Sound heading and the Look section still further down.
      final learningTop = tester.getTopLeft(learning).dy;
      final spokenRect = tester.getRect(spoken);
      final learnRect = tester.getRect(learn);
      expect(spokenRect.top, greaterThan(learningTop));
      expect(spokenRect.bottom, lessThanOrEqualTo(learnRect.top));
      expect(
        learnRect.top - spokenRect.bottom,
        lessThan(learnRect.height / 2),
        reason: 'nothing sits between the two rows',
      );
      expect(spokenRect.bottom, lessThan(tester.getTopLeft(sound).dy));
      expect(spokenRect.bottom, lessThan(tester.getTopLeft(look).dy));
      expect(
        tester.getTopLeft(learning).dy,
        lessThan(tester.getTopLeft(sound).dy),
        reason: 'Learning is above Sound',
      );
    });

    testWidgets('still opens the spoken-languages screen', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final row = find.text(l10n.settingsSpoken);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(SpokenLanguagesPage), findsOneWidget);
    });
  });

  testWidgets('the app language picker lists every translation by its own '
      'name and code', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    final picker = find.byType(DropdownButton<Locale>);
    await scrollTo(tester, picker);

    final items = tester.widget<DropdownButton<Locale>>(picker).items!;
    expect(
      items.map((i) => i.value),
      orderedEquals(AppLocalizations.supportedLocales),
    );
    for (final locale in AppLocalizations.supportedLocales) {
      final own = lookupAppLocalizations(locale);
      expect(
        find.text(
          l10n.settingsAppLanguageOption(
            own.localeOwnName,
            own.localeOwnIso639_3,
          ),
        ),
        findsWidgets,
      );
    }

    await tester.tap(picker);
    await tester.pumpAndSettle();
    final english = lookupAppLocalizations(const Locale('en'));
    await tester.tap(
      find
          .text(
            l10n.settingsAppLanguageOption(
              english.localeOwnName,
              english.localeOwnIso639_3,
            ),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.settingsAppLanguageChanged(english.localeOwnName)),
      findsOneWidget,
    );
  });

  testWidgets('the picker cannot change while the feature is incoming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final picker = find.byType(DropdownButton<Locale>);
    await scrollTo(tester, picker);
    expect(tester.widget<DropdownButton<Locale>>(picker).onChanged, isNull);
  });

  testWidgets('with every feature on, the rest of Settings works', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);

    // The reminder switch, and its time once it is on.
    final reminder = _row(l10n.settingsReminder);
    await scrollTo(tester, reminder);
    expect(find.text(l10n.settingsReminderTime), findsNothing);
    await tester.tap(reminder);
    await tester.pumpAndSettle();
    expect(state.settings.reminder, isTrue);
    expect(find.text(l10n.settingsReminderTime), findsOneWidget);

    // Grammar's switch is live too.
    final grammar = _row(l10n.skillGrammar);
    await scrollTo(tester, grammar);
    await tester.tap(grammar);
    await tester.pumpAndSettle();
    expect(state.settings.isEnabled(Skill.grammar), isFalse);

    final appearance = _row(l10n.settingsAppearance);
    await scrollTo(tester, appearance);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
    expect(find.byType(AppearancePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final switchProfile = find.text(l10n.settingsSwitchProfile);
    await tester.ensureVisible(switchProfile);
    await tester.pumpAndSettle();
    await tester.tap(switchProfile);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilesPage), findsOneWidget);
  });

  group('the review log backup', () {
    void answer(ProgressStore p, String card, int grade, int day) => p.record(
      deckId: 'hi-en-market',
      cardId: card,
      mode: DrillMode.production,
      grade: grade,
      now: DateTime(2026, 9, 20 + day, 19),
    );

    Future<void> tapRow(WidgetTester tester, String title) async {
      final row = find.text(title);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('Export saves the log as the profile\'s file', (tester) async {
      usePhone(tester);
      final files = _FakeLogFiles();
      final progress = MemoryProgress();
      answer(progress, 'hi-0231', 4, 0);
      answer(progress, 'hi-0232', 1, 1);
      final state = await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(progress: progress, logFiles: files),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.settingsExportDesc(2)), findsOneWidget);

      await tapRow(tester, l10n.settingsExport);
      final name = 'fluenough-${state.currentProfile.id}-reviews.jsonl';
      expect(files.saved.keys, [name]);
      expect(LogJsonl.decode(files.saved[name]!).reviews, hasLength(2));
      expect(find.text(l10n.settingsExported(name)), findsOneWidget);
    });

    testWidgets('Import merges a backup and says how many reviews were new', (
      tester,
    ) async {
      usePhone(tester);
      final old = MemoryProgress();
      answer(old, 'hi-0231', 4, 0);
      answer(old, 'hi-0231', 5, 1);
      answer(old, 'hi-0232', 3, 1);
      final files = _FakeLogFiles(picked: old.exportJsonl());
      final progress = MemoryProgress();
      answer(progress, 'hi-0231', 5, 1);
      await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(progress: progress, logFiles: files),
      );
      final l10n = l10nOf(tester);

      await tapRow(tester, l10n.settingsImport);
      expect(files.title, l10n.settingsImportPick);
      expect(progress.log, hasLength(3), reason: 'one review was already here');
      expect(find.text(l10n.settingsImported(2)), findsOneWidget);
      expect(find.text(l10n.settingsExportDesc(3)), findsOneWidget);

      await clearSnackBars(tester);
      await tapRow(tester, l10n.settingsImport);
      expect(progress.log, hasLength(3));
      expect(find.text(l10n.settingsImported(0)), findsOneWidget);
    });

    testWidgets('Import refuses a file that is not a log, and does nothing '
        'when none is picked', (tester) async {
      usePhone(tester);
      final files = _FakeLogFiles(picked: 'id,front,back\n1,casa,house\n');
      final state = await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(logFiles: files),
      );
      final l10n = l10nOf(tester);

      await tapRow(tester, l10n.settingsImport);
      expect(
        find.text(l10n.settingsImportFailed('line 1 is not JSON')),
        findsOneWidget,
      );
      expect(state.progress.log, isEmpty);

      await clearSnackBars(tester);
      files.picked = null;
      await tapRow(tester, l10n.settingsImport);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('the footer shows the version in pubspec.yaml', (tester) async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(AppInfo.version, version);

    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final footer = find.text(l10nOf(tester).settingsFooter(AppInfo.version));
    await scrollTo(tester, footer);
    expect(footer, findsOneWidget);
  });

  testWidgets('the footer carries the brand mark, beside the name', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final footer = find.text(l10nOf(tester).settingsFooter(AppInfo.version));
    await scrollTo(tester, footer);
    final mark = find.byType(FluenoughMark);
    expect(mark, findsOneWidget);
    expect(tester.getSize(mark), const Size.square(32));
    expect(tester.getCenter(mark).dy, closeTo(tester.getCenter(footer).dy, 12));
  });
}
