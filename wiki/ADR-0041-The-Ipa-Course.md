# ADR-0041: The IPA is taught as a language, as one course

Source of truth: this wiki page.


- **Status:** Accepted (owner, 2026-10-16, #534: "Use sonnet for the IPA
  course"; the open points answered the same day: "Yes, recorded" and "Show,
  offer to add"; the design is the plan
  [ipa-course.md](Plan-Ipa-Course)).
- **Date:** 2026-10-16
- **Amended 2026-10-23 (#735):** the "my languages" scope is dropped (owner:
  "drop the only your languages IPA course. Doesn't matter. We anyway have
  the tags."). The course is the whole chart, one entry in the list, and
  `Settings.ipaScope`, `Catalog.forIpa` and the pinning of "sounds" cards are
  gone. Where the text below speaks of two entries or a scope, it is what was
  built first. A learner who had "my languages" keeps all their progress: it
  was always keyed by card, and the course now also offers the cards they had
  not been given.
- **Number:** the drafted `0026-ipa-course-and-icons` was never merged and
  0026 is taken ([ADR-0026](ADR-0026-Sound-On-Every-Card)); this is the next
  free number. The language icons are [ADR-0027](ADR-0027-Language-Icons).

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
   ([DECK-FORMAT.md, The IPA course](Deck-Format#the-ipa-course)). It
   is a core and layers like any other course, with a path that has no B1
   plan, since it is taught to no level. The `ipa` script needs no reading
   and no `tts` tag.
2. **An example says which sound it is and in which language.** An example
   gives its `language`, and `sounds: false` where the card's letter is not
   said with the card's sound. The card shows each example marked "Has this
   sound" or "Does not have this sound", by an icon and words, never by colour
   alone, and on the word sheet.
3. **One language, one entry, the whole chart.** The language list offers
   "IPA", and choosing it learns `ipa`. Cards still carry the languages that
   use their sound as tags, with `core` for the symbols everyone needs; the
   tags are for a learner to focus on their languages' symbols, and no
   screen cuts the course by them. (Until 2026-10-23 a second entry,
   "IPA: my languages", cut the course to the symbols of the languages the
   learner learns, filtered in `Catalog.forIpa`: dropped, #735.)
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
   The cards are of the whole chart: the symbols of a word are what the word
   needs.

## Consequences

- Every drill's header has one more button. It is empty on cards with no
  IPA, which is every card until the Wiktionary IPA lands
  (`wiktionary-ipa.md`, removed; see git history; now `tools/import_wiktionary.py`); Indic decks have theirs.
- The substring match over-includes: `t` is found in `t̪`. A learner sees the
  plain letter as well as the marked one, which is a fair review and costs a
  card more; a segmenter needs a list of every symbol and its marks, which is
  the course's own data and may come later.
- The decks are `CC-BY-SA-4.0`, as every deck is since
  [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa).

## Alternatives considered

- **A scope: "my languages" beside the whole chart** (built first, dropped
  2026-10-23, #735). Two entries of one language with one progress, the
  course cut by tags in one place. The tags already let a learner focus on
  their languages' symbols, so the second entry cost a setting, a filter and
  a pin for the "sounds" session for little.
- **Two languages, `ipa` and `ipa-mine`.** Progress is keyed by card, so two
  languages would need the same cards twice or a ref from one to the other.
- **A keyboard of IPA symbols for typing.** Phone keyboards have none and an
  on-screen one is a project of its own; choosing the symbol is a fair test of
  recognition and recall, and is what `typed: false` asks.
- **A segmenter for the button.** Rejected for now: see Consequences.

See also: [Contributing](Contributing) · [ADR-Index](ADR-Index) · [Home](Home)
