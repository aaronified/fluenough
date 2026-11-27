# Deck work queue: Korean A1 plan

Status (2026-11-26): owner order: "Resume the deck work". Scope is Korean (`ko`, tracker #379) to the A1 mark of `ko-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read Korean for Kannada, `ko` for `kn`, `iso639_3: "kor"`). The shape is that of [Deck-Work-Queue-SAT](Deck-Work-Queue-SAT.md), [Deck-Work-Queue-ML](Deck-Work-Queue-ML.md) and [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md).

State was read from `origin/decks-live` with PyYAML over every `decks/ko/**` file and `ko-path.yaml`, and from `origin/main`'s `tools/` and `assets/languages.yaml` (2026-11-26).

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `ko`, `iso639_3: kor`, script `hangul`, tts `ko-KR`, icon 한 |
| decks-live | 28 files in `decks/ko/`: `ko-phrasebook` (19 cards), `ko-first-words` (12), `ko-sound-differences` (16), `ko-questions` (16), `ko-addressing` (20), the three Hangul script decks (vowels 10, consonants 18, compound vowels 11), sentences decks for sound-differences, questions, addressing (6 each), three reading decks (no cards of their own), `ko-sounds` (kind `sounds`, 0 cards), their English layers, `ko-path.yaml`. 140 card ids in `ko-0001..ko-0158` |
| Path | 136 units: 1 to 7 built (phrasebook and first words, sound differences, questions, addressing, the three Hangul decks), 8 to 136 planned; `alphabet` lists the three Hangul decks; no facts file, no `docs/review-queue/ko.md` |
| A1 mark | unit 45 (`ko-help`, `milestone: A1`): 45 units; 38 still to build: 23 word units (about 730 planned words), 14 grammar units, 1 script unit (`ko-hangul-batchim`, unit 8) |
| Units to A1 | 8 batchim (script), 9 pronouns, 10 family, 11 numbers-1-20, 12 about-me, 13 everyday-verbs, 14 adverbs, 15 quantities, 16 describing, 17 time, 18 location, 19 more-verbs, 20 grammar sound-changes-1 (liaison, nasalisation), 21 copula, 22 topic-subject (은/는, 이/가), 23 object-place (을/를, 에, 에서), 24 haeyo-present, 25 negation, 26 isseoyo (있어요, 없어요), 27 demonstratives, 28 more-particles, 29 work, 30 numbers-big, 31 counters, 32 loanwords, 33 market, 34 groceries, 35 food, 36 past, 37 transport, 38 directions, 39 want (-고 싶어요), 40 body, 41 places, 42 home, 43 requests (-(으)세요, -아/어 주세요), 44 future (-(으)ㄹ 거예요, -(으)ㄹ까요), 45 help (A1) |
| Engine | `korean()` in `tools/transcribe.py` gives the Revised-Romanization reading only (liaison, nasalisation, ㄹ and ㅎ changes; tensing not written); **it returns an empty `ipa`**. No Korean card has a broad `ipa` (the build-deck skill's "no ipa in the existing Korean cards" predates the owner's 2026-10-30 rule). No `ko` entry in `tools/phonetic_languages.yaml`, no `decks/ko/ko-phonetics.yaml`, 0 `phonetic` on any card. So the engine is incomplete: KO-110 (a main PR) comes first |
| Readings | the 140 existing cards write RR as the engine does (spot-checked: `hangugeo`, `jota`, `gwaenchanta` bases); an example sentence's `bases[].reading` is the engine's reading of the dictionary form |
| Review queue | `docs/review-queue/ko.md` does not exist; created by KO-150 |
| Sources reachable | kaikki.org Korean dump (answers 200); en.wiktionary pages; ko.wiktionary; Wikimedia sites need a polite client and back-off. Nothing from an NC source (owner) |
| Licence | Wiktionary text is CC BY-SA 4.0 (compatible, one item per source) |

## 2. Findings that shape the plan

- **IPA is an engine job.** `ipa` and (later) `phonetic` are written by tools only (CLAUDE.md, owner 2026-10-30). KO-110 extends `korean()` with a broad phonemic `ipa` (Seoul standard; sources named in its docstring: Wikipedia "Korean phonology", Wiktionary's Korean pronunciation pages) and adds the `ko` registry entry (measured on the kaikki Korean dump: rules-only unless its forms agree with the broad `ipa`). The Korean cards that exist then get `ipa` in the same wave (patch the field only, no other edit, rule 8 of AGENTS.md).
- **Hangul script units.** Three are built; unit 8 `ko-hangul-batchim` (the seven final sounds and linking) is the last A1 script unit. Hanja are not taught (#379).
- **Stem-changing verbs** (크다/커요, 쓰다/써요, ㅂ/ㄷ/ㅅ/르 irregulars): the validator warns of them; a card whose base changes its stem says so in its note and names the base. Avoid in early units; the planned verb units are checked by their builder against the guide.
- **Polite -요 only.** haeyo-che is used through A1; formal and casual are A2.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry (kaikki Korean dump or the page). A gloss or reading written from memory is not allowed. A word with no readable source goes to `docs/review-queue/ko.md` as a shortfall, never invented. Example sentences use only taught words or the engine's bases, each word with a `bases` entry.
- **Grammar units** (particles, copula, -아/어요, negation, past, future, requests, counters): taught from sources read to the page (Wikipedia and Wiktionary appendices; the public-domain grammars of Ross and Underwood/Gale are not needed for A1). A table row that cannot be checked is left out and queued.

## 3. Task table

Ids (never reused, ascending inside a task; highest in use `ko-0158`): script `ko-1000..1299`, grammar words `ko-0400..0999`, new vocab `ko-1300..2999`, sentences `ko-3000..3999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| KO-110 | Sonnet | `tools/ko-transcribe` (main) | broad `ipa` in `korean()` with tests, the `ko` registry entry; check against the existing 140 cards; a disagreement is a review-queue row, never a silent edit |
| KO-050 | Haiku | none (a report) | candidate words per planned A1 theme from the kaikki Korean dump (gloss, part of speech, polite form); shortfalls named |
| KO-070 | Haiku | `decks/ko-a1-wave1` | `ko-hangul-batchim` script deck and layer; path `alphabet` and unit 8 edit |
| KO-100.. | Haiku (Sonnet specs the tables) | `decks/ko-a1-wave1` | the 14 grammar units and 22 word units, with layers; path entries move from `planned` to `decks` in the same commit |
| KO-130.. | Haiku | `decks/ko-a1-wave1` | sentences decks for word units with enough taught words |
| KO-140 | Haiku | `decks/ko-a1-wave1` | `ipa` patched onto the 140 existing cards (after KO-110 merges) |
| KO-150 | Haiku | rides on the wave | `docs/review-queue/ko.md` rows for every uncertain card |
| KO-160 | Sonnet | `decks/ko-phonetics-wave1` | `ko-phonetics.yaml`, `derive_phonetic.py ko --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-26: audit done, this page written.

Merged, each with CI green and one Sonnet review: #1738 (KO-110: `korean()` returns a broad `ipa`, `ko` registered rules-only, on main); #1739 on decks-live (batchim script deck, 23 word units with sentences decks, 30 grammar decks for the 14 grammar units, broad `ipa` on the 140 existing cards with 6 reading typo fixes, `docs/review-queue/ko.md`, `loanwords` theme); #1749 on decks-live (`ko-phonetics.yaml`, 26 rules, `phonetic` on 993 cards).

## 5. Final state, 2026-11-27

A1 stops here by the owner's order: path units 1 to 45 are all written (45 of 45); 995 cards in `decks/ko`, about 790 of them word cards, 30 grammar decks, `ipa` and `phonetic` on 993. Word units are under their planned sizes where the Wiktionary extract, duplicate cards across units or untaught example words limited them (pronouns 10 of 20, work 24 of 35, loanwords 21 of 30, numbers-big 19 of 35); no card is written from memory.

Left for the owner and later work:

- Korean speaker review of `docs/review-queue/ko.md`; a Korean phonetician for the narrow rules (ㅎ allophones, aspirated initial ㅅ, ɐ for ㅏ).
- Engine gap in `tools/transcribe.py` (a main PR): a coda ㅅ ㅆ ㅈ ㅊ ㅌ ㅍ ㄲ ㅋ before ㅎ is written as plain k/t/p + h in the broad `ipa` (따뜻하다); 값 reads `gapt`, 색깔 `saekkkal`; ㄼ in 밟다. The narrow rule repairs the narrow form only.
- Built decks (`ko-first-words` and others) still use 좋다, 뜨겁다, 차갑다 and similar as plain bases though they are now cards; the Sino-Korean 이, 사, 오, 팔 are not taught as number cards (they collide with existing syllable cards), so 십오 and 십팔 lack their unit digits; 어제, 두세, 한두 and the Sino numerals 일 to 이십 have no examples (no counters or past tense taught yet); 112 and 119 emergency numbers need a read source.
- No facts file, no genre decks, no A2/B1 (not in scope).
