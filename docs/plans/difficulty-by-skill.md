# Plan: difficulty by skill and by card

Written 2026-10-05.

## What the owner asked

> separate difficulty by skill and card (eg. recognition and reproduction
> of a word are different skills, and so are listening and speaking)

## What exists

- **Schedules are already separate by skill.** Since ADR-0005 each
  `(card, mode)` pair has its own state: recognition, production,
  listening, speaking, grammar and reading. Each has its own SM-2 ease. So a
  word that is easy to recognise but hard to say already comes back sooner
  for speaking.
- **Lesson difficulty is not.** `Difficulty.of(card)` in
  `lib/core/scheduling/lesson.dart` gives one difficulty per card, for every
  skill:
  - hard: a phrase, a sentence of three words or more, or a grammar cell;
  - medium: two words, or seven letters or more, counted in the reading;
  - easy: the rest.
- A lesson takes three cards of each difficulty and picks each card's
  questions by that one difficulty (`lessonQuestions`):

  | Difficulty | Check after teaching | Exercise |
  |---|---|---|
  | Easy | recognition, by choosing | speaking |
  | Medium | listening, by choosing | match pairs |
  | Hard | production, typed or in word order | speaking |

- So a short word with a retroflex or aspirated sound counts as easy in
  every skill, though it may be hard to hear or to say. A long but plain
  word counts as medium in every skill. Nothing else uses `Difficulty`.

## What it takes

1. **A difficulty per card and skill**, `Difficulty.of(card, skill)`,
   computed from what makes that skill hard. Every card now has its IPA
   (#180), which makes the sound-based measures computable:

   | Skill | What makes it hard |
   |---|---|
   | Recognition (see → meaning) | length; conjunct letters; known words that look alike |
   | Production (meaning → word) | length; conjuncts; letters written but not said, as the inherent vowel dropped |
   | Listening (hear → meaning) | the language's contrasts in `<lang>-sounds.yaml` (aspirated or not, retroflex or dental, long or short); known words that sound alike |
   | Speaking (meaning → say) | sounds the learner's own languages lack, from the IPA; length |

2. **Learned difficulty per pair**, once the pair has reviews. Today that
   is SM-2's ease; with FSRS (`fsrs.md`), it is the pair's difficulty D.
   That is already per skill, and can feed lessons and quick revision.
3. **Lessons pick by the skill asked.** The three easy, three medium and
   three hard stay, but each card's questions are chosen by its difficulty
   in each skill. A word easy to read but hard to hear gets an easy check
   and a harder listening question.
4. **Inspect** can show a card's difficulty in each skill.
5. **Tests:** the measures on known words, such as పాలు and పలు, which
   differ only in vowel length and so should be hard to hear; and lesson
   plans by skill.

FSRS can also keep separate parameters per skill, which would let listening
forget faster than recognition. That depends on `fsrs.md`.

## To decide

- Whether speaking difficulty depends on the languages the learner speaks
  (retroflex sounds are hard for an English speaker, not for a Hindi one).
- What a lesson's three of each difficulty counts by: the hardest skill, the
  skill asked first, or each skill on its own.
- Whether quick revision picks the hardest words first, by learned
  difficulty, rather than at random as now.

## Estimate

About 4–6 hours. The measures need tuning on real cards. Confidence:
medium-low.
