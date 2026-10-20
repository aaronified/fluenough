# ADR-0041: The IPA is taught as a language, in two courses that share progress

- **Status:** Accepted (owner, 2026-10-16, #534: "Use sonnet for the IPA
  course"; the open points answered the same day: "Yes, recorded" and "Show,
  offer to add"; the design is the plan
  [ipa-course.md](../plans/ipa-course.md)).
- **Date:** 2026-10-16
- **Number:** the drafted `0026-ipa-course-and-icons` was never merged and
  0026 is taken ([ADR-0026](0026-sound-on-every-card.md)); this is the next
  free number. The language icons are [ADR-0027](0027-language-icons.md).

## Context

The owner asked for a course on the International Phonetic Alphabet "which
will be for learning how the IPA alphabet works, not only via repetition
(which will be via practice), but with as much logical structure as
possible", "offered like a language"; every symbol with an example of "how it
sounds, and one for how it doesn't"; and on every card in every language "a
button to take them through a curated IPA deck that only has the symbols used
in the card". Its content, 179 cards, was written first. Nothing of the app
side existed: a language is a thing a learner types in a script and hears in
a voice, and the IPA is neither.

## Decision

1. **The IPA is a language in the data** with `script: "ipa"`, code `ipa`,
   ISO 639-3 `zxx` ("no linguistic content"), icon `ə`, and `typed: false`
   ([DECK-FORMAT.md, The IPA course](../DECK-FORMAT.md#the-ipa-course)). It
   is a core and layers like any other course, with a path that has no B1
   plan, since it is taught to no level. The `ipa` script needs no reading
   and no `tts` tag.
2. **An example says which sound it is and in which language.** An example
   gives its `language`, and `sounds: false` where the card's letter is not
   said with the card's sound. The card shows each example marked "Has this
   sound" or "Does not have this sound", by an icon and words, never by colour
   alone, and in Inspect.
3. **One language, two entries, one progress.** The language list offers
   "IPA: my languages" and "IPA: whole chart". Choosing either learns `ipa`;
   choosing the other while it is learned changes only the learner's scope,
   `Settings.ipaScope`. Cards carry the languages that use their sound as
   tags, with `core` for the symbols everyone needs; in "my languages" a card
   is in the course when it is `core` or tagged with a language the learner
   learns. **This is filtered in one place**, `Catalog.forIpa`, applied by
   `AppState` to what every screen reads (`decks`, `deckById`, `deckOf`), so
   counts, lessons, finished decks and Inspect agree. A deck left with no card
   is not on offer. A card the learner has answered stays in their course
   whatever its tags: it is scheduled.
4. **The IPA is learned only when chosen.** A profile that learns "every
   language" because it never chose does not learn the IPA
   (`Profile.learns`). The picker does not place it: there is no level to
   find.
5. **Production is chosen where the language is not typed.** In reviews
   (`reviewAsks`), in lessons and in the check of a hard word
   (`lessonQuestions`), a card of a language with `typed: false` is asked as
   `Ask.chooseWord`.
6. **Examples are said in their own languages' voices**, preferring the
   languages being learned: an example's speaker plays it in the voice of its
   `language`, which `AppState` looks up among the languages the decks teach
   and are taught from; those the learner learns come first; a language with
   no voice on the phone has no speaker, the sound being optional.
7. **"The sounds of this word"**, a button in every drill's header and on the
   card sheet for every card that has an `ipa`, opens a lesson of the IPA
   cards whose symbols occur in that `ipa` (`ipaCardsFor`: a card's target
   found in the transcription, the slashes, brackets and full stop aside).
   Owner, 2026-10-16: the answers are recorded: "Yes, recorded" — they count
   as IPA course practice and are scheduled. For a learner who is not
   learning the IPA the button still shows and first offers to add the course
   ("Show, offer to add"), downloading its decks if they are not on the phone.
   The cards are of the whole chart, whatever the scope: the symbols of a word
   are what the word needs.

## Consequences

- A symbol card out of a learner's "my languages" tags reaches their course
  by being practised from the button, and stays in it. Without that, the
  schedule would hold cards no screen shows.
- Every drill's header has one more button. It is empty on cards with no
  IPA, which is every card until the Wiktionary IPA lands
  (`wiktionary-ipa.md`, removed; see git history; now `tools/import_wiktionary.py`); Indic decks have theirs.
- The substring match over-includes: `t` is found in `t̪`. A learner sees the
  plain letter as well as the marked one, which is a fair review and costs a
  card more; a segmenter needs a list of every symbol and its marks, which is
  the course's own data and may come later.
- Two entries in the picker share one language's card state (download,
  alpha notice, its progress) and differ only in their name, tick and scope.
- The decks are `CC-BY-SA-4.0`, as every deck is since
  [ADR-0040](0040-decks-are-cc-by-sa.md).

## Alternatives considered

- **Two languages, `ipa` and `ipa-mine`.** Progress is keyed by card id, so
  two languages would need the same cards twice or a ref from one to the
  other, and a learner switching would see two progresses. One language with
  a scope is simpler and is what the owner asked for ("They share progress").
- **Filtering in each screen.** Counts, lessons, finished decks and Inspect
  would disagree the first time one forgot; the plan says "in one place".
- **A keyboard of IPA symbols for typing.** Phone keyboards have none and an
  on-screen one is a project of its own; choosing the symbol is a fair test of
  recognition and recall, and is what `typed: false` asks.
- **A segmenter for the button.** Rejected for now: see Consequences.
