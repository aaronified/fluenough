# Review log backup format, version 1

Settings → Export review log saves a profile's history as one UTF-8 text
file, `fluenough-<profile>-reviews.jsonl`. Import review log reads such a
file back. The format is [JSON Lines](https://jsonlines.org): one JSON object
per line, `\n` between them.

The file holds what happened, never scheduling state. Intervals, ease and
due dates are recomputed from the grades on import, so a backup stays valid
whatever the scheduler becomes.

```jsonl
{"format":"fluenough-review-log","version":1}
{"type":"review","ts":"2026-09-28T13:34:05.678Z","deck":"hi-en-market","card":"hi-en-market-0001","mode":"production","grade":4,"elapsed_ms":3120,"answer":"बाज़ार"}
{"type":"review","ts":"2026-09-29T02:10:00.000Z","deck":"hi-en-market","card":"hi-en-market-0001","mode":"recognition","grade":3,"elapsed_ms":2400}
{"type":"leech","ts":"2026-10-02T11:00:00.000Z","deck":"hi-en-market","card":"hi-en-market-0001","mode":"production","kind":"setAside"}
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
| `deck` | yes | Deck id. |
| `card` | yes | Card id, permanent (AGENTS.md rule 1). |
| `mode` | yes | `recognition`, `production`, `listening` or `grammar`. |
| `grade` | yes | SM-2 grade, a whole number 0–5. |
| `elapsed_ms` | yes | How long the answer took, in milliseconds. |
| `answer` | no | What was typed. Absent for a self-graded review. |

## `leech` lines

One per action taken on a leech, oldest first: a row of `leech_actions`.

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `leech`. |
| `ts`, `deck`, `card`, `mode` | yes | As for a review. |
| `kind` | yes | `reset`, `undoReset`, `setAside` or `bringBack`. |

## Reading

- Blank lines are skipped.
- A line whose `type` this version does not know is skipped, so an older app
  still reads a newer backup's reviews. A new kind of line never needs a new
  version; a change to an existing line's meaning does.
- Any other malformed line refuses the whole file, naming the line.

## Merging

Import never replaces or deletes. It adds each review the profile does not
already hold, then rebuilds every scheduling state from the whole log in time
order. A review is the same review when its deck, card, mode and `ts`, to the
millisecond, match; a leech action when those and its `kind` match. So:

- importing the same file twice adds nothing the second time;
- a backup from an old phone, imported on a new one that has been used since,
  slots its older reviews in before the new ones.
