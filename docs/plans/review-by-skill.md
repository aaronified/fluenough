# Plan: review by skill from Today

Written 2026-10-05. Built in aaronified/fluenough#191, as ADR-0030 records.

## What the owner asked

> also, let the user review stuff by skills in the homepage.
>
> e.g. want to revise all spoken skills

## What exists

- **Today's due card** shows four skill tiles: recognition, production,
  listening and grammar, each with how many due cards drill it. Speaking
  has none. The tiles
  start nothing. Only Start review starts a session, of everything due.
- **A session can already be one skill:** `DrillRequest(skill: …)`, used
  from a deck's page.
- **Quick revision** (ADR-0029) revises 5–20 known words at random, in any
  skill, and records only the misses.

## What it takes

1. **The skill tiles start a review** of that skill's due cards. A tile with
   nothing due starts nothing, as now.
2. **Revise by skill:** quick revision gains a choice of skills, such as
   "Spoken: listening and speaking", or one skill. It then revises known
   words in those skills, due or not, recording the misses as it does now.
3. **Spoken skills** as a group: listening and speaking together, since
   both are by ear and mouth.
4. **Tests** for each tile's session, the skill choice in quick revision, and
   the spoken group.

## Decided with the owner

- "Spoken" means listening and speaking together.
- A tile reviews what is due in its skill. With nothing due, it asks
  whether to revise everything known in it.
- Speaking gets a tile of its own; a sentence tile will follow. Quick
  revision gets the skill choice too.

## Estimate

About 2–3 hours. Confidence: medium.
