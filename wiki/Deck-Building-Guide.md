# Deck building guide

Source of truth: this wiki page.

Deck content, one YAML file per deck, organised by language code.

```
decks/
  bn/  bn-first-words.yaml        a core: the Bengali side of a deck, for every learner
       en/  bn-en-first-words.yaml  its English layer; merged, they are the deck bn-en-first-words
       bn-en-reading-sahaj-path-1.yaml  a reading deck, single-file
       bn-script.yaml             how the script works: a core, with its English layer in en/
       bn-sounds.yaml             the sound contrasts: a core, with its English layer in en/
       bn-path.yaml               the order Bengali is taught in, from every language
  es/  es-core-100.yaml, en/es-en-core-100.yaml …
       es-path.yaml
  hi/  hi-first-words.yaml, en/hi-en-first-words.yaml …
       hi-path.yaml
  ja/  ja-en-hiragana.yaml        single-file; kept in the repository but not offered in the app for now
       ja-path.yaml
  te/  te-home.yaml, en/te-en-home.yaml …   not yet checked by a Telugu speaker
       te-path.yaml               the path, by core id, with Telugu's regions
  mr/  the same, for Marathi; not yet checked by a Marathi speaker
  kn/  the same, for Kannada; not yet checked by a Kannada speaker
  gu/  the same, for Gujarati; not yet checked by a Gujarati speaker
  as/  the same, for Assamese; not yet checked by an Assamese speaker
  themes.yaml                   the shared themes; the one file the app bundles
  index.json                    what the app downloads, written by tools/deck_index.py
```

**A deck may be a core and its layers.** The core,
`decks/<lang>/<lang>-<name>.yaml`, holds the language learnt; each layer,
`decks/<lang>/<native>/<lang>-<native>-<name>.yaml`, holds one native
language's meanings, notes and labels, and the two merged are the deck
`<lang>-<native>-<name>`. Every vocab and grammar deck is split
(`tools/split_deck.py` splits a single-file one) but Japanese's, which has
no B1 plan yet; reading decks stay one file. See "Core and layer files" in the format specification.

**Every deck is on its language's path.** `<lang>-path.yaml` lists the
language's decks in teaching order, in units, by core id (`te-home` for
`te-en-home`), once for every language it is taught from; each course reads
it through its own decks, and a unit with none of them is "Coming" for that
course. The validator fails a deck left off it. See "Paths" in the format
specification.

- Format specification: [Deck-Format](Deck-Format)
- How to contribute one: [Contributing](Contributing)

**The app downloads these files; it does not bundle them** (#210, ADR-0037).
`index.json` lists every language with its files, each with its size and
SHA-256, and the app reads it from `main` on GitHub. Only `themes.yaml`
ships inside the app. After a merge touching `decks/`, a workflow writes the
index again on main; do not run `tools/deck_index.py` or commit the index.
Validating a single deck or one language directory only checks what you
pointed it at. `decks/ja/` is left out of the index on purpose for now: it is
listed in `HIDDEN` in `tools/deck_index.py`, and still validated.

**Reviewers change these files too** (ADR-0038). A native speaker's
suggestion arrives as a `proposed` line on its card, written by the review
bot, and when enough other reviewers accept it the bot writes it into the
card and removes the line. Learners never see a proposal. Do not write or
edit one by hand; to overrule one, delete its line or change the field.
See "Proposals" in the format specification.

Validate before committing — CI runs exactly this:

```sh
python3 tools/validate_decks.py decks/
```

## Every language

- **An ISO 639-3 code on every language block.** `language` and `native` both
  carry `iso639_3` (`hin`, `spa`, `eng`) beside `code`. CI rejects a deck
  without one.
- **A facts file, `<code>-facts.yaml`, with at least 30 facts.** One fact about
  the language is shown each day, and 30 of them must be true whatever the
  learner's interface language. Facts that compare it with one interface
  language (say, how its s sounds differ from English) are extra and marked
  `contrast`. See "Facts files" in the format specification. CI checks a facts
  file when there is one; it does not yet require every language to have one.

## Decks no speaker has checked

Tag a deck `unreviewed` when no native speaker has checked it. The app then
says so on the deck's screen and asks speakers to report mistakes, and the
deck's `description` should say so too. The Telugu decks carry it (#39), and
so do the Marathi, Kannada, Gujarati and Assamese ones. Once a speaker has
checked a deck, tag it `reviewed` instead: a deck is one or the other, and a
file with a culture note must carry one of the two.

## Contributing a deck

Deck work follows [Deck-Format](Deck-Format). That file is
the guide: where a deck goes, how cards, ids and paths work, and what makes a
deck good. Agents building a deck use the `build-deck` skill at
[.claude/skills/build-deck/SKILL.md](https://github.com/aaronified/fluenough/blob/main/.claude/skills/build-deck/SKILL.md),
which itself follows DECK-FORMAT.md.

Whatever the format says, two things are yours to check as a contributor:

**You have the right to contribute the content under CC BY-SA 4.0.**
Wordlists taken from textbooks or commercial courses are not acceptable,
*even reworded*. Public domain frequency lists, Wiktionary (CC BY-SA 4.0),
counts from Wikipedia (CC BY-SA), Tatoeba (CC BY 2.0 FR) and your own work
are fine, and each item taken from outside names its source. The deck's
`license` field is `"CC-BY-SA-4.0"`; see
[Licensing deck content](Deck-Format#licensing-deck-content).

**Run the tools before you push** (see the checklist under
[Contributing](Contributing#before-opening-the-pull-request)): `python3 tools/deck_index.py`, then
`python3 tools/validate_decks.py decks/`. They need PyYAML
(`pip install pyyaml`). To turn a wordlist into a deck, use
`tools/import_csv.py` (see `tools/README.md`).

---

## For coding agents

The build steps for agents are in [build-deck](https://github.com/aaronified/fluenough/blob/main/.claude/skills/build-deck/SKILL.md). Deck work goes in larger pull requests: several units per branch, one review per pull request (owner, 2026-10-30).

See also: [Home](Home)
