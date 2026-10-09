# ADR-0034: Recognition, Hear, Say and Write: four schedules per word

- **Status:** Accepted
- **Date:** 2026-10-08
- **Amends:** ADR-0005 (which pairs are scheduled) and ADR-0024 (how
  listening is asked, and what a right choice records).

## Context

The owner asked that the listening test ask for the meaning, not the
transliterated word, "otherwise we cannot know whether the user understands
pen and time in telugu separately", and that the app learn the learner's
strengths per skill. The research is in `docs/research/skill-evidence.md`;
the decisions were settled in #235 and by the owner on 2026-10-06, 2026-10-08
and 2026-10-09, and are recorded below.

Until now each word was scheduled in four modes: recognition (choose or rate
the meaning), production (type the word), listening (hear the word, type
it) and speaking (say it).

## Decision

- **Four schedules per word: Recognition, Hear, Say and Write,** and
  grammar's. Hear is the `listening` mode, Write `production`, Say
  `speaking`. Recognition was first made a lesson step only; the owner
  then ruled it "a skill on its own right. The research says it is
  important" (2026-10-09), so it is scheduled like the others, and the
  recognition-only decks are reviewed. The names stay
  as they were: they are stored in the review log, which is never
  rewritten.
- **Hear asks for the meaning.** The word is played; its meaning is chosen
  while the pair is new or was last missed, and typed once it was last
  remembered. Where what is heard is the form itself, it is still typed as
  heard: script practice (a deck that teaches the alphabet) and generated
  numbers.
- **A right choice counts for less than a right recall:** a right choice in
  Hear or Write records 3 (Hard); recalling records as before. A right
  choice of a meaning seen, recognition, records 4, as it did.
- **Typed meanings** are graded by the answer grader, with the articles of
  the language the deck is taught from, against `Card.meanings`: the
  meaning whole, each part of it between `/`, `;` and `,` outside brackets,
  and `alt_native`.
- **The old log replays as it is:** dictation answers into Hear, production
  into Write, speaking into Say, grammar into grammar. Recognition answers
  stay in the log and schedule nothing.
- **One answer judges its own skill, and in part the skills it implies**
  (`SkillMap`, a Q-matrix; owner, from `docs/research/skill-evidence.md`).
  Write and Say imply Recognition; Hear implies Recognition, and in script
  practice, where what is heard is written, Write. A right answer counts
  for half a review there (Pan & Rickard 2018, d 0.28 against 0.58;
  low confidence, to be fitted on the phone from the learner's own log):
  FSRS moves the implied pair's stability half way to a Good review, never
  its due date, and never starts a pair not yet asked; the ability layer
  moves the
  implied skill by half its own surprise. A miss counts against its own
  pair alone in FSRS; in the ability layer its blame is split the same way
  (owner, 2026-10-09: "a miss's blame split", Park et al. 2019).
- **The ability layer.** An Elo rating per language and schedule, and a
  difficulty per pair, each moved after every answer by how surprising it
  was, by K = 1 ÷ (1 + 0.05 n) after n answers (Pelánek 2016). Like the
  scheduling state it is rebuilt from the log. Its reading is the
  chance of a right answer on a word of average difficulty, per skill, for
  one language. Progress was to show it as "Your strengths"; the owner
  removed that section on 2026-10-09 as saying the same as "Correct, by
  skill" (ADR-0035). A pair never asked in Hear
  starts at recall rather than choice once the learner's Hear strength
  there is 80% or more over at least 20 answers.
- **Pictures** (owner: Noto Emoji, Apache-2.0): a card may name one emoji
  (`picture:`) for a concrete word. Write shows it above the meaning, and
  Hear beside each meaning it offers (Carpenter & Olson 2012). Only the
  images the decks use are bundled (`tools/pictures.py`). Each picture was
  matched by an agent and checked by another; abstract words, kinship and
  near misses get none.
- **A minimal-pair partner** can be named on a card (`pair:`); Hear offers
  its meaning among the options. కలం (pen) and కాలం (time) name each
  other.

## Consequences

- A word practised in Write comes due for Recognition later than it
  would alone, but no sooner.
- Hear's typed recall is in the language the learner speaks, so a near
  homophone (కలం pen, కాలం time) is caught by its meaning, not passed by
  its sound.
- A word chosen right in Hear or Write comes back sooner than one recalled.

## Alternatives considered

- **Renaming the modes** to `hear`, `say` and `write`: every row of
  `reviews` and `leech_actions` holds the old names, and both tables are
  append-only.
- **Recognition as Write's first rung:** it tests the opposite direction to
  Write.
- **Recognition as a lesson step only:** chosen first, then reversed by
  the owner: it is a skill of its own.
- **One weight, .68, between every pair of skills:** a correlation of
  vocabulary sizes across learners (Milton & Hopkins 2006), not of one
  word's skills; other studies give .46 to .88.
- **No credit across skills,** or **a full review for every skill a
  question touches:** the research finds transfer real but partial.
- **Dictation kept as Hear's recall:** it tests the form, not the meaning,
  so pen and time could not be told apart.

## Record of the owner's decisions, moved from the deleted plan

`docs/plans/skill-model.md` was deleted when #207 closed (the rule in
`docs/ROADMAP.md`). What it held that was still needed is above, or here: the
owner's words with their dates, the decisions the sections above do not
carry, and what is open or lives elsewhere. The research summary is
`docs/research/skill-evidence.md`, whose appendix holds the evidence behind
Hear, Say and Write.

