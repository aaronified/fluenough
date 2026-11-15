<!-- Design note for BN-033..BN-040, see Deck-Work-Queue-BN.md section 4.9 -->
# BN-032 design note: Bengali tense tables as rules tables (for BN-033 to BN-040)

Author: Sonnet deck designer, 2026-11-15. Append this to the notes of the BN-032 row of `wiki/Deck-Work-Queue-BN.md` (section 4.9) on main. The pilot, `bn-grammar-verb-past`, is on branch `decks/bn-tenses` (commit f71d3126): `decks/bn/bn-grammar-verb-past.yaml`, `decks/bn/en/bn-en-grammar-verb-past.yaml`, and the path edit. Nothing was run (no tests, no validator): CI is the first check.

## 1. What the pilot decided (all nine tables follow it)

- **Shape.** One `kind: "rules"` core + one English layer per tense, header and file layout exactly as `bn-grammar-verb-present` (copy the header block of `decks/bn/bn-grammar-verb-past.yaml`, change `id`). `applies_to: { pos: ["verb"], except: [the same 7 ids] }`. The 7 are the non-lemma verb cards of the present table: `bn-0251 bn-0291 bn-0306 bn-0322 bn-0696 bn-0697 bn-2330`; no tense table needs a different except list (see 6 for how to confirm). Rows: **the same 418 `word` ids, in the same order as `bn-grammar-verb-present`**. No `key`, no `ipas`, no `phonetic` (the present table has none; BN-065 does `phonetic`). Row count printed by the generator must equal 418 and 418 + 7 = the 425 verb cards of the course.
- **Slots** (permanent order; slot keys are quoted lower-case): six persons `["ami", "tui", "tumi", "apni", "se", "tini"]` for every table except the imperative (`["tui", "tumi", "apni"]`).
- **Rules: three per tense** (two is not used), ids `bn-rule-<tense>-first` (slot `ami`), `-second` (`tui`, `tumi`, `apni`), `-third` (`se`, `tini`); the imperative has ONE rule `bn-rule-imperative` (all three slots) and `bn-rule-imperative-<..>` is not used. Ids are unique in the language: checked, none of the new ones exists today (only `bn-rule-past-*` from the pilot). `<tense>` is the table's name below.
- **Layer.** `slot_name: "person"`; a label for every slot ("I or we, in the past", ... : `"<person>, in the <tense words>"`, copy the pilot's wording and change the tense words; no `{meaning}`); `rules:` name and explanation for every rule. The explanation quotes words only as `{1}`, `{2}` ... in the order of the core rule's `words` list, **every placeholder 1..N used, N = len(words)** (the pilot checked this with a small script: do the same). The rule `name` is `"<ending> (<reading>): <persons>"`, Bengali followed by its reading in half-width parentheses; the explanation and the description hold no Bengali letters outside placeholders. The description ends "Not yet checked by a Bengali speaker: please report any mistake."
- **Rule `words`** (core): `{ word, reading }`: the ending (`-লাম` / `-lām`), a full example with the pronoun (`আমি দেখলাম` / `āmi dekhlām`), the plural pronoun example for `first` (`আমরা ...`) and `third` (`তারা ...`), and the irregular stems that tense has (`যাওয়া` -> `গেলাম`). Readings from `python3 tools/transcribe.py bn "<text>" "<hint>"` (hint = how it is said, Latin; `sh` for শ ষ স when said `ś`).
- **Path.** Each new deck is added **after its pattern deck in the same unit's `decks` list, before any `"*"`**, and the unit's `grammar` list gains `<tense>`-first/second/third rule names (the topic of `bn-rule-x-y` is `x-y`); existing topics stay. Pilot diff: `["bn-calendar", "bn-grammar-past", "*"]` -> `["bn-calendar", "bn-grammar-past", "bn-grammar-verb-past", "*"]`, `grammar: ["past"]` -> `["past", "past-first", "past-second", "past-third"]`. Edit only those two lines; locate the unit by the pattern deck's id, never by number (units shift).
- **Additive only.** No existing id, card, pattern deck, set card (`bn-1447` ...), rule or file changes. Rules tables mint cell ids from `<core id>-<word number>-<slot index>`, so no `bn-5000` range id is used by BN-032..040. Do NOT edit `decks/index.json` (CI regenerates it on decks-live) or CHANGELOG (deck content stays out).

## 2. The nine tables: deck id, rule ids, unit, forms

Notation: S = past stem (the stem of the present `ami` form with its ending removed: `দেখি` -> `দেখ`, `লিখি` -> `লিখ`, `শুনি` -> `শুন`, `খাই` -> `খা`, `দাঁড়াই` -> `দাঁড়া`); the word applies to the last word of a multi-word verb only (`কাজ করি` -> prefix `কাজ ` kept). Vowel stems end in a vowel sign; irregular stems are in 3.

| Task | Deck id (`bn-grammar-verb-X`) / rules `bn-rule-X-first/second/third` | Insert after (in the path unit of) | Forms (ami / tui / tumi / apni / se / tini) |
|---|---|---|---|
| BN-032 pilot, DONE | `past` | `bn-grammar-past` | S+লাম / লি / লে / লেন / ল / লেন |
| BN-033 | `continuous` | `bn-grammar-continuous` | consonant S: S+ছি / ছিস / [ছো, ছ] / ছেন / ছে / ছেন (`করছি করছিস করছো করছ করছেন করছে`); vowel S: S+চ্ছি / চ্ছিস / [চ্ছো, চ্ছ] / চ্ছেন / চ্ছে / চ্ছেন (`যাচ্ছি`, `খাচ্ছে`); S+ছি uses the unchanged stem (`আসছি`, `লিখছি`) |
| BN-034 | `future` | `bn-grammar-future` | S+ব (shown first) and S+বো / বি / বে / বেন / বে / বেন: ami is a LIST `[করব, করবো]` |
| BN-035 | `perfect` | `bn-grammar-perfect` | consonant S: S+েছি / েছিস / [েছো, েছ] / েছেন / েছে / েছেন (`করেছি`, `দেখেছে`); vowel S (ā-stem, ো-stem): S with the final vowel sign turned into `ি` + `য়েছি...` (`দাঁড়িয়েছি`, `ঘুমিয়েছি`, `পাঠিয়েছি`, `বেরিয়েছি`) |
| BN-036 | `past-negative` | `bn-grammar-perfect` (same unit as perfect) | present form + নি: ami `করিনি`, tui `করিসনি`, tumi `[করোনি, করনি]` (vowel stems: one form `যাওনি`), apni `করেননি`, se `করেনি`, tini `করেননি`; vowel stems `যাইনি যাসনি যাওনি যাননি যায়নি যাননি`; this is the **present table's six forms + নি**, mechanical; readings by the tool |
| BN-037 | `past-continuous` | `bn-grammar-past-continuous` | continuous stem (BN-033) + ছিলাম / ছিলি / ছিলে / ছিলেন / ছিল / ছিলেন (`করছিলাম`, vowel S `যাচ্ছিলাম`) |
| BN-038 | `past-perfect` | `bn-grammar-past-more` | perfect stem (BN-035) + েছিলাম / েছিলি / েছিলে / েছিলেন / েছিল / েছিলেন (`করেছিলাম`, `খেয়েছিলাম`) |
| BN-039 | `habitual-past` | `bn-grammar-habitual-past` | S+তাম / তিস / তে / তেন / [তো, ত] / তেন; se is a list; irregular vowel-stem verbs change the stem (`যেতাম`, `খেতাম`, `পেতাম`, `দিতাম`, `নিতাম`, `হতাম`, `এলাম`->`আসতাম`) |
| BN-040 | `imperative` | `bn-grammar-imperatives` | **slots `["tui", "tumi", "apni"]`, one rule `bn-rule-imperative`.** tui = bare stem as the present tumi form minus its final ো / ও (`দেখো`->`দেখ`, `শোনো`->`শোন`, `লেখো`->`লেখ`, `খাও`->`খা`, `পাঠাও`->`পাঠা`); tumi = the present table's tumi form (`দেখো`); apni = the present table's `please` form (`দেখুন`). The imperative apni repeats the present table's `please` slot: kept (the pattern deck `bn-grammar-imperatives` teaches the three together), owner may drop it (open question OQ-1) |

Dependent tables reuse the **same stem derivation** as an earlier table, so the generator keeps one function `stem_forms(row)` and each tense is a small suffix table on top of it; for 036 the generator reads the present rows, for 037/038 it recomputes 033/035 stems, never reads another new deck.

## 3. Irregular stems (hand list; derived rows take them first)

By the verb word's present `ami` form (the key, last word). Everything else is regular.

- `যাই` (যাওয়া): past গে-, perfect [গিয়ে-, গে- (গেছি)], habitual যে-, future যা-, continuous যাচ্ছ-.
- `খাই`: past খে-, perfect খেয়ে-, habitual খে-. `পাই`: past পে-, perfect পেয়ে-, habitual পে-. `চাই`: past চাইলাম (stem চাই-), perfect চেয়ে-, habitual চাইতাম. `গাই`: past গাইলাম, perfect গেয়ে-, habitual গাইতাম.
- `দিই` (দেওয়া): past দি-, future ami `দেব`, tui `দিবি`, tumi `দেবে`, apni `দেবেন`; habitual দিতাম; perfect দিয়ে-. `নিই`: same with নি-/নেব/নিবি/নেবে; perfect নিয়ে-.
- `হই`: stem হ-: past হলাম, perfect হয়ে-, future হব, habitual হতাম, continuous হচ্ছি.
- `আসি`: past এলাম (এ-), perfect এসেছি (এসে-), habitual আসতাম, future আসব, continuous আসছি; imperative tui `আয়`, tumi `এসো` (NOT the present `আসো`), apni `আসুন`.
- `শুই`, `ধুই`, `ছুঁই` (stems শু-, ধু-, ছুঁ-): past শুলাম / ধুলাম / ছুঁলাম; perfect শুয়েছি / ধুয়েছি / ছুঁয়েছি; future শোব... (ami শোব/ধোব/ছোঁব, tui শুবি/ধুবি/ছুঁবি, tumi শোবে...): **list each of these three by hand in the report** and mark for the reviewer.
- A present `ami` ending in `ই` whose stem is a vowel sign is a vowel stem; ending in `ি` is a consonant stem.
- Present-table spelling quirks the generator must not copy: `ওঠি` (bn-2467 `গাড়িতে ওঠি`) -> stem `উঠ` (the pilot's `IRR` entry `ওঠি`); `ছুঁইস` (bn-2358 tui) is a present-table oddity, derive tui from the ami stem like the others. Wrong-looking source rows that were left as they are and reported (section 5): bn-4168 `ছোঁড়া`, bn-2789, bn-2793, bn-3351.
- Any form with no real equivalent (none found for the past) -> `null` in `forms`; never leave a slot empty, never invent; the row keeps >= 2 non-null forms.

## 4. Readings (exact procedure)

1. The reading of the **prefix words** (everything before the verb word) is copied from the present table's `ami` reading of the same row (the noun's reading as the course already writes it).
2. The reading of the **verb word** comes from the tool, never from the present reading (the present table's closed `o` in `kori` is vowel harmony that does not hold in other tenses, and three present rows carry wrong readings): `from transcribe import transcribe; transcribe(verb_word, "bn", hint).reading`. The hint is the Latin spelling of what is said: take the expected reading (stem reading + ending reading), fold it (`ś`/`ṣ`->`sh`, `ṭ`->`t`, `ḍ`->`d`, `ṛ`->`r`, `ṅ`->`ng`, `ñ`->`n`, `ā`->`a`, `ô`->`o`, `m̐`->`n`): a hint without `sh` makes the tool write `s` for স. Keep `m̐` for candrabindu as the tool writes it (the deck uses `dām̐ṛā`).
3. The generator compares the tool's reading with the expected one ignoring `o`/`ô`, prints every difference, and the report lists them. The pilot: 0 tool failures (`fitted` False never happened), 18 differences, all three are errors in the present table (`কমা`, `করা`, `খুঁজ`); the tool was right and was used.
4. Never write a reading by hand. A hand-listed irregular's reading comes from the tool the same way.

## 5. Generator (scratch, never committed; copy to the worker's scratch folder)

The pilot generator is below; BN-033..040 change only `SUF`, the irregular table and the stem function. It is guarded: each row in try/except, failures and differences printed to stderr and repeated in the report.

```python
#!/usr/bin/env python3
"""Scratch generator for decks/bn/bn-grammar-verb-past.yaml (BN-032 pilot).
Reads the present table (rows), derives the simple past of every row, writes
the core. Guarded: each row is in try/except, failures are printed."""
import sys, unicodedata, yaml
sys.path.insert(0, 'tools')
from transcribe import transcribe

WT = sys.argv[1]
present = yaml.safe_load(open(f'{WT}/decks/bn/bn-grammar-verb-present.yaml'))
tbl = present['table']
SLOTS = ["ami", "tui", "tumi", "apni", "se", "tini"]
SUF = {"ami": ("লাম", "lām"), "tui": ("লি", "li"), "tumi": ("লে", "le"),
       "apni": ("লেন", "len"), "se": ("ল", "lo"), "tini": ("লেন", "len")}
# irregular stems by the verb word's ami form: (bengali stem, reading stem)
IRR = {"ওঠি": ("উঠ", "uṭh"),   # present-table spelling quirk (bn-2467): past is উঠলাম
       "যাই": ("গে", "ge"), "খাই": ("খে", "khe"), "পাই": ("পে", "pe"),
       "দিই": ("দি", "di"), "নিই": ("নি", "ni"), "হই": ("হ", "hô"),
       "আসি": ("এ", "e"), "চাই": ("চাই", "cāi"), "গাই": ("গাই", "gāi")}
FOLD = [("ṭh","th"),("ḍh","dh"),("ś","sh"),("ṣ","sh"),("ṭ","t"),("ḍ","d"),("ṛ","r"),
        ("ṅ","ng"),("ñ","n"),("ṇ","n"),("ā","a"),("ī","i"),("ū","u"),("ô","o"),
        ("ê","e"),("m̐","n"),("ṁ","m")]
def fold(s):
    s = unicodedata.normalize("NFC", s)
    for a, b in FOLD: s = s.replace(a, b)
    return s

def stems(row):
    f, r = row['forms'], row['readings']
    ami, se = f['ami'].split(' '), f['se'].split(' ')
    rami, rse = r['ami'].split(' '), r['se'].split(' ')
    assert len(ami) == len(rami) == len(se) == len(rse), "token mismatch"
    v, rv = ami[-1], rami[-1]
    pre, rpre = ''.join(t + ' ' for t in ami[:-1]), ''.join(t + ' ' for t in rami[:-1])
    if v in IRR:  # keyed by the verb word's ami form
        s, rs = IRR[v]
    elif v.endswith('ই'):
        assert rv.endswith('i'), "reading"
        s, rs = v[:-1], rv[:-1]
    elif v.endswith('ি'):
        s = v[:-1]
        sv, rsv = se[-1], rse[-1]
        if sv.endswith('ে') and sv[:-1] == s and rsv.endswith('e'):
            rs = rsv[:-1]          # same letters: open vowels as in the se form
        else:
            assert rv.endswith('i'), "reading"
            rs = rv[:-1]           # stem changes (লিখ-, শুন-): the ami stem
    else:
        raise ValueError("unknown shape " + v)
    return pre, s, rpre, rs

rows, fails, mism, unfit = [], [], [], []
for row in tbl['rows']:
    try:
        pre, s, rpre, rs = stems(row)
        forms = {k: pre + s + SUF[k][0] for k in SLOTS}
        reads = {k: rpre + rs + SUF[k][1] for k in SLOTS}
        for k in SLOTS:                      # the verb word's reading is the tool's
            vtok = forms[k].split(' ')[-1]
            t = transcribe(vtok, 'bn', fold(rs + SUF[k][1]))
            if not t.fitted: unfit.append((row['word'], k, vtok, t.reading))
            comp = rs + SUF[k][1]
            if t.reading.replace('ô', 'o') != comp.replace('ô', 'o'):
                mism.append((row['word'], k, vtok, comp, t.reading))
            reads[k] = rpre + t.reading
        rows.append((row['word'], forms, reads))
    except Exception as e:
        fails.append((row['word'], repr(e)))
print("unfit", unfit[:20], len(unfit), file=sys.stderr)
print("rows", len(rows), "fails", fails, "mismatches", len(mism), file=sys.stderr)
for m in mism[:60]: print("MISMATCH", m, file=sys.stderr)

def q(s): return '"' + s + '"'
def obj(d): return '{ ' + ', '.join(f'{q(k)}: {q(v)}' for k, v in d.items()) + ' }'
out = []
if len(sys.argv) > 2:
    for w, f, r in rows:
        out.append(f'    - word: {q(w)}\n      forms: {obj(f)}\n      readings: {obj(r)}\n')
    open(sys.argv[2], 'w').write(''.join(out))
```

Output: `python3 gen_past.py <worktree> rows.txt`, then cat `header + rows.txt + footer` into `decks/bn/bn-grammar-verb-<tense>.yaml` (the header is the 12 lines of the pilot with `id` changed and `slots` adapted; the footer is the `rules:` block, written by hand for the three rules, readings from the tool).

## 6. Validator constraints (every builder reads before pushing; CI runs the validator)

- **Every verb of the course has a row or an `except` entry**: the validator takes every `pos: "verb"` card a B1 deck teaches. The row ids = the present table's rows; the builder prints `len(rows)` and `len(except)` and checks 418 + 7 against `grep -c 'pos: "verb"'` over the cores (done by script on the YAML, never the validator). A new verb card added later owes a row in all nine tables (rule in section 3.1 of the page), and BN-033..040 must merge **before** any task adds a verb (none does).
- Rows: `word` is a verb card id, not a phrasebook card, not in `except`, with a reading; `readings` has an entry for every slot whose form is not null. **A slot whose form is a list has a list of readings of the same length, in the same order** (`"tumi": ["করেছো", "করেছ"]` with `"tumi": ["kôrecho", "kôreche"]`; `check_pattern_readings` in `tools/validate_decks.py` takes a reading or a list of non-empty strings, and the pattern deck `bn-grammar-perfect` shows the shape). The pilot has no list slots; the perfect, continuous, future, habitual-past and past-negative tables do. The first form of a list is the one shown. Perfect and continuous readings write `ছ` as `ch` (`kôrechi`, `kôrchi`).
- Rules: every slot belongs to exactly one rule; `id` `bn-rule-[a-z0-9]+(-[a-z0-9]+)*`; `words` objects `{ word, reading }` only (no `ipa` needed).
- Layer: label for every core slot, no unknown placeholder, a name and an explanation for every rule (a missing rule is "not taught"), placeholders `{1}..{N}` counted from 1 with no leading zeros, every Bengali word in `name`, `description`, labels followed by its reading in half-width parentheses.
- YAML: quote every scalar except whole numbers and booleans; slot keys quoted; two-space indent; the `words:` flow lists on one line are fine.
- Path: the new id appears in the path unit once; a grammar topic is the rule id minus `bn-rule-`.
- Card ids are permanent: no existing id changes; nothing is removed; only the six listed files per task are touched (core, layer, `bn-path.yaml` on the two lines).

## 7. Task checklist for a Haiku worker (BN-033 to BN-040)

1. New worktree from `origin/decks-live`; merge `origin/decks/bn-tenses` (it has the pilot, this design and the path edits of the earlier workers); branch `decks/bn-tenses` (shared, rule 17).
2. Copy the generator, change `SUF`, `IRR` and the stem function for the tense (section 2 and 3); run it; read the printed differences; list every hand exception.
3. Write core (header, rows, rules), layer, path edit; check by a script (not the validator): 418 rows, same word order as the present table, every slot filled, every placeholder used, no Bengali in prose outside placeholders and readings.
4. Commit small, merge `origin/decks-live`, push fast-forward to `origin/decks/bn-tenses`; never open a PR (the architect opens one for the branch); never run tests or the validator.
5. Report: row count, except count, the irregular list, the tool-vs-expected differences, anything unclear (stop and report, never improvise).

## 8. Reviewer queue and questions

- **Rows for `docs/review-queue/bn.md` (BN-066):** present-table readings `bn-2789 কমাই` (`kamā-`, tool `kômā-`), `bn-2793 করাই` (`karā-`, tool `kôrā-`), `bn-3351 খুঁজি` (`khuñj-`, tool `khum̐j-`); spelling `bn-2467 গাড়িতে ওঠি` (should be `উঠি`) and `bn-4168 ছোঁড়ি` (standard `ছুঁড়ি`; the pilot follows the present table: `ছোঁড়লাম`) , `bn-4169` `পোঁছি` (check `পোঁছা`/`মোছা`), `bn-2358 ছুঁইস` (tui). Past forms of the three `পৌঁছ-` and `জিজ্ঞেস করি` rows follow the present table's spelling. Not fixed here: card ids and existing rows are permanent, and these need a bilingual reviewer.
- **OQ-1 (default taken):** imperative table keeps `apni`, repeating the present table's `please`. Owner may drop it (then slots `["tui", "tumi"]`).
- **OQ-2 (default taken):** no set cards (`kind: "set"`, rule + verb) for the new tables; the present table has 27 in `bn-verbs.yaml`. They would need ids from `bn-5000..`; add only if the owner wants them.
- **OQ-3 (default taken):** negative imperatives (`করো না`, `কোরো না`) and the negative of the other tenses are not tables.
- Candidates not decided: whether the tui perfect/past forms of vowel stems accept the colloquial `গেছি` style beyond the one list for `যাই` (the pattern deck lists it; the table does too).
