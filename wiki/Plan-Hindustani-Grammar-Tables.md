# Plan: Hindustani grammar tables as rules decks (HI-094 to HI-099)

Status: design, written 2026-11-15 by a Sonnet designer. Nothing was built, run through the validator or tested; CI is the first check of every deck this plan produces. It answers the open items of [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md) section 3.6 ("A Sonnet designs the generator first"). The owner rule it serves (2026-10-23): Hindustani grammar tables are full tables covering every taught word, as Bengali's are; the parent session confirmed it in scope on 2026-11-15. The Bengali precedent is [Deck-Work-Queue-BN-Tenses](Deck-Work-Queue-BN-Tenses.md).

**Measured for this plan (2026-11-15, read-only, not committed):** `decks/hi` of `origin/decks-live` with PyYAML; the Wiktionary extract at `https://kaikki.org/dictionary/Hindi/kaikki.org-dictionary-Hindi.jsonl` (168,373,020 bytes, last modified 2026-10-30), downloaded through the proxy into a scratch folder; `tools/transcribe.py hi` from `origin/main`; the validator's rules-deck code on `origin/main`. Every number below says which of these it comes from. A number marked *unknown* was not measured.

## 0. Decisions in brief

| # | Decision | Default taken here | Who decides |
|---|---|---|---|
| D1 | Source of forms | **Hybrid:** generate by a reviewed rule set, verify every form against two oracles (the Wiktionary dump and the course's own hand-checked pattern decks), send disagreements to the review queue. Never copy the dump's table. | taken; owner may veto |
| D2 | Generator location | A **Hindustani-specific script in the worker's scratch folder**; only its output is committed (the Bengali way). The rule data and algorithm are specified on this page so any session can rebuild it. A **language-agnostic verifier** (`tools/rules_table_check.py`) is proposed as a separate shared-code issue (section 3) | parent files the issue |
| D3 | Perso-Arabic (Urdu) forms | **The table cannot carry them today** (section 1.5). v1 ships Devanagari forms only; a shared-code issue adds per-script row forms; the Urdu forms are a later pass | **owner**: accept a Devanagari-only v1? |
| D4 | Slots | One slot per **distinct form**, not per pronoun: 8 slots for the four tenses that carry an auxiliary, 4 for gender-number tenses (section 1.2). This is smaller than the "12 slots" of HI-095 | owner may ask for 12 |
| D5 | Scope | Rules cores for nouns, pronouns (two tables), adjectives, and ten verb tables. Causative, passive, reported speech, honorifics and the clause frames stay pattern decks (HI-099, section 4) | owner |
| D6 | Pre-task | A **part-of-speech audit** of the 258 cards with `pos: other` and 58 with none: real nouns, adjectives, a verb (हंसना) and the pronoun आप sit there and would be missed by `applies_to.pos` (section 1.6) | taken |
| D7 | Branch and PR target | One branch `decks/hi-grammar-tables`; the pull request targets `decks-live` (Deck-Work-Queue rule 5). `CLAUDE.md` says "main or `decks-next`" for deck PRs: the parent confirms which | parent |

## 1. The schema for Hindustani

### 1.1 What a rules deck is (from `wiki/Deck-Format.md`, "Rules decks", and `tools/validate_decks.py` `check_rules_core`)

A rules deck is a core `decks/hi/hi-grammar-<name>.yaml` (`kind: "rules"`, `part: "core"`) with a `table` and `rules`, plus one English layer `decks/hi/en/hi-en-grammar-<name>.yaml`. Facts the validator enforces and this plan relies on (read in the code, not assumed):

- A row has only `word`, `key`, `forms`, `readings`, `ipas` (`ROW_KEYS`). `applies_to` has only `pos`, `tags`, `except` (`APPLIES_KEYS`). **No `target_scripts`, no `phonetic`, no `source` on a row.**
- Slot keys match `[a-z0-9-]+`, start with a letter, are not `yes no on off true false y n` (`_is_key`). The existing pattern decks' slots (`"मैं (m)"`) are free text and cannot be reused as keys.
- `forms[slot]` is a string, a non-empty list of strings (first shown, all accepted, none repeated) or `null`; every slot must be present; **a row with every form null is an error**, so a word with no forms goes in `except`. A row with a single distinct form only warns.
- `readings` are required for a script that needs one (Devanagari does) and must match the filled slots; a reading under a null form is an error.
- Every vocab card of the language that a B1 deck teaches, of a part of speech in `applies_to.pos`, must have a row or be in `except` (`_check_rows`). A row's word must be a vocab card with a reading, not a phrasebook card, and not also in `except`. **So every table below must list every noun, verb, adjective or pronoun the course teaches, now and in future.**
- Cell ids are `<core id>-<row part>-<slot index>` (row part is the card number, `0777` for `hi-0777`). Reordering slots rewrites every id. **Slots are append-only.**
- A rule id is `hi-rule-<name>`, unique in the language across every rules core. None exists today in `decks/hi` (grep, decks-live).
- A layer gives `slot_name`, a label for **every** slot (placeholder `{meaning}` only), optional `prompts`, and `name` and `explanation` for each rule; the explanation quotes the core rule's `words` as `{1}`, `{2}` ... and every placeholder must be used (Bengali's pilot checked this with a small script; do the same).
- Cells are four-skill vocabulary cells; the questions are `grammarUnderstood` and `grammar` (Deck-Format, "Its cells").

### 1.2 The decks, slots and rules

