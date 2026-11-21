# ADR-0060: Culture media from Wikimedia Commons: portraits and posters, fetched and never invented

Source of truth: this wiki page.

- **Status:** Proposed (owner request, 2026-11-21). The choices below are the author's defaults for the owner to confirm. The full reasoning, the licence survey, the measurements and the work packages are in [Plan-Culture-Media](Plan-Culture-Media).
- **Date:** 2026-11-21

## Context

The owner asked: "we need posters and other information for the culture decks. Fetch those from the wikimedia commons. And serve them with the app as well. Image size max: 2k." (2026-11-21), and, for the sibling sounds work, that it be "a loop of fetch requests, whatever is fetched, gets packaged in decks-live with their cards. Whatever cannot be fetched, remain as is" ([ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio)).

Today a creator may have an `image` (D5; capped at 1024 px and 300 KB, licences limited to 4.0, and none of the 460 creators on `decks-live` has one), a card may have a 256 px `image` (#523), and a work (a recommendation, D13) has no image field at all; the app already draws a creator's portrait, its credit line and a licence link, and draws a medium icon for a work. Decks are CC BY-SA 4.0 ([ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa)), so only CC0, public-domain, CC BY and CC BY-SA files can ship. Film posters and modern book covers are mostly copyrighted and are on English Wikipedia as fair use, not on Commons; the works on the lists are overwhelmingly 20th-century films.

## Decision

1. **Culture decks carry images of three kinds, each once, on the thing it belongs to:** a portrait per creator (creator `image`), a poster, cover or title page per work (a new `image` on a recommendation), and an image on a culture card that is about a place or an event (the card's own `image`). A quotation card never gets a poster.
2. **Images are fetched, never made.** A tool, `tools/fetch_culture_media.py`, resolves each creator and work to a Wikidata item (verified by type, dates and creator, never by name alone), reads the item's image statements (P18, P3383, P996), checks each file through the Commons API, converts it and writes the credit. **A work or person with no verified match gets no image**, and the app shows the placeholder it already has.
3. **The licence gate is the repo's allow list, read through Commons:** CC0, public domain, CC BY 2.0 to 4.0, CC BY-SA 2.0 to 4.0; never NC, ND, GFDL alone or fair use. Files come **only from Commons**, never from `en.wikipedia.org` local uploads (where the fair-use posters are). A file with no machine-readable author is skipped (one exception proposed for public-domain files). Author, licence, licence URL and source URL are stored with the file and **shown with it in the app**.
4. **Size: 2048 px on the longest side is the ceiling** ("2k" read as 2048), never upscaled, WebP. Validator ceiling 2048 px and **500 KB** for shared images (today 1024 px, 300 KB); the tool targets 1024 px for portraits and 2048 px for work images; a culture card's own image stays at 1024 px and 300 KB because it downloads with the course.
5. **Images are lazy:** shared images are listed in the index's `shared_media`, kept out of a course's size, fetched when first shown and kept on the phone. Work images get a second shared folder, `decks/recommendations/images/`.
6. **A ceiling in git: 100 MB for culture images in `decks-live`, 10 MB for a language,** checked by the validator. An image is written once; replacing one needs `--refresh` for that id.
7. **Wikidata is used as CC0 data: a `wikidata` QID key on creators and works, and a `--facts` report** that compares the deck's dates and places with Wikidata's; it never overwrites a deck value. Wikipedia text is not copied into decks.
8. **The app first decodes at the size shown** (`cacheWidth`), stores pictures as binary files with a bounded memory cache, then shows a poster on the work page and cover strip, the credit caption and a "Licence and source" link with every image, a full-screen viewer, and an aggregated Sources line.

## Consequences

- **Coverage will be partial and uneven.** Expected: portraits 40 to 60 per cent (public-domain-by-age portraits of the dead), works 10 to 25 per cent (pre-1931 books, a few silent films). Most 1950s to 2010s films will have no poster. The survey run measures it before any budget is spent.
- A validator and index change on `main` comes first; data can then land on `decks-live` as fetched. The released app ignores the new keys (`image` on a work, `wikidata`); work posters appear with the app release that holds the display, and the index entries for work images carry that `min_app`.
- Raising the cap to 2048 px is **unsafe until the app decodes at the displayed size**: a 2048 px image decodes to about 12 MB and a list of portraits would exhaust memory. The decode fix ships first.
- Wikimedia rate-limits the shared proxy address: measured here, the Commons and Wikidata APIs answered 429 with `Retry-After` of 9 to 40 seconds after a few requests, while `upload.wikimedia.org` and `Special:FilePath` answered 200. The loop is serial, batched (50 titles), cached and resumable, and runs take several sessions. The owner may need to allow `commons.wikimedia.org`, `upload.wikimedia.org`, `www.wikidata.org` and `en.wikipedia.org` (all reachable now; `query.wikidata.org` optional) and, if limits persist, give a Wikimedia API account.
- Images in git grow the repository for good; with the sounds ceiling (50 MB) the two kinds could add 150 MB to a repository at about 134 MiB.
- A file may later be deleted from Commons for a copyright finding. The packaged copy stays until an audit lists it; removal is a one-line change.
- The rule that a source-it-yourself work ships no image ([Plan-Language-Completeness](Plan-Language-Completeness)) is narrowed to "no copy of the work's own media": a free Commons picture of a poster is a separate free file.

## Alternatives

- **Take posters from English Wikipedia (fair use).** Rejected: not free, not allowed in a CC BY-SA deck, and the owner's instruction names Commons.
- **Search Commons by title and accept the best hit.** Rejected: wrong-person and wrong-work images are the main risk; only Wikidata's curated statements are accepted, and `--search` results go to a human.
- **Ship images with the course download.** Rejected for shared images: a course would grow by tens of MB for pictures many learners never open; kept for a culture card's small own image.
- **A separate `works` file with its own images** instead of an `image` on a recommendation. Rejected: a second record for the same work; the recommendation already is the work.
- **Copy the Wikipedia lead sentence as `bio`.** Rejected for now: one language, CC BY-SA attribution per sentence, and the bios are authored and sourced already.
- **Git LFS or release assets for the images.** Not considered: the app downloads files by plain URL from `decks-live`.
- **Higher caps (3840 px) or a lower one (1024 px).** 2048 px is the owner's maximum and more than any phone shows a poster at; 1024 px keeps zoom poor.

## Owner decisions needed

1. **What "2k" means: 2048 px on the longest side** (recommended); or 2000, 1920 or 2560. Downside: none beyond bytes; 2048 is far above what a list needs, and it is a maximum, not a target.
2. **Per-image byte cap: 500 KB for shared images, 300 KB and 1024 px for a culture card's own image** (recommended); or 600 KB, or one cap for all. Downside: the detailed posters are re-compressed harder to fit, some skipped; the estimate rests on one measured file, so the survey run confirms it.
3. **Tool targets below the ceiling: portraits 1024 px, work images 2048 px** (recommended); or 2048 px for everything. Downside: a portrait cannot be zoomed to 2k; 2048 px portraits would cost about three times the bytes for no visible gain at 96 dp.
4. **A ceiling in git: 100 MB total, 10 MB a language, warning at 75 MB** (recommended); or none, or tighter. Downside: the tail languages may be cut; git history never shrinks; together with the sounds ceiling it is about 150 MB more.
5. **Delivery: lazy, any connection, plus a "Show pictures" switch and a per-course "Download pictures" action** (recommended); or with the course, or Wi-Fi only. Downside: a first view needs the network and mobile data; offline shows the placeholder until the picture was seen once.
6. **Works get an additive `image` on the recommendation and a `wikidata` QID on creators and works** (recommended); or a separate works file. Downside: the released app ignores them, so posters wait for an app release; one more key to keep right.
7. **A file with no machine-readable author: skip it** (as for sounds), **except a public-domain file, credited "Unknown author" with its source** (recommended); or skip all, or credit the uploader. Downside: an "unknown" credit is thin; strict skipping loses many old portraits; crediting the uploader risks a wrong attribution.
8. **One licence list for creators and cards: CC0, public domain, CC BY and CC BY-SA 2.0 to 4.0, ported included** (recommended); or CC0, public domain and 4.0 only as the creator rule is today. Downside: BY-SA 2.0 and 3.0 files in a BY-SA 4.0 deck rest on the one-way compatibility ADR-0040 already accepted for cards; the 4.0-only rule would lose most of Commons.
9. **Living creators: no portrait by default** (recommended); or take a free-licensed one. Downside: modern authors and directors have none; a free photo of a living person still raises privacy and personality-rights questions Commons itself flags.
10. **A later painting, statue or imagined likeness of a person with no portrait from life is accepted and marked** with a new optional `image.kind` shown in the credit (recommended); or only contemporary portraits. Downside: a later picture can still mislead a learner; the marking and the reviewer check limit it.
11. **Narrow the source-it-yourself rule "no image" to "no copy of the work's own media"** (recommended), so a free Commons poster of a non-public-domain film may ship. Downside: an image on such a work may look like a rights claim; only a free licence passes the gate.
12. **Fair-use or non-free images: never**, whatever their source (as asked); files from `/wikipedia/en/` are refused by host. Downside: none; the many modern film posters get no image.
13. **Attribution in the app: caption with every image, a "Licence and source" link, the viewer, and a Sources line per language** (recommended); or a credits page only. Downside: the caption adds a line at 1.4x text; the credits-page-only route is lighter but weaker against the licences' "reasonable manner" duty.
14. **Wikimedia access: allow the hosts (`commons.wikimedia.org`, `upload.wikimedia.org`, `www.wikidata.org`, `en.wikipedia.org`, optionally `query.wikidata.org`) and accept slow, resumable runs** (recommended); or a Wikimedia API account or bot password. Downside: several sessions per language; an account is a secret to look after.
15. **Wikipedia text is not copied into decks; Wikidata facts verify and never overwrite** (recommended); or copy the lead sentence into a summary field. Downside: bios stay hand-written; copying brings per-sentence CC BY-SA attribution and one language.
16. **A mockup of the work page, creator row, viewer and credit line first, approved by the owner** (recommended, as the mockup rule says), before the app display work. Downside: the display is a release later.
17. **Lift "Deck work waits for the rest" for the per-language fetch runs, or keep the code packages (validator, tool, decode fix, display) first and the runs after** (recommended). The read-only survey run needs no PR and is not deck work. Downside: the runs are late; lifting them competes with the coding queue.
18. **Place and event images on culture cards come last**, after portraits and works (recommended). Downside: the culture cards about places have no picture for a while.

See also: [Plan-Culture-Media](Plan-Culture-Media) · [ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio) · [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa) · [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics) · [ADR-Index](ADR-Index) · [Home](Home)
