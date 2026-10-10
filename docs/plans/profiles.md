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
- **a child can't become a reviewer** (owner, 2026-10-10: "And a child
  cannot become a reviewer"): "Become a reviewer" is not shown, reviewer
  mode can't be turned on, and the admin can't allow it either; so the
  separate offensive-words review can't be reached.

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

**Growing up** (owner, 2026-10-10: "the child will grow up one day. So
the intended way here is for the child to take a download of their
learning history and then upload that in a new adult account without
restrictions"). A child profile is never turned into an adult one in
place. Instead:

- the child's learning history is exported with the review log's export
  (#20); in a child profile that export is one of the locked actions, so
  the admin's PIN allows it;
- it is imported into a new adult profile, which starts with no
  restrictions;
- the export carries the learning history only, never the child
  profile's restrictions, so nothing of the supervision follows the
  learner into the adult profile.
- **The app says so** (owner, 2026-10-10: "That needs to be mentioned in
  the plan and in the builds"): where a child profile is made, in the
  admin's view of it, and in the child profile's own Settings, one line
  explains that its limits can't be lifted, and that a grown-up learner
  takes their history to a new adult profile with Export and Import.
  The export, the import into a new profile, and that no restriction
  carries over are each tested.

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
- First launch makes the admin profile and says it is the admin; no child
  profile can be made there.
- Making a child profile is refused until every adult profile has a PIN,
  and an adult PIN can't be removed while a child profile exists.
- The admin sees the child's Progress, read-only.
- A child profile never shows "Become a reviewer", and reviewer mode
  can't be turned on in it, even by the admin.
- A child profile's history, exported with the admin PIN and imported
  into a new adult profile, keeps its reviews and schedules and carries
  none of the restrictions; the line explaining this shows in all three
  places.

## Decided (owner, 2026-10-10)

- **The parent sees the child's progress** from their own profile
  ("Yes"): the admin's view of a child profile shows its Progress,
  read-only.
- **The first profile is the admin** ("Only from an existing admin
  account. The first account will be admin account. This is to be
  explicitly called out when creating the first account"). First launch
  makes the admin profile and says so in so many words: this profile
  manages the others, and child profiles are made from it. A child
  profile is never made at first launch.
- **Every adult profile is locked before a child profile can exist**
  ("all adult accounts on the phone must be locked to create a child
  account"). Making a child profile asks for a PIN on every adult
  profile that has none, and is refused until each has one, so a child
  can't open an unlocked adult profile and its content. While a child
  profile exists, an adult profile's PIN can't be removed.

## Estimate

About 3–5 days for profiles and the PIN lock (#204), then 3–5 days for
parental supervision (#97), with tests. Confidence: low; nothing is built
yet.
