# Plan: a Research and standards page, with the sources

Written 2026-10-06. **After FSRS (`fsrs.md`) and the B1 plans
(`b1-plans.md`)**, the owner's order, since the page cites both.

## What the owner asked

> all the research should be called out in the app and readme. users should
> know what all standards this follows so that they can trust it better.
> this is also a plan with the details of the research, since this has to
> land after FSRS and B1 targeting is done.

> a Research and standards page in the app: this can actually club well
> with the sources section. we also need a lot more sources.

## What exists

- **Sources** (Settings > Sources, #197): the books the decks quote, from
  each deck's `source` field: *Sahaj Path*, *Abol Tabol*, *Panch Parmeshwar*,
  *Diddubatu*, and the Bengali spelling rules. The README's Sources section
  lists the same.
- **The README** explains ISO 15919 and the IPA. Nothing in the app or the
  README names the research behind the design.
- **The research** for `skill-model.md` was gathered from abstracts and
  summaries; the full texts were not read (the network blocked the
  publishers).

## The page

**Research and standards**, in place of Settings' Sources row, with three
sections:

1. **Standards the app follows,** each with a line on where:

   | Standard | Where |
   |---|---|
   | CEFR (Council of Europe 2001; Companion Volume 2020) | Levels A1–B1, the B1 target, the themes of each level |
   | ISO 15919 | Readings in Latin letters |
   | IPA | How a word is said |
   | ISO 639 and BCP 47 | Language codes, and the voices and recognisers asked for |
   | Unicode | Every script |
   | FSRS | Scheduling |

2. **Research behind the design,** grouped by what it decided, each with a
   plain line on what the app does because of it, then the citation:

   | Group | What the app does | Research |
   |---|---|---|
   | Spacing | Reviews spread out, further apart as you remember | Cepeda et al. 2006, 2008; Kim & Webb 2022 |
   | Testing | You recall rather than reread | Roediger & Karpicke 2006; Karpicke & Roediger 2008; Kang et al. 2007 |
   | Skills | Hear, Say and Write kept apart | Nation 2022; Laufer & Goldstein 2004; González-Fernández & Schmitt 2020; Steinel et al. 2007; DeKeyser 1997 |
   | Listening for meaning | Hear asks what a word means | Hayes-Harb & Masuda 2008; Cook et al. 2016; Ota et al. 2009 |
   | Phonemic contrasts | The sounds your languages lack, with feedback | Werker & Tees 1984; Logan et al. 1991; Thomson 2018; Uchihara et al. 2025 |
   | Accents | Several voices where the phone has them | Bradlow & Bent 2008; Baese-Berk et al. 2013 |
   | Latin letters | ISO 15919, marking every contrast | Hayes-Harb & Cheng 2016; Bassetti 2017; Escudero et al. 2008 |
   | Grammar | Understanding and producing apart, timed | DeKeyser 1997; Ellis 2005; Shintani et al. 2013 |
   | Your strengths | FSRS per word, an Elo ability per skill | Pelánek 2016; Choffin et al. 2019; Settles & Meeder 2016 |

   A group shows only once the app does what it says. Skills, Listening
   for meaning and Your strengths wait for `skill-model.md`.

3. **Sources of the decks' texts,** as the Sources page shows them now.

A citation opens its DOI or the publisher's page in the browser. Nothing
is fetched to show the page.

## One list, in two places

- The entries live in one file in the repository, read by the app and
  checked against the README's section by a test, so that the two never
  disagree.
- **Each entry:** id, group, the plain line, authors, year, title, venue,
  DOI or ISBN, and the link.
- **Checked before it ships:** every citation against the publisher's
  record, with its DOI resolving. Entries from the research so far are
  marked unchecked until then.

## The README

A **Research and standards** section after "What it does": the standards,
then the research by group, one line each, with links. The Sources section
moves under it.

## What it takes

1. The file and its parser, in `lib/core`.
2. The page, and the Settings row in place of Sources.
3. The README section, and a test that keeps it in step with the file.
4. Checking every citation.
5. **Tests:** the parser; a group hidden until its feature exists; the
   page's sections; a citation opening its link; twice the text size, both
   themes, screen-reader labels.

## To decide

- **Which sources first:** the owner wants both more research and
  standards, and more sources for the decks' content (dictionaries,
  frequency lists, Wiktionary, public-domain books). Which ones, per
  language, is still open.
- **The file:** a new file kind, which needs the owner's answer
  (AGENTS.md), or a section of an existing one.
- Whether the page shows how sure each line is, as the plans do.

## Estimate

| Part | Hours |
|---|---|
| File, parser, page, README test | 4–6 |
| Checking the citations, about 60 | 3–5 |

Confidence: medium.