### What the owner asked, 2026-10-06

> in the listening test, we should ask users for the meaning and not the
> transliterated word (unless it is script practice). otherwise we cannot
> know whether the user understands pen and time in telugu separately

> choose for recognition, type for production.

> divide checked skills into matching, listening, typing, speaking, etc,
> that the user does. the app learns the user's strengths in terms of
> recognition-sound, recognition-text, recognition-picture,
> recognition-script, production-sound (speech), production-text (typing),
> production-script (using the script), understanding-grammar,
> understanding-accent, etc. discuss in detail. this will go into planning
> as well. before the deck grading (the B1 target plan).

The order the owner gave: the skill model, then the B1 plans, then deck
downloads (`docs/plans/decks-from-github.md`), then the settings redesign
(`language-picker.md`, `settings-wording.md`, `voices-per-language.md`).
The skill model is done; `docs/ROADMAP.md` holds the order that remains.

### Terms (the owner's definitions)

- **Minimal pairs:** "words in the same language that sound the same", such
  as కలం (pen) and కాలం (time).
- **Phonemic contrasts:** "sounds that do not exist in the native languages
  for the user but exist in the language being taught."

A minimal pair can be used to practise a phonemic contrast; the two terms
are not interchangeable.

### Decided with the owner, 2026-10-06, after the research

- **Two layers.** *Activities* are what you do, and what Settings switches
  on: matching, choosing, listening, typing, speaking, grammar, reading,
  phonemic contrasts. *Strengths* are what the app learns about you from
  them.
- **Three schedules per word: Hear, Say, Write,** chosen as the grouping of
  review methods that covers the most strengths with the fewest reviews
  (the table under "Why three" below). Recognition was added as a fourth on
  2026-10-09.
- **Hear asks for the meaning.** A transliteration is never asked for as
  dictation, except in script practice, where you say what a letter is
  written as.
- **Write asks for the word,** from its meaning or a picture, typed in the
  script or in ISO Latin letters. The Script / Latin letters switch stays
  for these questions, and ISO transliterations stay after the script.
- **Choosing and recalling are two grades of one schedule,** not two
  schedules. A right choice counts for less than a right recall.
- **Grammar has two schedules per item, understand and produce,** and the
  time an answer takes is recorded as a sign of how automatic it is (a
  nullable column on `reviews`, which is append-only: AGENTS.md rule 9).
