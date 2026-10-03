import '../../app/deck_catalog.dart';

/// The id of [readingFixtureDecks]'s one deck.
const String readingFixtureDeckId = 'bn-en-fixture-reading';

/// Where the fixture's first passage says it comes from.
const String readingFixtureSource = "Written for Fluenough's tests";

/// Where the rest of the fixture comes from, its deck's own source.
const String readingFixtureDeckSource = "Fluenough's sample passages";

/// A small reading deck (#98), in memory, for the reading drill's gallery
/// entries and tests.
///
/// The real passages, from Sahaj Path and Abol Tabol, are content and come
/// in their own deck. This one is a fixture, never bundled and never under
/// `decks/`, and its ids say so. Its first passage is made of phrases the
/// Bengali decks teach; its second has an older spelling, ক’রে, in its
/// glossary.
MemoryDeckSource readingFixtureDecks() =>
    MemoryDeckSource(const <String, String>{
      'fixtures/bn/bn-en-fixture-reading.yaml': readingFixtureYaml,
    });

const String readingFixtureYaml =
    '''
schema: 1
id: bn-en-fixture-reading
name: "Bengali reading (fixture)"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
source: "$readingFixtureDeckSource"
tags: [fixture]

passages:
  - id: bn-en-fixture-reading-shop
    title: "At the shop" # ui-literal-ok: deck content, in a fixture
    theme: market
    source: "$readingFixtureSource"
    sentences:
      - text: "নমস্কার। কত দাম?"
        reading: "nomoshkar. koto dam?"
      - text: "পঞ্চাশ টাকা।"
        reading: "ponchash taka."
      - text: "একটু কম করুন।"
        reading: "ektu kom korun."
      - text: "আচ্ছা। ধন্যবাদ।"
        reading: "achchha. dhonnobad."
    questions:
      - id: bn-en-fixture-reading-shop-q1
        prompt:
          en: "What does the buyer ask first?"
          hi: "ग्राहक पहले क्या पूछता है?"
        options:
          - { en: "The price", hi: "दाम" }
          - { en: "The way", hi: "रास्ता" }
          - { en: "The time", hi: "समय" }
        answer: 1
      - id: bn-en-fixture-reading-shop-q2
        prompt:
          en: "The buyer asks for a lower price."
        answer: true
      - id: bn-en-fixture-reading-shop-q3
        prompt:
          en: "What is the price at first?"
        options:
          - { en: "Twenty taka" }
          - { en: "Fifty taka" }
          - { en: "A hundred taka" }
        answer: 2

  - id: bn-en-fixture-reading-home
    title: "Going home" # ui-literal-ok: deck content, in a fixture
    sentences:
      - text: "সে কাজ ক’রে বাড়ি যায়।"
        reading: "she kaj kore bari jay."
      - text: "বাড়িতে সে ভাত খায়।"
        reading: "barite she bhat khay."
    glossary:
      - word: "ক’রে"
        modern: "করে"
        reading: "kore"
        meaning: { en: "having done" }
        note: { en: "older spelling; the apostrophe marks a dropped ই" }
      - word: "বাড়িতে"
        modern: "বাড়িতে"
        reading: "barite"
        meaning: { en: "at home" }
    questions:
      - id: bn-en-fixture-reading-home-q1
        prompt:
          en: "They eat rice at home."
        answer: true
      - id: bn-en-fixture-reading-home-q2
        prompt:
          en: "Where do they go after work?"
        options:
          - { en: "Home" }
          - { en: "To the market" }
        answer: 1
''';
