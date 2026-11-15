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
| BN-035 | `perfect` | `bn-grammar-perfect` | **perfect = the course's conjunctive form (`bn-grammar-conjunctive`, slot `conjunctive`, last word of the verb) + ending, with the 11 corrections of 3.1.** Endings: ami ছি / tui ছিস / tumi list [ছো, ছ] / apni ছেন / se ছে / tini ছেন (`করে`->`করেছি`, `জেনে`->`জেনেছি`, `খেয়ে`->`খেয়েছি`, `এসে`->`এসেছি`). Do NOT derive it as stem+েছি: that is wrong for 70 verbs (3.1). `যাই` is the one verb with variants (3.2) |
| BN-036 | `past-negative` | `bn-grammar-perfect` (same unit as perfect) | present form + নি: ami `করিনি`, tui `করিসনি`, tumi `[করোনি, করনি]` (vowel stems: one form `যাওনি`), apni `করেননি`, se `করেনি`, tini `করেননি`; vowel stems `যাইনি যাসনি যাওনি যাননি যায়নি যাননি`; this is the **present table's six forms + নি**, mechanical; readings by the tool |
| BN-037 | `past-continuous` | `bn-grammar-past-continuous` | continuous stem (BN-033) + ছিলাম / ছিলি / ছিলে / ছিলেন / ছিল / ছিলেন (`করছিলাম`, vowel S `যাচ্ছিলাম`) |
| BN-038 | `past-perfect` | `bn-grammar-past-more` | the perfect stem of BN-035 (conjunctive form, 3.1 corrections included) + ছিলাম / ছিলি / ছিলে / ছিলেন / ছিল / ছিলেন (`করেছিলাম`, `জেনেছিলাম`, `খেয়েছিলাম`); `যাই` has the list variants of 3.2 |
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

### 3.1 Changed stems in the perfect and past perfect (added after BN-035 stopped)

**Rule (a -> e).** In a consonant stem whose last vowel is আ (া), the perfect stem has এ (ে): `জানা` `জানি` -> `জেনেছি`, `মারা` -> `মেরেছি`, `থাকা` -> `থেকেছি`, `আনা` -> `এনেছি`, `আসা` -> `এসেছি`, `ভালোবাসা` -> `ভালোবেসেছি`. The same stem is the conjunctive stem (`জেনে`, `মেরে`), which is why the course's conjunctive table is the source for it. Other stem-vowel changes are already in the present `ami` stem (`লেখা` -> `লিখি` -> `লিখেছি`, `শোনা` -> `শুনি` -> `শুনেছি`); derived stems in -ানো raise ো -> ু and এ -> ই and take `-িয়ে-` (`শেখানো` -> `শিখিয়েছি`, `ঘোরানো` -> `ঘুরিয়েছি`, `ভেজানো` -> `ভিজিয়েছি`), and these too are already in the conjunctive table. Source (fetched and read 2026-11-15): Wikipedia, "Bengali grammar", section Verbs, passage on vowel harmony: "the following transformations take place: ô → o, o → u, æ → e, e → i, and a → e", with a → e "only in the perfect tenses" and the example `জানা` -> `আমি জেনেছি`; it does not say "monosyllabic", so the scope below is taken from the course's own 418 verbs. Scope check (script on the YAML, not the validator): of all consonant-stem verbs of the present table with an আ vowel, **none keeps আ** in the perfect, so the rule has no exceptions among the 418, in single and compound verbs alike (`সাঁতার কাটা` -> `সাঁতার কেটেছি`, only the last word changes).