- **The model:** FSRS keeps each word's memory in each schedule (ADR-0033);
  an Elo ability per skill sits on top. DAS3H is reconsidered later, once
  there are logs enough to compare the two. Not done.
- **Handwriting answers Write** (owner, 2026-10-06; it replaces "a skill of
  its own"): writing in the script by hand is one way to answer a Write
  question, not a schedule of its own (`docs/plans/handwriting.md`).
- **Cloze is a sentence's own item, produced in Write:** the gap is any word
  the learner has learnt (`docs/plans/sentence-building.md`).
- **After the script,** Write expects the script; an answer in Latin letters
  counts as before (#168). Not built.
- **A picture** is a cue for Write and for Hear's choices, for concrete
  words (Carpenter & Olson 2012; Lotto & de Groot 1998).

### Why three: cells covered per schedule

Each question has one cue and one response, so it tests one cell:

| Cell | Review methods | Grade |
|---|---|---|
| Understand · sound | Hear the word, choose or type its meaning | choose / recall |
| Understand · Latin letters | Choose the meaning; match pairs | choose |
| Understand · script | The same, shown in the script | choose |
| Produce · Latin letters | Choose the word; put words in order; fill a gap (cloze); type the word | choose / choose / recall / recall |
| Produce · script | The same in the script; write it by hand | recall |
| Produce · sound | See the meaning, say the word | recall |
| *Form only* | Dictation; read aloud | script practice only |

A cell can be taken from another where the research supports it: producing a
word in a channel implies understanding it in that channel, since
recognition comes first (medium confidence). Nothing is taken from sound to
writing, or from saying to hearing (Uchihara et al. 2024). The owner's
2026-10-09 ruling that recognition is a skill of its own, and the partial
implication in the Decision above, came after this ranking.

Ranked by **coverage = cells covered ÷ schedules per word** (four cells
before the script, six after):

| Schedules per word | Before the script | After |
|---|---|---|
| **Hear, Say, Write** (chosen) | 4/3 = 1.33 | 6/3 = 2.0 |
| Hear, Say, Write Latin, Write script | 1.33 | 1.5 |
| Hear, Say, Write, Read | 1.0 | 1.5 |
| Every cell | 1.0 | 1.0 |
| *Then:* recognition, production, listening (dictation), speaking | 0.75 | 0.75 |

### Decided with the owner, 2026-10-08 (#235)

- **The Today tiles:** Hear, Say, Write and Grammar (understood and produced
  share one tile); Reading stays.
- **Spill-over:** as the research says. Nothing is taken from sound to
  writing or from saying to hearing, so no schedule counts another's
  answers. A new schedule starts from the learner's ability there. (The
  2026-10-09 rulings below refine this: partial credit, only where research
  found the skills related.)
- **Match pairs and choose the meaning** are lesson steps, not scheduled.
  Reversed for Recognition, 2026-10-09, below.
- **The old log:** dictation replays into Hear, production into Write,
  speaking into Say, grammar into grammar produced. Recognition answers stay
  in the log and feed no schedule. (Recognition is scheduled since
  2026-10-09; until grammar understood is built, grammar is one schedule.)
- **Typed meanings** are graded by the answer grader's folding and typo
  rules against each meaning: `native` split on `/`, `;` and `,`, and an
  optional `meanings:` list on the card.
- **Answer time** is recorded (`reviews.elapsed_ms` already holds it) and
  does not change a grade for now.
- **Pictures:** an open-licence set for concrete words, **Noto Emoji**
  (Apache-2.0), bundled PNGs named on a card as `picture:`, no new
  dependency.
- **Cloze** is chosen as its easier grade and typed as its harder one.
- **The pair partner** is among Hear's options where a card names one.
  (Proposed first: where a word has a minimal-pair partner, Hear's options
  include its meaning, "time" for కలం "pen", whose partner is కాలం, so that
  a learner who confuses the two is caught; Ota et al. 2009.)

### Decided with the owner, 2026-10-09

- **Recognition is a skill in its own right,** scheduled like the others:
  "Recognition is a skill on its own right. The research says it is
  important." This reverses "lesson steps, not scheduled" above. The
  recognition-only decks (the `-registers` and `-spelling` decks, and
  `bn-en-sadhu-cholito`) are reviewed again with it.
- **Shared ability, first ruling:** "Our research said everything is
  interdependent." An answer in one skill moves the learner's ability and
  the word's difficulty in another **only where research has found the two
  related, and by as much as it found** (owner: "It should only be used
  where research has found correlation and with the strength that research
  has found"). So far: Recognition and Hear, .68 (Milton & Hopkins 2006,
  recognising words in writing and by ear). Due dates stay per skill. The
  Q-matrix ruling below replaced the single .68.
- **One question, several skills; partial implication.** The owner: "Same
  questions can judge multiple skills. And one skill may partially imply
  other skills. These research based stuff is the backbone of the app."
  Which skills each question judges, and how much one skill implies another,
  were taken from the research before they were built
  (`docs/research/skill-evidence.md`, every claim checked against its source
  by a second agent; the checked claims are in
  `docs/research/skill-evidence-claims.json`).
- **Decided from the evidence** (owner, 2026-10-09):
  - **Ability:** a Q-matrix with multi-skill Elo. Each question lists the
    skills it judges, primary or secondary; one answer's update is shared
    over them, and a miss's blame split (Park et al. 2019; Koedinger et al.
    2011). The single .68 goes: it is a correlation of vocabulary sizes
    across learners, not of one word's skills.
  - **Scheduling:** a full review for each skill a question exercises; on a
    right answer only, a partial stability gain for the skills it implies,
    never moving their due date (Choffin et al. 2019; Pan & Rickard 2018).
  - **Order:** the skill model and FSRS are finished, rated and opened as a
    pull request first; then the B1 format; then the colours.
