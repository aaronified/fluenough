import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/added_decks.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/log_files.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/features/profiles/new_profile_page.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/settings/activities_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/languages_page.dart';
import 'package:fluenough/features/settings/profiles_privacy_page.dart';
import 'package:fluenough/features/settings/reminders_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
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

Switch _switchOf(WidgetTester tester, Finder row) => tester.widget<Switch>(
  find.descendant(of: row, matching: find.byType(Switch)),
);

/// Saves into [saved] and opens [picked], in place of the phone's dialogs.
class _FakeLogFiles implements LogFiles {
  _FakeLogFiles({this.picked});

  final Map<String, String> saved = <String, String>{};
  String? picked;
  String? title;

  @override
  Future<bool> save(
    String fileName,
    String contents, {
    String mimeType = 'application/jsonl',
  }) async {
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<String?> open({required String title}) async {
    this.title = title;
    return picked;
  }
}

/// The incoming rows of a page read as incoming, and say so when tapped.
Future<void> _expectIncoming(WidgetTester tester, List<String> labels) async {
  final l10n = l10nOf(tester);
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
}

void main() {
  group('Activities and memory (#243)', () {
    testWidgets('has a switch for each activity a learner may skip, in the '
        'mockup\'s order, with Play words, Speech rate and Voices where '
        'they belong', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
      await pumpScreen(tester, const ActivitiesPage());
      final l10n = l10nOf(tester);

      final order = <Finder>[
        _row(Skill.production.settingsLabel(l10n)),
        _row(Skill.listening.settingsLabel(l10n)),
        _row(l10n.settingsAutoplay),
        _row(Skill.speaking.settingsLabel(l10n)),
        find.text(l10n.settingsSpeechRate),
        _row(l10n.settingsVoices),
        _row(Skill.reading.settingsLabel(l10n)),
      ];
      var previous = -1.0;
      for (final finder in order) {
        expect(finder, findsOneWidget);
        final top = tester.getTopLeft(finder).dy;
        expect(top, greaterThan(previous));
        previous = top;
      }
      // Four activity switches and Play words automatically.
      expect(find.byType(Switch), findsNWidgets(5 + 1 /* Adjust to me */));
    });

    testWidgets('has no switch for Seen words, grammar, matching pairs or '
        'phonemic contrasts, and no Sound switch, and says what is always '
        'asked', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
      await pumpScreen(tester, const ActivitiesPage());
      final l10n = l10nOf(tester);
      for (final skill in <Skill>[
        Skill.recognition,
        Skill.grammar,
        Skill.pair,
      ]) {
        expect(_row(skill.settingsLabel(l10n)), findsNothing, reason: '$skill');
        expect(skill.hasSwitch, isFalse);
      }
      expect(_row(l10n.settingsSound), findsNothing);
      expect(find.text(l10n.settingsActivitiesAlwaysAsked), findsOneWidget);
      expect(Skill.pair.label(l10n), 'Minimal pairs');
      expect(Skill.pair.settingsLabel(l10n), 'Phonemic contrasts');
    });

    testWidgets('Written words, Heard words and Reading switch their skill; '
        'the line changes with the switch', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const ActivitiesPage());
      final l10n = l10nOf(tester);
      final settings = state.settings;
      for (final skill in <Skill>[
        Skill.production,
        Skill.listening,
        Skill.reading,
      ]) {
        final row = _row(skill.settingsLabel(l10n));
        await scrollTo(tester, row);
        expect(settings.isEnabled(skill), isTrue);
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining(skill.settingsOn(l10n)),
          ),
          findsOneWidget,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(settings.isEnabled(skill), isFalse, reason: '$skill');
        expect(_switchOf(tester, row).value, isFalse);
        expect(
          find.descendant(
            of: row,
            matching: find.textContaining(skill.settingsOff(l10n)),
          ),
          findsOneWidget,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(settings.isEnabled(skill), isTrue, reason: '$skill');
      }
      // Heard words' off line says words still play from a speaker.
      expect(
        Skill.listening.settingsOff(l10n),
        'No listening questions. Words still play when you tap a speaker',
      );
    });

    testWidgets('Play words automatically switches on its own, whatever '
        'Heard words is set to', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const ActivitiesPage());
      final l10n = l10nOf(tester);
      final autoplay = _row(l10n.settingsAutoplay);
      await scrollTo(tester, autoplay);
      expect(_switchOf(tester, autoplay).value, isFalse);
      await tester.tap(autoplay);
      await tester.pumpAndSettle();
      expect(state.settings.autoplay, isTrue);
      state.settings.setSkillEnabled(Skill.listening, false);
      await tester.pumpAndSettle();
      expect(_switchOf(tester, autoplay).onChanged, isNotNull);
      await scrollTo(tester, autoplay);
      await tester.tap(autoplay);
      await tester.pumpAndSettle();
      expect(state.settings.autoplay, isFalse);
    });

    testWidgets('speech rate sets the rate the voice is given', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const ActivitiesPage());
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
    });

    testWidgets('the Voices row counts voiced languages and opens Voices', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const ActivitiesPage(),
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

    testWidgets('Adjust to me stays on the page, after the switches', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, const ActivitiesPage());
      final l10n = l10nOf(tester);
      await scrollTo(tester, find.text(l10n.settingsAdjustAuto));
      expect(find.text(l10n.settingsAdjustAuto), findsOneWidget);
    });
  });

  group('Your languages', () {
    testWidgets('keeps Languages I know first, directly above the languages '
        'you learn, then the readings, IPA and 18+ switches', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
      await pumpScreen(tester, const LanguagesSettingsPage());
      final l10n = l10nOf(tester);
      final rows = find.byType(GroupedTile);
      String titleAt(int i) => tester.widget<GroupedTile>(rows.at(i)).title;
      expect(titleAt(0), l10n.settingsSpoken);
      expect(titleAt(1), l10n.settingsLearn);
      expect(titleAt(2), l10n.settingsRomanisation);
      expect(titleAt(3), l10n.settingsIpa);
      expect(titleAt(4), l10n.settingsAdult);
      // The skill switches left for Activities and memory.
      expect(_row(Skill.production.settingsLabel(l10n)), findsNothing);
    });

    testWidgets('Languages I know still opens its screen, and the readings '
        'switch changes the setting', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const LanguagesSettingsPage());
      final l10n = l10nOf(tester);
      final romanisation = _row(l10n.settingsRomanisation);
      await scrollTo(tester, romanisation);
      await tester.tap(romanisation);
      await tester.pumpAndSettle();
      expect(state.settings.showRomanisation, isFalse);

      final row = find.text(l10n.settingsSpoken);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(SpokenLanguagesPage), findsOneWidget);
    });
  });

  group('Look and language', () {
    testWidgets('is the appearance page with App language as its last row, '
        'incoming', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const AppearancePage());
      final l10n = l10nOf(tester);
      expect(find.text(l10n.appearanceTitle), findsOneWidget);
      expect(l10n.appearanceTitle, 'Look and language');
      await _expectIncoming(tester, <String>[l10n.settingsAppLanguage]);
      final picker = find.byType(DropdownButton<Locale>);
      expect(tester.widget<DropdownButton<Locale>>(picker).onChanged, isNull);
      // Last: below the card text size.
      expect(
        tester.getTopLeft(find.text(l10n.settingsAppLanguage)).dy,
        greaterThan(tester.getTopLeft(find.text(l10n.appearanceCardSize)).dy),
      );
    });

    testWidgets('the app language picker lists every translation by its own '
        'name and code', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const AppearancePage(),
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
  });

  group('Profiles and privacy', () {
    testWidgets('lists You, Switch profile, Add profile, PIN lock and Delete '
        'this profile, every one incoming and inert', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpScreen(tester, const ProfilesPrivacyPage());
      final l10n = l10nOf(tester);
      await _expectIncoming(tester, <String>[
        state.currentProfile.name ?? l10n.commonUnnamedProfile,
        l10n.settingsProfilesSwitch,
        l10n.settingsProfilesAdd,
        l10n.settingsPinLock,
        l10n.settingsDeleteProfile,
      ]);
      expect(find.byType(ProfilesPage), findsNothing);
      expect(find.byType(NewProfilePage), findsNothing);
      // Delete is in the error colour.
      final delete = tester.widget<GroupedTile>(
        _row(l10n.settingsDeleteProfile),
      );
      expect(
        delete.titleColor,
        Theme.of(tester.element(find.byType(ProfilesPrivacyPage)))
            .colorScheme
            .error,
      );
      semantics.dispose();
    });

    testWidgets('with profiles on, Switch and Add profile open their '
        'screens', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const ProfilesPrivacyPage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsProfilesSwitch));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilesPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsProfilesAdd));
      await tester.pumpAndSettle();
      expect(find.byType(NewProfilePage), findsOneWidget);
    });
  });

  group('Reminders', () {
    testWidgets('are incoming: the switch, and the languages it counts, off '
        'and inert', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpScreen(tester, const RemindersPage());
      final l10n = l10nOf(tester);
      await _expectIncoming(tester, <String>[
        l10n.settingsReminder,
        l10n.settingsRemindersLanguages,
      ]);
      expect(state.settings.reminder, isFalse);
      semantics.dispose();
    });

    testWidgets('with the feature on, the switch gives a time to set', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const RemindersPage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      final l10n = l10nOf(tester);
      final reminder = _row(l10n.settingsReminder);
      expect(find.text(l10n.settingsReminderTime), findsNothing);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      expect(state.settings.reminder, isTrue);
      expect(find.text(l10n.settingsReminderTime), findsOneWidget);
    });
  });

  group('Your decks', () {
    testWidgets('Upload a deck opens the page that adds a deck; Get a '
        'template is incoming; with none added it says so', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, const YourDecksPage());
      final l10n = l10nOf(tester);
      expect(find.text(l10n.settingsDecksNone), findsOneWidget);
      expect(find.text(l10n.settingsDecksAbout), findsOneWidget);
      await _expectIncoming(tester, <String>[l10n.settingsDecksTemplate]);
      semantics.dispose();
      await tester.tap(find.text(l10n.settingsDecksUpload));
      await tester.pumpAndSettle();
      expect(find.byType(ImportPage), findsOneWidget);
    });

    testWidgets('lists a deck that was added under its languages, with '
        'Open, Send it to us (incoming) and Remove, which asks first', (
      tester,
    ) async {
      usePhone(tester);
      final text = await _template();
      final state = AppState.test(
        addedDecks: MemoryDeckStore(<String, String>{'hi-en-my-words': text}),
      );
      await pumpScreen(tester, const YourDecksPage(), state: state);
      final l10n = l10nOf(tester);
      final entry = state.deckById('hi-en-my-words')!;
      expect(YourDecksPage.ownDecks(state.decks), hasLength(1));
      expect(
        find.text(
          l10n.settingsDecksGroup(entry.language.name, entry.deck.native.name),
        ),
        findsOneWidget,
      );
      expect(find.text(entry.deck.name), findsOneWidget);
      expect(
        find.text(l10n.settingsDecksCards(entry.itemCount)),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsDecksOpen), findsOneWidget);
      expect(find.text(l10n.settingsDecksSend), findsOneWidget);
      expect(find.text(l10n.incomingBadge), findsWidgets);

      await tester.tap(find.text(l10n.settingsDecksRemove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(state.deckById('hi-en-my-words'), isNotNull);

      await tester.tap(find.text(l10n.settingsDecksRemove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deckRemoveConfirm).last);
      await tester.pumpAndSettle();
      expect(state.deckById('hi-en-my-words'), isNull);
      expect(find.text(l10n.settingsDecksNone), findsOneWidget);
    });
  });

  group('Your data', () {
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

    testWidgets('is one page: Backup and restore, Cloud and Recent backups, '
        'then the Review log, all on it and in that order', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      await pumpScreen(tester, const YourDataPage());
      final l10n = l10nOf(tester);
      final headings = <String>[
        l10n.settingsDataBackup,
        l10n.settingsDataCloud,
        l10n.settingsDataRecent,
        l10n.settingsDataLog,
      ];
      var previous = -1.0;
      for (final heading in headings) {
        final finder = find.text(heading).first;
        expect(finder, findsOneWidget, reason: heading);
        final top = tester.getTopLeft(finder).dy;
        expect(top, greaterThan(previous), reason: heading);
        previous = top;
      }
      for (final row in <String>[
        l10n.settingsDataBackupNow,
        l10n.settingsDataRestore,
        l10n.settingsDataConnect,
        l10n.settingsExport,
        l10n.settingsImport,
      ]) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
    });

    testWidgets('back up, restore, the cloud and recent backups are '
        'incoming and inert', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, const YourDataPage());
      final l10n = l10nOf(tester);
      await _expectIncoming(tester, <String>[
        l10n.settingsDataBackupNow,
        l10n.settingsDataRestore,
        l10n.settingsDataConnect,
        l10n.settingsDataRecent,
      ]);
      semantics.dispose();
    });

    testWidgets('lists every answer by day, newest first, each with its '
        'card, activity and rating', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
      final state = await pumpScreen(tester, const YourDataPage());
      final l10n = l10nOf(tester);
      final entry = state.decks.firstWhere((e) => e.cards.length > 1);
      final first = entry.cards[0];
      final second = entry.cards[1];
      state.progress.record(
        deckId: entry.id,
        cardId: first.id,
        mode: DrillMode.production,
        grade: 4,
        now: DateTime(2026, 9, 27, 9),
      );
      state.progress.record(
        deckId: entry.id,
        cardId: second.id,
        mode: DrillMode.listening,
        grade: 1,
        now: DateTime(2026, 9, 28, 8),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsDataToday), findsOneWidget);
      expect(find.text(l10n.settingsDataYesterday), findsOneWidget);
      expect(find.text(l10n.rateAgain), findsOneWidget);
      expect(find.text(l10n.rateGood), findsOneWidget);
      // Today's answer is above yesterday's.
      expect(
        tester.getTopLeft(find.textContaining(second.target)).dy,
        lessThan(tester.getTopLeft(find.textContaining(first.target)).dy),
      );
      expect(find.text(l10n.settingsDataLogIntro(2)), findsOneWidget);
    });

    testWidgets('the log shows the last 10 answers, up to 50 when expanded '
        '(owner, 2026-10-17)', (tester) async {
      usePhone(tester);
      final progress = MemoryProgress();
      for (var i = 0; i < 60; i++) {
        progress.record(
          deckId: 'hi-en-market',
          cardId: 'hi-0231',
          mode: DrillMode.production,
          grade: 4,
          now: DateTime(2026, 9, 20, 8).add(Duration(minutes: i)),
        );
      }
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: AppState.test(progress: progress),
      );
      final l10n = l10nOf(tester);
      final more = find.byKey(const ValueKey<String>('review-log-more'));
      await scrollTo(tester, more);
      expect(find.text(l10n.settingsDataLogShowing(10, 60)), findsOneWidget);
      expect(find.text(l10n.settingsDataLogMore(50)), findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await scrollTo(tester, more);
      expect(find.text(l10n.settingsDataLogShowing(50, 60)), findsOneWidget);
      await tester.tap(find.text(l10n.settingsDataLogFewer));
      await tester.pumpAndSettle();
      await scrollTo(tester, more);
      expect(find.text(l10n.settingsDataLogShowing(10, 60)), findsOneWidget);
      // Export still saves all 60.
      final export = find.text(l10n.settingsExportDesc(60));
      await scrollTo(tester, export);
      expect(export, findsOneWidget);
    });

    testWidgets('Export saves the log as the profile\'s file', (tester) async {
      usePhone(tester);
      final files = _FakeLogFiles();
      final progress = MemoryProgress();
      answer(progress, 'hi-0231', 4, 0);
      answer(progress, 'hi-0232', 1, 1);
      final state = await pumpScreen(
        tester,
        const YourDataPage(),
        state: AppState.test(progress: progress, logFiles: files),
      );
      final l10n = l10nOf(tester);
      await scrollTo(tester, find.text(l10n.settingsExportDesc(2)));
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
        const YourDataPage(),
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
        const YourDataPage(),
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
}

/// The deck template, as the learner downloads it.
Future<String> _template() =>
    rootBundle.loadString(deckTemplateAsset, cache: false);
