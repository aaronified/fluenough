# Review log backup format, version 1

Settings → Export review log saves a profile's history as one UTF-8 text
file, `fluenough-<profile>-reviews.jsonl`. Import review log reads such a
file back. The format is [JSON Lines](https://jsonlines.org): one JSON object
per line, `\n` between them.

The file holds what happened, and of scheduling state only what cannot be
worked out again from it: FSRS's parameters as fitted to the learner, per
language and skill (`parameters` lines). Intervals, stabilities and due
dates are recomputed from the grades on import, with those parameters, so a
restored phone schedules exactly as before, and a backup stays valid
whatever the scheduler becomes.

```jsonl
{"format":"fluenough-review-log","version":1}
{"type":"review","ts":"2026-09-28T13:34:05.678Z","deck":"hi-en-market","card":"hi-0231","mode":"production","grade":4,"elapsed_ms":3120,"answer":"बाज़ार"}
{"type":"review","ts":"2026-09-29T02:10:00.000Z","deck":"hi-en-market","card":"hi-0231","mode":"recognition","grade":3,"elapsed_ms":2400}
{"type":"leech","ts":"2026-10-02T11:00:00.000Z","card":"hi-0231","mode":"production","kind":"setAside"}
{"type":"parameters","ts":"2026-10-03T08:15:00.000Z","language":"hi","mode":"production","w":[0.212,1.2931,2.3065,8.2956,6.4133,0.8334,3.0194,0.001,1.8722,0.1666,0.796,1.4835,0.0614,0.2629,1.6483,0.6014,1.8729,0.5425,0.0912,0.0658,0.1542],"reviews":1480,"loss_before":0.3412,"loss_after":0.3297}
```

## Header

The first non-blank line. A file without it is not a review log.

| Field | Notes |
|---|---|
| `format` | Always `fluenough-review-log`. |
| `version` | `1`. An app refuses a file whose version is newer than it reads. |

## `review` lines

One per answered card, oldest first: a row of the `reviews` table
([DESIGN.md](DESIGN.md)).

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `review`. |
| `ts` | yes | When it was answered: ISO 8601, in UTC. Read back in local time. |
| `deck` | yes | The deck it was answered in. Not part of the pair: a card listed in several decks has one schedule (ADR-0018). |
| `card` | yes | Card id, permanent (AGENTS.md rule 1). |
| `mode` | yes | `recognition`, `production`, `listening`, `grammar` or `speaking`. |
| `grade` | yes | The grade, a whole number 0–5, read by FSRS as a rating (ADR-0033): 0–2 Again, 3 Hard, 4 Good, and 5 Easy when there is no `answer` (the learner rated it), Good when there is (typed exactly). |
| `elapsed_ms` | yes | How long the answer took, in milliseconds. |
| `answer` | no | What was typed, or for `speaking` what the recogniser heard. Absent for a self-graded review, and only then: its absence makes a grade of 5 Easy. |

## `leech` lines

One per action taken on a leech, oldest first: a row of `leech_actions`.

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `leech`. |
| `ts`, `card`, `mode` | yes | As for a review. An action is on the pair, in whichever deck; a `deck` from an older file is ignored. |
| `kind` | yes | `reset`, `undoReset`, `setAside` or `bringBack`. |

## `parameters` lines

One per language and skill that has been fitted (Settings → Adjust to me,
or the automatic refit; `docs/plans/skill-model.md`), after the reviews and
leech actions, by language and then mode: a row of `fsrs_parameters`.

A fit starts from the one before it, so these cannot be worked out again
from the reviews; they are the one piece of scheduling state a backup
keeps. A language with none for a skill is scheduled with that skill's set
from the language most recently studied, else FSRS-6's defaults.

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `parameters`. |
| `ts` | yes | When the fit ran: ISO 8601, in UTC. |
| `language` | yes | The language learned, as card ids name it: `hi` for `hi-0231`. |
| `mode` | yes | The skill, as for a review. |
| `w` | yes | FSRS-6's 21 parameters, w0 to w20, in use for the skill from that fit on. Each must lie within the range fitting clips it to (`FsrsFit.isPlausible`): w20 from 0.1 to 0.8, for example. A set outside them refuses the file. |
| `reviews` | yes | The skill's reviews in the language when it was fitted. The automatic refit waits for 10% more. |
| `loss_before`, `loss_after` | no | The log loss, on the fit's window, of the set in use before and of the set the fit gave. The fitted set was kept when `loss_after` is lower; otherwise `w` is the set that was already in use. |

A backup from before fitting has no `parameters` lines, and restores as it
always did: every skill on the defaults until it is fitted.

## Reading

- Blank lines are skipped.
- A line whose `type` this version does not know is skipped, so an older app
  still reads a newer backup's reviews. A new kind of line never needs a new
  version; a change to an existing line's meaning does.
- Any other malformed line refuses the whole file, naming the line.

## Merging

Import never replaces or deletes. It adds each review the profile does not
already hold, and each `parameters` line unless the profile has a later fit
of that language and skill, then rebuilds every scheduling state from the
whole log in time order. A review is the same review when its card, mode
and `ts`, to the millisecond, match; a leech action when those and its
`kind` match. So:

- importing the same file twice adds nothing the second time;
- a backup from an old phone, imported on a new one that has been used since,
  slots its older reviews in before the new ones.
