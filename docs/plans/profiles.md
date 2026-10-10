# Plan: profiles, a PIN lock, and parental supervision

Written 2026-10-10. Tracks #204 (profiles and a PIN lock) and #97 (child
lock), which this plan widens into parental supervision.

## What the owner asked

> In the user account plan, make sure to add parental supervision on kids'
> profiles. They will not get any abuse related content, not even the
> similar sound indication.
>
> The admin user can allow or disallow anything related to their learning,
> including holding off whole languages.

## What exists

- Settings shows Profiles and PIN lock as "Feature incoming"
  (`Feature.profiles`, `Feature.pinLock` in `lib/app/features.dart`).
- One learner per phone: one log, one set of schedules, one set of
  settings.
- Offensive words sit behind the 18+ setting (#96), with sound-alike and
  look-alike warnings on words like them (`offensive-words.md`).

## Profiles (#204)

- More than one learner on a phone, each with their own log, schedules
  and settings.
- A PIN per profile, asked when it opens.

## Parental supervision (#97, widened)

**Roles.** One profile is the **admin** (the parent). The admin marks any
other profile as a **child profile**, protected by the admin's PIN, which
is separate from the child's own profile PIN.

**No abuse-related content, ever, in a child profile** (owner,
2026-10-10). This is not a setting the admin can turn on:

- offensive and adult decks (`audience: adult`, #96) are never listed,
  downloaded or shown;
- **no sound-alike or look-alike warnings** either: the "Careful: said
  slightly wrong, this sounds like an offensive word" note is not shown,
  and nothing hints that an offensive word exists;
- no offensive word in any drill, reading, search, Inspect or deck
  page;
- reviewer mode is not available, so the separate offensive-words review
  cannot be reached.

**The admin allows or disallows anything about the child's learning**
(owner, 2026-10-10), from the admin's view of the child profile:

- **whole languages:** hold a language off entirely, so the child can't
  choose it in the picker and its decks don't download for that profile;
- **courses and decks:** hide a course, a unit or a deck;
- **activities:** turn each drill kind on or off (speaking, listening,
  writing, grammar), and the skills' Settings switches (#243);
- **settings that change data,** locked by default: reset or delete
  progress, import or export the log, add decks (#22), delete the
  profile, switch profiles, Deck downloads;
- **time:** an optional daily limit, after which Today says "done for
  today".

**Unlocking.** The admin's PIN unlocks the child profile's locked
settings for the session. A forgotten admin PIN uses the recovery the
profile PIN has (`pinForgotBody`), which must not be something a child
can do alone.

**Not this plan.** Locking the whole phone: Android's screen pinning and
Family Link do that, and the help text points to them.

## Tests

- A child profile never lists, downloads or shows an adult deck, and
  never shows a sound-alike or look-alike warning, even when the deck
  files carry them.
- Every data-changing action is refused without the admin PIN, with a
  test for each.
- A held-off language is missing from the child's picker and downloads.
- A turned-off activity never appears in the child's lessons or reviews.

## To decide

- Whether the admin can see the child's progress from their own profile.
- Whether a child profile can be made from first launch, or only from an
  existing admin profile.

## Estimate

About 3–5 days for profiles and the PIN lock (#204), then 3–5 days for
parental supervision (#97), with tests. Confidence: low; nothing is built
yet.