- **Reading is a skill of the script.** The owner: "Reading is a skill
  related to script." **Later,** recognition can be checked together with
  reading: "Recognition can later be checked along with read, e.g. when we
  bring in script only options for a picture" (a picture shown, the word
  chosen from options written in the script only). Not built.
- **Grammar understood and produced** are built with the B1 format, not in
  the skill model's pull request (owner, 2026-10-09). **Understood is shown a
  form and choosing what it means;** choosing among forms of the same word,
  the rule cards' question, or typing the form, is produced (owner,
  2026-10-09, settling `b1-format-spec.md` #22). Until then grammar keeps one
  schedule, typed.
- **Settings** already has one switch per skill, so one per activity; their
  wording waits for `docs/plans/settings-wording.md`.
- **SM-2 goes, all but its history** (owner, 2026-10-09): migration 6 drops
  `reviews.ease_before` and `ease_after`, keeping every row; see ADR-0033.
- **FSRS fitted to the learner** and everything the owner decided about it
  is in ADR-0035.
- **How the work was run** (owner, 2026-10-09): commit and push everything
  as it goes; no raters until a whole feature is built; once the skill model
  and FSRS are done, rate them, then open a pull request.

### Open, not built, or kept elsewhere

- **Grammar understood and produced:** moved to the B1 format's spec,
  `docs/plans/b1-format-spec.md` on branch `feat/b1-format` (4.7, and OPEN-22,
  settled 2026-10-09), which holds the owner's ruling and the questions.
- **Cloze,** with the owner's wording of how it is asked and its easier and
  harder grades: `docs/plans/sentence-building.md` (#222).
- **The optimiser:** done, ADR-0035.
- **Tracked for the learner, not per word,** not built, and in no plan:
  accent, from hearing several voices (Bradlow & Bent 2008; Baese-Berk et
  al. 2013; the CEFR's B1 assumes a familiar accent); phonemic contrasts, per
  sound pair, as identification with feedback (Logan et al. 1991; Thomson
  2018); the script, letter by letter, from the script decks.
- **DAS3H** compared with Elo, once there are logs enough: not done.
- **Write expecting the script** after the script is learnt (#168), and
  **Recognition checked together with reading:** both above, not built.
