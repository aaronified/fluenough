/// A tiny Hindustani course in two scripts (#623): Devanagari first, then
/// Perso-Arabic, each with its letters deck, and a deck of words, one with
/// its Perso-Arabic spelling and one without. Taught from English.
Map<String, String> twoScriptCourse() => const <String, String>{
  'decks/hi/hi-en-letters.yaml': '''
schema: 1
id: hi-en-letters
name: "Letters"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari, scripts: [devanagari, perso_arabic] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: hi-en-letters-0001, target: "क", native: "k", reading: "ka" }
''',
  'decks/hi/hi-en-urdu-letters.yaml': '''
schema: 1
id: hi-en-urdu-letters
name: "Urdu letters"
language: { code: hi, iso639_3: hin, name: Hindustani, script: perso_arabic, scripts: [perso_arabic], rtl: true }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: hi-en-urdu-letters-0001, target: "ک", native: "k", reading: "ka" }
''',
  'decks/hi/hi-en-words.yaml': '''
schema: 1
id: hi-en-words
name: "Words"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari, scripts: [devanagari, perso_arabic] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-words-0001, target: "किताब", target_scripts: { perso_arabic: "کتاب" }, native: "book", reading: "kitāb" }
  - { id: hi-en-words-0002, target: "घर", native: "house", reading: "ghar" }
''',
  'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
alphabet:
  - hi-letters
  - hi-urdu-letters
units:
  - [hi-letters]
  - [hi-urdu-letters]
  - [hi-words]
''',
};