**Mechanical derivation for BN-035 and BN-038.** For each row, take the course's conjunctive form (`decks/bn/bn-grammar-conjunctive.yaml`, row with the same `word`, slot `conjunctive`; present in all 418 rows). Perfect ami = that form + `ছি`; the other slots add the endings of section 2 to the same form (it already ends in `ে`). Past perfect: the same form + `ছিলাম` etc. Of the 418 rows, 348 give exactly the pilot-style forms (stem + `েছি`, vowel stems `-িয়েছি`, the irregulars of section 3); **70 differ from "S + েছি" and are listed below, so a generator that adds `েছি` to the present stem is wrong for exactly these.** The first 59 are right in the conjunctive table; the last 11 are wrong in the course's conjunctive table (it keeps আ: `মারে`) and must be corrected by hand in the new deck; they are reviewer-queue rows for the conjunctive table (do not change that table here).

Changed stem from the conjunctive table (59):
- `bn-0875` থাকা: present `থাকি` -> perfect stem form `থেকে` (`থেকেছি`)
- `bn-0881` জানা: present `জানি` -> perfect stem form `জেনে` (`জেনেছি`)
- `bn-0893` আনা: present `আনি` -> perfect stem form `এনে` (`এনেছি`)
- `bn-0894` রাখা: present `রাখি` -> perfect stem form `রেখে` (`রেখেছি`)
- `bn-0896` হাঁটা: present `হাঁটি` -> perfect stem form `হেঁটে` (`হেঁটেছি`)
- `bn-0898` ডাকা: present `ডাকি` -> perfect stem form `ডেকে` (`ডেকেছি`)
- `bn-0899` হাসা: present `হাসি` -> perfect stem form `হেসে` (`হেসেছি`)
- `bn-0736` পারা: present `পারি` -> perfect stem form `পেরে` (`পেরেছি`)
- `bn-1099` রাঁধা: present `রাঁধি` -> perfect stem form `রেঁধে` (`রেঁধেছি`)
- `bn-1101` কাটা: present `কাটি` -> perfect stem form `কেটে` (`কেটেছি`)
- `bn-1102` ভাঙা: present `ভাঙি` -> perfect stem form `ভেঙে` (`ভেঙেছি`)
- `bn-1109` পৌঁছানো: present `পৌঁছাই` -> perfect stem form `পৌঁছে` (`পৌঁছেছি`)
- `bn-1111` থামা: present `থামি` -> perfect stem form `থেমে` (`থেমেছি`)
- `bn-1112` ঢালা: present `ঢালি` -> perfect stem form `ঢেলে` (`ঢেলেছি`)
- `bn-1114` শেখানো: present `শেখাই` -> perfect stem form `শিখিয়ে` (`শিখিয়েছি`)
- `bn-1118` ভাবা: present `ভাবি` -> perfect stem form `ভেবে` (`ভেবেছি`)
- `bn-1119` কাঁদা: present `কাঁদি` -> perfect stem form `কেঁদে` (`কেঁদেছি`)
- `bn-2098` বাটা: present `বাটি` -> perfect stem form `বেটে` (`বেটেছি`)
- `bn-2111` মাখা: present `মাখি` -> perfect stem form `মেখে` (`মেখেছি`)
- `bn-2112` নাড়া: present `নাড়ি` -> perfect stem form `নেড়ে` (`নেড়েছি`)
- `bn-2114` মেশানো: present `মেশাই` -> perfect stem form `মিশিয়ে` (`মিশিয়েছি`)
- `bn-2115` ছাঁকা: present `ছাঁকি` -> perfect stem form `ছেঁকে` (`ছেঁকেছি`)
- `bn-2131` ভেজানো: present `ভেজাই` -> perfect stem form `ভিজিয়ে` (`ভিজিয়েছি`)
- `bn-2217` আঁকা: present `আঁকি` -> perfect stem form `এঁকে` (`এঁকেছি`)
- `bn-2230` হারা: present `হারি` -> perfect stem form `হেরে` (`হেরেছি`)
- `bn-2245` নাচা: present `নাচি` -> perfect stem form `নেচে` (`নেচেছি`)
- `bn-2248` ভালোবাসা: present `ভালোবাসি` -> perfect stem form `ভালোবেসে` (`ভালোবেসেছি`)
- `bn-2266` ধুলো ঝাড়া: present `ধুলো ঝাড়ি` -> perfect stem form `ধুলো ঝেড়ে` (`ধুলো ঝেড়েছি`)
- `bn-2271` বাসন মাজা: present `বাসন মাজি` -> perfect stem form `বাসন মেজে` (`বাসন মেজেছি`)
- `bn-2272` কাপড় কাচা: present `কাপড় কাচি` -> perfect stem form `কাপড় কেচে` (`কাপড় কেচেছি`)
- `bn-2276` ঝোলানো: present `ঝোলাই` -> perfect stem form `ঝুলিয়ে` (`ঝুলিয়েছি`)
- `bn-2277` গোছানো: present `গোছাই` -> perfect stem form `গুছিয়ে` (`গুছিয়েছি`)
- `bn-2344` কাচা: present `কাচি` -> perfect stem form `কেচে` (`কেচেছি`)
- `bn-2345` জাগা: present `জাগি` -> perfect stem form `জেগে` (`জেগেছি`)
- `bn-2347` নেভানো: present `নেভাই` -> perfect stem form `নিভিয়ে` (`নিভিয়েছি`)
- `bn-2356` বোঝানো: present `বোঝাই` -> perfect stem form `বুঝিয়ে` (`বুঝিয়েছি`)
- `bn-2360` টানা: present `টানি` -> perfect stem form `টেনে` (`টেনেছি`)
- `bn-2363` লাগা: present `লাগি` -> perfect stem form `লেগে` (`লেগেছি`)
- `bn-2364` কাঁপা: present `কাঁপি` -> perfect stem form `কেঁপে` (`কেঁপেছি`)
- `bn-2365` নামা: present `নামি` -> perfect stem form `নেমে` (`নেমেছি`)
- `bn-2366` ঘোরানো: present `ঘোরাই` -> perfect stem form `ঘুরিয়ে` (`ঘুরিয়েছি`)
- `bn-2373` ছাঁটা: present `ছাঁটি` -> perfect stem form `ছেঁটে` (`ছেঁটেছি`)
- `bn-2376` সাঁতার কাটা: present `সাঁতার কাটি` -> perfect stem form `সাঁতার কেটে` (`সাঁতার কেটেছি`)
- `bn-2419` ফোন রাখা: present `ফোন রাখি` -> perfect stem form `ফোন রেখে` (`ফোন রেখেছি`)
- `bn-2423` বাজা: present `বাজি` -> perfect stem form `বেজে` (`বেজেছি`)
- `bn-2460` টিকিট কাটা: present `টিকিট কাটি` -> perfect stem form `টিকিট কেটে` (`টিকিট কেটেছি`)
- `bn-2468` গাড়ি থেকে নামা: present `গাড়ি থেকে নামি` -> perfect stem form `গাড়ি থেকে নেমে` (`গাড়ি থেকে নেমেছি`)
- `bn-2470` গন্তব্যে পৌঁছানো: present `গন্তব্যে পৌঁছাই` -> perfect stem form `গন্তব্যে পৌঁছে` (`গন্তব্যে পৌঁছেছি`)
- `bn-3092` টিকিট কাটা: present `টিকিট কাটি` -> perfect stem form `টিকিট কেটে` (`টিকিট কেটেছি`)
- `bn-3498` ফসল কাটা: present `ফসল কাটি` -> perfect stem form `ফসল কেটে` (`ফসল কেটেছি`)
- `bn-3926` পাশে থাকা: present `পাশে থাকি` -> perfect stem form `পাশে থেকে` (`পাশে থেকেছি`)
- `bn-3928` মনে রাখা: present `মনে রাখি` -> perfect stem form `মনে রেখে` (`মনে রেখেছি`)
- `bn-4173` লেখানো: present `লেখাই` -> perfect stem form `লিখিয়ে` (`লিখিয়েছি`)
- `bn-4194` শোয়ানো: present `শোয়াই` -> perfect stem form `শুইয়ে` (`শুইয়েছি`); the course conjunctive table has a typo `শুইিয়ে`, do not copy it
- `bn-4480` জোড়ানো: present `জোড়াই` -> perfect stem form `জুড়িয়ে` (`জুড়িয়েছি`)
- `bn-4482` মেলানো: present `মেলাই` -> perfect stem form `মিলিয়ে` (`মিলিয়েছি`)
- `bn-4484` ফেরানো: present `ফেরাই` -> perfect stem form `ফিরিয়ে` (`ফিরিয়েছি`)
- `bn-4485` খোলানো: present `খোলাই` -> perfect stem form `খুলিয়ে` (`খুলিয়েছি`)
- `bn-4488` ঢোকানো: present `ঢোকাই` -> perfect stem form `ঢুকিয়ে` (`ঢুকিয়েছি`)

