import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

// Every switch says what happens now, and its line changes the moment it is
// flipped (docs/plans/settings-wording.md).

/// Every language the bundled decks teach, so that no line adds what the
/// phone lacks.
const Set<String> _everyLanguage = <String>{
  'as',
  'bn',
  'es',
  'gu',
  'hi',
  'ja',
  'kn',
  'mr',
  'te',
};

/// The switch row titled [title]: a section heading of the same name, such
/// as Sound, is not one.
Finder _switchRow(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byWidgetPredicate(
    (w) => w is GroupedTile && w.toggleValue != null,
  ),
);

/// A state with every feature on, a voice and a recogniser for every
/// language, and reviewing's first-time page already seen.
AppState _everythingOn() {
  final state = AppState.test(
    features: FeatureRegistry.all(),
    tts: FixedTtsEngine(_everyLanguage),
    speech: FixedSpeechEngine(onDevice: _everyLanguage),
  );
  state.settings.reviewIntroShown = true;
  return state;
}

/// Taps the switch row [title] and answers any question it asks, then
/// checks that its line is now the one for its new value.
Future<void> _flip(
  WidgetTester tester,
  String title, {
  required String on,
  required String off,
  String? confirm,
}) async {
  final row = _switchRow(title);
  await scrollTo(tester, row);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  final before = tester.widget<GroupedTile>(row).toggleValue!;
  expect(
    tester.widget<GroupedTile>(row).line,
    before ? on : off,
    reason: '$title before',
  );
  expect(
    find.descendant(of: row, matching: find.text(before ? on : off)),
    findsOneWidget,
    reason: '$title shows its line',
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
  if (confirm != null && !before) {
    await tester.tap(find.text(confirm));
    await tester.pumpAndSettle();
  }
  await clearSnackBars(tester);
  final after = tester.widget<GroupedTile>(row);
  expect(after.toggleValue, !before, reason: '$title flipped');
  expect(after.line, before ? off : on, reason: '$title after');
  expect(
    find.descendant(of: row, matching: find.text(before ? off : on)),
    findsOneWidget,
    reason: '$title shows its new line',
  );
  expect(find.text(before ? on : off), findsNothing, reason: title);
}

/// Every switch row built anywhere in the scrollable list, from top to
/// bottom.
Future<List<GroupedTile>> _everySwitch(WidgetTester tester) async {
  final seen = <String, GroupedTile>{};
  void collect() {
    for (final tile in tester.widgetList<GroupedTile>(
      find.byType(GroupedTile),
    )) {
      if (tile.toggleValue != null) seen[tile.title] = tile;
    }
  }

  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 60; i++) {
    collect();
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  collect();
  return seen.values.toList();
}

/// [hour]:[minute] as the phone writes a time.
String _time(WidgetTester tester, int hour, int minute) =>
    MaterialLocalizations.of(tester.element(find.byType(Scaffold).first))
        .formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));

void _expectEveryLineChanges(List<GroupedTile> switches) {
  for (final tile in switches) {
    expect(tile.subtitleOn, isNotNull, reason: tile.title);
    expect(tile.subtitleOff, isNotNull, reason: tile.title);
    expect(
      tile.subtitleOn,
      isNot(tile.subtitleOff),
      reason: '${tile.title} keeps the same line in both states',
    );
  }
}

