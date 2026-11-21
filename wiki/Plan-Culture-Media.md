# Plan: posters, portraits and other information for the culture decks, fetched from Wikimedia Commons

Source of truth: this wiki page.

Written 2026-11-21. Builds on [Plan-Sounds-Decks](Plan-Sounds-Decks) and [ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio) (the sibling fetch loop, whose approach is reused), [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics) (creators, recommendations, D5 and D13), [Plan-Language-Completeness](Plan-Language-Completeness) (the culture checklist), [Deck-Format](Deck-Format) ("A card's own image" and "Deck kinds") and [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa). The decision record is [ADR-0060](ADR-0060-Culture-Media-From-Wikimedia-Commons) (Proposed). Nothing here is built. Everything marked **Proposed** is the author's, not a decision.

## What the owner asked

> Also, we need posters and other information for the culture decks. Fetch those from the wikimedia commons. And serve them with the app as well. Image size max: 2k. (2026-11-21)

The same pipeline as the sounds decks (2026-11-21): a loop of fetch requests; whatever is fetched is packaged on `decks-live` with the cards; whatever cannot be fetched stays without an image, and the app shows the placeholder it already has.

**"2k" is read here as 2048 pixels on the longest side.** The repo says nothing else: today's creator images are capped at 1024 px (`IMAGE_MAX_SIDE`), a card's image is made at 256 px (`IMAGE_SIZE` in `tools/import_wiktionary.py`), and no file mentions "2k". 2048 is the usual meaning of 2K for a still image and sits one step above the 1920 px widths Wikimedia serves as a standard thumbnail. It is a **maximum**: nothing is upscaled and a smaller source stays smaller. Owner decision 1.

## What exists (verified 2026-11-21 on `main` and `decks-live`)

### In the deck format

