The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

See [AGENTS.md](AGENTS.md) for how to work in this repository.

Read it before making changes. It is short, and three of its rules — card ids
are permanent, YAML scalars must be quoted, and `lib/core` stays free of
Flutter imports — protect against mistakes that pass every test.

## Rules at a glance

The sections below hold every rule with its owner quote and date. These are the
ones that matter most; read the section before acting on one.

- **Model by job:** Sonnet does complex coding, reviews and writes skills and ADRs; Haiku does simple, fully specified coding tasks (it never improvises: it reports issues and the architect re-specifies), builds decks, makes routine doc edits and fan-outs; Opus only when the owner asks ([Which model does what](#which-model-does-what-owner-2026-10-22)).
- **Agent limits:** one Haiku deck builder, one Sonnet coder, and an extra Sonnet only for reviews while a review runs; at most three agents, never more than two Sonnet; the main session only orchestrates ([Which model does what](#which-model-does-what-owner-2026-10-22)).
- **Reviews:** one Sonnet review per pull request; bug fixes only for decks and reviews ([Agents and models](#agents-and-models)).
- **Docs straight to main:** a change to Markdown docs only is pushed to main with no PR and no CI check ([Git, PRs and CI](#git-prs-and-ci)).
- **PRs for everything else:** code, decks, `decks/index.json` and the CHANGELOG go through a pull request, with CI green and one review ([Git, PRs and CI](#git-prs-and-ci)).
- **Tests run only in CI:** no agent runs the tests or the deck validator locally ([Git, PRs and CI](#git-prs-and-ci)).
- **No stray branches:** never push a branch after its PR has merged, and never push scratch, review or worktree branches ([Git, PRs and CI](#git-prs-and-ci)).
- **No tags:** never create or push git tags; only the owner tags releases ([Tags](#tags-owner-2026-10-12)).
- **Off limits:** `homelab-stacks` is never cloned, modified or pushed to ([Repositories off limits](#repositories-off-limits-owner-2026-10-12)).
- **Releases:** the owner runs the Release workflow; each PR adds its own CHANGELOG line; deck content stays out of a release ([Releases and milestones](#releases-and-milestones)).
- **Top priorities after the placement release** (owner, 2026-11-07): 1. private decks, 2. on-device voice recognition, both recorded for later; the session that ships the placement bugfix release stops there, and no agent starts them without a new owner instruction ([Releases and milestones](#releases-and-milestones)).
- **Deck work:** the language lists, priorities and what is in scope this week, and the order after the placement fix, are in one place; deck PRs are large, and `tools/deck_index.py` is never run locally ([Content and decks](#content-and-decks)).
- **Decks live on `decks-live`** (owner, 2026-11-06): deck PRs target it; its index and review queue are regenerated there; `decks/themes.yaml` is edited only on main ([Content and decks](#content-and-decks)).
- **Card ids are permanent**, YAML scalars are quoted, and `lib/core` has no Flutter imports ([AGENTS.md](AGENTS.md)).
- **Mockups and text size:** build the approved spec exactly, at 1.4x text only; a `direct-code` issue has every decision made ([Mockups, issues and dependencies](#mockups-issues-and-dependencies)).
- **Never stop anything** unless the owner explicitly asks ([Agents and models](#agents-and-models)).
- **Contributor sessions** (`DhyanendraSinghSikarwar`) follow their own rules ([Contributor DhyanendraSinghSikarwar](#contributor-dhyanendrasinghsikarwar-2026-10-13)).

Rules that no longer govern, and what replaced them, are kept in the wiki page
[Owner-Decisions-History](wiki/Owner-Decisions-History.md)
([on the wiki](https://github.com/aaronified/fluenough/wiki/Owner-Decisions-History)).

## Repositories off limits (owner, 2026-10-12)

`homelab-stacks` is not part of this work. Never clone or download it, never
modify it, and never push to it, even if it appears in a session's
repositories.

## Tags (owner, 2026-10-12)

Never create or push git tags. Only the owner tags releases.

## Contributor DhyanendraSinghSikarwar (2026-10-13)

When the session's GitHub user is `DhyanendraSinghSikarwar`, the contributor
rules in [Owner-Decisions-History](wiki/Owner-Decisions-History.md#contributor-dhyanendrasinghsikarwar-2026-10-13)
replace "Push straight to main" above: read them before the first commit.

## Agents and models

### Which model does what (owner, 2026-10-22)

The main session only orchestrates agents; it does not write code or decks
itself. Pick the model by the job:

| Job | Model |
|---|---|
| Simple, straightforward coding jobs (small, isolated, fully specified tasks) | Haiku |
| Complex coding, multi-file changes and bug fixes | Sonnet |
| UI mockups | Sonnet |
| Building decks | Haiku |
| Reviews (one per PR, decks included) | Sonnet |
| Routine doc updates, CHANGELOG lines, find-and-replace | Haiku |
| Skills, ADRs, audits, keeping several docs consistent | Sonnet |
| Fan-outs and large reads | Haiku |

**Architect and Haiku coders** (owner, 2026-11-10: "For simple straight forward coding jobs, use haiku subagents. You are the Lead Mobile Architect. You will generate the system architecture, write the core state management, and break down UI features into small, isolated tasks for Haiku subagents to code. And ask the haiku agents to never improvise and rather report issues, which you will solve and message them with the altered params. You will break down complex problems to byte size stuff for haikus to deal with."):

- The main session acts as the Lead Mobile Architect: it designs the architecture and the core state management (through Sonnet agents where the work is complex) and breaks every feature, especially UI features, into small, isolated, byte-sized tasks.
- Simple, straightforward coding jobs go to Haiku subagents. Each Haiku task is fully specified: files to touch, exact behaviour, the expected inputs and outputs, and what not to touch.
- Haiku agents never improvise. If anything is unclear, missing, or does not match the task, they stop and report the issue. The main session solves it and messages the Haiku agent with the altered parameters.
- Complex problems are broken down until each piece is a byte-sized task a Haiku can do. Whatever stays complex (core state management, multi-file design, bug diagnosis) goes to Sonnet.
- The existing limits still apply (at most three agents at once, one review per pull request, tests only in CI).

At most **three agents run at the same time, and never more than two
Sonnet** (owner, 2026-10-22; kept by 2026-11-06).

**Slots** (owner, 2026-11-06: "only one haiku deck builder. and one sonnet
coder. an extra sonnet will pop up from time to time to review the decks or
the code PRs."): one Haiku deck builder, one Sonnet coder, and an extra Sonnet
only while a review runs, for a deck or a code PR. Never a second coder and
never more than one Haiku deck builder. This replaces the 2026-10-23 slot
split (one Haiku and one Sonnet on decks, one Sonnet on the Today chain), which
is kept in [Owner-Decisions-History](wiki/Owner-Decisions-History.md).

**Opus only when the owner explicitly asks**, reviews included (owner,
2026-10-22). Nothing defaults to Opus.

**Reviews** (owner, 2026-10-22): one Sonnet review per pull request. A second
review runs only if the first caught a breaking bug, and it is also Sonnet.
Ratings are opt in (`.claude/skills/work-rating/SKILL.md`).

**Bug fixes are only for decks and reviews** (owner, 2026-10-16: "Don't do
bugfixes that are not relevant to decks and reviews"). Others wait for a
contributor.

- **Questions.** Ask them as soon as they come up. Record the owner's
  answers, quoted and dated, in the plan and the issue they belong to. For a
  decision, explain the options (what each means and its main downside), then
  ask (owner, 2026-10-22).
- **Budget.** Tokens are limited: one review per change (see "Which model
  does what"), no extra verification passes, and no new work unless the owner asks for it.
- **Never stop anything** unless the owner explicitly asks (owner, 2026-10-23:
  "Never stop anything unless i explicitly ask to.").
- **Do not stop for confirmation** (owner, 2026-11-07: "Go on with the
  placement track. Do not stop for my confirmation in the future."). Decisions
  the orchestrator can make with a sensible default are made and recorded; the
  owner is told what was decided, not asked first. Questions stay only for
  choices with no sensible default or that cannot be undone.

## Git, PRs and CI

- **Docs live in the wiki** (owner, 2026-10-22). The repo's wiki/ folder is
  the source of truth, published to the GitHub wiki by
  `.github/workflows/wiki-sync.yml`. Repo docs are pointers, except files
  tools or agents read from disk.
- **Docs straight to main** (owner, 2026-10-17: "Docs go straight to main,
  no PR"). A change to documentation only (Markdown such as `docs/`,
  `CLAUDE.md`, `AGENTS.md`, the READMEs and the skills) is pushed straight to
  main, with no pull request and no review. A change that touches code, a
  deck, `decks/index.json` or the CHANGELOG is not docs only.
- **Pull requests for everything else** (owner, 2026-10-16: "Do use PRs for
  everything", replacing "Push straight to main" of 2026-10-11). Every other
  change goes through a pull request to main
  (or, for decks, to `decks-live`). Before it merges, CI's checks pass (`flutter
  analyze`, the full `flutter test`, the deck validator and the tools'
  tests) and one review finds nothing blocking (see "Which model does what").
  The owner approves it in review; then merge it
  once CI is green (owner, 2026-10-16, on #529: "I have approved it in
  review. So you should be able to merge").
- **Commit and push often** (owner, 2026-10-15: "Keep committing and pushing
  to a branch frequently"). Long work is committed in small steps and pushed
  to a work branch (`wip/<topic>`) as it goes, so nothing is lost if a
  session ends. Only checked, approved work reaches main or `decks-live`.
- **No stray branches** (owner, 2026-10-24). Merged pull requests delete
  their head branch (repo setting). So: never push a branch again after its
  pull request has merged; never push scratch, review or worktree branches;
  and never merge one work branch into another and leave it pushed: open
  its own pull request instead. Agents cannot delete remote branches (the
  session's git proxy refuses it), so list any branch left over for the
  owner to delete. Never ask to delete `decks-live` or an open pull
  request's base.
- **Tests check behaviour** (owner, 2026-10-20). The rule is in
  [AGENTS.md](AGENTS.md), "Tests check behaviour".
- **Tests run only in CI** (owner, 2026-10-17: "You should not run tests
  locally at all"; on the validator: "Why not let ci do it?"; 2026-10-22: "Doc
  pushes do not need CI.").
  No agent runs the tests or the deck validator locally, and none is launched
  just to run tests. CI runs them for free. Code and deck commits are checked
  by CI: after pushing, read CI's result. A docs-only push to main needs no CI
  check.
- **Irrelevant checks** (owner, 2026-10-22). When reading CI for a change,
  ignore failing checks that are irrelevant to it. A deck-only change needs
  only "Validate decks" and "Released app reads the decks" green (#524, owner,
  2026-10-17). An irrelevant failure is fixed in its own pull request, never
  by widening the current change or pushing a fix straight to main.

## Releases and milestones

- **Releases** (owner, 2026-10-20: "Can the release workflow not
  automatically take care of the release commit? So that I can cut releases
  just from the UI?"). Each pull request adds its own CHANGELOG.md line under
  `## [Unreleased]`; deck content (new or filled decks, paths) is not part of
  a release and stays out of it (owner, 2026-10-19: "This has nothing to do
  with the release. It is content."). The owner releases by running the
  Release workflow from the Actions tab, from main, with the version (like
  `0.5.3`): it bumps `pubspec.yaml` and `lib/app/app_info.dart`, dates the
  changelog, commits, tags and builds (`tools/prepare_release.py`). There is
  no release pull request.
- **Milestones are releases** (0.4.4, 0.5.0, 0.6.0, 0.7.0, 0.9.0). The milestone's
  description holds its order, and the wiki's Roadmap page is generated from
  it (#484). Tidy issues and plans after work lands, and close issues when done. Tag new issues to a
  milestone only as the owner says.
- **Current milestone** (owner, 2026-11-06: "We are now working on 0.9.0"). Milestone 0.9.0 exists, and new work is recorded against it.
- **Top priorities after the placement release** (owner, 2026-11-07: "After the release these will be the top priorities: 1. Private decks 2. On device voice recognition"; "Do not build them. You will stop at the release."). After the placement rebuild (V3) and its bugfix release, these two are the next items, in this order: 1. Private decks (private custom language courses; issue #1017, wiki Plan-Private-Languages / Plan-Profiles pages), 2. On-device voice recognition (offline recogniser, issue #1004, wiki Plan-Speech-Offline-Alert, ADR-0054 notes). The session that ships the placement bugfix release stops there. No agent builds either item without a new instruction from the owner, and deck content work stays paused until the owner resumes it.

## Content and decks

- **Content.** Keep transliteration in deck prose, and say in a card's notes
  when its base word changes its stem (`wiki/Deck-Format.md`).
  Telugu readings write a word-final anusvara (ం) as `ṁ`, course-wide
  (owner, 2026-10-19).
- **Readings.** Readings are *based on* ISO 15919. Never say they strictly
  follow it.
- **Reviewers** are bilingual and the meaning of a card never changes; new
  themes come only by pull request (`wiki/Plan-Reviewing-Scope.md`).

Every language's path and decks are built here (owner, 2026-10-18: "We
will build the paths for every language that we want here. This is to be
a repository of world's languages. The tower of babel, is to rise
again."). The other courses' decks (#420) and the new courses'
paths are no longer left to contributors.

**Deck work paused for the placement rebuild** (owner, 2026-11-07: "Stop the deck work."): no deck agents run until the owner resumes deck work; open deck PRs (Malayalam #1062) stay drafts.

**Deck priority** (owner, 2026-10-18). Decks are built in this order:
1. Telugu, 2. Bengali, 3. Spanish, 4. Marathi, 5. Kannada, 6. Assamese,
7. Chinese, 8. Hindustani, 9. Japanese, 10. Korean, 11. Toki Pona (owner,
2026-10-20: "Make it high priority (11th language)"). Decks stop at A1
(owner, 2026-10-23: "Stop the deck work after A1. You need to work on
codes."): no new B1 units. B1 batches already open as PRs are merged. Other
languages' paths and decks follow.

**Toki Pona to B1, then stop** (owner, 2026-10-23: "once the current one is
done fully complete toki pona to B1. then stop the deck work"; "1 PR").
Toki Pona is the one exception to the A1 stop: its units 18 to the B1
milestone are written in a single PR. After that no new deck work starts;
open deck PRs are still reviewed and merged. Conversations (#722) are a
long-horizon ask (owner, 2026-10-23).

**Bengali, Hindustani and Spanish to full B1, and French A1** (owner, 2026-10-30: "Build the bengali, hindustani, and spanish decks to full B1. And add french A1. Haiku deck builders. Sonnet reviews. Also, make all decks compliant with the full [] IPA notations."). This lifts the 2026-10-23 A1 stop for these three courses: the planned A2 and B1 units of bn, hi and es are built (Haiku builds, one Sonnet review per pull request), in that order, then French A1 (a new course: path units, cores and English layers, facts file). Every card also gets its narrow IPA in `[ ]`: the `phonetic` field of wiki/Plan-Ipa-Revamp-And-Language-Phonology.md, written by the tools of that plan, never by hand, and any card still lacking a broad `ipa` is given one. The A1 stop still holds for every other course.

**Deck order after Bengali and Hindustani** (owner, 2026-11-01: "Once hindustani and bengali are done, do all first courses, then our priority 10 list to full B1."). Once the Bengali and Hindustani B1 branches are done, build Spanish to B1 and French A1 (the courses already queued above), then the ten courses of the deck priority list (Telugu, Bengali, Spanish, Marathi, Kannada, Assamese, Chinese, Hindustani, Japanese (Korean moved to the later list below, owner 2026-11-02)) to full B1. This lifts the A1 stop for those ten courses. Deck agents work lazily: one Haiku deck builder (owner, 2026-11-06, see "Slots"), batches of at least 20 units, one branch per language, one Sonnet review of the whole branch at B1 (owner, 2026-11-02). Deck work still yields to coding work (owner: "Deprioritise deck work whenever you have coding work."; "All 7.0.x work must be top priority").

**Deck order after Chinese and Japanese** (owner, 2026-11-02: "Deprioritise deck work post chinese+japanese. And instead of korean, go for french. Next priority list for languages: tamil, malayalam, santhali, korean, africaans, italian, german, russian, classical (heavy focus on Panini's grammar) and vedic sanskrit, greek."). (owner, 2026-11-02: "add yiddish, polish to later languages.") (owner, 2026-11-02: "indonesian, persian, pashto, dutch, santhali.") The order is: Chinese and Japanese to B1 (builders running), then French to B1 (A1 is built), replacing Korean in the earlier priority-10 list. After that deck work is deprioritised: it runs only when there is no coding work. The next language list, in this order: Tamil, Malayalam, Santali, Korean, Afrikaans, Italian, German, Russian, Classical Sanskrit (heavy focus on Pāṇini's grammar), Vedic Sanskrit, Greek, Yiddish, Polish. Most already have a language entry and starter decks (Tamil, Malayalam, Korean, Italian, German, Russian, Greek, Vedic Sanskrit, Yiddish, Polish); Santali has an entry but no decks; Afrikaans has neither and needs its language entry first; each gets a path and a phonology plan before its B1 build. The A1 stop is lifted for every language on this list. Also queued, after the list above and in this order: Indonesian, Persian, Pashto, Dutch, Ukrainian (all new languages needing their own language entry, path and phonology plan first; Ukrainian is a separate language from Russian, so no Russian decks are reused; Cyrillic is shared) and Santali (entry exists, no decks yet; the README language list is filled from decks/index.json, so Santali appears there once it has decks). (owner, 2026-11-02: "cool. queue ukrainian too", after being told Ukrainian is a separate language from Russian).

**Three language lists** (owner, 2026-11-02: "all should get their first words this week only. we will complete the first list to B1, and the second list to A1, ukrainian and others are third list"). First list, to B1: Telugu, Bengali, Spanish, Marathi, Kannada, Assamese, Chinese, Hindustani, Japanese and French. Second list, to A1 (Classical Sanskrit to B1, owner, 2026-11-06: "2nd list A1 and all languages first deck only. Only classical sanskrit to B1."): Tamil, Malayalam, Santali, Korean, Afrikaans, Italian, German, Russian, Classical Sanskrit, Greek and Polish (owner, 2026-11-06: "Remove vedic sanskrit and yiddish from the second list."). Third list, first words only: Indonesian, Persian, Pashto, Dutch, Ukrainian and others added later. This week every language on all three lists gets its first-words deck. Already done (audit 2026-11-02): Tamil, Malayalam, Korean, Italian, German, Russian, Polish, Yiddish, the four Greeks, Vedic Sanskrit and French. Still to build: Santali and Classical Sanskrit (entry, no decks), Afrikaans, Persian, Pashto, Dutch, Ukrainian and Indonesian (no entry; Indonesian is today an alias of Malay). Each new language needs its language entry first (assets/languages.yaml, fonts, path generator), then its phrasebook, first-words deck, romanisation and path; facts files go in issues this week. Deck work still yields to coding work, but first-words work takes every free Haiku slot.

**This week's deck scope** (owner, 2026-11-02: "stop at the first list of languages at B1 for this week. the second and third lists will be next week." then "leave out japanese, chinese, and french as well. will see if i have tokens after wednesday"). Deck work for 2026-11-02 to Wednesday is closed. Telugu, Bengali, Hindustani, Spanish, Marathi, Kannada and Assamese are at B1 and merged. Chinese, Japanese and French B1 are left out until the owner decides after Wednesday (replaced for those three by the 2026-11-06 rule below), and the second and third lists (above) start next week at the earliest. Resume state, so nothing is lost: `decks/zh-b1` is at 57314bf with these planned units left: emergencies, law, verbs-4, idioms, abstract-words, characters-7, money, grammar-written-register, society, university, food-culture, literature, verbs-5, grammar-politeness (B1 mark); `decks/ja-b1` is at 3e3de03 (path units 8 to 43 built, the first kanji unit included; units 44 to 134 left, including the kanji units 56, 74, 93, 109 and 127; sentence and reading decks for units 17 to 36 still owed; kanji deck files carry a minimum app version of 0.8.1 in decks/min_app.json); French B1 has not started (A1 is merged). The deck builders' scripts live only in a session scratch folder, so a new session rebuilds them from the branches. No deck pull request is opened for these branches until the owner says so, and deck pushes to branches cost no CI.

**Chinese, Japanese and French to B1** (owner, 2026-11-06: "for the language haiku, ignore tamil for now. build chinese, japanese, and french to B1"). This replaces the 2026-11-02 rule that left them out until the owner decides. The language Haiku builder builds them to B1, using the resume state above. Tamil is set aside for now. The second list (under "Three language lists") is the current list; the list names in the "Deck order" paragraphs above are older.

**Deck order after the placement fix** (owner, 2026-11-06: "Complete the placement fix, then carry on with the decks. On the 1st list of languages, get the situations cards before the all A1. Both will come after the 2nd list gets B1."; earlier the same day: "Deck builds can be paused"; then, correcting it: "Ok, sorry. 2nd list A1 and all languages first deck only. Only classical sanskrit to B1."). The pause on deck building is lifted when the placement fix (the guess-proof Find my level work) lands. From then on the order is: (1) the second list (under "Three language lists") is built to A1, with Classical Sanskrit to B1, the only language that goes to B1; (2) the situations cards (decks of kind `situations`, `wiki/Deck-Format.md`) for the first list of languages (Telugu, Bengali, Spanish, Marathi, Kannada, Assamese, Chinese, Hindustani, Japanese and French); (3) the first deck (first words and phrases) for all other languages (the third list and any others). Wording to confirm with the owner: what exactly "first deck only" and "before the all A1" cover in step (3).

**Hindustani** is one course (owner, 2026-10-18: "Hindi and Urdu should be
combined as we should not care about socipolitics over linguistics"; chose
"One course, two scripts"). The `hi` course and its card ids stay; it is
renamed Hindustani, teaches the shared colloquial vocabulary, and offers
Devanagari or the Perso-Arabic (Urdu)
script as the learner's script, as Punjabi offers
Gurmukhi or Shahmukhi. Sanskrit- and Persian-leaning synonyms go on the
card. The Urdu path (#602) is folded into it. Its grammar tables (nouns,
adjectives, verbs) are full tables covering every word, as Bengali's are
(owner, 2026-10-23).

- **Larger deck pull requests** (owner, 2026-10-30: "Open larger PRs for decks, to minimize ci burden, when you restart work on decks"). CI runners are the bottleneck, so deck work goes in larger pull requests: several units (a course's next 3 to 6 units, theme and sentences decks together) per branch and per pull request, one Sonnet review per pull request, instead of one pull request per unit. Fix review findings on the same branch before opening it where possible.
- **Deck work waits for the rest** (owner, 2026-10-30: "Don't do deck work till all else is done"). No new deck work starts (no new units, facts or decks, no deck agents) until all the other work is done: the code, app, tooling and documentation issues and pull requests. Deck pull requests already open are still reviewed and merged. When the rest is done, deck work restarts in larger pull requests (see above).
- **Decks live on `decks-live`** (owner, 2026-11-06). Decks live on the
  permanent branch `decks-live`, and the apps download decks from it (PR
  #1052 merged). Deck PRs target `decks-live`. `main`'s `decks/` is frozen,
  kept only for old apps. `decks-next` is retired. `decks/themes.yaml` is
  bundled in the app, so it is edited only on main. Deck content never needs
  a release.
- **Deck index** (owner, 2026-10-23). `decks/index.json` is regenerated on
  `decks-live` by its workflow after each merge (`.github/workflows/deck-index.yml`,
  PR #719). The review queue (`decks/review-queue.json`) is regenerated there
  too. Never run `tools/deck_index.py` locally: it runs the full
  validator. On a conflict in `decks/index.json`, take `decks-live`'s side.

## Mockups, issues and dependencies

- **Mockups** follow `docs/mockups/README.md`: build the approved specs
  exactly, never rewrite one without approval, and adapt the older ones.
  Each uses the app's real theme, light and dark, 1.4x text (the app's
  cap, #505), a contrast self-check, and Hindi and Bengali examples, and
  is checked in Chromium. Remove a mockup once its feature is built
  (owner, 2026-10-16: "Remove when built").
  The page holds only the screens and their tweak controls, with what
  changed highlighted (not for a complete overhaul, where everything is
  new); the self-checks and the notes go in a Markdown file of the same
  name beside it, such as `progress-mastery.md` for `progress-mastery.html`
  (owner, 2026-10-22: "keep the self checks and notes separate in an md
  file with the same name as the mockup. Always. Keep the mockup clean").
- **Text size: 1.4x only** (owner, 2026-10-17: "We are now only building
  for 1.4x text"). The app caps text at 1.4x (#505), so layouts, layout
  tests and bug reports go up to 1.4x; a phone set to 2x is drawn at 1.4x.

### The `direct-code` label (owner, 2026-10-12)

Label an issue `direct-code` once every decision on it is made: the owner's
answers are in the issue, and any mockup it needs is approved. A
contributor can then build it as written, without asking anything. Remove
the label if a new question comes up, and add it when the last one is
answered.

Keep some simple `direct-code` issues for contributors (owner, 2026-10-17:
"You can keep some simple direct-code issues for the contributor as
well"). Leave them the small, self-contained ones, such as a UI bug or a
one-screen tweak. The deck and review work, and anything a deck build
waits on, is built here.

### Dependencies are marked, never assumed (owner, 2026-10-12)

When one issue needs another done first, record it on GitHub: set "blocked
by" between the issues and add the `blocked` label. Never rely on both
landing in the same milestone, or on any other timing.
