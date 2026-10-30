The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

See [AGENTS.md](AGENTS.md) for how to work in this repository.

Read it before making changes. It is short, and three of its rules — card ids
are permanent, YAML scalars must be quoted, and `lib/core` stays free of
Flutter imports — protect against mistakes that pass every test.

## Which model does what (owner, 2026-10-22)

The main session only orchestrates agents; it does not write code or decks
itself. Pick the model by the job:

| Job | Model |
|---|---|
| All coding, small or multi-file, and bug fixes | Sonnet |
| UI mockups | Sonnet |
| Building decks | Haiku |
| Reviews (one per PR, decks included) | Sonnet |
| Routine doc updates, CHANGELOG lines, find-and-replace | Haiku |
| Skills, ADRs, audits, keeping several docs consistent | Sonnet |
| Fan-outs and large reads | Haiku |

At most **three agents run at the same time, and never more than two
Sonnet** (owner, 2026-10-22). This replaces the earlier Opus rules
(2026-10-09, 2026-10-12, 2026-10-16, 2026-10-17).

**Slots** (owner, 2026-10-23: "1 haiku and 1 sonnet (reviews and associated
bug fixes) keep on decks. 1 sonnet on the today chain."): one Haiku and one
Sonnet keep on decks, and the Sonnet takes reviews and their associated bug
fixes. One Sonnet runs the Today chain (#722, #723, #724; their mockups are
done together on one page). This replaces the earlier slot rules (2 Haiku
deck agents; reviews only in the coder's gaps).

**Opus only when the owner explicitly asks**, reviews included (owner,
2026-10-22). Nothing defaults to Opus.

**Reviews** (owner, 2026-10-22): one Sonnet review per pull request. A second
review runs only if the first caught a breaking bug, and it is also Sonnet.
Ratings are opt in (`.claude/skills/work-rating/SKILL.md`).

**Bug fixes are only for decks and reviews** (owner, 2026-10-16: "Don't do
bugfixes that are not relevant to decks and reviews"). Others wait for a
contributor.

## How the owner works (owner, 2026-10-11)

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
  (or to `decks-next`). Before it merges, CI's checks pass (`flutter
  analyze`, the full `flutter test`, the deck validator and the tools'
  tests) and one review finds nothing blocking (see "Which model does what").
  The owner approves it in review; then merge it
  once CI is green (owner, 2026-10-16, on #529: "I have approved it in
  review. So you should be able to merge").
- **Commit and push often** (owner, 2026-10-15: "Keep committing and pushing
  to a branch frequently"). Long work is committed in small steps and pushed
  to a work branch (`wip/<topic>`) as it goes, so nothing is lost if a
  session ends. Only checked, approved work reaches main or `decks-next`.
- **No stray branches** (owner, 2026-10-24). Merged pull requests delete
  their head branch (repo setting). So: never push a branch again after its
  pull request has merged; never push scratch, review or worktree branches;
  and never merge one work branch into another and leave it pushed: open
  its own pull request instead. Agents cannot delete remote branches (the
  session's git proxy refuses it), so list any branch left over for the
  owner to delete. Never ask to delete `decks-next` or an open pull
  request's base.
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
- **Questions.** Ask them as soon as they come up. Record the owner's
  answers, quoted and dated, in the plan and the issue they belong to. For a
  decision, explain the options (what each means and its main downside), then
  ask (owner, 2026-10-22).
- **Readings.** Readings are *based on* ISO 15919. Never say they strictly
  follow it.
- **Milestones are releases** (0.4.4, 0.5.0, 0.6.0, 0.7.0). The milestone's
  description holds its order. Until the roadmap is generated from them
  (#484), update `docs/ROADMAP.md` by hand to match. Tidy issues and plans
  after work lands, and close issues when done. Tag new issues to a
  milestone only as the owner says.
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
- **Content.** Keep transliteration in deck prose, and say in a card's notes
  when its base word changes its stem (`docs/DECK-FORMAT.md`).
  Telugu readings write a word-final anusvara (ం) as `ṁ`, course-wide
  (owner, 2026-10-19).
- **Reviewers** are bilingual and the meaning of a card never changes; new
  themes come only by pull request (`docs/plans/reviewing-scope.md`).
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
- **Budget.** Tokens are limited: one review per change (see "Which model
  does what"), no extra verification passes, and no new work unless the owner asks for it.
- **Never stop anything** unless the owner explicitly asks (owner, 2026-10-23:
  "Never stop anything unless i explicitly ask to.").
- **Deck index** (owner, 2026-10-23). `decks/index.json` is regenerated on
  main by a workflow after each merge (`.github/workflows/deck-index.yml`,
  PR #719). Never run `tools/deck_index.py` locally: it runs the full
  validator. On a conflict in `decks/index.json`, take main's side.

## 0.6.0 (owner, 2026-10-23)

The 2026-10-18 hold on 0.6.0 is lifted (owner, 2026-10-23: "We are working on
0.6.0 anyway"). Deck work and 0.6.0 work go on side by side.

Milestones by week (owner, 2026-10-23: "This week is 0.6.x, next week is
0.7.x"). This week's work, and deck content for existing courses, goes in
0.6.0; next week's (focus tracks #723, cheatsheets #724, the reviewer-mode
overhaul with its onboarding) goes in 0.7.0.

## Repositories off limits (owner, 2026-10-12)

`homelab-stacks` is not part of this work. Never clone or download it, never
modify it, and never push to it, even if it appears in a session's
repositories.

## Tags (owner, 2026-10-12)

Never create or push git tags. Only the owner tags releases.

## The `direct-code` label (owner, 2026-10-12)

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

Every language's path and decks are built here (owner, 2026-10-18: "We
will build the paths for every language that we want here. This is to be
a repository of world's languages. The tower of babel, is to rise
again."). This replaces the 2026-10-17 rule that only Telugu and Bengali
were built here; the other courses' decks (#420) and the new courses'
paths are no longer left to contributors.

**Deck priority** (owner, 2026-10-18). Decks are built in this order:
1. Telugu, 2. Bengali, 3. Spanish, 4. Marathi, 5. Kannada, 6. Assamese,
7. Chinese, 8. Hindustani, 9. Japanese, 10. Korean, 11. Toki Pona (owner,
2026-10-20: "Make it high priority (11th language)"). Decks stop at A1
(owner, 2026-10-23: "Stop the deck work after A1. You need to work on
codes."): no new B1 units. B1 batches already open as PRs are merged. This
replaces the 2026-10-18 target of B1. The owner's earlier "Once these decks
are done till B1 and we have added the movies songs books parts, we can
finally start advertising the app." is superseded for the B1 part. Other
languages' paths and decks follow.

**Toki Pona to B1, then stop** (owner, 2026-10-23: "once the current one is
done fully complete toki pona to B1. then stop the deck work"; "1 PR").
Toki Pona is the one exception to the A1 stop: its units 18 to the B1
milestone are written in a single PR. After that no new deck work starts;
open deck PRs are still reviewed and merged. Conversations (#722) are a
long-horizon ask (owner, 2026-10-23).

**Bengali, Hindustani and Spanish to full B1, and French A1** (owner, 2026-10-30: "Build the bengali, hindustani, and spanish decks to full B1. And add french A1. Haiku deck builders. Sonnet reviews. Also, make all decks compliant with the full [] IPA notations."). This lifts the 2026-10-23 A1 stop for these three courses: the planned A2 and B1 units of bn, hi and es are built (Haiku builds, one Sonnet review per pull request), in that order, then French A1 (a new course: path units, cores and English layers, facts file). Every card also gets its narrow IPA in `[ ]`: the `phonetic` field of docs/plans/ipa-revamp-and-language-phonology.md, written by the tools of that plan, never by hand, and any card still lacking a broad `ipa` is given one. The A1 stop still holds for every other course.

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

## Dependencies are marked, never assumed (owner, 2026-10-12)

When one issue needs another done first, record it on GitHub: set "blocked
by" between the issues and add the `blocked` label. Never rely on both
landing in the same milestone, or on any other timing.

## Contributor DhyanendraSinghSikarwar (2026-10-13)

When the session's GitHub user is `DhyanendraSinghSikarwar`, these rules
replace "Push straight to main" above:

- **Author.** Before the first commit, run:
  `git config user.name "DhyanendraSinghSikarwar"` and
  `git config user.email "87273551+DhyanendraSinghSikarwar@users.noreply.github.com"`.
- **Trailer.** End each commit message with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No
  `Claude-Session` line.
- **Branches and PRs.** One branch and one PR per issue, named
  `issue-<n>-<slug>`. Work without an issue uses a branch name without a
  number. Never push to main.
- **Commits.** One commit per fix, even within a PR. Push each one as soon
  as it is made.
- **Skills.** Use the repo's skills in `.claude/skills/`.
- **Decisions.** Ask whenever in doubt. Never decide alone.
