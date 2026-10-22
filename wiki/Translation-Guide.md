# Translation guide

Two kinds of text can be translated. They work differently.

| What | Where it lives | State today |
|---|---|---|
| The app's own text: menus, buttons, messages | `lib/l10n/app_en.arb` | English only |
| What decks say to a learner: meanings, notes, deck names | `decks/<language>/<native>/` English layers | English layers for most courses |

You do not need to write Dart for either. [ADR-0006](ADR-0006-Interface-Text-Is-Tokens) set this up so that a deck contributor, who knows the language, can translate the app too.

## 1. The app's text

### How it works

No visible text is written into a screen. Every label is a token with a value in an ARB file. ARB is JSON. The English file is `lib/l10n/app_en.arb`. It has about 1,600 messages. It is the template: `l10n.yaml` names it, and other languages are generated against it ([`l10n.yaml`](https://github.com/aaronified/fluenough/blob/main/l10n.yaml)).

Today there is no other ARB. The app is English only. The language picker in the screens exists but is disabled, with "Feature incoming" ([#46](https://github.com/aaronified/fluenough/issues/46)).

### Add a language

1. Pick the code. Use the language's code, such as `hi` for Hindi or `bn` for Bengali.
2. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb`, for example `app_hi.arb`.
3. Change the first line to the new code: `"@@locale": "hi",`.
4. Translate each value. Leave every key, and every `@key` block, as it is. You may delete the `@key` blocks in your copy: only the English file needs them.
5. Run `flutter pub get`. It runs `gen_l10n` and rebuilds the `AppLocalizations` class. The generated files are not committed.
6. A message you have not translated is listed in `build/untranslated_messages.txt`. Until it is translated, the app shows the English text for it.
7. Open a pull request. See [Contributing](Contributing) and [Development setup](Development-Setup).

Your language then appears in `AppLocalizations.supportedLocales`, which the language picker lists.

### Rules for a translation

- **Keep the placeholders.** `{count}`, `{language}` and `{title}` stand for values the app fills. Do not translate them or change their spelling. Move them where your grammar needs them.
- **Plurals and choices.** A value such as `{count, plural, =1{1 card} other{{count} cards}}` is ICU text. Keep the shape. Write the words for each case inside the braces. Your language may need more cases, such as `few` or `many`.
- **Do not build a sentence from pieces.** If a message holds a whole sentence with a placeholder, translate the whole sentence, so you control word order.
- **Longer text.** Hindi, Bengali and Telugu are often longer than English. The app is drawn at up to 1.4 times text size ([#505](https://github.com/aaronified/fluenough/issues/505)). Short labels are better.
- **Right to left.** Screens use start and end, never left and right, so Urdu and other right-to-left languages can be added.
- **Names that stay.** `appTitle` stays "Fluenough". The Android launcher label is not in this file.
- **Read the `@key` description** in the English file. It says where the text appears.
- **Deck text is not here.** Words, meanings and notes are deck data, not interface.

An example, from the English file:

```json
"navToday": "Today",
"commonCardCount": "{count, plural, =0{No cards} =1{1 card} other{{count} cards}}",
```

In `app_hi.arb` the first would be `"navToday": "आज"`. Keep the second one's shape and write Hindi words in each case.

### Check it

Do not run the tests locally. Push to a branch and read CI's result ([Development setup](Development-Setup)).

## 2. Deck English layers

A deck is a core and layers. The core holds the language learnt: ids, words, readings. A layer holds one native language: the deck's name, each card's meaning, notes, and examples' translations. So the same Telugu core can be taught from English, and from Bengali, by adding layers. The core does not change.

Layers live one folder down: the Telugu core `decks/te/te-about-me.yaml` has its English layer at `decks/te/en/te-en-about-me.yaml`. A layer's id is the language, the native language and the same name. A card a layer does not translate is not taught from that language.

To translate a course into a new native language:

1. Copy an English layer to `decks/<language>/<native>/`, for example `decks/te/bn/te-bn-about-me.yaml`.
2. Change `id`, `native` and the name and description. Write every meaning, note and example in the native language.
3. Keep the card ids. They are permanent.
4. Quote every YAML scalar.
5. Keep the reading beside any script word in notes. A Telugu word in a Bengali note still needs its reading, based on ISO 15919. A Bengali word in a Bengali layer needs none.
6. Mention in a note when a base word changes its stem.
7. Push to a branch and open a pull request. CI runs the deck validator.

Full rules: the [Deck building guide](Deck-Building-Guide), [Deck format](Deck-Format), and [Romanising Indic languages](Romanising-Indic-Languages). Reviewers are bilingual, and a card's meaning never changes in review ([Reviewing guide](Reviewing-Guide)).

Decks are licensed CC BY-SA 4.0 ([Deck licences and quoted books](Deck-Licences-and-Quoted-Books)).

## Which language list

A learner says which languages they know from `assets/languages.yaml`. A new language is a new entry there, with no code change. A new script's name is added to `scriptName` in `app_en.arb`.

See also: [Home](Home), [Contributing](Contributing).
