---
name: work-rating
description: Have an independent subagent rate a finished piece of work out of 10 against the user's own prompts, before reporting it complete. Use at the end of any substantial task, when the user asks how good the work was, or whenever a session's requests arrived in fragments and something may have been dropped.
---

# Rate the work before calling it done

A closing pass that asks an independent agent one question: **did the work that was done
match the work that was asked for?** It exists because the author of a change is the worst
judge of whether it covered the request — especially in a session where the scope arrived in
pieces, which is when a request goes missing.

## When to run it

- At the end of any task that touched more than a couple of files.
- Whenever the user's requests arrived across several messages, or mid-task.
- When the user asks for a rating, a score, or a check on the work.
- Before reporting a multi-part task complete.

Not worth it for a one-line fix, a question answered in prose, or a task the user is still
actively redirecting.

`session-digest` is the mid-session counterpart, and the two do not overlap: it reports
status repeatedly and cheaply while the work is still moving, and reports the score this
skill produced rather than producing one of its own. Its ledger of the user's prompts —
verbatim, written as each arrived — is also the best source for Step 1's evidence, because it
cannot have drifted.

## The rule that makes the score mean anything

**The rater is never told the target.** It is not told what score counts as passing, what
score previous work received, or that the score has any consequence at all. It is told only
to rate. A rater that knows the pass mark rates to the pass mark, and the number stops
carrying information.

So: do not put a threshold, an expectation, a previous score, or any encouragement in the
prompt you hand it. Hand it the prompts, the work, and nothing else.

Equally: do not soften, re-weight, or argue with the number when reporting it. Report the
score the rater gave, verbatim, with its findings.

## Procedure

### Step 1 — assemble the evidence

Collect, without editorialising:

- **Every prompt the user sent this session, verbatim and in order.** Include the mid-task
  ones. Do not summarise them — a paraphrase is where the request quietly becomes the thing
  that was built.
- **The work**: `git diff` (or `git diff --stat` plus the diff of each file) for uncommitted
  work, or `git log -p <base>..HEAD` for committed work.
- **The verification output**: the actual test / build / lint runs, pass or fail. If none
  were run, say so — that is itself something to be rated.

### Step 2 — spawn the rater

If your runtime supports subagents, spawn one with the body of `.claude/agents/work-rater.md`
as its instructions and pass it the evidence from Step 1. It needs a strong model — this is
judgement, not extraction.

**ITS OWN HELPERS RUN ON THE CHEAP TIER.** The owner's ruling of 27 September: a rater that
fans out, or runs the screenshot bot, does it on the cheap tier. The judgement stays with the
rater; what it hands off is retrieval and capture, and a helper that inherits the rater's deep
tier pays for judgement nobody asked it for. So any agent a rater starts is started on the
cheap tier, and screens are captured through the screenshot runner, which is cheap.

**TWO THINGS IN THAT FILE'S FRONTMATTER ARE LOAD-BEARING and are not to be ignored.**

- `tools: Read, Grep, Glob, Bash` — **no `Edit`, no `Write`.** The rater's most valuable
  technique is breaking the code to see whether a test notices, and the tree under review is
  the one place it may not do that in. Granted edit access, one of them left a shipped SQL
  migration with a delete trigger's `kind` clause stripped, at the moment its caller's
  commit hook was asking for a commit; the file's own section explains the rest.
- Launch it **isolated** if your runtime can — `isolation: "worktree"` in Claude Code's
  Agent tool — so it has a checkout of its own to mutate. It is told to make one anyway,
  because it must not depend on having been launched correctly.

And do not run anything heavy against the same tree while it works: its test runs and yours
compete, and a suite that fails because two things were building at once produces findings
that are not findings.

If your runtime has no subagents, do the pass inline against that same rubric, but say
plainly in the report that the rating is self-assessed rather than independent.

#### No more than five raters, and the commits grouped to fit

The owner's ruling: *"Don't fan out more than 5 raters. Group commits if needed."* When the
work is more commits than five raters can each take one of, group them — by the area they
touch, or by the finding they answer — so that every rater is handed a body of work large
enough to judge. Each rater gets the prompts behind its whole group, and scores each commit
in it.

**WHY A CAP, AND NOT ONE RATER PER COMMIT.** A rater must return a rating, and one handed a
commit with nothing wrong in it reports something anyway. The owner, stopping a fan-out of
twenty-two: *"If you create such minute raters they will start hallucinating issues
resulting in regressions."* It had been measured before it was ruled. In one consuming
repository, pushes rated one commit per rater came back with 40 to 75 findings a round and
never converged, and two commits made while answering those rounds were regressions that a
later round had to catch: a publish job that stopped running, and a pairing code that
outlived a factory reset.

**A RATING THAT FINISHED STILL STANDS WHEN THE FAN-OUT IS STOPPED.** Also the owner's:
*"You can act on whatever raters already rated. If they were more than 8, those commits are
already rated then."* Recover the finished results (a workflow's journal records what each
agent returned) and act on them as on any other round. A commit whose finished rating
already clears the caller's bar is rated. Re-rate only the commits with no result, grouped
as above.

#### Documentation findings are reported, and scored only where a reader meets them

