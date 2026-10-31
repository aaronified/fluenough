// Skills are kept for the whole app but the learned lists per profile: one
// profile's edit must not delete decks another still learns, an unreadable
// entry is not Leave, and the sole spoken language sent back to the pool is
// not left reading.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/picker.dart';

/// Downloads that hold decks of [held] and record each removal.
class HeldDecks extends DeckDownloads {
  HeldDecks(this.held)
    : super(
        fetcher: FakeDeckRemote(<String, String>{}),
        files: MemoryDownloadedDecks(),
        clock: DateTime.now,
      );

  final Set<String> held;
  final List<String> removed = <String>[];

  @override
  bool hasDecks(String language) => held.contains(language);

  @override
  Future<void> remove(String language) async {
    removed.add(language);
    held.remove(language);
  }
}

void main() {
  final es = pickerSpokenList.firstWhere((l) => l.code == 'es');
  final en = pickerSpokenList.firstWhere((l) => l.code == 'en');

  AppState twoProfiles(HeldDecks downloads) {
    final state = AppState.test(
      deckDownloads: downloads,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    addTearDown(state.dispose);
    // A second profile with its own list, still learning Spanish.
    state.createProfile(name: 'B', languages: <String>{'es'});
    return state;
  }

  test('decks another profile learns are kept when one leaves the language, '
      'and that profile still reads Learn', () async {
    final downloads = HeldDecks(<String>{'es'});
    final state = twoProfiles(downloads);
    // Profile A (the default, following the setting) sets Spanish to Leave.
    state.applySkills(es, LanguageSkills());
    expect(state.learningCodes, isNot(contains('es')));

    await state.removeUnneededDecks();
    expect(downloads.removed, isEmpty);

    // Profile B reads its own list, not A's edit.
    state.selectProfile(state.profiles.last.id);
    expect(state.skillsOf(es).anyLearn, isTrue);
  });

  test('decks go when no profile learns the language any more', () async {
    final downloads = HeldDecks(<String>{'es'});
    final state = twoProfiles(downloads);
    state.applySkills(es, LanguageSkills());
    state.selectProfile(state.profiles.last.id);
    state.applySkills(es, LanguageSkills());
    await state.removeUnneededDecks();
    expect(downloads.removed, <String>['es']);
  });

  test('an unreadable stored entry is not taken for Leave', () async {
    final downloads = HeldDecks(<String>{'es'});
    final state = AppState.test(
      deckDownloads: downloads,
      settings: SettingsNotifier(spokenLanguages: const <String>['en']),
    );
    addTearDown(state.dispose);
    state.settings.setLanguageSkills('es', <String, String>{'dance': 'learn'});
    await state.removeUnneededDecks();
    expect(downloads.removed, isEmpty);
    expect(state.settings.languageSkillsOf('es'), isNotNull);
  });

  test('the sole spoken language sent back to the pool stays listed but '
      'reads nothing', () {
    final state = AppState.test(
      settings: SettingsNotifier(spokenLanguages: const <String>['es'])
        ..scriptsRead = <String, bool>{es.code: true},
    );
    addTearDown(state.dispose);
    state.applySkills(es, LanguageSkills());
    expect(state.settings.languageSkillsOf('es'), isEmpty);
    expect(state.settings.spokenLanguages, <String>['es']);
    expect(state.settings.scriptsRead[es.code], isFalse);
  });

  test('English is fixed: sending it back to the pool changes nothing', () {
    final state = AppState.test(
      settings: SettingsNotifier(spokenLanguages: const <String>['en']),
    );
    addTearDown(state.dispose);
    state.applySkills(en, LanguageSkills());
    expect(state.settings.languageSkillsOf('en'), isNull);
    expect(state.settings.spokenLanguages, <String>['en']);
  });
}
