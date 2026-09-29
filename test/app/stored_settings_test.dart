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
    ..newCardsPerDay = 35
    ..setSkillEnabled(Skill.listening, false)
    ..showRomanisation = false
    ..speechRate = 0.8
    ..themeMode = ThemeMode.dark
    ..seed = ThemeSeed.clay
    ..dynamicColour = true
    ..highContrast = true
    ..cardTextScale = 1.2
    ..reminder = true
    ..reminderTime = const TimeOfDay(hour: 7, minute: 5);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every setting survives toStored and restore', () {
    final changed = SettingsNotifier();
    changeAll(changed);
    final restored = SettingsNotifier()..restore(changed.toStored());
    expect(restored.toStored(), changed.toStored());
    expect(restored.toStored(), isNot(SettingsNotifier().toStored()));
  });

  test('unreadable or out-of-range values keep a sensible setting', () {
    final s = SettingsNotifier()
      ..restore(const <String, String>{
        'new_cards_per_day': '500',
        'speech_rate': 'NaN',
        'theme_mode': 'purple',
        'seed': '',
        'reminder_time': '25:00',
        'card_text_scale': '9',
        'show_romanisation': 'maybe',
        'enabled_skills': 'recognition,unknown',
      });
    final defaults = SettingsNotifier();
    expect(s.newCardsPerDay, SettingsNotifier.maxNewCardsPerDay);
    expect(s.speechRate, defaults.speechRate);
    expect(s.themeMode, defaults.themeMode);
    expect(s.seed, defaults.seed);
    expect(s.reminderTime, defaults.reminderTime);
    expect(s.cardTextScale, SettingsNotifier.maxCardTextScale);
    expect(s.showRomanisation, defaults.showRomanisation);
    expect(s.enabledSkills, {Skill.recognition});
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
