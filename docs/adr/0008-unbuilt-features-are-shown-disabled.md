# ADR-0008: Features without a backend are built and shown disabled

- **Status:** Accepted
- **Date:** 2026-09-28

## Context

The UI is built from a design that draws the whole app: profiles and PINs,
four drills and minimal pairs, import from four sources, statistics, leeches,
a reminder, appearance, review-log export. Most of that has no backend yet. The
database is #3 and #5, the grammar expander #2, minimal pairs #31, import #22
and #23, and so on.

The maintainer's instruction is to replicate the design as a whole and switch
features on as their backends land. That leaves two questions: what a screen
shows for something that is built but not yet working, and how the codebase
knows which is which without every screen deciding for itself.

The design answers the first itself: a "Feature incoming" badge on a greyed
control, and a toast saying "Feature incoming. Not in this version yet."
(Main.dc.html, its `incoming` flags).

## Decision

**A registry.** `lib/app/features.dart` holds `enum Feature`, one value per
switchable thing, each naming the issue whose PR turns it on. The set
`Feature.available` is what this version ships: the recognition, production and
listening drills. `FeatureRegistry` wraps it; `AppState.features` is the one
screens read. It is interface policy, so it lives in `lib/app`, not
`lib/core`.

An issue number of 0 means no issue exists yet. That is allowed only for the
features the UI plan lists as having none — profiles and PINs, colour seeds and
wallpaper colours, in-app CSV import, and the voice settings link, which needs a
dependency before it can have an issue — and `test/app/features_test.dart`
holds that list. Every other feature that is not available must name an issue.

**How a feature is switched on.** The PR that completes a feature's backend
adds it to `Feature.available` — a one-line diff in a file nobody else edits —
and adds a widget test showing the screen working live. Tests and the debug
gallery can use `FeatureRegistry.all()` to see every screen live now.

**How disabled looks.** `IncomingFeature(feature:, label:, child:)` in
`lib/ui/widgets/incoming.dart`, and the same treatment built into
`GroupedTile`:

- the content at 38% opacity, M3's disabled-content opacity, with controls in
  M3's own disabled styling (`onChanged: null`);
- a full-contrast "Feature incoming" badge, so the state is never shown by
  colour alone;
- a tap shows the SnackBar "Feature incoming. Not in this version yet.", which
  screen readers announce;
- one semantics node — a disabled button labelled "*label*, feature incoming",
  with the hint "Not in this version yet" — so TalkBack says all of it without
  needing the SnackBar.

**Three kinds of absence, kept apart.** *Incoming* comes from the registry and
looks as above. *Missing on this phone* is a runtime check — no voice for a
language — and shows the reason and a way to fix it, never the incoming badge.
*No content* is data: an empty state, or a row that is not shown. A screen
that mixes these up tells the learner the wrong thing: that a voice is coming
in an update, say, when it only needs installing.

## Consequences

Every screen of the design exists from the first UI release, so the design and
the app can be compared screen by screen, and a backend PR's diff is its
backend plus one line, not a screen.

The cost is shipping controls that do nothing. A learner sees a PIN switch they
cannot turn on. The badge and the SnackBar make that honest, but it is still
more interface than working features, and a release that is mostly badges
would read as unfinished. The registry makes the ratio visible: it is the
length of `Feature.available` against `Feature.values`.

A feature can only be off or on for everyone. There is no per-user or remote
flag, and none is wanted: this is a build-time list, reviewed in PRs.

Building a screen before its backend means guessing its data. Where a screen is
built on fixtures (grammar, minimal pairs, statistics, leeches), the guess can
be wrong, and the backend PR may have to change the screen after all. #14's
table needs each card's `(entry, slot)`, for example, which #2 should expose.

## Alternatives considered

**Hide what is not built.** The usual approach, and what `DESIGN.md` said for
listening without a voice. Rejected for *incoming* features because the design
is the north star and is drawn complete; hiding would make every backend PR also
a UI PR. *Missing on this phone* is not hidden either: the design shows a
disabled Listening row with "Set up", and a session still never contains a card
that cannot be drilled, so nothing is broken.

**Build a screen only when its backend lands.** Keeps the app honest, but
serialises the UI behind the backlog and splits one design across a dozen PRs
by different people. Rejected.

**A flag per screen, decided in the screen.** No registry, each screen checks
its own condition. Rejected: nothing would list what is off, and nothing would
fail when a feature has no issue to turn it on.
