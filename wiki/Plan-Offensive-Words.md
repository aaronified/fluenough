# Plan: offensive words, their level, and warnings on words like them

Source of truth: this wiki page.


Written 2026-10-09. Tracks #96 (offensive words behind an adult gate),
whose rules stand: decks marked `audience: adult` are hidden until the
learner turns on adult content and confirms they are 18 or over, per
profile; never in a child profile (#97), where the sound-alike and
look-alike warnings are not shown either (`profiles.md`); a disclaimer before the first
card; offensive cards are recognition only, never typed or said; a
speaker reviews every card before it ships, Telugu included.

## What the owner asked

> The offensive words deck needs to be built soon. With offensiveness
> level. Also, any words that sound similar should have a warning about
> its similarity to an offensive word, and as such needs extra care when
> writing or speaking (two separate similarity matrices)

## Decided with the owner, 2026-10-09

- **A level on every offensive card,** from the research in
  `docs/research/offensiveness-scale.md` (owner, 2026-10-09):
  - **Four bands:** mild, medium, strong, strongest, meaning how a native
    speaker hears the word in general (Janschewitz 2008's question), not
    how strong it feels to the learner, since learners misjudge both ways
    (Dewaele 2004, 2016).
  - **Slurs** (caste, religion, ethnicity, disability, gender) are always
    strongest, with their own warning.
  - Each card also has a **type** (swear, slur, sexual, family insult),
    whether it **can be friendly among peers**, and a **region note**
    where speakers differ.
- **Levels set by several native raters per language:** agents draft the
  list and a provisional level; several native speakers, from more than
  one region where possible, rate each word ("How offensive is this word
  to native speakers in general?", 1 to 9; the owner's wording, after
  Janschewitz 2008's "to people in general"); the median sets the band, by written
  cut-offs; slurs strongest by rule; a disagreement of a band or more
  becomes a region note. Nothing ships before (owner).
- **Two similarity lists, found by a tool and confirmed by a person:** a
  tool compares every word of a language with its offensive words twice,
  by sound (IPA) and by writing (the script and ISO 15919 letters), and
  lists the close pairs. A reviewer keeps the real ones, each with a note
  on what to take care of ("keep the long ā"), at most 40 letters, with
  the budget shown as you type ("30/40 letters"; owner, 2026-10-09): "sounds like" means care
  when speaking, "looks like" care when writing. The validator warns about
  a close pair left unexplained.
- **Without adult content on,** a learner meeting such a word sees the
  warning with the offensive word hidden: "Careful: said slightly wrong,
  this sounds like a rude word. Keep the long ā." The word itself shows
  only with adult content on.
- **When:** the format (the level, the gate, the two warnings, the tool)
  goes into the B1 format now; the Bengali and Telugu agents write the
  offensive decks and the warnings as part of their courses, shipping
  only once a speaker has reviewed them.

## Built: the adult gate (#628, owner, 2026-10-23)

With Adult content off, an adult deck is "Hidden everywhere": not listed,
not taught, and not in Today, reviews or practice; it comes back when the
setting is turned on. The setting is off by default. An adult deck is one
tagged `offensive`; a rude card is one tagged or registered `offensive`, and
one inside an ordinary deck follows the same rule. The sound-alike warning
still shows with the setting off, with the rude word hidden. The
`audience: adult` deck field, the per-profile 18+ confirmation, the
disclaimer and the child-profile rule are not built yet.

## Built: reviewer-only until rated (#630, owner, 2026-10-24)

> Merge, reviewer-only until rated

The offensive decks are written and merged now. A deck tagged `offensive`
whose words no native speaker has rated is **unrated**: no learner ever sees
it, with Adult content on or off. It is not listed, taught, in Today,
reviews, practice or search, and only the language's Offensive words review
lists it, where the raters score each word 1 to 9. Once the median of the
raters has set each word's band, the deck gains the deck tag **`rated`** and
follows the adult gate above.

How "rated" is written: as the deck tag `rated`, beside `offensive`
(`ratedTag` in `lib/core/decks/adult_gate.dart`). It is an ordinary tag, so no
new deck key and no new release is needed: an app that does not know it reads
the deck as before, and the validator rejects `rated` on a deck not tagged
`offensive`. The ratings themselves stay in the reviewers' files, sent by
mail; the tag is added by hand when they are in. The planned per-card `level`
(mild to strongest) is still not a card key: it is a new key, which released
apps reject, so the app must read it a release before decks use it
(`tools/pick_warning.py` waits for it as well). A released app that has the
adult gate but not this rule shows an unrated deck to a learner with Adult
content on; a deck should not be merged before the release that has the rule.

## Built: the sound-alike and look-alike tool (#629)

`tools/offensive_alikes.py <decks> [--language te] [--unexplained]` compares
each word of a language with its offensive words (a card registered or
tagged `offensive`, or in a deck tagged so), by IPA (at most one segment
apart) and by writing (the script, or the ISO 15919-based reading, at most
one letter or mark apart; a length mark or a dot is one), and prints the
close pairs for a reviewer. Words of fewer than three segments or letters
and pairs of two offensive words are left out. A kept pair is explained by a
`pair` note naming the offensive word by `ref` (sound), or a `lookalike` or
`homograph` note (writing), either on the word or on the offensive word. The
validator warns of a pair no note explains (a warning, never an error); a
pair a reviewer rejects has no way to be marked yet, so it keeps warning.

## Register rules deferred here (owner, 2026-10-15, #517)

> Defer both to the offensive-words work

Both are built when the offensive-words ratings live in the repo:
- **The validator check:** a card in the ratings must carry `register: "offensive"`.
- **Register on rules-table cells:** cells gain a `register` field.

See also: [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
