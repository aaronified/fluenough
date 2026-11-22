# ADR-0062: The catalog is one unit per language, loaded on demand off the UI isolate

Source of truth: this wiki page.

- **Status:** Proposed (owner order, 2026-11-22). The choices below are the author's defaults for the owner to confirm; the open questions, each with its default, are in section 9 of the plan. The full reasoning, the consumer inventory, the work packages and the acceptance numbers are in [Plan-Lazy-Language-Loading](Plan-Lazy-Language-Loading).
- **Date:** 2026-11-22

## Context

The owner's order, 2026-11-22: "Load only the language selected on startup (then load others when they are selected), not all of them. And not in UI thread."

Today a cold start reads every installed deck file of every language on the main isolate, copies all of the text into one isolate job that parses everything from a single snapshot (ADR-0048), and returns the whole catalog; the UI isolate then loops over every card of every deck to build the skill map (which also triggers a synchronous full replay of the review log, `MemoryProgress.skills`) and to apply the adult filter. The decks on `decks-live` are 85.6 MB in 7,174 files, and a phone holds every language it downloaded. The learner sees one language at a time (#461), so most of this work is for languages that are not on screen, and the cost grows with each language added.

The data is already partitioned: every deck file lies under `decks/<code>/`, card and deck ids name their language (ADR-0018), no card ref crosses a language, and the index and the download manifest are per language already (ADR-0037).

## Decision

- **One catalog unit per language.** A language unit holds that language's decks, its language files (path, facts, situations, numbers, romanisation, sounds, script guide, topics), its creators and recommendations, the private-package and learner-added files that name it, and its hidden decks. The shared unit (`themes.yaml`, `sections.yaml`) is small and always loaded. `DeckCatalog.parseAll` parses a unit by being given only that unit's files plus the shared texts.
- **Loaded on demand, in an isolate.** A worker isolate reads the unit's files itself (the main isolate never holds deck text), reads that language's snapshot, parses, and returns only the parsed model (by `Isolate.exit`, transferred, not copied). One unit load at a time; the selected language goes first.
- **Startup loads the selected language only.** The selected language is resolved without the catalog (as `_todayScope` already does for the saved Today summary), from the settings, the profile and the languages on the phone. Other languages load when the learner selects them (the language bar applies the choice at once and the content shows a per-language loading state that never blocks input), when a flow enters them (placement, a reviewer's language, a deep link, a reminder tap), or, optionally, by idle prefetch of the likely next one.
- **A snapshot per language** (ADR-0048's content, one file per language, same SHA-256 and version rules), so that an app update or a download re-parses only the languages that are used.
- **A language summary**, one small record per language on the phone, computed by the same unit job and by a *summarise* job after every download or update, kept in one file read at startup: the language info, names, icon, scripts, natives, course and unit counts, the B1 plan units, deck lists, which features a language has, credits, the skill-map inputs (`formHeardCards`, script deck ids, primary script), the IPA keyboard's symbols, and a stamped cache of the learner's share toward B1. Every screen that lists or names languages, the picker, Languages, the language bar, Sources, backup names and reminders read the summary or the deck index, never a parsed deck. A summary is stale-while-revalidate: used after an app update and refreshed in idle time.
- **The skill map comes from the summaries**, so it is complete at startup and does not change when a unit loads; passing it into the open's replay removes the UI-isolate replay that every launch and every `_reloadDecks` does today.
- **Progress needs no deck.** The log, the progress index and the per-language versions work from card ids; due counts of languages that are not loaded come from the log (exact once loaded); only building a session, and numbers that count cards, need the unit.
- **Migration behind a flag.** The old whole-catalog API is kept as a composed view over the loaded units while consumers move (one pull request per consumer group); the default flips to lazy when they have; the whole-catalog path is deleted in a last pull request. Caches keyed on the identity of `state.decks`, and `_structureVersion`, become per language.

## Consequences

- Startup reads, decodes and parses one language instead of every language, with no deck text on the UI isolate; the first-frame cost no longer grows with the number of languages downloaded.
- A language selected for the first time in a session costs one unit load, with a snapshot hit usually under a second (INFERENCE); the loading state is part of the design.
- A new cache to keep honest (the summaries): its freshness stamp, its golden test and the parity test with the deck index's counts are part of the work, as the `SkillMap` equivalence test and the "union of units equals the whole catalog" test are.
- Features that read across languages are named and given a rule: the IPA course is a dependency language loaded on demand, a partner card for a sound-alike is found in its own language, a reviewer's pages load the language in hand, and a global search is not offered.
- `lib/core` keeps its Flutter-free rule; no card id, deck file, index schema or download protocol changes; the new files are caches and can be deleted at any time.

## Alternatives considered

- **Keep the whole catalog, only move the reads and the loops off the UI isolate.** This is the first step (the `whole` mode of the plan) and removes the UI-thread work, but the parse and the memory still grow with every language, and the first frame waits for all of it.
- **Snapshot the parsed models** (the alternative ADR-0048 rejected). Faster per language, but needs a codec for every model and a version bump with each model change; it can still be added later per unit without changing this design.
- **Compute the summaries in `tools/deck_index.py`** and ship them in the index. They would be ready for languages not downloaded, but the tool cannot see the phone's actual files (partial downloads, the learner's native layers, private and added decks) and would duplicate the parsers' counting rules; the index keeps serving the languages not on the phone.
- **Load a language when a screen first reads it, implicitly.** Synchronous getters would then have to block or return partial data; explicit `ensureLoaded` and a load state keep the UI thread free and make every cross-language read visible and testable.