The owner's ruling: *"Make the rater cut rating marks only for actual issues, documentation
problems are non rated issues (still should be reported) unless it is facing the user in the
app or about a wrong claim in readme or wiki."* So every finding is one of two kinds, and the
rater's prompt says which is which. That is part of how to score, not a target:

- **Scored.** A behaviour defect. A test that cannot fail for the defect it names. A breach
  of the repository's rules in code. A documentation problem a reader meets: text a user sees
  in the app (labels, help, errors, sample content), or a wrong claim in the README or the
  wiki.
- **Reported, not scored.** Any other documentation problem: commit bodies, code comments,
  internal notes such as plans, test headers and fixture notes, and wording slips in any of
  them. Each is still listed, still fixed or answered in one line, and marked unscored. None
  of them lowers the number.

**ONE EXCEPTION STAYS SCORED: A FALSE ACCOUNT OF THE WORK.** A body or report claiming a test
ran, a mutation failed, or a thing was done, when it was not, is not a documentation slip. It
is the dishonest report the score weighs most (see *What the score is measuring*).

**WHY.** It was measured before it was ruled. One consuming repository's release took six
rating passes. The last four scored commits below the bar almost entirely for their commit
bodies: a misquote, a miscount, a file named wrong. History there is never rewritten, so each
correction was a new body for the next pass to find fault with, and the loop ended only when
the owner stopped it.

### Step 3 — act on it, then report

1. **Fix what the rater found**, if it found something real, before you report anything. A
   rating is a work item, not a verdict to be filed. Re-run the affected tests after fixing.
2. **Report the score as given**, then the findings, then what you did about each. If you
   disagree with a finding, say so in one line with the reason — do not silently drop it.
3. **Re-rate only after fixing**, and only by handing the rater the new diff. Do not ask it
   to reconsider the same work; that is asking for a better number rather than a better
   answer.
4. **Re-rate at all only when the pass found at least three major findings**, meaning scored
   ones the rater marked high or medium. The owner's ruling: *"if a rater didn't find at least 3
   major issues, no need to rerun rater, regardless of rating."* Fewer than three: fix them all
   and stop, whatever the score. The caller's own bar (a pass mark, say) can only ask for
   fewer passes than this, never more.

## What the score is measuring

Fidelity to the request, in this order of weight: every distinct thing asked for was done;
each piece is complete (migration, second language, test, doc, every call site the rule
reaches); it is correct; it fits the surrounding code; and the report of it is honest.

The last one carries the most weight in both directions. Claiming a suite passed without
running it, describing stubbed work as finished, or narrowing the scope without saying so
should cost more than any implementation flaw.

## Do not

- Do not tell the rater the target. Not the pass mark, not a previous score, not that the
  score has a consequence, and not that you would like it to go well. A rater that knows the
  pass mark rates to the pass mark.
- Do not summarise the prompts before handing them over. A paraphrase is where the request
  quietly becomes the thing that was built.
- Do not soften, re-weight, or round the number when reporting it.
- Do not drop a finding you disagree with. Say so in one line, with the reason, and leave it
  in the report.
- Do not re-rate by asking the same rater to reconsider the same work. That is asking for a
  better number rather than a better answer. Fix first, then hand it the new diff.
- Do not let the agent that did the work rate it, unless the runtime has no subagents — and
  then say in the report that the rating is self-assessed.
- Do not fan out more than five raters, and do not hand a rater a commit too small to judge
  on its own. Group the commits. A rater with nothing real to find invents something, and the
  fix for an invented finding is how a regression gets in.
- Do not throw away a finished rating because the run it was part of was stopped.
- Do not let a rater's helpers inherit its tier. A fan-out or a screenshot run it starts is
  on the cheap tier.
- Do not let a documentation problem the reader never meets lower the score. Report it,
  marked unscored. Only text in the app, or a wrong claim in the README or wiki, is scored,
  and so is a false account of what was run or done.
- Do not treat the score as the deliverable. It is a work item; the fixes are the deliverable.
- Do not run this on a one-line fix, a question answered in prose, or a task the user is still
  actively redirecting.

## Verify

- [ ] Every prompt the user sent this session reached the rater verbatim and in order,
      including the ones that arrived mid-task.
- [ ] The rater was given the diff and the real verification output — or told plainly that
      none was run, which is itself something to be rated.
- [ ] Nothing in the rater's prompt named a threshold, an expectation, a previous score, or a
      consequence.
- [ ] The rater was independent of the work, or the report says the rating is self-assessed.
- [ ] No more than five raters ran, and each was given a group of commits large enough to
      judge.
- [ ] The rater was told which findings are scored and which are reported unscored, and the
      report keeps the unscored ones.
- [ ] A re-rating ran only after a pass with at least three major findings.
- [ ] Every agent the rater started, and every screenshot run, was on the cheap tier.
- [ ] The score is reported exactly as given, alongside its findings.
- [ ] Every finding was either fixed or answered in one line with a reason; none was dropped.
- [ ] The affected tests were re-run after the fixes.
- [ ] Any re-rate was made against a new diff.

---

## Provenance

Copied from [claude-kit](https://github.com/aaronified/claude-kit) (MIT,
Copyright (c) 2026 Aro) and vendored here so it travels with this checkout.
Paths to the rater agent are rewritten for this repository's layout; the
procedure is otherwise unchanged. Fix it upstream as well as here.
