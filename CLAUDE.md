See [AGENTS.md](AGENTS.md) for how to work in this repository.

Read it before making changes. It is short, and three of its rules — card ids
are permanent, YAML scalars must be quoted, and `lib/core` stays free of
Flutter imports — protect against mistakes that pass every test.

## Which model does what (owner, 2026-10-09)

When work is handed to subagents or workflows, pick the model by the job:

| Job | Model |
|---|---|
| Docs, reviews and audits | Sonnet |
| Writing decks | Haiku at low effort, reviewed by Sonnet at medium effort (owner, 2026-10-17) |
| Fan-outs and large reads | Haiku |
| Small coding jobs and bug fixes | Sonnet, reviewed by Opus (owner, 2026-10-16) |
| Complex coding that touches several files | Opus |
| UI mockups | Opus (Sonnet was not enough, owner, 2026-10-12) |

"All small coding jobs will be by sonnet from now on. Only complex ones that
touch multiple files will be via opus." (owner, 2026-10-16)

**Bug fixes are only for decks and reviews** (owner, 2026-10-16: "Don't do
bugfixes that are not relevant to decks and reviews"). Others wait for a
contributor.

At most **two Opus agents run at the same time** (owner, 2026-10-09). The
quota is shared: each Opus slot left unused buys 1.5 Sonnet agents, and each
Sonnet slot 1.5 Haiku agents (so one Opus slot = 1.5 Sonnet = 2.25 Haiku).
Pause and queue Opus work rather than run a third; prefer the cheaper model
wherever the table above allows it.

## How the owner works (owner, 2026-10-11)

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
  tests) and one review finds nothing blocking. Never run the tests or
  the deck validator locally (owner, 2026-10-17: "You should not run tests
  locally at all"; on the validator: "Why not let ci do it?"): commit,
  push, and read CI's result. The owner approves it in review; then merge it
  once CI is green (owner, 2026-10-16, on #529: "I have approved it in
  review. So you should be able to merge").
- **Commit and push often** (owner, 2026-10-15: "Keep committing and pushing
  to a branch frequently"). Long work is committed in small steps and pushed
  to a work branch (`wip/<topic>`) as it goes, so nothing is lost if a
  session ends. Only checked, approved work reaches main or `decks-next`.
- **Releases.** Bump `pubspec.yaml` and `lib/app/app_info.dart`, check with
  `tools/check_release_version.py`, write the release's CHANGELOG.md entry
  (owner, 2026-10-16: "I will not write changelog"), and open the release
  pull request. The owner tags the release. Deck content (new or filled decks, paths)
  is not part of a release and stays out of its CHANGELOG entry (owner,
  2026-10-19: "This has nothing to do with the release. It is content."). The release
  pull request needs no CI: merge it once opened (owner, 2026-10-19: "The
  release PR doesn't need CI. Just merge it").
- **Questions.** Ask them as soon as they come up. Record the owner's
  answers, quoted and dated, in the plan and the issue they belong to.
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
- **Text size: 1.4x only** (owner, 2026-10-17: "We are now only building
  for 1.4x text"). The app caps text at 1.4x (#505), so layouts, layout
  tests and bug reports go up to 1.4x; a phone set to 2x is drawn at 1.4x.
- **Content.** Keep transliteration in deck prose, and say in a card's notes
  when its base word changes its stem (`docs/DECK-FORMAT.md`).
  Telugu readings write a word-final anusvara (ం) as `ṁ`, course-wide
  (owner, 2026-10-19).
- **Reviewers** are bilingual and the meaning of a card never changes; new
  themes come only by pull request (`docs/plans/reviewing-scope.md`).
- **CI.** A deck-only change needs only "Validate decks" and "Released app
  reads the decks" green (#524, owner, 2026-10-17).
- **Budget.** Tokens are limited: one review per change, no extra
  verification passes, and no new work unless the owner asks for it.

## Decks before 0.6.0 (owner, 2026-10-18)

"Do not start work on 0.6.0 at all before the full deck work, across all
languages." No 0.6.0 issue is started, planned in code, or built until the
deck work is done.

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

**Deck priority** (owner, 2026-10-18). Decks are built to B1 in this order:
1. Telugu, 2. Bengali, 3. Spanish, 4. Marathi, 5. Kannada, 6. Assamese,
7. Chinese, 8. Hindustani, 9. Japanese, 10. Korean. "Once these decks are
done till B1 and we have added the movies songs books parts, we can
finally start advertising the app." Other languages' paths and decks
follow.

**Hindustani** is one course (owner, 2026-10-18: "Hindi and Urdu should be
combined as we should not care about socipolitics over linguistics"; chose
"One course, two scripts"). The `hi` course and its card ids stay; it is
renamed Hindustani, teaches the shared colloquial vocabulary, and offers
Devanagari or the Perso-Arabic (Urdu)
script as the learner's script, as Punjabi offers
Gurmukhi or Shahmukhi. Sanskrit- and Persian-leaning synonyms go on the
card. The Urdu path (#602) is folded into it.

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
