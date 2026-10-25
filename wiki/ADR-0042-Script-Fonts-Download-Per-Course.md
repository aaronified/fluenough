# ADR-0042: Script fonts are downloaded per course

Source of truth: this wiki page.


- **Status:** Accepted (owner, 2026-10-19: "on-demand per course, build it.
  It will download with the deck (the app will say font is being downloaded
  as well).")
- **Date:** 2026-10-19

## Context

A phone draws only the scripts its maker shipped a font for, and draws some
badly: Indic conjuncts that break, a Nastaliq Urdu line set in a plain Naskh
face, a script missing altogether on an old or stripped Android. A drilling
app shows deck text in these scripts all day, so a wrong glyph is a wrong
card. Bundling every script's font would add several megabytes to every
install, for scripts most learners never open; the decks already download
per course ([ADR-0037](ADR-0037-Decks-Download-From-Main)).

## Decision

1. **One OFL-licensed Noto font per script that phones often draw wrongly or
   lack** is kept in the repository, in `decks/fonts/<script>/` with its
   `OFL.txt`: Noto Nastaliq Urdu for `perso_arabic`, and Noto Sans for
   Devanagari, Bengali (which Assamese shares), Telugu, Kannada, Gujarati,
   Gurmukhi, Odia, Tamil and Malayalam, and for Egyptian hieroglyphs,
   cuneiform and Linear B. Each is the single variable or Regular TTF in
   Google Fonts' `ofl/` folder, and is under 2 MB. Chinese, Japanese and
   Korean are left out: phones have them, and their fonts are too large.
2. **The index lists them under a new per-language key `fonts`** (path,
   size, SHA-256, script, family), never in `files` or `media`. The released
   app reads only those, and ignores other keys, so it is untouched. The
   index `version` stays 1, and the language's `size` does not count them.
3. **They download with the course.** When a course's decks are downloaded
   or updated, the fonts it lists that are not on the phone download first,
   by the same downloader, checked against the same size and SHA-256, and
   are kept beside the decks. The progress text says so ("Downloading decks
   and the Telugu font…"). A font a course gained is an update like any
   other. A font shared by courses in one script downloads once; removing a
   course deletes only the fonts no course on the phone lists.
4. **They are loaded at launch and after a download** with Flutter's
   `FontLoader`, one family per script (`FluenoughScript-<script>`), and
   `TargetText` draws a script's text in that family, falling back to the
   phone's own font while none is loaded.
5. **They are credited** on the Sources screen once one is on the phone.

## Consequences

- Up to a megabyte more to download for a course, once per script, and the
  repository grows by about eight megabytes of binary files that change
  rarely. `decks/fonts/**` is marked binary in `.gitattributes`: the
  line-ending rule for `decks/` would rewrite bytes and break the hash.
- A course's text is drawn in the phone's font until its font arrives, and
  stays so if the download fails: the fonts improve the drawing and never
  block a course.
- Courses that write in several scripts, such as Hindustani in Devanagari
  or Perso-Arabic, download the font of each, whichever the learner reads.
  `TargetText` draws by the course's one `script` for now.
- The fonts are variable, one file each, registered without a weight, so
  the weight is set on the `wght` axis; static fonts ignore it.
- A font that changes in the repository is an update on every phone that
  has it; a loaded font cannot be unloaded, so a changed one is drawn after
  the next launch.

## Alternatives considered

- **Bundle every font in the app.** Rejected: it is paid by every install,
  for scripts most learners never use.
- **Rely on the phone's fonts.** Rejected: it is what fails today.
- **Fetch fonts from Google Fonts at run time** (a package that does it).
  Rejected: another host that learns who learns what, a new dependency, and
  no offline use; the app already downloads from one place.
- **List fonts in `files`.** Rejected: the released app would parse them as
  deck files and refuse the path.

## Update (2026-10-24, #611)

Owner, 2026-10-23: "Offer to download the fonts, ask user if they can read a
sample. Otherwise download. Same for everything." The font check, approved
2026-10-24, changes decision 3 and 1 and leaves the rest:

- A course no longer downloads a font by itself. For each script the learner
  reads, the app shows a sample in the phone's own font. "Yes, I can read it"
  keeps it; "No, it shows boxes" downloads the script's font from
  `decks/fonts` as before, and shows the sample again in it. Fonts already on
  a phone from before stay and are drawn with; Settings, Look and language,
  Script fonts, checks again, or removes a downloaded font.
- Simplified Hanzi, kana (with the kanji) and Hangul now have fonts: Noto
  Sans SC, JP and KR, 10 to 18 MB each, downloaded only on "No". Traditional
  Hanzi has none yet.

See also: [Contributing](Contributing) · [ADR-Index](ADR-Index) · [Home](Home)
