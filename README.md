<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="fluenough-brand/fluenough-lockup-dark.svg">
  <img src="fluenough-brand/fluenough-lockup.svg" alt="Fluenough" width="320">
</picture>

<br>

*Fluent enough.*

A language-agnostic drilling app for basic language skills — vocabulary,
production, listening and grammar — scheduled by spaced repetition, running
offline on your phone once a language's decks are downloaded.

<p>
  <a href="https://github.com/aaronified/fluenough/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/aaronified/fluenough/ci.yml?branch=main&amp;label=CI&amp;logo=github" alt="CI status"></a>
  <a href="https://github.com/aaronified/fluenough/releases/latest"><img src="https://img.shields.io/github/v/release/aaronified/fluenough?label=release" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/aaronified/fluenough" alt="Licence: GPL-3.0"></a>
  <a href="https://github.com/aaronified/fluenough/releases/latest"><img src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&amp;logoColor=white" alt="Platform: Android"></a>
  <a href="docs/DEVELOPMENT.md"><img src="https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter&amp;logoColor=white" alt="Flutter 3.47 or later"></a>
  <a href="#why-fluenough-is-different"><img src="https://img.shields.io/badge/works_offline-once_decks_are_in-2E7D32" alt="Works offline once decks are in"></a>
  <a href="#courses"><img src="https://img.shields.io/badge/languages-11-C2621D" alt="11 languages"></a>
  <a href="https://github.com/aaronified/fluenough/issues"><img src="https://img.shields.io/github/issues/aaronified/fluenough" alt="Open issues"></a>
</p>

<p>
  <a href="https://github.com/aaronified/fluenough/releases/latest"><b>Download</b></a> ·
  <a href="https://github.com/aaronified/fluenough/wiki/Courses-and-Paths">Courses</a> ·
  <a href="https://github.com/aaronified/fluenough/wiki/Deck-Building-Guide">Decks</a> ·
  <a href="https://github.com/aaronified/fluenough/wiki/Contributing">Contribute</a> ·
  <a href="https://github.com/aaronified/fluenough/wiki/Roadmap">Roadmap</a>
</p>

</div>

> **Status: early development.** The architecture, deck format, example
> decks, deck parser and validator are in, and the app's screens are built
> from the design. Progress is saved on the phone, one database per profile,
> and features not built yet are shown disabled, marked "Feature incoming". See
> [docs/ROADMAP.md](docs/ROADMAP.md).

## Screenshots

A Bengali learner from English, three and a half weeks in, and the same phone
in reviewer mode.

<table align="center">
  <tr>
    <td align="center"><strong>Deck path</strong></td>
    <td align="center"><strong>Today</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/deck-path.gif" width="220" alt="The Bengali course path: done units, the unit up next, milestones, and the units still being written, shown as Coming"></td>
    <td align="center"><img src="docs/screenshots/today.gif" width="220" alt="Today: the day's lesson, the words due by skill, the streak, quick revision and the day's fact"></td>
  </tr>
  <tr>
    <td align="center"><strong>Progress</strong></td>
    <td align="center"><strong>Reviewing</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/progress.gif" width="220" alt="Progress: reviews, what is remembered, the streak, twelve weeks of reviews, and how well each skill and tag is going"></td>
    <td align="center"><img src="docs/screenshots/review.gif" width="220" alt="Reviewing the Bengali Family unit: the rater code, cards marked right, and cards still to check"></td>
  </tr>
</table>

## Why Fluenough is different

Most drilling apps are built around one language and then stretched to fit
others. Fluenough inverts that: **a language is just data.** A deck is a text
file, the card model is a superset that accommodates Latin, syllabic and
logographic scripts alike, and grammar is described by pattern tables rather
than hard-coded rules. Adding a language means adding files, never code.

> **Status: early development.** The architecture, deck format, example
> decks, deck parser and validator are in, and the app's screens are built
> from the design. Progress is saved on the phone, one database per profile,
> and features not built yet are shown disabled, marked "Feature incoming". See
> [the roadmap](https://github.com/aaronified/fluenough/wiki/Roadmap).

## Courses

Taught from English: Telugu, Bengali, Spanish, Marathi, Kannada, Assamese,
Chinese (Mandarin), Hindustani, Japanese, Korean and Gujarati. Every course
has a B1 plan in its path: the units up to B1, in teaching order, those not
yet written shown as "Coming". Telugu is written to B1; Bengali has all but one of its A1
units; the others have their first units, or more. Each Indic course
starts with its script decks, digits included, and a script guide. Hindustani
is one course in two scripts, Devanagari and Perso-Arabic, and Chinese in
two, simplified and traditional: the learner chooses which to learn. A course
is tagged Alpha until its A1 units are written and Beta until its B1 units
are.

Two courses teach a notation rather than a language: the International
Phonetic Alphabet, and English Braille (uncontracted UEB, typed on the app's
own six-dot keyboard). Each is tagged Complete once its path is written. See
[docs/ROADMAP.md](docs/ROADMAP.md).

The app comes with no decks. It downloads a language's decks from this
repository's `main` branch when you choose it, and you can start once its
first five are in; after that it works offline. Fixed and new decks arrive
without an app update: once a day at most it asks whether to fetch them, and
Settings > Deck downloads lists each language, with Update and Remove, and
can turn the daily check off
([ADR-0037](docs/adr/0037-decks-download-from-main.md)).

## Documentation

The full documentation is in the [wiki](https://github.com/aaronified/fluenough/wiki). Start here:

- [Learner guide](https://github.com/aaronified/fluenough/wiki/Learner-Guide): what the app does and how each drill works.
- [Getting started](https://github.com/aaronified/fluenough/wiki/Getting-Started): install, first run, and the placement test.
- [Courses and paths](https://github.com/aaronified/fluenough/wiki/Courses-and-Paths): courses, paths, units and downloads.
- [Deck building guide](https://github.com/aaronified/fluenough/wiki/Deck-Building-Guide): how to write and check a deck.
- [Contributing](https://github.com/aaronified/fluenough/wiki/Contributing): ways to help, and how pull requests and review work.
- [Development setup](https://github.com/aaronified/fluenough/wiki/Development-Setup): building and testing the app.
- [Roadmap](https://github.com/aaronified/fluenough/wiki/Roadmap): what has shipped, and what comes next.
- [Licence](https://github.com/aaronified/fluenough/wiki/Licence) and [sources and attributions](https://github.com/aaronified/fluenough/wiki/Sources-and-Attributions).
