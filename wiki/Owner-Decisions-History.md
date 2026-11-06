# Owner decisions history

Source of truth: this wiki page.

Owner decisions that no longer govern, or that applied for one week, moved
out of `CLAUDE.md` on 2026-11-02 so that the file agents read every session
holds only the rules in force. Nothing was dropped: each rule and each owner
quote is kept here as it was written, with the rule that replaced it. The
rules in force are in `CLAUDE.md` ([Agentic-Coding](Agentic-Coding) copies
it).

The restructure was decided by the owner on 2026-11-02 ("Wiki is the main
home for all docs. other docs are obsolete"; `CLAUDE.md` restructured: rules
summary at the top, rules grouped under five headings, history moved to a
wiki page, every quote kept).

The old heading "How the owner works (owner, 2026-10-11)" held most of the
bullets. They are now grouped in `CLAUDE.md` under five headings (Agents and
models; Git, PRs and CI; Releases and milestones; Content and decks;
Mockups, issues and dependencies), each bullet with its own date and quote.

## 0.6.0 (owner, 2026-10-23)

Both weeks have shipped, so this is history.

The 2026-10-18 hold on 0.6.0 is lifted (owner, 2026-10-23: "We are working on
0.6.0 anyway"). Deck work and 0.6.0 work go on side by side.

Milestones by week (owner, 2026-10-23: "This week is 0.6.x, next week is
0.7.x"). This week's work, and deck content for existing courses, goes in
0.6.0; next week's (focus tracks #723, cheatsheets #724, the reviewer-mode
overhaul with its onboarding) goes in 0.7.0.

## Rules that were replaced

Each entry gives the sentence that stood in `CLAUDE.md`, then the earlier
rule it replaced, as it was written (from the file's git history).

### The agent slot split (owner, 2026-10-22, 2026-10-23)

Replaced by the 2026-11-06 rule in `CLAUDE.md`, under "Which model does what":
"one Haiku deck builder, one Sonnet coder, and an extra Sonnet only while a
review runs, for a deck or a code PR". The three-agent cap, with no more than
two Sonnet, is kept.

In `CLAUDE.md`, under "Which model does what (owner, 2026-10-22)", as it
stood on 2026-11-02:

> At most **three agents run at the same time, and never more than two
> Sonnet** (owner, 2026-10-22).
>
> **Slots** (owner, 2026-10-23: "1 haiku and 1 sonnet (reviews and associated
> bug fixes) keep on decks. 1 sonnet on the today chain."): one Haiku and one
> Sonnet keep on decks, and the Sonnet takes reviews and their associated bug
> fixes. One Sonnet runs the Today chain (#722, #723, #724; their mockups are
> done together on one page).

### The Opus rules (2026-10-09, 2026-10-12, 2026-10-16, 2026-10-17)

In `CLAUDE.md`, under "Which model does what (owner, 2026-10-22)": "At most
three agents run at the same time, and never more than two Sonnet (owner,
2026-10-22). This replaces the earlier Opus rules (2026-10-09, 2026-10-12,
2026-10-16, 2026-10-17)."

The earlier rules, as they stood on 2026-10-17 under "Which model does what
(owner, 2026-10-09)":

> When work is handed to subagents or workflows, pick the model by the job:
>
> | Job | Model |
> |---|---|
> | Docs, reviews and audits | Sonnet |
> | Writing decks | Haiku at low effort, reviewed by Sonnet at medium effort (owner, 2026-10-17) |
> | Fan-outs and large reads | Haiku |
> | Small coding jobs and bug fixes | Sonnet, reviewed by Opus (owner, 2026-10-16) |
> | Complex coding that touches several files | Opus |
> | UI mockups | Opus (Sonnet was not enough, owner, 2026-10-12) |
>
> "All small coding jobs will be by sonnet from now on. Only complex ones that
> touch multiple files will be via opus." (owner, 2026-10-16)
>
> At most **two Opus agents run at the same time** (owner, 2026-10-09). The
> quota is shared: each Opus slot left unused buys 1.5 Sonnet agents, and each
> Sonnet slot 1.5 Haiku agents (so one Opus slot = 1.5 Sonnet = 2.25 Haiku).
> Pause and queue Opus work rather than run a third; prefer the cheaper model
> wherever the table above allows it.

Before that, on 2026-10-09: docs, reviews and audits Sonnet; writing decks
Sonnet; fan-outs and large reads Haiku; fixing and coding Opus; at most two
Opus agents at once, with the same quota exchange.

For a day the replacement also read: "One Sonnet slot is kept for coding
(owner, 2026-10-23); reviews and other Sonnet work share the other." The slot
rules below replaced that sentence.

### The slot rules

In `CLAUDE.md`, under "Slots": "This replaces the earlier slot rules (2 Haiku
deck agents; reviews only in the coder's gaps)." The earlier rules were the
sentence above, "One Sonnet slot is kept for coding (owner, 2026-10-23);
reviews and other Sonnet work share the other.", and two Haiku deck agents,
with reviews run only in the coder's gaps.

### Only Telugu and Bengali are built here (owner, 2026-10-17)

In `CLAUDE.md`, under "Every language's path and decks are built here": "This
replaces the 2026-10-17 rule that only Telugu and Bengali were built here; the
other courses' decks (#420) and the new courses' paths are no longer left to
contributors." (`CLAUDE.md` keeps the part after the semicolon.)

The earlier rule: "Only the Telugu and Bengali decks are built here in full
(owner, 2026-10-17: "You will only build the telugu and bengali decks in
full. Other decks will then be marked as direct-code"; on when: "Now"). The
other courses' decks (#420) are `direct-code`, for contributors."

### The B1 target of the deck priority (owner, 2026-10-18)

In `CLAUDE.md`, under "Deck priority": "This replaces the 2026-10-18 target of
B1. The owner's earlier "Once these decks are done till B1 and we have added
the movies songs books parts, we can finally start advertising the app." is
superseded for the B1 part."

The earlier rule, as it stood on 2026-10-22: "**Deck priority** (owner,
2026-10-18). Decks are built to B1 in this order: 1. Telugu, 2. Bengali, 3.
Spanish, 4. Marathi, 5. Kannada, 6. Assamese, 7. Chinese, 8. Hindustani, 9.
Japanese, 10. Korean, 11. Toki Pona (owner, 2026-10-20: "Make it high priority
(11th language)"; built next week). "Once these decks are done till B1 and we
have added the movies songs books parts, we can finally start advertising the
app." Other languages' paths and decks follow."

### The second list to B1 (owner, 2026-11-06, replaced the same day)

The first correction of 2026-11-06 made the second list a B1 target: "Complete the placement fix, then carry on with the decks. On the 1st list of languages, get the situations cards before the all A1. Both will come after the 2nd list gets B1." The owner then replaced it the same day: "Ok, sorry. 2nd list A1 and all languages first deck only. Only classical sanskrit to B1." The second list therefore stays at A1 as set on 2026-11-02 ("the second list to A1"), and only Classical Sanskrit goes to B1. See "Deck order after the placement fix" in `CLAUDE.md`. Nothing about A1 was superseded.

### Push straight to main (owner, 2026-10-11)

`CLAUDE.md` still says, in "Pull requests for everything else": "(owner,
2026-10-16: "Do use PRs for everything", replacing "Push straight to main" of
2026-10-11)". The 2026-10-11 rule, under "How the owner works (owner,
2026-10-11)":

> **Push straight to main.** Documentation, plans and the 0.5.0 work go
> directly to main, with no pull request. Push only after the checks pass:
> analyze, the full test suite (read its "All tests passed" line, not just
> the last line of output), the deck validator and the tools' tests, and
> after one Sonnet review finds nothing blocking.

## Contributor DhyanendraSinghSikarwar (2026-10-13)

These rules apply only to the contributor session named here. `CLAUDE.md`
keeps one sentence that points to this section.

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

See also: [Agentic-Coding](Agentic-Coding) · [ADR-0044](ADR-0044-Documentation-Lives-In-The-Wiki) · [Home](Home)