All forms are Devanagari (the course's `script`). Slot keys are Latin: `main` (मैं), `tum`, `vah` (वह, also तू), `ham` (हम, also आप and वे), `m-sg` etc. for the gender-number tenses. Persons that share a form share a slot (D4): तू takes the `vah` form of the present, future and perfect (तू जाता है), आप and वे take the `ham` form (आप जाते हैं), so a separate slot would hold identical answers and make the "which meaning" question unanswerable. The layer's labels say so ("we; also you (आप) and they").

| Deck id (`hi-grammar-X`) | Applies to | Slots, in this permanent order | Rules (`hi-rule-...`) | Replaces / sits beside |
|---|---|---|---|---|
| `noun-forms` | noun | `pl`, `obl-sg`, `obl-pl` | `noun-plural` (pl), `noun-oblique-sg` (obl-sg), `noun-oblique-pl` (obl-pl) | pattern `hi-grammar-nouns` (8 entries), kept |
| `pronoun-forms` | pronoun (personal and demonstrative; possessives and indefinites in `except`) | `obl`, `ko`, `se`, `ne`, `ka` | `pronoun-oblique`, `pronoun-ko`, `pronoun-se`, `pronoun-ne`, `pronoun-ka` | pattern `hi-grammar-pronouns` (9 entries), kept |
| `possessive-forms` | pronoun (personal and demonstrative in `except`) | `fem`, `masc-obl` | `possessive-fem`, `possessive-masc-obl` | pattern `hi-grammar-possessives` (9), kept |
| `adjective-forms` | adj (indeclinable adjectives in `except`) | `fem`, `masc-obl` | `adjective-fem`, `adjective-masc-obl` | pattern `hi-grammar-adjectives` (6), kept |
| `verb-present` | verb | `main-m`, `main-f`, `tum-m`, `tum-f`, `vah-m`, `vah-f`, `ham-m`, `ham-f` | `present-first` (main-m, main-f), `present-second` (tum-*), `present-third` (vah-*), `present-plural` (ham-*) | pattern `hi-grammar-present` (3), kept |
| `verb-future` | verb | the same 8 | `future-first`, `-second`, `-third`, `-plural` | `hi-grammar-future` (2) |
| `verb-perfect` | verb | the same 8 | `perfect-...` four | `hi-grammar-perfect` (4) |
| `verb-continuous` | verb | the same 8 | `continuous-...` four | `hi-grammar-continuous` (2) |
| `verb-past` | verb | `m-sg`, `f-sg`, `m-pl`, `f-pl` | `past-masc` (m-sg, m-pl), `past-fem` (f-sg, f-pl) | `hi-grammar-past` (3) |
| `verb-habitual-past` | verb | the same 4 | `habitual-past-masc`, `-fem` | `hi-grammar-habitual-past` (211) |
| `verb-past-continuous` | verb | the same 4 | `past-continuous-masc`, `-fem` | `hi-grammar-past-continuous` (82) |
| `verb-conditional` | verb | the same 4 | `conditional-masc`, `-fem` | `hi-grammar-conditional` (176) |
| `verb-subjunctive` | verb | `main`, `tum`, `vah`, `ham` | `subjunctive-first`, `-second`, `-third`, `-plural` | `hi-grammar-subjunctive` (176) |
| `verb-imperative` | verb | `tu`, `tum`, `aap`, `mat-tum` | one rule `imperative` | `hi-grammar-imperatives` (77) |

Choices behind the table, each reversible only before merge (slot order is permanent after):

- **Nouns.** `pl` is the direct plural, `obl-sg` the singular before a postposition, `obl-pl` the plural before a postposition: the three slots of the existing pattern deck and of HI-094. **No vocative in v1** (it would be `null` for about nine nouns in ten; Wikipedia's "Hindustani grammar" lists it, so it can be appended later as `voc-sg`, `voc-pl` without moving an id).
- **Verbs.** The auxiliary forms follow the course's own decks: present `जाता हूँ / जाते हो / जाता है / जाते हैं`, future `जाऊँगा / जाओगे / जाएगा / जाएँगे`, perfect `आया हूँ`, continuous `कर रहा हूँ`. A form with an auxiliary is a multi-word string, as Bengali's `জল থেকে`; readings are word by word (section 1.4).
- **Feminine plural, no auxiliary.** The conditional and the habitual past write `-तीं`/`थीं`; the existing pattern decks write `उठती` for the plural conditional. The new row gives a list `["उठतीं", "उठती"]` (first shown, both accepted), so no existing answer is lost. The reviewer queue gets one unit-level row.
- **Imperative.** `mat-tum` ("मत उठो") repeats the `tum` form after a particle; kept because the pattern deck teaches it. It may be dropped (Bengali's OQ-1 was the same question for its `please` slot).
- **Conjunctive (-कर/-के), purpose, before-after, while.** These are fixed frames on every verb. They stay pattern decks in v1 and are completed to 230 verbs in HI-096c as a low-priority tail (they have no irregular forms to review).

### 1.3 Example rows

Cards used: nouns `hi-0421` कमरा (m), `hi-1095` किताब (f), `hi-0192` घर (m); verbs `hi-0777` जाना, `hi-0779` करना, `hi-0785` देना; adjectives `hi-0898` अच्छा, `hi-0894` बड़ा. Readings are what `tools/transcribe.py hi` returned today with a typed hint (run 2026-11-15); forms are what the rules of section 2 give. These are illustrations of the shape, not checked data: the workers' output is checked by CI and the reviewers.

`decks/hi/hi-grammar-noun-forms.yaml` (header as `hi-grammar-nouns` plus `kind: "rules"`; `authors` and `tags: ["grammar", "unreviewed"]` as Bengali's):

```yaml
table:
  applies_to:
    pos: ["noun"]
    except: ["hi-0383", "hi-0595"]   # illustrative: a plural-only noun, an indeclinable; the real list comes from the audit
  slots: ["pl", "obl-sg", "obl-pl"]
  rows:
    - word: "hi-0421"
      forms: { "pl": "कमरे", "obl-sg": "कमरे", "obl-pl": "कमरों" }
      readings: { "pl": "kamrē", "obl-sg": "kamrē", "obl-pl": "kamrōm̐" }
    - word: "hi-1095"
      forms: { "pl": "किताबें", "obl-sg": "किताब", "obl-pl": "किताबों" }
      readings: { "pl": "kitābēm̐", "obl-sg": "kitāb", "obl-pl": "kitābōm̐" }
    - word: "hi-0192"
      forms: { "pl": "घर", "obl-sg": "घर", "obl-pl": "घरों" }
      readings: { "pl": "ghar", "obl-sg": "ghar", "obl-pl": "gharōm̐" }
```

The third row has two equal forms (`pl` and `obl-sg` are `घर`); that is correct Hindustani, and the validator only warns when **every** form of a row is the same.

`decks/hi/hi-grammar-verb-present.yaml` (3 of 230 rows; the `ham-*` slots serve आप and वे too):

```yaml
table:
  applies_to:
    pos: ["verb"]
    except: ["hi-0240", "hi-0273", "hi-0290", "hi-0460"]   # the four inflected-form cards: दीजिए चलिए मुड़िए चाहिए
  slots: ["main-m", "main-f", "tum-m", "tum-f", "vah-m", "vah-f", "ham-m", "ham-f"]
  rows:
    - word: "hi-0777"
      forms: { "main-m": "जाता हूँ", "main-f": "जाती हूँ", "tum-m": "जाते हो", "tum-f": "जाती हो", "vah-m": "जाता है", "vah-f": "जाती है", "ham-m": "जाते हैं", "ham-f": "जाती हैं" }
      readings: { "main-m": "jātā hūm̐", "main-f": "jātī hūm̐", "tum-m": "jātē hō", "tum-f": "jātī hō", "vah-m": "jātā hai", "vah-f": "jātī hai", "ham-m": "jātē haim̐", "ham-f": "jātī haim̐" }
    - word: "hi-0779"
      forms: { "main-m": "करता हूँ", "main-f": "करती हूँ", "tum-m": "करते हो", "tum-f": "करती हो", "vah-m": "करता है", "vah-f": "करती है", "ham-m": "करते हैं", "ham-f": "करती हैं" }
    - word: "hi-0785"
      forms: { "main-m": "देता हूँ", "main-f": "देती हूँ", "tum-m": "देते हो", "tum-f": "देती हो", "vah-m": "देता है", "vah-f": "देती है", "ham-m": "देते हैं", "ham-f": "देती हैं" }
```

(`readings` of the second and third rows are written by the tool in the real file; they are left out here only to keep the page short.)

`verb-past`, the irregular perfective (the generator takes these from the irregular list, section 2.4): `hi-0785` देना gives `{ "m-sg": "दिया", "f-sg": "दी", "m-pl": "दिए", "f-pl": "दीं" }`, readings `diyā`, `dī`, `diē`, `dīm̐` (tool). `hi-0777` जाना gives `गया`, `गई`, `गए`, `गईं`. `hi-0779` करना gives `किया`, `की`, `किए`, `कीं`. The imperative row of करना is `{ "tu": "कर", "tum": "करो", "aap": "कीजिए", "mat-tum": "मत करो" }`: the polite form is the irregular `कीजिए` (existing `hi-grammar-imperatives` has it).

`decks/hi/hi-grammar-adjective-forms.yaml` (only adjectives that agree: the ā-stem ones):

```yaml
table:
  applies_to:
    pos: ["adj"]
    except: ["hi-0916"]   # लाल is one of about 120 indeclinable adjectives; the real list comes from section 2.5
  slots: ["fem", "masc-obl"]
  rows:
    - word: "hi-0898"
      forms: { "fem": "अच्छी", "masc-obl": "अच्छे" }
      readings: { "fem": "acchī", "masc-obl": "acchē" }
    - word: "hi-0894"
      forms: { "fem": "बड़ी", "masc-obl": "बड़े" }
      readings: { "fem": "baṛī", "masc-obl": "baṛē" }
```

`fem` is the form with a feminine noun, whatever its number or case; `masc-obl` is the masculine plural and the masculine before a postposition. These are the two slots of the existing `hi-grammar-adjectives`. Both cards already carry the same forms in their `forms` list (kind `feminine`, `plural`), which is a third oracle for the 22 adjectives that have them.

### 1.4 Readings and IPA

- **Readings only from the tool.** `tools/transcribe.py hi` (`transcribe(text, "hi", hint)`, `.reading`, `.fitted`) writes ISO 15919-based letters as the course's cards do (`jātā`, `haim̐`, `kamrōm̐`). It needs a hint (the word as typed in Latin letters) and says "the hint did not fit the letters; the rules were used" when it does not fit. In a trial today a multi-word string (`जाता हूँ` with hint `jaata hoon`) did not fit, so **transcribe word by word and join with a space**: participle and auxiliary are separate calls, each with its own hint.
- **Where the hint comes from.** The generator builds the expected reading from the card's own `reading` (stem reading = the lemma's reading without `-nā`, e.g. `jānā` gives `jā`) plus the ending's reading from a small table, folds it to a Latin hint as Bengali's section 4 did (`ā` to `aa`, `ū` to `oo`, `ṭ ḍ ṛ` to `t d r`, `ṅ ñ m̐` to `n`, `ś ṣ` to `sh`), calls the tool, and **compares the tool's reading with the expected one**. The tool's reading is what is written. A difference is printed and listed in the report (and in the review queue when it is not just `o`/`ō`).
- **Known tool behaviour to expect, not to fix by hand.** The tool wrote `karēṅgī` for करेंगी and `jāēm̐gē` for जाएँगे (a nasal before ग is `ṅ` in one and `m̐` in the other, as the deck's existing future entries also have it). One unit-level review-queue row asks whether this is intended. The wiki rule for Telugu (word-final anusvara as `ṁ`) is Telugu's, not Hindustani's.
- **`ipas`: not written.** A row may give `ipas`, but the Bengali tables have none and a row cannot carry `phonetic`. Leave both out; the broad IPA of each word is already on its card. The narrow `[ ]` forms belong to [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology.md) and would need a row-level field (shared code, not part of this plan).

### 1.5 Perso-Arabic (Urdu) forms

**What the validator allows.** `target_scripts` is a card field (Deck-Format "A card's other scripts") and the validator checks it only on cards and on examples. `ROW_KEYS` has no `target_scripts`, and the app's row model (`lib/core/models/rule.dart`) has `readings` and `ipas` but no scripts. A row with `target_scripts` is an `unknown field` error. So **a rules table carries one script: Devanagari.**

**v1 decision.** Ship Devanagari tables. An Urdu learner sees Devanagari forms in these cells, with the Latin reading, exactly as the existing hand-picked grammar decks do today (their `forms` are Devanagari only too), so v1 is not a regression. State it in each layer's `description`.

**Follow-up (shared code, filed through the parent, blocks nothing in v1).** "Rules rows: per-script forms." Proposed shape, in the card's own idiom:

```yaml
- word: "hi-0421"
  forms: { "pl": "कमरे", ... }
  readings: { ... }
  target_scripts:
    perso_arabic: { "pl": "کمرے", "obl-sg": "کمرے", "obl-pl": "کمروں" }
```

Validator: the script must be in the language's `scripts`; each value is a form, a list or `null` exactly where the Devanagari one is; letters checked by `_check_target_scripts`. The app must read and show it by the learner's script setting. **A released parser rejects unknown fields** (Deck-Format, `phonetic` note), so the decks cannot carry the field until a release that reads it is out. That ordering (code, release, then data) is the work of the shared-code issue, not of this branch.

**How the Urdu forms will be made.** Not by transliterating Devanagari (ambiguous: ज़ is ز ذ ض ظ). By the card's own `target_scripts.perso_arabic` (2,271 of 3,443 own cards have one): Urdu stem plus the Urdu ending of the same rule, for example `کتاب` + `وں`, `لڑک` + `ے`. The ending table is small (about 40 entries) and is added to the generator in a second pass; the dump gives an Urdu spelling only for the headword, so it is no oracle for inflected Urdu forms (measured: the `Urdu` tag appears once per entry, on the lemma).

### 1.6 Which words are rows: part-of-speech audit first (D6)

`applies_to.pos` picks rows by a card's `pos`, and a card whose `pos` is wrong is silently outside every table. Counts from `decks/hi` on decks-live (top-level core cards with an `id` and a `target`): noun 1,253, verb 234, adj 186, pronoun 16 (the audit's 1,245, 232, 181 and 16 were counted another way; use these, they are what the validator will see). **258 cards have `pos: other` and 58 have none.** Most are letters, sounds and numbers (`hi-numbers-big` 85, `hi-phonology-consonants` 42 ...), but the same list holds real words that belong in a table: `आप` (`hi-0134`, a pronoun, in `hi-first-words`), `क्या` and `कौन` (pronouns), `कितना`, `हंसना` (`hi-0623`, a verb, in `hi-spelling`), `प्रश्न` `उत्तर` `प्रयोग` `समय` `सहायता` `प्रतीक्षा` (nouns), `आवश्यक` `कठिन` `सरल` (adjectives). **HI-094a** lists every card with `pos` of `other` or none that is a word of the four kinds (a Haiku reads the 316 targets, no guessing: it marks a card only where the card's own meaning in its English layer says what it is), and sets `pos` on them. This edits core files owned by other decks (a one-line `pos:` change each; ids and every other field untouched). **Unknown:** how many of the 316 are real words (a skim suggests about 30 to 40). **Owner decision folded in:** whether interrogatives `क्या` `कौन` become `pronoun` (then they need a row in the pronoun table or `except`; the plan puts them in `except`, as indefinites without a case paradigm).

## 2. Where the forms come from

### 2.1 What the Wiktionary dump gives (measured)

The dump is Wiktextract's JSONL. A Hindi entry has `forms` generated from Wiktionary's own templates: nouns from `hi-ndecl`, adjectives from `hi-adecl`, verbs from `hi-conj`. Each form carries tags (`direct`, `oblique`, `singular`, `plural`, `vocative`, `masculine`, `feminine`, `habitual`, `perfective`, `future`, `subjunctive`, `imperative` ...). The entry names its template (`inflection_templates`) and class (`cons-stem`, `ā-stem`, `ī-stem` ...). Against the 1,253 / 234 / 186 / 16 cards (matched by headword and part of speech):

| Kind | Cards with a template table in the dump | Without | What "without" means |
|---|---|---|---|
| noun | 1,082 | 171 | loanwords and compounds (प्लास्टर, इंजेक्शन, ड्राइवर, पोंछा ...), months, plural-only nouns |
| verb | 226 | 8 | the 4 inflected-form cards (दीजिए चलिए मुड़िए चाहिए) and 4 lemmas (चमकाना झूलाना झुंझलाना चहचहाना) |
| adjective | 64 | 122 | mostly the **indeclinable** adjectives: the entries' headword template carries `ind` |
| pronoun | 16 | 0 | tables exist for the possessives (`hi-adecl`) |

So the dump covers **about 85 percent of the words but is not complete**, and where it is silent for an adjective that silence is itself information (indeclinable, to be confirmed by the reviewer).

**The dump is not reliable enough to copy.** A prototype of a 30-line noun rule set (class by gender and final letter, section 2.3) agreed with the dump's direct plural, oblique singular and oblique plural for **971 of 1,056** nouns with a table (92 percent). Of the 85 disagreements (counted by category with a small script, and the first 45 read by eye; the counts are approximate): about 42 are rows where **the dump's plural equals the singular or is missing** while ordinary Hindi has an ending (feminine consonant nouns like पैंट, जैकेट, चॉकलेट, खाद, परिषद); about 21 are **masculine consonant nouns that the dump gives a feminine plural `-ें`** (किसान, पत्रकार, कलाकार, पतझड़, नाप, मटर: the template was run with a feminine gender or on a different homograph); a few are homograph mix-ups (तारा given `ताराएँ`) or Perso-Arabic broken plurals that the course does not teach (मसला with `मसाइल`, तारीख़ with `तवारीख़`); about 6 are Sanskrit agent nouns in `-ता` (नेता, विजेता, अभिनेता, मतदाता) that do not change in the plural (a real class the rules need); the rest are gaps in the prototype (a final independent ई as in सुई, मिठाई, सफ़ाई takes `-इयाँ`). **The first group and the second are mistakes in the dump; copying them would teach wrong Hindi.** For verbs the dump is verbose and overgenerates: it lists `होऊँगा`, `होएगा` beside `हूँगा`, `होगा`, mixes archaic `-ये` spellings with `-ए`, and its person tags are ambiguous (second and third person singular share a tag). It is good for **membership** ("is this form attested for this verb"), poor as a table to copy.

**Licence.** The dump's text is CC BY-SA 4.0. The committed forms are generated by rules and only *checked* against it, so no Wiktionary text is copied. Where an irregular's spelling is taken from the dump, say so in the deck's `description` ("checked against Wiktionary, CC BY-SA 4.0") and add the row to the Sources screen list if the owner wants it (the narrow-IPA line of 2026-10-30 is the model). **Unknown:** whether the owner wants an attribution line for check-only use.

### 2.2 The published grammars (the rule authority)

The rule set is written from, and cites in each deck's `description` and in the PR, the English Wikipedia article **"Hindustani grammar"** (fetched and read 2026-11-15; CC BY-SA): section "Nouns" (types I, II and III; its notes: *-y-* is inserted before a plural ending when the stem ends in a vowel; unmarked nouns in *-ū* and *-ī* shorten to *-u* and *-i* before the oblique plural, the latter inserting *y*; family nouns in *-ā* (पापा, चाचा, राजा) and Sanskrit feminine loans in *-ā* (भाषा, माता) do not follow the *-ā* rule), "Adjectives", "Pronouns" (oblique, dative `ko`, ergative `ne`, genitive), and "Verbs" (aspects; the perfective "displaying a number of irregularities"; "a very small number of irregular forms, spelled out"). The article cites Shapiro (2003), Snell and Weightman (1989), Kachru (2006) and McGregor (1987); workers do **not** quote those books and do not assert anything a page they read does not say. This is the same standing Bengali's plan gave Wikipedia's "Bengali grammar".

### 2.3 Recommendation and algorithm

**Recommended: the hybrid.** Rule-based generation owns the forms (so every taught word gets a row, and a rule set can be reviewed, versioned and rerun when a word is added). Two oracles check it. Disagreements are the work list, not silently resolved. Why not the dump alone: it is silent for about 15 percent of nouns and most adjectives, and wrong in the ways above. Why not rules alone: a generator checked only by its author repeats its author's blind spots; the dump caught the `-ता` class and the independent-vowel gap in the prototype.

**Oracles.**

1. **The dump** (`.cache/phonetic/kaikki.org-dictionary-Hindi.jsonl` via `tools/import_phonetic.py`'s `ensure_dump("hi")`, which uses the same URL; or `curl` into the scratch folder). Check by **membership**, never by tag: a generated form must appear among the `forms` of that verb or noun entry (any tag), after normalising only `ये`/`ए`, `यी`/`ई` (Wiktionary writes both, the course writes the short ones) and the chandrabindu/anusvara pair (`हैं`/`हैँ`). A form absent from the dump is a **disagreement**. Match the entry by headword and part of speech; where several entries of one pos exist (35 nouns have more than one table, e.g. लाल) prefer the entry whose head template gender equals the card's `gender`.
2. **The course's own pattern decks** (34 `kind: "grammar"` decks, hand-built and, where marked, reviewed): for every entry of `hi-grammar-nouns`, `-present`, `-future`, `-past`, `-perfect`, `-continuous`, `-subjunctive`, `-imperatives`, `-conditional`, `-habitual-past`, `-past-continuous`, `-adjectives`, `-pronouns`, `-possessives`, `-irregular`, the generated form for the same lemma and the same persons must equal the deck's form (except where a section 1.2 choice, such as the plural `-तीं`, differs on purpose; those are listed in the report). This is a regression oracle: of the 12-slot decks a worker maps each of the 12 slots to the 8 or 4 new ones by person and gender.

**Algorithm.** One function `stem_info(card)` and one small table per tense, as Bengali's design had. In Python, standard library plus PyYAML, no network except the optional dump read.

*Nouns (`noun-forms`).* Class by `(gender, final letter)` where `gender` is the card's field (16 nouns have none, mostly months and plural-only nouns: the generator skips them to `except` with a printed list). Spelling: the Devanagari join rule is the one non-obvious step. A suffix that begins with a vowel is written as a vowel sign after a consonant and as an independent vowel after a vowel sign or a vowel (`स` + `ु` + `ई` is `सुई`, plural `सुइयाँ`). Keep one function `attach(stem, vowel)` for it.

| Class | `pl` | `obl-sg` | `obl-pl` | Example |
|---|---|---|---|---|
| masculine in `ा`, unmarked list excluded | `ा` to `े` | same as `pl` | `ों` | कमरा: कमरे, कमरे, कमरों |
| masculine in `ा`, **unmarked list** (पापा, चाचा, राजा, दादा, नाना, मामा ...; the Sanskrit agent nouns in `ता`: नेता, विजेता, अभिनेता, मतदाता, संवाददाता, दाता) | unchanged | unchanged | `ाओं` for the agent nouns, `ाओं` or `ों` per the reviewer for the family nouns | नेता: नेता, नेता, नेताओं |
| masculine ending in a vowel sign plus independent `आ` (बटुआ) | `आ` to `ए` | same | `आ` to `ओं` | बटुए, बटुए, बटुओं |
| masculine consonant, `ि`, `ी` unmarked | unchanged | unchanged | `ों`; `ि`/`ी` become `ियों` | घर: घर, घर, घरों; चपरासी: चपरासी, चपरासी, चपरासियों |
| masculine in `ू`, `ु` | unchanged | unchanged | `ुओं` | पशु: पशु, पशु, पशुओं |
| feminine consonant | `+ें` | unchanged | `+ों` | किताब: किताबें, किताब, किताबों |
| feminine in `ी` | `ियाँ` | unchanged | `ियों` | कोहनी: कोहनियाँ, कोहनी, कोहनियों |
| feminine in independent `ई` (after a vowel) | `इयाँ` | unchanged | `इयों` | सुई: सुइयाँ, सुई, सुइयों |
| feminine in `ा`, `ँ`, `ू` | `+एँ`; `ँ` replaced; `ू` to `ू`+`एँ`, the oblique plural shortens to `ुओं` | unchanged | `+ओं` | माँ: माएँ, माँ, माओं |
| marked masculine nouns with nasalisation (कुआँ, गेहूँ) | per the **irregular list** | | | |

Anything the table does not decide (a final letter outside the classes, `gender` missing, a multi-word noun such as `हवाई अड्डा`, an abstract noun the dump marks as having no plural) is **not generated**: it is printed, put in the review queue, and either gets a hand-listed row from the irregular list or goes in `except`. Multi-word nouns: only the last word changes (`हवाई अड्डे`, as Bengali's compound verbs kept the prefix).

*Pronouns.* A closed list of 16 cards, written by hand from Wikipedia's "Pronouns" tables and verified against the dump (all 16 have tables) and the two pattern decks. `pronoun-forms` covers मैं तू तुम यह वह ये वे and gives the oblique stem (`मुझ`), the `ko` form (`मुझे`), the `se` form (`मुझसे`), the `ne` form (`मैंने`) and the genitive `ka` (`मेरा`); `आप` and `हम` join the table when D6 gives them `pos: pronoun`. The possessives मेरा तेरा तुम्हारा आपका हमारा उसका अपना go to `possessive-forms` (they decline as ā-stem adjectives). कोई and कुछ (indefinites, `kisī`/`kuch` in the oblique) are in `except` of both tables: they are the 2 cards with no case paradigm worth a table. The split is made with `except`, not tags, so no card is edited.

*Adjectives.* An ā-stem adjective declines (`अच्छा`: `fem` `अच्छी`, `masc-obl` `अच्छे`). Everything else is indeclinable and goes in `except`. The generator takes the ā-stem set from cards whose target ends in `ा` (73 of 186) **minus** the dump's indeclinable marking (`ind`) and a reviewed list of ā-ending words that do not decline (थोड़ा, सारा have no table in the dump; 9 ā-ending adjectives have no table; they are reported). The comparative frames (`ज़्यादा X`, `से X`, `सबसे X`) are not a table of forms; they stay in `hi-grammar-comparison` (8 entries) and are extended to every adjective in HI-097b only if the owner wants it (**unknown value, default no**).

*Verbs.* `stem = lemma minus ना`. All 230 `-ना` lemmas fall in six stem types (counted): consonant 160, `ा` 59, `ो` 7, `े` 2 (देना, लेना), `ी` 1 (पीना), `ू` 1 (छूना). The four non-`-ना` cards are inflected forms and go in `except`.

| Form | Consonant stem | `ा` `ो` `ू` stem | `े` stem (देना लेना) | `ी` stem (पीना) |
|---|---|---|---|---|
| habitual participle `-ता/ती/ते` | उठता | जाता, सोता, छूता | देता | पीता |
| subjunctive `main` | `ूँ` (करूँ) | `ऊँ` (जाऊँ, सोऊँ) | दूँ, लूँ | पीऊँ (see risks) |
| subjunctive `vah` | `े` (करे) | `ए` (जाए) | दे, ले | पिए |
| subjunctive `tum` | `ो` (करो) | `ओ` (जाओ) | दो, लो | पियो |
| subjunctive `ham` | `ें` (करें) | `एँ` (जाएँ) | दें, लें | पिएँ |
| future | subjunctive 1sg + `गा/गी`; `tum` + `ोगे/ोगी`; `vah` + `ेगा/ेगी`; `ham` + `ेंगे/ेंगी` | `ाओगे`, `ाएगा`, `ाएँगे` | दूँगा, दोगे, देगा, देंगे | पिऊँगा, पियोगे, पिएगा, पिएँगे |
| perfective `m-sg f-sg m-pl f-pl` | उठा उठी उठे उठीं | जाना: **irregular** (गया गई गए गईं); आना: आया आई आए आईं (stem + `या ई ए ईं`) | **irregular** | **irregular** |
| imperative `tu` / `tum` / `aap` | stem; subjunctive `tum`; stem + `िए` (उठिए) | stem; `ाओ`; stem + `इए` (जाइए, आइए) | दे, दो, **दीजिए** | पी, पियो, **पीजिए** |

The present is participle + `हूँ / हो / है / हैं`; the perfect is perfective + the same auxiliary; the continuous is stem + `रहा/रही/रहे/रही` + the same; the habitual past is the participle + `था/थी/थे/थीं`; the past continuous is the continuous participle + `था/थी/थे/थीं`; the conditional is the participle alone (`उठता, उठती, उठते, उठतीं`). The perfect and the continuous take the perfective and `रह-` forms from the `m-sg`, `f-sg`, `m-pl`, `f-pl` of the past table: **no tense reads another new deck; all derive from `stem_info`** (Bengali's rule).

### 2.4 The irregular lists

Hand lists, in the generator, each entry cited to Wikipedia "Hindustani grammar" "Verb forms" and confirmed by the dump and by `hi-grammar-irregular`:

- **Perfective:** करना (किया की किए कीं), देना (दिया दी दिए दीं), लेना (लिया ली लिए लीं), पीना (पिया पी पिए पीं), जाना (गया गई गए गईं), होना (हुआ हुई हुए हुईं), छूना (छुआ छुई छुए छुईं: confirm in the dump; **unknown** until read).
- **Polite imperative:** कीजिए (करना), दीजिए (देना), लीजिए (लेना), पीजिए (पीना); होना takes `होइए`; the dump also lists the rare `हूजिए`, not used.
- **Subjunctive and future of होना:** `हूँ हो हो हों` and future `हूँगा होगा होगे होंगे` (the dump's `होऊँगा`, `होएगा` are not used: they overgenerate). होना is also **in `except` of the subjunctive table only if the reviewers want the two subjunctives kept apart** (Wikipedia: honā is the one verb with distinct present and future subjunctive). Default: the present subjunctive.
- **Stem alternation before vowel endings** (`पीना` to `पि-`, `जीना`, `सीना`): only पीना is in the course (counted). The generator **stops with an alarm for any other `ी` or `ू` stem** not on the list, rather than guess.
- **Defective verbs:** चाहिए is a form card (excepted). The dump and the cards show no other verb the course teaches that lacks a tense; a verb a reviewer marks defective for a tense goes in that table's `except`, and **it is an open question whether the validator allows a different `except` per table: it does, since `except` is per table** (read in `check_rules_core`), so a defective verb costs one id in one list. The audit's "per-tense `except`" question (HI-094 Open) is answered: yes.

### 2.5 Disagreements, unknowns and indeclinables

Per word and form the generator records one of: **agree** (matches both oracles); **dump-only silent** (no dump table: written from rules and counted); **rules differ from the dump** (the dump has the entry and the form is not among its `forms`); **rules differ from a pattern deck**. Resolution, in this order, never by a worker's memory:

1. A disagreement with **only the dump** and **agree with a pattern deck**: the rules' form is kept. One summary row for the class in the review queue.
2. A disagreement with **the pattern deck** (a section 1.2 choice excepted): stop that word, put it in the review queue naming the card, both forms, the sources, and write the pattern deck's form. The pattern decks are the older reviewed data; the generator never overwrites them.
3. A disagreement with **both**: the word gets no row now, goes in `except` of that table with a review-queue row ("card, form from rules, form in the dump, question"). Nothing is guessed.
4. **Indeclinable and undefined words** (adjectives with `ind`, plural-only and uncountable nouns, defective verbs, loanwords with no stable plural): `applies_to.except` for the whole word. A word with some slots only gets `null` in the others (`forms` allows it: Bengali's `জল` has no plural). Default for an uncountable noun is `null` for `pl` and `obl-pl` only where the dump's table also has no plural; otherwise one unit-level review row lists the nouns whose plural is in doubt.
5. Every `except` id is a vocab card id of the language (the validator checks it); the generator prints the lists, and the report states the counts: rows, excepted, nulls, per table.

Review-queue rows go in `docs/review-queue/hi.md` (shape: `| card id | unit | question | raised by | date |`), written by the one task that owns it (HI-099 row below). `unit-level` rows for classes; a card id for a card.

## 3. Where the generator lives

**Recommendation: a Hindustani-specific script in the worker's scratch folder; only the output is committed.** The CLAUDE.md, Deck-Work-Queue and the Bengali tenses precedent all say a deck builder's script lives only in a session scratch folder. Reasons for not putting the generator in `tools/`:

- The owner's rule of 2026-11-14 is that **code must be language-agnostic and driven by per-language data**. The core of this generator (Devanagari joining, `ā`-stem classes, the verb stem types) is Hindustani logic; making it language-agnostic means a general inflection engine with a morpho-phonological join per script, which is a large shared-code project, not a deck task.
- The Bengali generator was handled this way and its design note carried the algorithm. This page carries the same: the class table, the irregular lists, the oracles and the checks are all specified (section 2), enough for a Haiku to write it, as Bengali's were.
- The generated YAML is the long-lived artefact; the validator already checks rows against the course, and CI checks the shape. What the script gives is rerunnability when a word is added (the rows rule makes every new noun, verb or adjective cost a row in every table). A new card's rows are then written by rerunning the scratch script (rebuilt from this page) or by hand from the same rules. **Risk, stated:** a lost scratch script means a rebuild from this page. HI-094 therefore keeps a copy of the final script text in the PR description under a `<details>` block (not in the repo).

**What is worth sharing (a separate issue, filed by the parent):** `tools/rules_table_check.py`, a **language-agnostic verifier**: reads a rules core, a Wiktextract JSONL (`import_phonetic.ensure_dump` already downloads it) and a per-language YAML `tools/data/rules_table_<lang>.yaml` that maps each slot to tag sets and a form normaliser, and prints every row/slot whose form is absent from the dump's `forms`. It is data driven (no Hindi in code), reusable for Bengali, Marathi, Assamese and Gujarati tables, and testable with a fixture of ten JSONL lines (`tools/test_rules_table_check.py`, standard library plus PyYAML, like `tools/test_import_wiktionary.py`). It does **not** generate forms. Until it exists, the worker's own scratch check does the membership test. **Unknown:** whether the other languages' tables want it (Bengali's design checked against the course's conjunctive table, not a dump); the parent decides whether it is worth the tokens.

No test is added to `tools/` by this plan (none of its work is in `tools/`). Nobody runs the validator or tests locally: CI does ("Validate decks", "Released app reads the decks").

## 4. Work breakdown

One branch `decks/hi-grammar-tables` (D7). Haiku workers; each task ends with a report that states counts, disagreements, excepted ids and review-queue rows (Deck-Work-Queue rules 1 and 8). One Sonnet review of the whole branch at the end (CLAUDE.md "Reviews"). Nobody runs the validator or tests locally.

### 4.1 Shared rules for every task here

- **Ids.** Rules tables mint cell ids themselves; **no new vocab id is planned.** The range `hi-6000` to `hi-6999` is free (highest id today `hi-5857`, grep over `decks/hi`; the course range ends at `hi-6999`) and is reserved for HI-094a: **only** if a lemma card turns out to be missing (for example a verb whose only card is an inflected form such as `मुड़ना`), a worker adds it from `hi-6000` ascending, never reused, and reports it. A range left unused stays unused.
- **Card ids and slot order are permanent.** Never edit an existing card's id, never reorder a table's `slots` or `rules`, never rename a rule id after it has merged. Existing pattern decks, cards and rules are untouched (**additive only**, as Bengali's: the only edits to existing files are the `pos:` lines of HI-094a and the path lines of 4.3).
- **Quote every YAML scalar** except `true`, `false` and whole numbers: slot keys, rule ids, `word` ids, forms, readings. A bare `no`, `on` or `y` as a slot key is a YAML 1.1 boolean: the slots here are `main-m`, `tu`, `fem` and so on, never those words. `null` is the only unquoted non-boolean (as the Bengali tables have it). Tag new files `"unreviewed"`; licence `CC-BY-SA-4.0`.
- **Readings by the tool, never by hand,** word by word (section 1.4). `ipas` and `phonetic` are not written.
- **Never edit** `decks/index.json` (CI regenerates it), `CHANGELOG.md` (deck content stays out of a release), `decks/min_app.json`, or another task's file.
- **A layer's text.** Each rule's `name` is `"<ending> (<reading>): <persons>"` (Bengali followed by its reading, here Devanagari followed by its reading in half-width parentheses); an explanation and a description hold no Devanagari outside placeholders; the words an explanation quotes are placeholders `{1}`...`{N}` in the order of the core rule's `words`, all of them used; labels have no placeholder but `{meaning}`; the description ends "Not yet checked by a Hindustani speaker: please report any mistake."
- **Path.** Each new deck is added after its pattern deck in the same unit's `decks` list, before any `"*"`, and the unit's `grammar` list gains the rule names without `hi-rule-` (`noun-plural`, `present-first` ...); existing topics stay. Locate the unit by the pattern deck's id, never by its number (units shift). Edit only those lines of `decks/hi/hi-path.yaml`; **the path file has exactly one owner per batch (HI-099b).**

### 4.2 Tasks

Sizes: S under 100 rows, M up to 250 rows or one table, L several tables. Each task owns its files; no other task edits them.

| Task | Size | What | Files it owns (creates) | Depends on |
|---|---|---|---|---|
| **HI-093b** (design check) | S | Haiku reads this page and the three oracles' availability: downloads the dump into a scratch folder and prints, per kind, the counts of section 2.1 against `decks/hi`; reports any card with `pos` of `other` or none that is a word (the HI-094a list). Builds nothing. | none (report) | none |
| **HI-094a** | S | Part-of-speech audit and fix (section 1.6): `pos:` lines only, in the cores that hold the 316 cards; reports each change with the evidence from the layer meaning; unclear cases go to the review queue. | the existing core files it touches (one `pos:` line per card) | HI-093b |
| **HI-094b** | M | The generator, scratch only: `stem_info`, `attach`, the class tables and irregular lists of section 2, the two oracles, the guarded per-row loop (each row in try/except, every failure logged and repeated in the report, rules 2 and 3), output of a `.yaml` row block and a disagreement report. Dry run: print the counts (rows, except, nulls, disagreements) for every table. | none committed (script text in the PR description) | HI-094a |
| **HI-094** | L | `hi-grammar-noun-forms` core and `hi-en-grammar-noun-forms` layer (1,253 minus the excepted; about 3 rules, 3 slots). Rule `words`: the endings `-ें`, `-ों`, a full example per rule, and the unmarked class. This is the largest table; it stays one core file, but a worker may write rows in two commits (the first 600, then the rest). | `decks/hi/hi-grammar-noun-forms.yaml`, `decks/hi/en/hi-en-grammar-noun-forms.yaml` | HI-094b |
| **HI-095a** | M | `hi-grammar-verb-present` (+layer), 4 rules, 8 slots, 230 rows. | the two files | HI-094b |
| **HI-095b** | M | `hi-grammar-verb-future` (+layer) | the two files | HI-094b |
| **HI-095c** | M | `hi-grammar-verb-past` (+layer), 4 slots, irregular perfectives from the list | the two files | HI-094b |
| **HI-095d** | M | `hi-grammar-verb-perfect` (+layer), 8 slots, from the past table's forms | the two files | HI-095c |
| **HI-095e** | M | `hi-grammar-verb-continuous` (+layer), 8 slots | the two files | HI-094b |
| **HI-096a** | M | `hi-grammar-verb-habitual-past`, `-past-continuous`, `-conditional` (+layers): 4 slots each | the six files | HI-095e, HI-095c |
| **HI-096b** | M | `hi-grammar-verb-subjunctive`, `-imperative` (+layers) | the four files | HI-094b |
| **HI-096c** | S, low priority | The clause frames to 230 verbs as rules cores, if the owner wants them: `-conjunctive` (`-कर`, `-के`), `-purpose`, `-before-after`, `-while` | eight files | HI-096b |
| **HI-097** | M | `hi-grammar-adjective-forms` (+layer, 2 slots, the ā-stem adjectives; every other adjective in `except`). The comparative stays `hi-grammar-comparison`. | the two files | HI-094b |
| **HI-098** | S | `hi-grammar-pronoun-forms` and `hi-grammar-possessive-forms` (+layers), by hand from section 2.3 and checked against the dump and pattern decks | the four files | HI-094a |
| **HI-099a** | S | The decision record (no deck): for causative (33 entries), passive (29), reported speech (3), honorifics (5), irregular (6), a one-line proposal each. Proposal here: **they stay pattern decks.** Causative needs a per-verb valid-causative list the dump does not give (it has no causatives) and a reviewer; passive needs transitivity data that no card has; reported speech and honorifics are not per-verb; `hi-grammar-irregular` is absorbed by the perfective and imperative tables. Report only. | none | none |
| **HI-099b** | S | **Path edit and review queue.** The one owner of `decks/hi/hi-path.yaml` and `docs/review-queue/hi.md` for this branch: places every new deck (4.3) and collects every task's review-queue rows. | those two files (edits) | all above |
| **HI-100** | S | A Haiku re-reads the generated rows against the three oracles one last time from the committed files (not the generator) and writes the final counts: rows, excepted, nulls, disagreements, per table, into the PR description. | none | HI-099b |

Order: HI-093b, HI-094a, HI-094b, then HI-094, HI-095a, HI-095b, HI-095c, HI-095e, HI-096b, HI-097, HI-098 in parallel (disjoint files), then HI-095d and HI-096a, then HI-099a, HI-099b, HI-100, then the Sonnet review, then the PR to `decks-live`. HI-096c only when the owner asks. Total cells at B1 (per layer, English): about 3,700 (nouns) + 4 tenses of 8 slots at 1,840 each + 6 tables of 4 at 920 each + the adjective and pronoun cells, about 17,000 in all. The audit's "about 2,800 per 12-slot tense" becomes 1,840 per 8-slot tense: a third fewer cells, with no duplicate answers.

### 4.3 Path placement (HI-099b)

From `hi-path.yaml` as read on decks-live: `noun-forms` after `hi-grammar-nouns` (the unit at line 150, grammar topic `nouns`); `pronoun-forms` after `hi-grammar-pronouns` and `possessive-forms` after `hi-grammar-possessives` (line 159 unit); `adjective-forms` after `hi-grammar-adjectives` (line 171); `verb-present` after `hi-grammar-present`; `verb-continuous` after `hi-grammar-continuous` (the unit that lists `hi-directions` ... `"*"`); `verb-future` after `hi-grammar-future`; `verb-past` after `hi-grammar-past` (in `hi-calendar` unit); `verb-perfect` after `hi-grammar-perfect`; `verb-past-continuous` after `hi-grammar-past-continuous`; `verb-imperative` after `hi-grammar-imperatives`; `verb-subjunctive` after `hi-grammar-subjunctive`; `verb-conditional` after `hi-grammar-conditional`; `verb-habitual-past` after `hi-grammar-habitual-past`. **Unknown:** whether the path's `words:` counts and any `"*"` placement need a change beyond adding the deck id; Bengali's pilot added only the id and the topics.

### 4.4 Validation traps (each is a CI failure to avoid)

- A new noun, verb, adjective or pronoun in any B1 deck of the course needs a row (or `except`) in **every** table of its kind in the same change. This branch must be rebased and its row lists refreshed against `decks-live` just before the pull request, because other waves add cards.
- `except` ids that are not cards, a word both a row and in `except`, or a phrasebook card as a row: errors.
- A row whose every form is `null`: error. A row whose every form is equal: warning only (not a CI failure).
- A reading under a `null` form, or a missing reading for a filled slot: error. A hint that did not fit: the tool falls back on rules; the worker reports it, and does not hand-edit.
- A rule with no slots, a slot in two rules, a slot in no rule: errors. Every slot of the 8-slot tables is in exactly one of four rules.
- Layer: a label for every slot; no `{...}` other than `{meaning}`; every `explanation` placeholder used; a rule id not in the core is an error.
- Rule ids are language-wide: `hi-rule-present-first` must not collide with a future one, and a `hi-rule-...` named in a sentence or a topic must exist.
- Quote scalars; the slot key `fem` or `tum-m` is fine, `y` or `no` is not.
- Card ids permanent: no existing card's id, pattern deck or entry key is touched (pattern `hi-grammar-nouns` keeps its cell ids: the new decks mint different ids).
- `lib/core` is not touched.

### 4.5 Risks

1. **The tool and the course disagree on a reading** (the `ṅ` versus `m̐` case above): the plan's answer is "the tool, and a review-queue row". If the owner wants one convention, that is a tool issue, not a deck fix.
2. **`पीऊँ` versus `पिऊँ`.** The existing subjunctive deck gives `पीऊँ` for the first person but `पिए पियो पिएँ` for the rest. Standard grammars write `पिऊँ`. The new table follows the pattern deck and queues the question; do not change the pattern deck.
3. **The class lists are incomplete for the long tail** (unmarked `-ा` nouns, Persian `-ा` masculines like बच्चा that decline normally, feminines in `-ा`): the generator reports every noun it cannot classify rather than guess; the first run's size is **unknown** (the prototype classified 1,056 of 1,082 table-bearing nouns by form alone and left about 26 for hand lists, and 171 nouns have no dump table to check against).
4. **Dump drift.** The dump is a snapshot (2026-10-30). A later dump may change forms; the committed decks do not depend on it.
5. **Size.** Noun-forms is the largest table the course has had (1,240 rows); CI time rises. The branch is one PR by the owner's rule 17, and a reviewer reads the report counts, not the rows.
6. **Double counting by homograph.** `कप` (`hi-0877`, `hi-2553`) is two cards with one form; each gets its row. `ठीक` is an adjective and an adverb: only the adjective card is a row.
7. **Urdu learners** see Devanagari in these cells until the shared-code follow-up lands and a release reads it.

### 4.6 What remains for the owner

- **D3:** accept Devanagari-only tables for now, and approve the shared-code issue for per-script row forms (and the wait for a release that reads it).
- **D4:** accept 8 and 4 distinct-form slots instead of 12.
- **D5:** confirm causative, passive, reported speech, honorifics and irregular stay pattern decks, and whether the clause frames (HI-096c) and the adjective comparative (HI-097b) are wanted.
- **D6:** whether `क्या` and `कौन` become pronouns, and attribution wording for the Wiktionary check.
- **Reviewers:** a bilingual reviewer settles the review-queue rows (the class summaries, the `ṅ`/`m̐` convention, `पीऊँ`, the feminine plural `-तीं`, the family nouns in `-ा`, uncountable nouns). Until then every table is tagged `"unreviewed"`.
- **The branch and the PR target (D7).**