void main() {
  testWidgets('each switch in Settings: its line before and after one tap', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: _everythingOn(),
    );
    final l10n = l10nOf(tester);

    for (final skill in Skill.values) {
      final title = skill.settingsLabel(l10n);
      // Flipped twice, so that the next switch finds Settings as it was.
      for (var i = 0; i < 2; i++) {
        await _flip(
          tester,
          title,
          on: skill.settingsOn(l10n),
          off: skill.settingsOff(l10n),
        );
      }
    }
    expect(state.settings.isEnabled(Skill.speaking), isFalse);

    final pairs = <(String, String, String)>[
      (
        l10n.settingsRomanisation,
        l10n.settingsRomanisationOn,
        l10n.settingsRomanisationOff,
      ),
      (
        l10n.settingsAdjustAuto,
        l10n.settingsAdjustAutoOn,
        l10n.settingsAdjustAutoOff,
      ),
      (
        l10n.settingsAutoplay,
        l10n.settingsAutoplayOn,
        l10n.settingsAutoplayOff,
      ),
      (l10n.settingsSound, l10n.settingsSoundOn, l10n.settingsSoundOff),
      (
        l10n.settingsReminder,
        l10n.settingsReminderOn(_time(tester, 19, 30)),
        l10n.settingsReminderOff,
      ),
      (
        l10n.settingsUpdateAuto,
        l10n.settingsUpdateAutoOn,
        l10n.settingsUpdateAutoOff,
      ),
    ];
    for (final (title, on, off) in pairs) {
      for (var i = 0; i < 2; i++) {
        await _flip(tester, title, on: on, off: off);
      }
    }

    for (var i = 0; i < 2; i++) {
      await _flip(
        tester,
        l10n.reviewSettingsSwitch,
        on: l10n.reviewSettingsSwitchOn,
        off: l10n.reviewSettingsSwitchOff,
        confirm: l10n.reviewTurnOn,
      );
    }
  });

  testWidgets('the reminder line names the time it is set for', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: _everythingOn(),
    );
    final l10n = l10nOf(tester);
    state.settings
      ..reminder = true
      ..reminderTime = const TimeOfDay(hour: 8, minute: 5);
    await tester.pumpAndSettle();
    final row = _switchRow(l10n.settingsReminder);
    await scrollTo(tester, row);
    expect(
      tester.widget<GroupedTile>(row).line,
      l10n.settingsReminderOn(_time(tester, 8, 5)),
    );
  });

  testWidgets('PIN lock, which cannot be changed here yet, says whether '
      'this profile asks for its PIN', (tester) async {
    usePhone(tester);
    for (final locked in <bool>[false, true]) {
      await pumpScreen(
        tester,
        SettingsPage(key: UniqueKey()),
        state: AppState.test(
          features: FeatureRegistry.all(),
          profiles: <Profile>[
            Profile(id: 'p', name: 'Aro', pin: locked ? '1234' : null),
          ],
          currentProfileId: 'p',
        ),
      );
      final l10n = l10nOf(tester);
      final row = _switchRow(l10n.settingsPinLock);
      await scrollTo(tester, row);
      expect(tester.widget<GroupedTile>(row).toggleValue, locked);
      expect(
        tester.widget<GroupedTile>(row).line,
        locked ? l10n.settingsPinLockOn : l10n.settingsPinLockOff,
      );
    }
  });

  testWidgets('each switch in Appearance: its line before and after one tap', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const AppearancePage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    for (final (title, on, off) in <(String, String, String)>[
      (
        l10n.appearancePureBlack,
        l10n.appearancePureBlackOn,
        l10n.appearancePureBlackOff,
      ),
      (
        l10n.appearanceWallpaper,
        l10n.appearanceWallpaperOn,
        l10n.appearanceWallpaperOff,
      ),
    ]) {
      for (var i = 0; i < 2; i++) {
        await _flip(tester, title, on: on, off: off);
      }
    }
  });

  testWidgets('a skill, by language, and an alphabet, by language: each '
      'line before and after one tap', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: _everythingOn(),
    );
    final l10n = l10nOf(tester);
    final telugu = state.languages.firstWhere((l) => l.code == 'te');

    final languages = find.text(l10n.settingsSkillLanguages).first;
    await scrollTo(tester, languages);
    await tester.tap(languages);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await _flip(
        tester,
        telugu.name,
        on: l10n.settingsSkillAskedIn(telugu.name),
        off: l10n.settingsSkillNotAskedIn(telugu.name),
      );
    }
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    final alphabets = find.text(l10n.settingsAlphabet);
    await scrollTo(tester, alphabets);
    await tester.tap(alphabets);
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.settingsAlphabetOn('telugu', telugu.name)),
      findsOneWidget,
    );
    expect(
      l10n.settingsAlphabetOn('telugu', 'Telugu'),
      'Learning the Telugu script',
    );
    for (var i = 0; i < 2; i++) {
      await _flip(
        tester,
        telugu.name,
        on: l10n.settingsAlphabetOn(telugu.script, telugu.name),
        off: state.courseUnits('te').isEmpty
            ? l10n.settingsAlphabetOffEmpty
            : l10n.settingsAlphabetOff,
      );
    }
  });

  testWidgets('a skill that needs a voice says, after its state, which '
      'languages have none on this phone', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(tts: FixedTtsEngine(const <String>{'es'})),
    );
    final l10n = l10nOf(tester);
    final missing = <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code) &&
            state.voiceStatus(language) == VoiceStatus.missing)
          language.name,
    ].join(l10n.commonListSeparator);
    expect(missing, isNotEmpty);
    await _flip(
      tester,
      Skill.listening.settingsLabel(l10n),
      on: l10n.settingsSkillNoVoice(Skill.listening.settingsOn(l10n), missing),
      off: l10n.settingsSkillNoVoice(
        Skill.listening.settingsOff(l10n),
        missing,
      ),
    );
  });

  testWidgets('Languages I speak shows the languages chosen', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    state.settings.spokenLanguages = const <String>['bn', 'en'];
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(l10n.settingsSpoken),
          matching: find.byType(GroupedTile),
        ),
        matching: find.text('Bengali${l10n.commonListSeparator}English'),
      ),
      findsOneWidget,
    );
  });

  group('no switch keeps the same line in both states', () {
    testWidgets('in Settings', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage(), state: _everythingOn());
      final l10n = l10nOf(tester);
      final switches = await _everySwitch(tester);
      // Every skill, readings, adjusting, sound, playing, the reminder, the
      // PIN, reviewing and updates, at least.
      expect(
        switches.map((t) => t.title),
        containsAll(<String>[
          for (final skill in Skill.values) skill.settingsLabel(l10n),
          l10n.settingsRomanisation,
          l10n.settingsAdjustAuto,
          l10n.settingsSound,
          l10n.settingsAutoplay,
          l10n.settingsReminder,
          l10n.settingsPinLock,
          l10n.reviewSettingsSwitch,
          l10n.settingsUpdateAuto,
        ]),
      );
      _expectEveryLineChanges(switches);
    });

    testWidgets('in Appearance', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const AppearancePage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      final switches = await _everySwitch(tester);
      expect(switches, hasLength(greaterThanOrEqualTo(2)));
      _expectEveryLineChanges(switches);
    });

    testWidgets('in the per-language dialogs', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage(), state: _everythingOn());
      final l10n = l10nOf(tester);
      for (final opener in <Finder>[
        find.text(l10n.settingsSkillLanguages).first,
        find.text(l10n.settingsAlphabet),
      ]) {
        await scrollTo(tester, opener);
        await tester.tap(opener);
        await tester.pumpAndSettle();
        final switches = tester
            .widgetList<GroupedTile>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(GroupedTile),
              ),
            )
            .toList();
        expect(switches, isNotEmpty);
        expect(switches.every((t) => t.toggleValue != null), isTrue);
        _expectEveryLineChanges(switches);
        await tester.tap(find.text(l10n.commonDone));
        await tester.pumpAndSettle();
      }
    });
  });

  test('the skills are named in the learner’s words', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      <String>[for (final skill in Skill.values) skill.settingsLabel(l10n)],
      <String>[
        'Seen words',
        'Written words',
        'Heard words',
        'Spoken words',
        'Grammar',
        'Reading',
        'Phonemic contrasts',
      ],
    );
    expect(l10n.settingsRomanisation, 'Latin-letter readings');
  });
}