Corrected by hand, the conjunctive table is wrong (11):
- `bn-4145` মারা: course conjunctive table has `মারে` (wrong) -> use `মেরে` (`মেরেছি`)
- `bn-4148` ঝাড়া: course conjunctive table has `ঝাড়ে` (wrong) -> use `ঝেড়ে` (`ঝেড়েছি`)
- `bn-4149` মাপা: course conjunctive table has `মাপে` (wrong) -> use `মেপে` (`মেপেছি`)
- `bn-4151` বাছা: course conjunctive table has `বাছে` (wrong) -> use `বেছে` (`বেছেছি`)
- `bn-4152` চাখা: course conjunctive table has `চাখে` (wrong) -> use `চেখে` (`চেখেছি`)
- `bn-4154` ভাসা: course conjunctive table has `ভাসে` (wrong) -> use `ভেসে` (`ভেসেছি`)
- `bn-4155` চাটা: course conjunctive table has `চাটে` (wrong) -> use `চেটে` (`চেটেছি`)
- `bn-4157` সাজা: course conjunctive table has `সাজে` (wrong) -> use `সেজে` (`সেজেছি`)
- `bn-4160` বাঁচা: course conjunctive table has `বাঁচে` (wrong) -> use `বেঁচে` (`বেঁচেছি`)
- `bn-4164` হাঁকা: course conjunctive table has `হাঁকে` (wrong) -> use `হেঁকে` (`হেঁকেছি`)
- `bn-4167` চাপা: course conjunctive table has `চাপে` (wrong) -> use `চেপে` (`চেপেছি`)

