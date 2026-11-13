# Private language package

Source of truth: this wiki page.

A **private language package** is one file, `something.fnzip`, that holds a
whole language, or your own version of a course the app already teaches. You
add it in Settings, Your decks, Add a private language. It stays on your
phone and in your backups; nothing is uploaded or sent anywhere. The plan and
the decisions behind it are in [Plan-Private-Languages](Plan-Private-Languages)
(#1017).

A `.fnzip` is an ordinary zip file with a different name, so any zip tool
opens and makes one. It uses the same files as the repository's decks
([Deck-Format](Deck-Format)): the app reads them with the same code, so
anything a public deck can do, a private one can (levels, hidden decks, the
newer deck kinds).

## Start from something that works

Two buttons on Your decks save a file to edit:

- **Get a starter package** saves a tiny invented language (`qaa`, "Tiny")
  with a comment on every part. Unzip it, change it, zip it again.
- **Download a course to change** lists the courses already on your phone;
  pick one and it saves a package with a copy of that course's decks (see
  below).

The two buttons next to them: **Export** (on a package you added) saves it
back as a `.fnzip`, so you can move it to another phone or keep a copy; **Get
a template** saves the single-deck template (one deck, no package).

## What is in the file

```
manifest.yaml                  required: what the package is
<code>-path.yaml               the path (required when you change a course)
<code>/<deck>.yaml             core decks, as decks/<lang>/ in the repository
<code>/<native>/<deck>.yaml    layers: the meaning in one native language
themes.yaml                    optional own themes
```

Only `.yaml` and `.json` files, in plain-named folders. No fonts, audio or
pictures: a language uses the voices and fonts your phone has.

### The manifest

```yaml
format: "fluenough-private"
package: "fnpd-qaa"            # fnpd- and the language code
revision: 1                    # a whole number; goes up each time you update
kind: "new-language"           # or "modified-language"
based_on: "te-0.10.0"          # for a changed course: what you started from
min_app: "0.9.0"
license: "CC-BY-SA-4.0"        # the only licence a package may have
language:
  code: "qaa"
  iso639_3: "qaa"
  name: "Tiny"
  own_name: "Tiny"             # optional
  script: "latin"
```

- **A new language** takes a code from `qaa` to `qtz` that the app does not
  use (those codes are never an official language, so they can never clash
  later). This version accepts no other code for a new language, even when
  the language has an ISO 639-1 or 639-3 code of its own.
- **A changed course** carries the real code of a language the app teaches,
  such as `te`, and needs the path file.

### Ids

Every id in the package starts with **`fnpd-<code>-`**: the package, each
deck, each layer, each card. A file whose ids lack it is refused, so a private
file can never reach a built-in card.

- **You write the card ids** (`fnpd-qaa-0001`, or a short name) and the app
  never renumbers them.
- **A card id is permanent.** Your progress belongs to the id, so keep it
  when you fix a spelling. The app cannot tell a fix from a new meaning, so
  change the meaning of a card and you keep the old card's progress; give it a
  new id if the card is really another word.
- **An id you drop in an update is retired for good** (the app remembers it,
  even if you remove the package and add it again): a later revision may not
  give it to a different card.

### The path

The path file lists the units in the order they are taught, as in the
repository ([Courses-and-Paths](Courses-and-Paths)). A new language's units
name its own decks. A changed course's path **replaces** the built-in one
while the package is active, and a small "Privately modified" tag shows on the
course; a unit may name the course's own decks (`te-home`) or your copies
(`fnpd-te-home`). Without a path, a new language's decks are one unit in file
order.

## Change a course

1. On Your decks, **Download a course to change**, pick the course.
2. The file has copies of the course's vocabulary and grammar decks and their
   layers with every id rewritten to `fnpd-<code>-`, and the course's own
   path. Facts, sounds, scripts, romanisation, rules decks and reading decks
   are not copied: the app owns them and the path keeps naming them. (How
   many were left out is told when the file is saved.)
3. The path still names the built-in decks, so as it is, the package teaches
   exactly what the course did and every card keeps its progress. To teach
   your version of a deck, edit its copy and change that unit's deck id in the
   path from `te-home` to `fnpd-te-home`. A changed card is a new card: it
   starts fresh, and its built-in twin keeps its progress.
4. A card that replaces a built-in card may say so with `replaces: "te-0001"`;
   the review screen counts them. A card you leave as the course's can stay in
   your deck as `- ref: "te-0001"`, which keeps its progress.
5. Raise `revision` (or add the package for the first time), zip it, and add it
   with Add a private language.

## Check it

Adding a package shows a review before anything is saved: what it holds, and
what was found, by file and line. **Errors** stop it (a safe-to-open problem,
an id without the prefix, a card id twice, a path unit with no deck, a
retired id reused); **warnings** and **notes** never do (a missing reading, a
licence or source note, no voice on your phone).

The same checks run on a computer, with the tools of the repository, before you
send the file to anyone:

```sh
python3 tools/validate_decks.py --private my-package/        # a folder
python3 tools/validate_decks.py --private my-package.fnzip   # or the file
```

It checks the package (names, sizes, manifest, ids, path) and then each deck
and layer with the validator's own rules. Exit code 0 means no error. The
validator refuses a private id anywhere else, so a private package can never be
put under `decks/` by mistake.

## Limits

| Limit | Value |
|---|---|
| The `.fnzip` file | 10 MB |
| Unpacked | 30 MB, and no entry may unpack to more than 100 times its packed size |
| One file | 2 MB |
| Files | 1,000 |
| Cards | 20,000 |
| Private languages on at once | 3 (a fourth asks which to turn off) |
| Languages in all | no limit |

The numbers were measured on the courses of the app: see
[Plan-Private-Languages](Plan-Private-Languages#measured-limits-task-24).
The largest course (Chinese) is 571 files and 4,379 cards, 1.3 MB packed,
about an eighth of the file limit.

## Updating, removing, backing up

- **Update** a package by adding a newer file of the same package: the review
  shows the new, changed and removed cards and the ids that retire. A lower
  revision is refused; an equal one is a reinstall.
- **Remove** keeps your review history, so adding the package again picks your
  progress up; **Remove and delete my progress** is the second, explicit
  choice, after a backup of everything.
- **Backups** carry your private packages (they exist nowhere else), and a
  restore brings them back, on this or another phone ([Backup-Format](Backup-Format)).
  A package already on the phone stays if the backup has no packages.
- **Sharing** is file to file: send the `.fnzip` to a friend. There is no
  upload and nothing to publish.

See also: [Plan-Private-Languages](Plan-Private-Languages) · [Deck-Format](Deck-Format) · [Deck-Tools](Deck-Tools) · [Home](Home)
