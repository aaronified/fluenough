// The language the app opens on is worked out without the catalog (ADR-0062)
// and is the one the language bar shows once the decks are loaded.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/startup_language.dart';
import 'package:flutter_test/flutter_test.dart';

String _deck(String code, String name, String iso) =>
    '''
schema: 1
id: $code-en-words
name: "$code words"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $code-1, target: "w", native: "n" }
''';

Map<String, String> _files() => <String, String>{
  'decks/es/es-en-words.yaml': _deck('es', 'Spanish', 'spa'),
  'decks/fr/fr-en-words.yaml': _deck('fr', 'French', 'fra'),
  'decks/hi/hi-en-words.yaml': _deck('hi', 'Hindustani', 'hin'),
};

/// One state of the learner: what they chose, in what order, and which
/// languages their profile learns (null: every one).
typedef _Case = ({
  String? chosen,
  List<String> learning,
  Set<String>? profile,
  List<String> onPhone,
  String? expected,
});

const List<_Case> _table = <_Case>[
  (
    chosen: null,
    learning: <String>[],
    profile: null,
    onPhone: <String>['es', 'fr', 'hi'],
    expected: 'es',
  ),
  (
    chosen: 'fr',
    learning: <String>['es', 'fr'],
    profile: null,
    onPhone: <String>['es', 'fr', 'hi'],
    expected: 'fr',
  ),
  (
    chosen: null,
    learning: <String>['hi', 'es'],
    profile: null,
    onPhone: <String>['es', 'fr', 'hi'],
    expected: 'hi',
  ),
  // The chosen language is no longer learned: the first of the options.
  (
    chosen: 'hi',
    learning: <String>['es', 'fr'],
    profile: <String>{'es', 'fr'},
    onPhone: <String>['es', 'fr', 'hi'],
    expected: 'es',
  ),
  // Chosen and learned but not on the phone.
  (
    chosen: 'de',
    learning: <String>['de', 'fr'],
    profile: null,
    onPhone: <String>['es', 'fr', 'hi'],
    expected: 'fr',
  ),
  // The profile learns one language only.
  (
    chosen: 'es',
    learning: <String>[],
    profile: <String>{'hi'},
    onPhone: <String>['es', 'fr', 'hi'],
    expected: 'hi',
  ),
  // First launch: nothing downloaded.
  (
    chosen: null,
    learning: <String>['es'],
    profile: null,
    onPhone: <String>[],
    expected: null,
  ),
];

void main() {
  group('StartupLanguage.resolve', () {
    for (final (i, c) in _table.indexed) {
      test('case $i opens on ${c.expected}', () {
        expect(
          StartupLanguage.resolve(
            chosen: c.chosen,
            learning: c.learning,
            learns: (code) => c.profile?.contains(code) ?? true,
            available: c.onPhone,
          ),
          c.expected,
        );
      });
    }

    test('a notation is not learned unless chosen', () {
      expect(
        StartupLanguage.resolve(
          chosen: null,
          learning: const <String>[],
          learns: Profile.defaultProfile.learns,
          available: const <String>['ipa', 'es'],
        ),
        'es',
      );
    });
  });

  group('equals the language bar once the decks are loaded', () {
    for (final (i, c) in _table.indexed) {
      if (c.onPhone.length != 3) continue;
      test('case $i', () async {
        final state = AppState.test(
          decks: MemoryDeckSource(_files()),
          profiles: <Profile>[Profile(id: 'p', languages: c.profile)],
        );
        addTearDown(state.dispose);
        state.settings
          ..learningLanguages = c.learning
          ..languageChoice = c.chosen;
        await state.load();
        final learning = <String>[
          ...<String>{
            ...state.settings.learningLanguages,
            ...?state.currentProfile.languages,
          },
        ];
        expect(
          StartupLanguage.resolve(
            chosen: state.settings.languageChoice,
            learning: learning,
            learns: state.currentProfile.learns,
            available: <String>[for (final l in state.languages) l.code],
          ),
          state.shownLanguage,
        );
      });
    }
  });
}