Present-table spellings that are not raised, so the perfect follows the present and conjunctive spelling and is queued for a bilingual reviewer (standard `ছুঁড়ে`, `মুড়ে`, `পুঁছে`): `bn-4168` `ছোঁড়েছি`, `bn-4170` `মোড়েছি`, `bn-4169` `পোঁছেছি`.

**Verbs that must NOT change:** every other row (348): vowel-final stems keep their own pattern (`দাঁড়া` -> `দাঁড়িয়েছি`), and stems with এ, ো, ই, উ, অ or an already raised vowel keep it (`দেখেছি`, `বলেছি`, `লিখেছি`, `শুনেছি`, `বুঝেছি`, `খেলেছি`, `ফেলেছি`, `পড়েছি`, `ধরেছি`, `উঠেছি`). Check every generated row against the conjunctive form + `ছি` by script; the only allowed differences are the 11 corrections and `যাই`.

### 3.2 List-valued slots in the perfect (and past perfect)

- **tumi is always a list** `[ছো, ছ]` in the perfect: `["করেছো", "করেছ"]`, readings a list of the same length written by the tool (`kôrecho`, `kôreche` is the tool's to decide, not a hand edit).
- **`যাই` (bn-0873) has two stems, so every slot is a list**: ami `["গিয়েছি", "গেছি"]`, tui `["গিয়েছিস", "গেছিস"]`, tumi `["গিয়েছো", "গিয়েছ", "গেছো", "গেছ"]`, apni `["গিয়েছেন", "গেছেন"]`, se `["গিয়েছে", "গেছে"]`, tini `["গিয়েছেন", "গেছেন"]` (the pattern deck `bn-grammar-perfect` has them). Past perfect of `যাই`: `["গিয়েছিলাম", "গেছিলাম"]`, `["গিয়েছিলি", "গেছিলি"]`, `["গিয়েছিলে", "গেছিলে"]`, `["গিয়েছিলেন", "গেছিলেন"]`, `["গিয়েছিল", "গেছিল"]`, `["গিয়েছিলেন", "গেছিলেন"]` (`bn-grammar-past-more` has them). No other verb has a variant stem; the compound `হেঁটে যাই`, `রেগে যাই`, `হাঁটতে যাই` (last word `যাই`) take the same variants on the last word.

### 3.3 The other tables are NOT affected

BN-036 (past negative) is the present forms + `নি`, so `জানিনি`, `জানেননি`, `থাকিনি`: the present stem is kept. BN-037 (past continuous) is the continuous stem, which is the unchanged present stem (`জানছিলাম`, `থাকছিলাম`). BN-039 (habitual past, `-তাম`) uses the present stem (`জানতাম`, `মারতাম`, `থাকতাম`; its irregulars are only the vowel stems of section 3). BN-040 (imperative: bare stem, tumi, polite) and BN-034 (future `জানব`, `মারব`) keep the stem too. The pilot (past `জানলাম`) was already right. The a -> e change belongs only to the perfect and past perfect (conjunctive and `-ে`-participle stems). Lists: none needed for those four beyond the irregular ones already in section 3.

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
2. For BN-035 and BN-038 take the stem from the conjunctive table plus the 11 corrections of 3.1, never "stem + েছি"; make the generator assert every row against it. Copy the generator, change `SUF`, `IRR` and the stem function for the tense (section 2 and 3); run it; read the printed differences; list every hand exception.
3. Write core (header, rows, rules), layer, path edit; check by a script (not the validator): 418 rows, same word order as the present table, every slot filled, every placeholder used, no Bengali in prose outside placeholders and readings.
4. Commit small, merge `origin/decks-live`, push fast-forward to `origin/decks/bn-tenses`; never open a PR (the architect opens one for the branch); never run tests or the validator.
5. Report: row count, except count, the irregular list, the tool-vs-expected differences, anything unclear (stop and report, never improvise).

## 8. Reviewer queue and questions

- **Rows for `docs/review-queue/bn.md` (BN-066):** present-table readings `bn-2789 কমাই` (`kamā-`, tool `kômā-`), `bn-2793 করাই` (`karā-`, tool `kôrā-`), `bn-3351 খুঁজি` (`khuñj-`, tool `khum̐j-`); spelling `bn-2467 গাড়িতে ওঠি` (should be `উঠি`) and `bn-4168 ছোঁড়ি` (standard `ছুঁড়ি`; the pilot follows the present table: `ছোঁড়লাম`) , `bn-4169` `পোঁছি` (check `পোঁছা`/`মোছা`), `bn-2358 ছুঁইস` (tui). Past forms of the three `পৌঁছ-` and `জিজ্ঞেস করি` rows follow the present table's spelling. Not fixed here: card ids and existing rows are permanent, and these need a bilingual reviewer.
- **OQ-1 (default taken):** imperative table keeps `apni`, repeating the present table's `please`. Owner may drop it (then slots `["tui", "tumi"]`).
- **OQ-2 (default taken):** no set cards (`kind: "set"`, rule + verb) for the new tables; the present table has 27 in `bn-verbs.yaml`. They would need ids from `bn-5000..`; add only if the owner wants them.
- **OQ-3 (default taken):** negative imperatives (`করো না`, `কোরো না`) and the negative of the other tenses are not tables.
- Candidates not decided: whether the tui perfect/past forms of vowel stems accept the colloquial `গেছি` style beyond the one list for `যাই` (the pattern deck lists it; the table does too).
