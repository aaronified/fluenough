# Plan: replace SM-2 with FSRS

Written 2026-10-05.

## What the owner asked

> replace SM-2 with FSRS

## What exists

- `lib/core/scheduling/sm2.dart` schedules each `(card, mode)` pair with
  SM-2: repetitions, ease, interval in days, due date and lapses. ADR-0005
  chose SM-2 over FSRS for being about a hundred lines with no dependency,
  and kept the whole review log so that FSRS could later replay it. FSRS is
  on the ROADMAP under "Later".
- The grades the app records are 1, 3, 4 and 5:

  | Grade | Recorded for |
  |---|---|
  | 1 | a wrong answer, "Again", a typo counted wrong, a missed match |
  | 3 | "Hard", a typo judged known, an answer typed in Latin letters |
  | 4 | "Good", a right choice, a right reading question |
  | 5 | "Easy", an answer typed exactly |

- The database (schema version 4):
  - `reviews` is append-only, and the schema refuses UPDATE and DELETE on
    it. Besides the grade, every row stores SM-2's interval and ease before
    and after (`interval_before`, `interval_after`, `ease_before`,
    `ease_after`; the "after" columns are not null). A CHECK keeps grades
    between 0 and 5.
  - `card_states` is a derived cache of the SM-2 state. It can be emptied
    and rebuilt from `reviews`.
- The backup file (`log_jsonl.dart`) holds only grades and times, not SM-2
  fields, so backups made before the change replay under FSRS as they are.
- SM-2 is also used by:
  - the rating buttons, which preview each rating's interval;
  - leeches, which count lapses;
  - quick revision (ADR-0029), which records only misses, because SM-2 has
    no rule for reviewing early.

## What FSRS is

FSRS-6, the current version, models each pair's memory with three numbers:

- **difficulty** D, from 1 to 10;
- **stability** S, the number of days until the chance of recall falls to
  90%;
- **retrievability** R, the chance of recall now.

The next review is set for when R falls to the *desired retention*, 0.9 by
default. FSRS-6 has 21 parameters, and takes four ratings: Again, Hard,
Good, Easy.

The Dart package [`fsrs`](https://pub.dev/packages/fsrs), version 2.0.1
from open-spaced-repetition (MIT), implements FSRS-6 scheduling in pure
Dart. Its only dependency is `meta`. It does not include the optimiser, the
part that fits the 21 parameters to one learner's history. That exists only
in the Rust and Python versions.

## What it takes

1. **Map grades to ratings:** 1 → Again, 3 → Hard, 4 → Good, 5 → Easy.
   Whether an answer typed exactly should count as Easy is a question for
   the owner. FSRS pushes Easy cards much further out.
2. **A scheduler in `lib/core/scheduling`** with SM-2's shape, a pure
   `next` and `replay`, but FSRS inside. The package can be used directly,
   or FSRS-6's formulas ported into a file of our own (about 200 lines).
   Either way `lib/core` stays free of Flutter.
3. **Database migration to version 5:**
   - `card_states` gets stability, difficulty and FSRS's learning state, and
     loses ease and repetitions. It is rebuilt by replaying the log.
   - `reviews` cannot lose columns: it is append-only, and changing it other
     than by adding columns needs the owner's answer (AGENTS.md). One way is
     to add nullable `stability_after` and `difficulty_after` columns and
     keep writing the interval. `ease_after` is not null, so it needs a value
     or a table rebuild.
4. **Replay the whole log through FSRS on upgrade.** Every due date moves at
   once, so the due count on Today may jump the first day. A one-time note
   could say why.
5. **Same-day steps:** FSRS can re-ask a card minutes later while it is
   learnt (learning steps, 1 and 10 minutes by default), or rely on FSRS-6's
   own handling of same-day reviews. A session asks each item once, so
   steps would mean re-asking within a session.
6. **Quick revision:** FSRS models an early review (R is high, so the gain
   in stability is small), so quick revision could record right answers
   too. That would change ADR-0029, so it is the owner's call.
7. **Rating buttons** preview FSRS's interval for each rating. Leeches
   count lapses as before.
8. **Tests:** port `sm2_test.dart`. Check that the replay matches the
   package's own results. Check properties: a better rating never gives a
   shorter interval, and a lapse resets stability.
9. **Docs:** a new ADR, superseding ADR-0005's choice of SM-2 but keeping
   its log and per-pair scheduling. Update the README and the ROADMAP.

Later: fit the parameters to each learner's history. That needs the Rust
optimiser on the phone (through FFI) or offline, and a long enough history.
Start with the default parameters.

## To decide

- The `fsrs` package, a new dependency (AGENTS.md asks for your answer), or
  a port of the formulas of our own.
- Whether an answer typed exactly is Easy or Good.
- The desired retention: 0.9 by default.
- What `reviews` keeps: new nullable columns, or a rebuild of the table.
- Learning steps within a session, or none.
- Whether quick revision then records right answers too.
- One set of parameters for every skill, or one per skill. See
  `difficulty-by-skill.md`.

## Estimate

About 6–8 hours, most of it the migration and the replay tests. Confidence:
medium.
