import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';

/// A small English Braille course (ADR-0043), as single-file decks: the
/// letters a to d, and a Spanish deck beside it.
const String brailleLanguage =
    '{ code: qbe, iso639_3: eng, name: English Braille, script: braille, '
    'icon: "⠃" }';

final Map<String, String> brailleFiles = <String, String>{
  'decks/qbe/qbe-en-letters.yaml':
      '''
schema: 1
id: qbe-en-letters
name: "Braille: a to d"
language: $brailleLanguage
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: qbe-0001, target: "⠁", native: "a", modes: [listening, speaking] }
  - { id: qbe-0002, target: "⠃", native: "b", modes: [listening, speaking] }
  - { id: qbe-0003, target: "⠉", native: "c", modes: [listening, speaking] }
  - { id: qbe-0004, target: "⠙", native: "d", modes: [listening, speaking] }
''',
  'decks/qbe/qbe-path.yaml': '''
schema: 1
kind: path
id: qbe-path
language: qbe
units:
  - [qbe-letters]
  - ["*"]
''',
  'decks/es/es-en-words.yaml': '''
schema: 1
id: es-en-words
name: "Words"
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-0001, target: "hola", native: "hello" }
  - { id: es-0002, target: "casa", native: "house" }
''',
};

/// An app learning [languages] from these decks, with a voice on the phone
/// for every tag, braille's code among them.
AppState brailleApp(List<String> languages, {TtsEngine? tts}) {
  final settings = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
    learningChosen: true,
  );
  return AppState.test(
    decks: MemoryDeckSource(brailleFiles),
    settings: settings,
    tts: tts ?? FixedTtsEngine(const <String>{'es', 'es-es', 'qbe', 'en'}),
  );
}
