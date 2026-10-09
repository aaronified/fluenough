/// A course with nothing yet but its alphabet: one script deck of Hindi from
/// English, which its path marks as needing the alphabet (#47). No bundled
/// course is like this, so tests that need one build it from these files.
Map<String, String> scriptOnlyCourse() => const <String, String>{
  'decks/hi/hi-en-letters.yaml': '''
schema: 1
id: hi-en-letters
name: "Letters"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: hi-en-letters-0001, target: "क", native: "k", reading: "ka" }
  - { id: hi-en-letters-0002, target: "ख", native: "kh", reading: "kha" }
''',
  'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
alphabet:
  - hi-letters
units:
  - [hi-letters]
''',
};
