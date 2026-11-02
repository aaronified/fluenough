/// A tiny Japanese course with kanji (ADR-0053): hiragana in kana, then a deck
/// of words and a deck of kanji, each written in kanji (`script: han`) with
/// its kana reading under `target_scripts.kana`. Taught from English.
///
/// There are more kanji decks than kana ones, which is how the real course
/// ends up: the course must still start in kana.
Map<String, String> japaneseKanjiCourse() => const <String, String>{
  'decks/ja/ja-en-hiragana.yaml': '''
schema: 1
id: ja-en-hiragana
name: "Hiragana"
language: { code: ja, iso639_3: jpn, name: Japanese, script: kana, tts: ja-JP }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: ja-en-hiragana-0001, target: "あ", native: "a", reading: "a" }
''',
  'decks/ja/ja-en-words.yaml': '''
schema: 1
id: ja-en-words
name: "Words"
language: { code: ja, iso639_3: jpn, name: Japanese, script: han, scripts: [han, kana], tts: ja-JP }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: ja-en-words-0001, target: "食べる", target_scripts: { kana: "たべる" }, native: "to eat", reading: "taberu" }
  - { id: ja-en-words-0002, target: "ありがとう", native: "thank you", reading: "arigatou" }
''',
  'decks/ja/ja-en-kanji-1.yaml': '''
schema: 1
id: ja-en-kanji-1
name: "First kanji"
language: { code: ja, iso639_3: jpn, name: Japanese, script: han, scripts: [han, kana], tts: ja-JP }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: ja-en-kanji-1-0001, target: "日", target_scripts: { kana: "ひ" }, native: "day, sun", reading: "hi" }
''',
  'decks/ja/ja-path.yaml': '''
schema: 1
kind: path
id: ja-path
language: ja
alphabet:
  - ja-hiragana
  - ja-kanji-1
units:
  - [ja-hiragana]
  - [ja-words]
  - [ja-kanji-1]
''',
};