- **A creator may have an `image`** (D5): `{ file, credit, author, licence, licence_url, source_url, retrieved }`, the file `decks/creators/images/<creator id>.<jpg|png|webp>`. `check_image` in `tools/validate_decks.py` requires every key but `licence_url` for a public-domain image, a licence from `IMAGE_LICENCES` (`public-domain`, `CC0-1.0`, `CC-BY-4.0`, `CC-BY-SA-4.0`: no 2.0 or 3.0), no public-domain image for a living creator, a file of at most `IMAGE_MAX_BYTES` (300 KB) and `IMAGE_MAX_SIDE` (1024 px), and no file in the folder that no creator cites. **No creator on `decks-live` has an image today** (460 creators in 11 files, none with `image`; the Gujarati file says "No pictures: none has a licence checked yet").
- **A card may have an `image`** (#523), a 256 px WebP `decks/<lang>/images/<card id>.webp` with `image_credit: { source, license, credit }`, written by `tools/import_wiktionary.py --images`; the licence must match `MEDIA_LICENSE_RE` (CC0, public domain, CC BY or CC BY-SA 2.0 to 4.0, ported versions too). Only three card images exist on `decks-live`, all in `ipa`. A culture card is a quotation (`pos: phrase`, `source`, `creator`); it has no picture, and a quotation has no poster.
- **A work is a recommendation** (D13, `decks/recommendations/<code>.yaml`): `id`, `medium`, `title`, `creator`, `year`, `level`, `briefing`, `questions`, optional `legal` and `quoted_in`. It has **no image field**. `REC_KEYS` in the validator would refuse one. 209 works across 11 languages (films 115, books 53, songs 16, comics 9, plays 7, series 6, podcasts 3).
- **Source-it-yourself works refuse an image today.** [Plan-Language-Completeness](Plan-Language-Completeness#source-it-yourself-works-and-the-rights-floor) lists "An `image`, `audio` or video file: No media is shipped" among the things the validator refuses for a `basis: "source-yourself"` item. That rule is specified and not implemented (task T23). This plan asks the owner to narrow it (decision 11).
- **Index.** Creator images are listed under the top-level `shared_media` (`SHARED_MEDIA = "decks/creators/images"` in `tools/deck_index.py`), not in a language's `size`, and downloaded on demand. A card's images go in the language's `media` and **are** in its `size`, downloaded after the decks. `mediaPathPattern` in `lib/core/decks/deck_index.dart` accepts a card image only as `decks/<lang>/images/<lang>-NNNN.webp`, and `SharedMediaFile.tryParse` only a path starting `decks/creators/images/`; anything else is logged and passed by.
- **`min_app`.** `MIN_APP_KINDS` gates `creators` and `recommendations` at 0.9.6 (to be raised to the real number at the release). `CARD_FIELD_MIN_APP` (`character` 0.10.2, `situation_icons` 0.10.3) gates **card fields** a released app's parser refuses. The released app's creator and recommendation parsers (`lib/core/data/creators.dart`, `recommendations.dart`) read the keys they know and ignore the rest, so a new key on a creator or a recommendation is not refused by a released app: only the validator's own key sets (`CREATOR_KEYS`, `IMAGE_KEYS`, `REC_KEYS`) have to grow. "Released app reads the decks" proves it in CI. `decks/min_app.json` is empty.

### In the app (`lib/`, `main`)

- **Creators have portraits already.** `CreatorThumb` (`lib/features/culture/culture_parts.dart`) shows the picture or a person icon on the secondary container; `CreatorSummary` is the row (48 to 96 dp); `CreatorCard` (`creator_sheet.dart`) shows it with a credit line (`cultureImageCredit`: credit, author, licence) and an "Licence" link to `licence_url` or `source_url`. With no image it says "no licensed image yet" (`cultureImageNone`).
- **`DeckDownloads.creatorImage(path)`** fetches the file when first shown, only if the index lists it in `shared_media`, checks size and SHA-256, keeps it **as base64 text in a notes file** (`creator-image-<sha>.b64`) and in an unbounded in-memory map. It never throws; failure shows the placeholder.
- **`Image.memory` has no `cacheWidth`.** The picture is decoded at its full size. That is harmless at 256 or 1024 px and **breaks at 2048 px**: a 2048 x 1448 image decodes to about 12 MB, a list of 30 creators to about 360 MB (Flutter's image cache holds 100 MB by default and the OS kills the app first). This must be fixed before any 2048 px file ships (work package 4).
- **A card's `image`** shows where `picture` shows (`CardPicture`, 72 to 88 px), credited on the deck screen ("Images") and, per the format, Settings' Sources screen.
- **Works have no picture.** `culture_works.dart` draws `recommendationIcon(medium)`; the "cover strip" of `completed_works_card.dart` (`_Cover`) is an icon with a tick. A work is shown with its title, briefing, creators (so their portraits) and legal links.
- The app shows **no image credit anywhere except** the creator sheet, the deck screen's image list and, as the format says, the Sources screen.

### What the culture decks hold (read on `decks-live`)

96 culture decks (four per language, `*-culture-1` to `-4`), 460 creators (as 17, bn 51, es 57, fr 51, gu 25, hi 64, ja 76, kn 33, mr 40, sa 16, te 30, zh 0), 209 works. Gujarati, Bengali and Sanskrit are the most complete: `gu-culture-1` is Narsinh Mehta's verse with `source` (work, date, basis `public-domain`, `author_died`, `rights_checked`), `creator`, and no image; `creators/gu.yaml` has 25 creators, eras and bios and no pictures; `recommendations/gu.yaml` has 20 works (13 films, 5 books, a play, a song) from 1969 onward, mostly. The works are overwhelmingly 20th-century films: that decides the licence reality below.

## 1. What a culture deck should carry

| Thing | Where it lives | Image? | Status |
|---|---|---|---|
| **A portrait per creator** | creator `image` | `decks/creators/images/<creator id>.webp` | Field, validator, loader and display exist; caps and licence list change (section 3) |
| **A poster, cover or title page per work** | recommendation `image` (new) | `decks/recommendations/images/<rec id>.webp` | New additive field, new `shared_media` prefix, new display |
| **A place or event image** where a culture card is about one | the card's own `image` (#523) | `decks/<lang>/images/<card id>.webp` | Field exists; new tool path; cap 1024 px (section 3) |
| **A legacy item's image** (a monument, a festival) | later: `image` on a `legacy` item | same shared folder | Not in this plan's first stage |
| **Other information** | see the table in section 1.2 | no | A QID field, verification, optional captions |

A culture card shows its work's cover only through the work: a recommendation that names the deck in `quoted_in` (a public-domain work whose text the deck quotes) lends its image to that deck's cards, derived by the app, never copied onto 18 cards. A card about a place or an event may carry its own `image`. A quotation card never gets a poster of its own.

### 1.1 Why one image per work, and not per card

A culture card is a line of a poem, not a work: 18 cards of the same poem would carry the same file 18 times, and the file name must be the card's id (`check_media`). The image belongs to the work or the creator, once.

### 1.2 Other information: candidate data

| Data | Source | Licence | Holds it today | Proposal |
|---|---|---|---|---|
| Dates of birth and death, birthplace (P19), country (P27), instance of (P31), occupation | Wikidata | **CC0** | `born`, `died`, `region` hand-written, with a check that the dates are sane | **Verify, never overwrite.** The tool's `--facts` report prints each creator's deck value beside Wikidata's and flags a disagreement (the Gujarati file already notes that Wikidata disagrees with en.wikipedia for Narsinh Mehta: a reason to report and not to write) |
| A work's publication date (P577), country (P495), director or author (P57, P50), genre (P136), original language (P364) | Wikidata | CC0 | `year`, `creator`, `medium` | Same: verify, report |
| The Wikidata item (QID) of a creator or work | Wikidata | CC0 | none | **New additive key `wikidata: "Q123"`** on a creator and on a recommendation. It makes every later run exact (no name search), lets reviewers check the identity in one click, and costs a few bytes. The released app ignores it |
| The page's Commons category (P373), the image statements P18 (image), P3383 (film poster), P996 (document scan, for a pre-1930 book), P154 (logo) | Wikidata | CC0 for the statement; **the file has its own licence** | none | The loop's candidate list (section 2). Every value of these properties is a Commons file, so a fair-use image can never be named by them |
| The Commons file description (`ImageDescription`, per language) | Commons | the file's own licence | `credit` only | Optional `alt` text for the screen reader, later; not required |
| The lead sentence of the Wikipedia article | Wikipedia REST summary | **CC BY-SA 4.0** (text) | `bio` hand-written per UI language with a `source` | **Not copied automatically.** A copied sentence would carry its authors' attribution and be in one language; `bio` stays authored. The summary is read to help the builder check a bio, not shipped (decision 15) |
| Where to watch or read | the app's `legal` links | n/a | `legal` | Unchanged; the loop never adds a link |
| Cast, runtime, awards, ratings | various | mixed | none | Not wanted: not needed to learn a language |

**`min_app` for the data.** A new key on a creator or a recommendation (`wikidata`, `image`) needs **no card-field gate**: the released app ignores it, and the file is already behind the `creators` and `recommendations` gates of `MIN_APP_KINDS`. The images themselves are listed in `shared_media`; an entry with the new prefix (`decks/recommendations/images/`) is passed by, with a log line, by an app that does not know it, and the entry carries a `min_app` of the release that shows work images so that an app that knows `shared_media` but not the prefix does not download it for nothing. The release number is chosen when package 4 is cut. A card `image` on a culture card needs no gate at all (the field and path exist).

## 2. Licence reality (essential)

NC sources stay out until the decks repository split; after it, NC decks may live in the new repository as whole decks, never mixed into a BY-SA language ([Plan-Decks-Repo-Split](Plan-Decks-Repo-Split)).

**The loop never decides what is legal.** It reads what Commons says. Commons hosts only free files: a file is on Commons only if its uploader and the Commons community have judged it public domain or freely licensed in its country of origin and in the United States. Fair-use images (most film posters and modern book covers on English Wikipedia) are **not** on Commons; they live on `en.wikipedia.org` under `/wikipedia/en/`. The loop therefore:

1. takes files **only from `commons.wikimedia.org`**, reached by their Commons title (from Wikidata P18 and P3383, which Wikidata allows to name Commons files only), and refuses any URL under `upload.wikimedia.org/wikipedia/en/` or any other wiki's local upload;
2. reads `extmetadata` through the Commons API and accepts only a licence on the repo's allow list: **CC0, public domain, CC BY 2.0 to 4.0, CC BY-SA 2.0 to 4.0** (ported versions as `MEDIA_LICENSE_RE` already reads them); **never NC, never ND, never GFDL alone, never "fair use"**, never a file whose `Restrictions` field names a trademark, personality or other right the deck cannot carry for the use;
3. stores **author, licence, licence URL and source URL** in the credit (`image`: `author`, `credit`, `licence`, `licence_url`, `source_url`, `retrieved`) and skips a file with no machine-readable author (decision 7 for the one exception);
4. never searches Wikipedia's REST `originalimage` or `thumbnail` (they can point at a fair-use file).

### Which works can have a poster

Copyright decides, and the table says what Commons realistically holds. Today is 2026-11-21: in the United States, works first published **before 1931** are public domain (95 years); 1931 enters on 1 January 2027.

| Kind of work | Can Commons hold its poster or cover? | What the loop does |
|---|---|---|
| **Book, first published before 1931, a classic** | **Yes, often.** The cover or title page of a public-domain edition is a public-domain scan (Commons template families `PD-old`, `PD-US-expired`, `PD-scan`; a faithful scan of a flat public-domain page adds no copyright in the US). Typical: a first-edition title page, a 19th-century frontispiece | Takes P18 or P996 of the work, or of the edition item |
| **Book, 1931 or later** | **Rarely.** The text may be free (author died before about 1956 for life+70; before 1966 for India's life+60) but the **cover art** is the illustrator's or the publisher's work. A free cover exists only where uploaded under a free licence or where the artist's term has run | Takes it if Wikidata names a free file; otherwise no image |
| **Film, before 1931** | **Sometimes**: a poster or lobby card of a silent film, public domain by age | Takes P3383 or P18 |
| **Film, 1931 to 1963, United States origin** | Sometimes, **only where the copyright was not renewed** (Commons: `PD-US-not-renewed`) or the poster carried no notice (`PD-US-no-notice`, 1929 to 1977): a Commons decision made file by file | Takes it only when Commons's licence name is a public-domain one |
| **Film, 1931 or later, any other country** (almost every film on the lists: the Telugu, Marathi, Bengali, Gujarati, Kannada, Spanish and French films of the 1950s to 2010s) | **Almost never.** The poster belongs to the studio or the poster artist; it is on Wikipedia as fair use, not on Commons. Exceptions: a poster the rights holder released under a free licence (some festival, independent and Wikimedia-organised screening posters, some open films), a poster that is not copyrightable (text only or simple shapes: `PD-ineligible`, `PD-textlogo`), government-origin posters where a country's law puts official works in the public domain (the United States federal government, `PD-USGov`; some others, per Commons' own template) | Takes what Wikidata names if it passes the gate; **otherwise no image. No fair-use fallback.** The work page shows its medium icon |
| **Song, album, single** | **Almost never**: sleeve art is copyrighted | No image, unless Wikidata names a free file (an old public-domain sheet-music cover, say) |
| **Play** | Sometimes for a play staged before 1931 (a PD theatre poster) | Same gate |
| **Comic, series, podcast** | A comic strip or magazine cover before 1931: sometimes. A television series, a podcast: only a simple logo (`PD-textlogo`) or a free file | Same gate; nothing otherwise |

**Expected coverage of the 209 works on the lists today: low, about 10 to 25 per cent, almost all of it pre-1931 books and a few silent films.** The survey run (package 5) turns this guess into a number before any budget is spent. A learner meets a work with no poster as today: the medium icon, the title, the briefing, the creators' portraits (the work page already lists them), the legal links.

### Which creators can have a portrait

Much better than for works, because a portrait of a person who died before about 1900 is a photograph or painting that is public domain by age. Expected: **40 to 60 per cent**, higher for Western, Japanese and Bengali figures, lower for medieval South Asian poets, for whom Commons often holds only later paintings or statues.

- **Photograph or painting made in the person's lifetime, public domain by age:** accept.
- **Later painting, statue, stamp or imagined likeness of a person with no portrait from life** (Mirabai, Pothana): the file is real and may be free, but **the image is not the person's face**. Proposed: accept, and mark it in the credit line (a new optional `image.kind`: `portrait`, `photograph`, `painting`, `statue`, `depiction`; shown as "Painting, 19th century" in the credit). Decision 10.
- **A 20th-century photograph:** only under a free licence from the photographer (CC BY or CC BY-SA, a government photo division where the law frees it, an archive's CC0). Many Wikipedia infobox photos qualify.
- **A living person:** skipped by default (decision 9). A living creator's image may never be `public-domain` by age (the validator already says so).
- **A contested figure or one whose likeness is disputed:** a reviewer check (D5 already says so). The loop flags a candidate whose Commons categories include `Fictional` or `Alleged`, `Disputed` or `Unidentified` and does not accept it by itself.
- **Wrong-person risk is the loop's main correctness risk.** A name match is never enough: see "Identity check" below.

## 3. Size and format

### Format

**WebP**, as every card image already is (`ffmpeg` with `libwebp`, installed here and in CI). The creator validator accepts `.jpg`, `.png` and `.webp`; the tool writes only `.webp`, with metadata stripped, and the app already decodes it. Alpha is kept for a transparent PNG and the app draws it on the surface colour (section 4).

### Size

- **Ceiling: 2048 px on the longest side.** The tool asks for a smaller rendering where one will do (below), downloads, and **never upscales**.
- **Bug to avoid in the existing code:** `convert_image` in `tools/import_wiktionary.py` scales with `scale=N:N:force_original_aspect_ratio=decrease`. Measured here, that **upscales** a small source to fit the box (a 1071 x 1500 JPEG became 1462 x 2048 with `N=2048`, 171 KB instead of 118 KB). At 256 px it never mattered; at 2048 it would inflate files. The new tool uses `scale='min(2048,iw)':'min(2048,ih)':force_original_aspect_ratio=decrease` (measured: 1071 x 1500 stays 1071 x 1500).
- **Targets below the ceiling.** A portrait is shown at 48 to 96 dp (about 300 px on a dense phone) and a full-screen view at about 1200 px wide; 2048 is for zooming a poster. So the tool targets **1024 px for portraits** and **2048 px for work images**, and both validators accept up to 2048. Owner decision 3.
- **The width trap.** The Commons thumbnail parameter is a **width**: `iiurlwidth=2048` on a tall portrait returns a 2048 px wide, perhaps 6000 px tall file, or the original unscaled when the original is narrower (observed: `Special:FilePath/...?width=2048` returned the 1071 x 1500 original, 132 KB, labelled `thumbnail_unscaled`). The tool reads the original's width and height first (`prop=imageinfo`, `iiprop=size`), computes the width that makes the **longest** side the target, and asks for that. It skips a source over 40 megapixels or 30 MB.
- **Standard thumbnail widths.** Wikimedia asks clients to use its standard thumbnail steps (as recalled, **unverified from here**: 320, 640, 960, 1280, 1920, 3840). Arbitrary widths may be refused. The survey run tests this on a few files; if arbitrary widths fail, the tool asks for 1920 (inside the ceiling) or the original when it is small, and downscales in `ffmpeg`.

### Bytes per image, from a real file

One real Commons file was fetched to measure (a 1909 photograph of a poet, 1071 x 1500, 1.6 megapixels, grainy, a hard case for WebP):

| Version | Bytes |
|---|---|
| Original JPEG, as served | 132,155 |
| WebP, native size, quality 70 / 75 / 80 | 108,276 / 118,038 / 143,424 |
| WebP, 1024 px long side, quality 78 | 75,682 |
| WebP, 256 px (a card's image today), quality 80 | 6,842 |

That is about **0.07 byte per pixel at quality 75** for a grainy photograph. Estimates from it (not measurements):

| Image | Pixels | Typical WebP at q75 to q80 | Hard case (halftone, texture, scan noise) |
|---|---|---|---|
| Portrait, 1024 px long side | 0.5 to 0.8 MP | 50 to 110 KB | up to 200 KB |
| Poster or cover, 2048 px long side (about 1400 x 2048) | 2.9 MP | 150 to 300 KB | up to 500 KB |
| Landscape poster or lobby card, 2048 x 1450 | 3.0 MP | 150 to 320 KB | up to 550 KB |

A flat-colour poster with large type compresses far smaller per pixel; a scanned 1920s lithograph with paper grain is the worst case. **The sample is one file.** The survey and the first runs report real byte counts, and the cap is confirmed from them before the first per-language PR (package 5).

### Caps (Proposed)

| Kind | Tool target | Validator ceiling | Byte cap | Today |
|---|---|---|---|---|
| Creator portrait | 1024 px | **2048 px** | **500 KB** | 1024 px, 300 KB |
| Work poster or cover | 2048 px | **2048 px** | **500 KB** | none (no field) |
| Culture card's own image (place, event) | 1024 px | **1024 px** | **300 KB** | 256 px made by the importer, no size check |

- **500 KB, one cap for shared images.** It covers about the 95th percentile of the estimates above. The tool's quality ladder is 80, 75, 70, 62: it stops at the first file under **350 KB** (the tool's warning level), refuses to go below 62, and then steps the side down (1792, 1536, 1280) until the file fits 500 KB; a file that still does not fit is skipped and reported. The validator rejects over 500 KB and over 2048 px as errors. A lower cap would force heavy re-compression on exactly the detailed posters learners care about; 600 KB is the alternative.
- **A culture card's image keeps 1024 px and 300 KB** because it is listed in the language's `media` and downloads with the course. Shared images are never in a course's download (below). Owner decision 2.

### Budget in git

`decks-live` already holds about 134 MiB of packed history and the indexes total about 85 MB of deck data; images in git never shrink.

| Estimate | Count | Coverage | Average | Total |
|---|---|---|---|---|
| Portraits, today's 460 creators | 460 | 40 to 60% | 90 KB | about 17 to 25 MB |
| Work images, today's 209 works | 209 | 10 to 25% | 250 KB | about 5 to 13 MB |
| Place and event card images | a few dozen | n/a | 150 KB | under 5 MB |
| **Now** | | | | **about 25 to 40 MB** |
| **All languages later** (about 1,000 creators, about 400 works) | | | | **about 55 to 90 MB** |

**Proposed ceiling: 100 MB for culture images in `decks-live`** (a warning at 75 MB), **at most 10 MB for one language**, enforced by the validator on the folders. The sounds plan proposes 50 MB for audio; together the two media kinds would add 150 MB to a repository already at 134 MiB, so the owner should see both numbers side by side (decision 4). Git LFS is not considered: the app downloads files by plain URL. A fetched image is **written once**: replacing a file adds the new bytes to history for ever, so a re-run never overwrites an existing file unless `--refresh` is given for a named id.

### What a learner downloads

- **A course download does not change.** Shared images are not in the language's `size`.
- **Pictures are fetched when first shown** (as creator images already are), from the index's `shared_media` list, checked by hash alone, and kept on the phone. Worst case if a learner opens every creator and work of Japanese: about 76 portraits x 90 KB + 30 posters x 250 KB, about 14 MB; the realistic figure is a few MB. Proposed: **lazy by default, any connection** (the owner's 2026-10 rule for decks), plus a Settings switch "Show pictures" that stops fetching and one "Download this course's pictures" action for a learner who wants them offline. Decision 5.
- **A card image on a culture card downloads with the course**, as any card image does, and is small (at most 300 KB, a few per deck).

## 4. The fetch loop and its tool

### The loop

Reuses the structure of ADR-0059's loop: a manifest of what to look for, a resolve-then-fetch pipeline, a report, and a PR on `decks-live` holding whatever was found.

1. **Manifest.** Read `decks/creators/<code>.yaml` and `decks/recommendations/<code>.yaml` (and, for place cards, a hand list of card ids). Skip anything that already has an `image`.
2. **Resolve the Wikidata item** (`wikidata` key if present; else search `wbsearchentities` by the title or name, then **verify**).
3. **Identity check.** A creator matches only if the item is a human (`P31 = Q5`) **and** birth and death years agree with the deck within one year (the deck's `circa` widens it to 5) **and** a label or alias matches in the deck's script or the English name. A work matches only if its label or alias matches **and** its publication year is within one year of `year` **and** a creator named in the item (P50, P57, P86, P170) is the same QID as a deck creator whose own QID has verified. **No match is no image**: a missing portrait is better than the wrong person's. A verified QID is written back as `wikidata`.
4. **Candidates.** The item's statements: creators P18; works P3383, P18, P996; places and events P18. **No Commons text search** except under `--search`, whose results are written to the report for a human and never accepted.
5. **Licence gate** through the Commons API, batched 50 titles to a request: `iiprop=url|size|mime|extmetadata`; the checks of section 2 (licence on the list, an author, `Restrictions` empty, mime in jpeg, png, webp, gif, tiff).
6. **Download and convert.** One rendering at the computed width from `upload.wikimedia.org` (or the original if small), `ffmpeg` to WebP with the quality ladder, never above the cap, never upscaling, metadata stripped. Name the file by the creator or recommendation id.
7. **Write the YAML** by a text patch of the one entry (as `import_wiktionary.py` patches, never re-serialising the file): `image:` block with `file`, `credit`, `author`, `licence`, `licence_url`, `source_url`, `retrieved`, `kind`, and the `wikidata` key.
8. **Report** per language: items looked at, resolved, rejected by identity, **fetched**, **missing** with the reason (no Wikidata item, no image statement, licence not on the list, no author, too large, request failed), bytes fetched, bytes per kind, the total against the ceiling. The report is committed as a docs page or the PR body, and **never** guesses.

What cannot be fetched stays without an image. No synthesised or generated image, ever, and no fair-use image.

### The tool

**A new `tools/fetch_culture_media.py`**, importing from `tools/import_wiktionary.py` (`commons_file`, `licence_id`, `strip_html`, `convert`, `ffmpeg`, `USER_AGENT`) rather than copying it, as `fetch_sound_audio.py` is planned to. Both the sounds tool and this one need a client that survives rate limits, so **the first of the two to land extracts `tools/wikimedia_client.py`** (a polite HTTP client with retry, cache and batching), and `import_wiktionary.py`'s `http_get` is pointed at it in the same PR; the second reuses it. No other import is new (`ffmpeg`, `PyYAML`, the standard library).

Flags: `--language`, `--kind creators|works|places`, `--survey` (steps 1 to 5, no download, no write: the survey run), `--facts` (print Wikidata vs deck), `--limit N`, `--dry-run`, `--refresh <id>`, `--search` (report only), `--max-bytes N` (stop when the run has fetched that much), `--cache DIR` (default `.cache/culture-media/`, already git-ignored by `/.cache/`), `--report FILE`.

**Resumable.** Every response is cached by request in `.cache/culture-media/` (JSON by title or QID, images by SHA of the URL), with a state file recording the id's stage. A rerun after an interruption makes **no** request it has an answer for; a run stopped by the rate limit exits 3 with a clear message and picks up where it was.

**Polite, and ready for the 429.** Measured here (below), the shared proxy address draws a **429 with `Retry-After`** on the Commons and Wikidata APIs after a few requests. The client:

- sends the existing identifying `User-Agent` (project name and its public repository URL, nothing personal);
- is serial, with at least 1 second between API requests and `maxlag=5`;
- **batches 50 titles** in `titles=A|B|C` for `imageinfo` and 50 ids in `ids=Q1|Q2` for `wbgetentities`, so a language of 80 creators is two or three API calls, not 160;
- **obeys `Retry-After`** (the header was 9 to 40 seconds), with exponential backoff and jitter on a 429 or 5xx, at most 5 tries per request, then stops cleanly and saves state;
- **keeps image downloads on a separate budget** from API calls: `upload.wikimedia.org` and `Special:FilePath` answered 200 while the action API answered 429;
- caches negative results so a missing image is not asked again.

### Reachability and rate limit measured here (2026-11-21, through the session proxy)

| Host and request | Result |
|---|---|
| `commons.wikimedia.org/w/api.php`, `imageinfo` with `extmetadata` | **Reachable. 429 on most requests**: 12 requests over about 4 minutes gave one 200 and eleven 429s; the body is the Wikimedia "too many requests" text, `Retry-After` was 9, 13, 17, 26, 30 and 40 seconds, counting down, and a request after the stated wait was still refused while the bucket was full |
| `commons.wikimedia.org/w/api.php`, `list=search` | **200** |
| `commons.wikimedia.org/wiki/Special:FilePath/<file>?width=2048` | **200**, redirected to `upload.wikimedia.org` and served the file, while the API was answering 429 |
| `upload.wikimedia.org` | **200** (via that redirect); a hand-built thumbnail URL with a wrong hash path gave 400 |
| `www.wikidata.org/w/api.php`, `wbgetentities` | **Reachable, one 429** (same bucket) |
| `www.wikidata.org/wiki/Special:EntityData/Q7241.json` | **200** (424 KB for one item: use it only for one-off reads; prefer batched `wbgetentities` with `props=claims`, filtered) |
| `query.wikidata.org` (SPARQL) | **200**, empty-result query |
| `en.wikipedia.org/api/rest_v1/page/summary/<title>` | **200** |
| `en.wikipedia.org/w/api.php` (`extracts`) | **200** |

All five hosts the sounds plan lists are reachable; add `www.wikidata.org` and, for the optional SPARQL cross-check, `query.wikidata.org`. The 429 is a property of the shared proxy address and may be harder or easier in another session, which is why the loop must be resumable and slow, and why runs take several sessions. If limits persist the owner may need a Wikimedia API account (decision 14). **No image was downloaded in bulk and none is committed**: one file was fetched to measure sizes and left in the scratch folder.

### Validator changes (package 1: built, PR to `main`)

Built as listed below, with these differences, all in `tools/validate_decks.py`: the caps are the constants `SHARED_IMAGE_MAX_SIDE` (2048), `SHARED_IMAGE_MAX_BYTES` (500 KB), `CARD_IMAGE_MAX_SIDE` (1024) and `CARD_IMAGE_MAX_BYTES` (300 KB), and a card's own image is now checked against its cap (it had none); `.jpg` and `.png` stay accepted beside `.webp` for shared images (the tool writes only `.webp`); the licence rule is one function, `check_licence_and_source`, used by recordings, card images and shared images; "Generated by tools/..." with `CC0-1.0` is allowed only on a card's `image` or `audio`; the rule that a `source-yourself` work may carry an image only with a Commons `source_url` is **not** built (a recommendation has no `basis` field; the rule waits for task T23); the Commons host is required for a work's image and not for a creator's (the existing fixture and creators' rule stay valid); `--image-report` prints the bytes per language. The plan's text, as proposed:

1. `IMAGE_MAX_SIDE` 1024 to **2048** and `IMAGE_MAX_BYTES` 300 KB to **500 KB**, per kind as the table in section 3 says (card images stay 1024 px and 300 KB).
2. **One licence rule.** `IMAGE_LICENCES` (creators: 4.0 only) is replaced by `MEDIA_LICENSE_RE`, the card media's rule (CC0, public domain, CC BY or CC BY-SA 2.0 to 4.0 including ported); most Commons files are CC BY-SA 2.0, 3.0 or 4.0. Still never NC, ND, GFDL alone or fair use.
3. **Recommendations may have `image`** (`REC_KEYS`, `IMAGE_KEYS` reused): `decks/recommendations/images/<rec id>.webp`, the file there, the credit complete, an `image` on a recommendation whose `basis` is `source-yourself` allowed only with `source_url` on `commons.wikimedia.org`.
4. **`wikidata`** (`^Q[1-9][0-9]*$`) allowed on a creator and a recommendation; **`image.kind`** (`portrait`, `photograph`, `painting`, `statue`, `depiction`, `title-page`, `poster`) optional.
5. **Credit rules for a fetched image:** `source_url` is `https://commons.wikimedia.org/wiki/File:...` (the host is checked); `author` plain text (no HTML), at most 300 characters; `retrieved` a date; `licence_url` required except for `public-domain`; `author` may be `Unknown author` only with `licence: public-domain` (decision 7); a living creator never `public-domain`.
6. **No orphans** in `decks/recommendations/images/`, as for creators.
7. **A budget lint** over the image folders: a warning at 75 MB total and 8 MB for a language, an error at 100 MB and 10 MB.
8. Tests for each; the tool's tests use fixtures, never the network.

### The index (`tools/deck_index.py`)

`SHARED_MEDIA` becomes two folders, `decks/creators/images` and `decks/recommendations/images`; each entry keeps `path`, `size`, `sha256`, `kind`, `language`; the work entries carry `min_app`. A creator image is not counted in a language's `size`, and neither is a work image.

## 5. The app

Everything here is code on `main`, one coder, behind a mockup the owner approves (package 3), and needs a release for a learner to see a work's poster. Creator portraits already display.

1. **Fix decoding first (prerequisite for 2048 px).** `Image.memory` and `Image.file` get a `cacheWidth` of the widget's width times the device pixel ratio (a 48 dp row decodes at about 150 px, not 2048). Lists use `ResizeImage`. Only the full-screen viewer decodes at full size. Without this a list of portraits at the new cap can exhaust memory.
2. **Keep pictures as binary files, with a bounded memory map.** The base64 note (`creator-image-<sha>.b64`) is 33 per cent larger on disk and is read and decoded as text; for files up to 500 KB the app stores the bytes in its files store and holds at most about 24 MB or 32 entries in memory (least recently used). The same `DeckDownloads` loader serves work images under a second prefix.
3. **A poster on the work page.** The work's header shows its image at the width of the screen (aspect ratio kept, at most about 40 per cent of the height; `BoxFit.contain` on the surface colour), with the title, briefing, creators, legal links below; no image shows the medium icon as now. The cover strip (`completed_works_card.dart`) shows a thumbnail cover when there is one, the icon with the tick otherwise.
4. **A portrait on creator rows**: unchanged, apart from the decode fix. A creator with no image keeps the person icon and "no licensed image yet".
5. **The credit line, a legal duty.** Attribution for CC BY and CC BY-SA means author, licence and a link, in a manner reasonable for the medium. Proposed, shown **with the image**: a one-line caption "Credit, author, licence" under every poster and portrait (the creator sheet already has it), a "Licence and source" button opening `licence_url` and `source_url` (the page of the file on Commons), and the same on the full-screen viewer. **Settings' Sources screen** adds one aggregated line per language: "Pictures from Wikimedia Commons" with the list of credits, as the deck screen lists card images. A `public-domain` image is credited too, though the law may not ask it: the credit text says where it came from. Decision 13.
6. **Tap to zoom.** A full-screen viewer (`InteractiveViewer`) for a poster or portrait, decoding at full size there only.
7. **Dark and light.** No inversion of a picture. An image with alpha is drawn on `surfaceContainer`; a poster has a hairline outline in `outlineVariant` so a light poster does not float on a light surface. Contrast of the caption is checked at 1.4x text, the cap.
8. **Offline.** A picture that was shown is on the phone and shows offline. One that was not shows the placeholder, without an error and without a retry storm: a failed fetch is remembered for the session, and retried on the next opening of the screen.
9. **Accessibility.** The image has a semantic label naming the work or person ("Poster of Kanku", `cultureImageOf`); the credit line is readable text, not part of the picture.
10. **Tests.** Widget tests at 1x and 1.4x text in light and dark with Hindi and Bengali titles, a golden-free check that `cacheWidth` is set, a loader test for hash mismatch and a missing index entry.

## 6. Work packages and order

Cards and creators need no change to benefit from the tool; the data lands on `decks-live` as the tool finds it, and the app shows work images once a release holds package 4. Repo rules apply (CLAUDE.md): this plan and the ADR are Markdown, straight to `main`; packages 1 to 4 are code, each a pull request to `main` with CI green and one Sonnet review; the data is a pull request to `decks-live` per language with "Validate decks" and "Released app reads the decks" green; one Sonnet coder and one Haiku deck builder at a time; no agent runs tests or the validator locally; no tags; one CHANGELOG line, for the release that shows work posters and credits.

| # | Package | Where | Who | Depends on |
|---|---|---|---|---|
| 0 | Owner decisions (list in ADR-0060) | issue | owner | none |
| 1 | **Validator** (done: tick, 2026-11-21): caps per kind, one licence rule, `image` on recommendations, `wikidata`, `image.kind`, credit rules, orphans, budget lint, `--image-report`, index `shared_media` for work images, tests | code, PR to `main` | Sonnet coder; one Sonnet review | 0 (1 to 4, 7 to 9) |
| 2 | **`tools/fetch_culture_media.py`** and the shared Wikimedia client (or reuse the sounds package's), tests with mocked network and `ffmpeg`, `tools/README.md` and Deck-Tools lines | code, PR to `main` | Sonnet coder; review | 1; 0 (14); the sounds tool's client if it has landed |
| 3 | **Mockup** (work page with poster, creator row, viewer, credit line, light and dark, 1.4x text, Hindi and Bengali), with its notes file | docs, per `docs/mockups/README.md` | Sonnet; owner approves | 0 (5, 13) |
| 4 | **App**: decode fix and binary cache (4a, may ship first and alone), work poster and cover thumbnail, credit line and licence link, viewer, Sources line, index `shared_media` for work images with `min_app`, tests | code, PRs to `main` (4a, then the rest) | Sonnet coder; review | 3 for the display; 1 for the index shape |
| 5 | **Survey run**, all languages, `--survey` only: the real coverage and the real byte sizes, the standard-width question, the 429 behaviour from this session; the numbers are written into this plan | report only, no PR | Haiku runs the tool | 2 |
| 6 | **First fetch run, Gujarati** (25 creators, 20 works: the most complete file and a small one), the identity check read closely; PR with images and credits | `decks-live`, PR | Haiku runs; one Sonnet review | 2, 5 |
| 7 | **The culture priority list**: Japanese, Spanish, French, Telugu, Marathi, Bengali, Assamese (the order of Plan-Language-Completeness), then Hindustani, Kannada, Sanskrit; one PR per language, creators and works together | `decks-live`, PRs | Haiku; one Sonnet review each | 6 accepted |
| 8 | **Place and event card images** for culture cards that are about one | `decks-live` | Haiku builder where a deck edit is needed; Sonnet review | 7 |
| 9 | **`--audit`**: re-read every stored credit, list files since deleted from Commons or relicensed, so a bad file is removed with its credit | code later | Sonnet | 7 |

Deck work waits for the coding queue (CLAUDE.md, "Deck work waits for the rest"). The survey run is read only and needs no PR; the per-language runs (6 to 8) are deck work, and the owner decides whether to lift the wait for them (decision 17).

## Open questions this plan does not settle

- How a work with **several editions** (a classic with many covers) picks one: proposed, the first free image Wikidata lists for the work, else the earliest edition item's.
- A **work whose creator has no verified QID** (a creator the identity check rejected) is not matched: the loop needs a verified creator to verify a work, so it waits for the creator's QID, which a reviewer may add by hand.
- **Right to be forgotten and takedown:** a file deleted from Commons after packaging stays in git and the app. The audit (package 9) lists it; removing it is a one-line change on `decks-live`.

See also: [ADR-0060](ADR-0060-Culture-Media-From-Wikimedia-Commons) · [Plan-Sounds-Decks](Plan-Sounds-Decks) · [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics) · [Plan-Language-Completeness](Plan-Language-Completeness) · [Deck-Format](Deck-Format) · [Plans-Index](Plans-Index) · [Home](Home)
