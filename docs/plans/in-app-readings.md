# Plan: readings made in the app, for sentences the learner adds

Written 2026-10-05.

## What the owner asked

> The app lacks built-in script-to-Latin transliteration since that's
> handled by the Python tool at deck creation time: can this be rule
> generated?? with how much accuracy?
>
> if accurate enough, implement

Then, before anything was built:

> this is a plan, not something for you to do. all decks will still get
> transliteration from wikitionary or soemthing, only user added sentences
> will get in app transliteration for training on those sentences

Asked earlier which languages, and how readings below the bar are shown,
the owner chose:

- **All seven Indian languages.**
- **Readings in a language below 95%** are shown as a suggestion to check
  or edit.

## Scope

- **Course decks** get their readings from Wiktionary or a similar source
  (`wiktionary-ipa.md`), not from the app.
- **The app makes readings only** for sentences the learner adds:
  - text imported (`import-text.md`);
  - cards of the learner's own, for training on them.

## How accurate rules are: measured

`tools/transcribe.py` already makes readings by rule. Normally it takes a
hint, the word as people type it, to tell which vowels are said. The app
has no hint for a learner's sentence. So it was run with no hint on every
card and grammar form of the seven Indian languages, 7,010 readings, and
compared with the decks' readings.

**Metric:** a reading counts as right when it equals the deck's exactly.
The table also shows:

- the share right once accents are ignored, as a typed answer is compared;
- the character error rate.

| Language | Right as it stands | With the three fixes below | Ignoring accents | Character errors |
|---|---|---|---|---|
| Telugu | 98.5% | 98.5% | 98.5% | 0.37% |
| Kannada | 98.2% | 98.2% | 98.2% | 0.44% |
| Hindi | 97.2% | 97.9% | 97.9% | 0.29% |
| Gujarati | 94.1% | 95.6% | 95.6% | 0.67% |
| Marathi | 88.8% | 90.7% | 90.7% | 1.61% |
| Assamese | 82.0% | 87.2% | 87.2% | 1.89% |
| Bengali | 67.5% | 86.9% | 88.2% | 2.25% |
| **All** | **87.9%** | **93.0%** | **93.2%** | **1.12%** |

**The three fixes** apply only when there is no hint:

1. **A word's last vowel after a cluster** ending in r, y, v, n, ṇ, m or l is
   said (Hindi, Marathi, Gujarati): मित्र *mitra*, पत्र *patra*.
2. **Bengali drops an inherent vowel inside a word** as Hindi does, between
   a vowel and a consonant that has a vowel after it: আপনার *āpnār*.
3. **Sibilants in Bengali and Assamese follow the language's table**, so
   Bengali *ś* and Assamese *x*, except before a dental or a stop, where they
   are *s*. With no hint, the tool used its own typed spelling *s* as if it
   were a hint, and wrote *s* for every স.

**Caveats** (confidence medium):

- **The deck readings were made by the same tool with a hint**, and no
  speaker has checked them. These figures measure agreement with the
  course, not with speech.
- **The fixes were found on the same words they were measured on**, so new
  sentences will score lower.

**What is still wrong:**

- vowels heard both ways in Hindi and Marathi (*janvarī* or *janvrī*);
- English loans spelled with फ but said with *f*;
- Bengali's inherent *o*, which needs a word list as much as rules.

## What it takes

1. **The three fixes in `tools/transcribe.py`**, in its no-hint path only, so
   the tool and the app agree. Readings made with a hint do not change.
2. **A Dart port** of the no-hint path, in `lib/core`, free of Flutter:
   - the script tables, the units, the clusters;
   - the rules above, and the tool's short list of words said otherwise;
   - readings only. The IPA can follow the same way.
3. **Tests:**
   - the Dart output equals the Python tool's on a fixture the tool writes,
     about 100 readings per language;
   - each language's agreement with the decks stays at or above the figures
     above.
4. **Shown as made:** a reading the app made is marked as such. In Marathi,
   Assamese and Bengali, below 95%, it is a suggestion the learner checks or
   edits before it is used, as the owner chose.

## To decide

- Whether the IPA is made in the app too.
- Whether a reading the learner corrects is kept as theirs, and offered as a
  fix to the course.

## Estimate

- The fixes in the Python tool, with tests: about 2 hours.
- The Dart port, with the parity fixture and accuracy tests: about 6–8
  hours.
- Marking and editing in the screens that use it: 1–2 hours.

Confidence: medium.
