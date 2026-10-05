import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/stored_settings.dart';
import 'package:fluenough/core/data/database.dart';

/// Every setting changed from its default.
void changeAll(SettingsNotifier s) {
  s
    ..setSkillEnabled(Skill.listening, false)
    ..showRomanisation = false
    ..soundOn = false
    ..autoplay = true
    ..countSpeakerTap()
    ..speechRate = 0.8
    ..themeMode = ThemeMode.dark
    ..seed = ThemeSeed.clay
    ..dynamicColour = true
    ..highContrast = true
    ..pureBlack = true
    ..setLearnsAlphabet('hi', false)
    ..cardTextScale = 1.2
    ..reminder = true
    ..reminderTime = const TimeOfDay(hour: 7, minute: 5)
    ..learningLanguages = const <String>['hi', 'bn']
    ..placedDecks = const <String>{'hi-en-first-words', 'hi-en-questions'}
    ..learningChosen = true
    ..autoUpdateCheck = true
    ..lastUpdateCheck = DateTime(2026, 10, 1, 8, 30)
    ..latestRelease = '0.2.0'
    ..pendingUpdate = '0.2.0';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every setting survives toStored and restore', () {
    final changed = SettingsNotifier();
    changeAll(changed);
    // Saved at all: a key left out of toStored would round-trip as its
    // default on both sides, and pass.
    expect(changed.toStored()['pure_black'], 'true');
    final restored = SettingsNotifier()..restore(changed.toStored());
    expect(restored.toStored(), changed.toStored());
    expect(restored.toStored(), isNot(SettingsNotifier().toStored()));
  });

  test('unreadable or out-of-range values keep a sensible setting', () {
    final s = SettingsNotifier()
      ..restore(const <String, String>{
        'speech_rate': 'NaN',
        'theme_mode': 'purple',
        'seed': '',
        'reminder_time': '25:00',
        'card_text_scale': '9',
        'show_romanisation': 'maybe',
        'enabled_skills': 'recognition,unknown',
        'learning_languages': 'hi,Hindi,,bn',
        'placed_decks': 'hi-en-market,Not A Deck',
        'auto_update_check': 'sometimes',
        'last_update_check': 'yesterday',
        'latest_release': 'latest',
        'pending_update': 'app-release.apk',
      });
    final defaults = SettingsNotifier();
    expect(s.speechRate, defaults.speechRate);
    expect(s.themeMode, defaults.themeMode);
    expect(s.seed, defaults.seed);
    expect(s.reminderTime, defaults.reminderTime);
    expect(s.cardTextScale, SettingsNotifier.maxCardTextScale);
    expect(s.showRomanisation, defaults.showRomanisation);
    // Reading is newer than a list with no marks, so it keeps its default.
    expect(s.enabledSkills, {Skill.recognition, Skill.reading});
    expect(s.learningLanguages, ['hi', 'bn']);
    expect(s.placedDecks, {'hi-en-market'});
    expect(s.autoUpdateCheck, isFalse);
    expect(s.lastUpdateCheck, isNull);
    expect(s.latestRelease, isNull);
    expect(s.pendingUpdate, isNull);
  });

  test('the update check is stored: the switch, when, what it found, and '
      'what is downloaded to install', () {
    final checked = DateTime(2026, 10, 1, 8, 30);
    final changed = SettingsNotifier()
      ..autoUpdateCheck = true
      ..lastUpdateCheck = checked
      ..latestRelease = '0.3.0'
      ..pendingUpdate = '0.2.0';
    final stored = changed.toStored();
    expect(stored['auto_update_check'], 'true');
    expect(stored['last_update_check'], '${checked.millisecondsSinceEpoch}');
    expect(stored['latest_release'], '0.3.0');
    expect(stored['pending_update'], '0.2.0');

    final restored = SettingsNotifier()..restore(stored);
    expect(restored.autoUpdateCheck, isTrue);
    expect(restored.lastUpdateCheck, checked);
    expect(restored.latestRelease, '0.3.0');
    expect(restored.pendingUpdate, '0.2.0');

    // Off, never checked and nothing downloaded, by default.
    final defaults = SettingsNotifier().toStored();
    expect(defaults['auto_update_check'], 'false');
    expect(defaults['last_update_check'], '');
    expect(defaults['latest_release'], '');
    expect(defaults['pending_update'], '');
    final fresh = SettingsNotifier()..restore(defaults);
    expect(fresh.autoUpdateCheck, isFalse);
    expect(fresh.lastUpdateCheck, isNull);
    expect(fresh.latestRelease, isNull);
    expect(fresh.pendingUpdate, isNull);
  });

  test(
    'a download forgotten after its update is stored as forgotten',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final stored = await StoredSettings.open(db);
      stored.settings.pendingUpdate = '0.2.0';
      await stored.flush();
      stored.settings.pendingUpdate = null;
      await stored.flush();
      final again = await StoredSettings.open(db);
      expect(again.settings.pendingUpdate, isNull);
    },
  );

  test('a skill added since the settings were stored keeps its default, '
      'and one switched off since stays off (#98)', () {
    // Stored before reading existed: listening was switched off.
    final older = SettingsNotifier()
      ..restore(const <String, String>{
        'enabled_skills': 'recognition,production,grammar',
      });
    expect(older.isEnabled(Skill.reading), isTrue);
    expect(older.isEnabled(Skill.listening), isFalse);
    expect(older.isEnabled(Skill.speaking), isFalse);

    final off = SettingsNotifier()..setSkillEnabled(Skill.reading, false);
    final again = SettingsNotifier()..restore(off.toStored());
    expect(again.isEnabled(Skill.reading), isFalse);
    expect(again.isEnabled(Skill.recognition), isTrue);

    // Stored by a version with a skill this one does not know, unmarked
    // skills absent: each keeps its default.
    final newer = SettingsNotifier()
      ..restore(const <String, String>{
        'enabled_skills': 'recognition,!production,someday',
      });
    expect(newer.isEnabled(Skill.production), isFalse);
    expect(newer.isEnabled(Skill.listening), isTrue);
    expect(newer.isEnabled(Skill.reading), isTrue);

    // Every skill on is still marked as a complete list, so a skill a later
    // version adds keeps its default rather than reading as off.
    final allOn = SettingsNotifier().toStored()['enabled_skills']!;
    expect(allOn.split(','), contains('+'));
    final later = SettingsNotifier()
      ..restore(const <String, String>{'enabled_skills': '+,recognition'});
    expect(later.isEnabled(Skill.listening), isTrue);
    expect(later.isEnabled(Skill.recognition), isTrue);
  });

  test('settings persist across closing and reopening the database', () async {
    final dir = Directory.systemTemp.createTempSync('fluenough');
    addTearDown(() => dir.deleteSync(recursive: true));
    AppDatabase open() =>
        AppDatabase(NativeDatabase(File('${dir.path}/profile.sqlite')));

    final db = open();
    final first = await StoredSettings.open(db);
    expect(first.settings.toStored(), SettingsNotifier().toStored());
    changeAll(first.settings);
    await first.flush();
    await db.close();

    final again = open();
    addTearDown(again.close);
    final restored = await StoredSettings.open(again);
    final expected = SettingsNotifier();
    changeAll(expected);
    expect(restored.settings.toStored(), expected.toStored());
  });

  test('only changed settings are written', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final stored = await StoredSettings.open(db);
    stored.settings.speechRate = 1.2;
    await stored.flush();
    expect(await db.settingsDao.all(), {'speech_rate': '1.2'});
  });
}
