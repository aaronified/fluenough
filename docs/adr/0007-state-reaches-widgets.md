# ADR-0007: State reaches widgets through AppScope, with no package

- **Status:** Accepted. Amended by ADR-0037: decks are downloaded, not bundled.
- **Date:** 2026-09-28

## Context

#43 asks how application state — the decks, the scheduling state, the
settings, whether a feature is built — reaches the widgets that show it. The UI
is about to be built by several people at once, from one design, so the answer
has to be settled before the first screen and has to be the same on every one.

Three constraints shape it. Rule 3 keeps `lib/core` free of Flutter, so state
that widgets listen to cannot live there. Rule 6 keeps dependencies few, and
every state-management package is one. And the maintainer chose built-in
state: `ChangeNotifier`, `ListenableBuilder` and an `InheritedNotifier`, and
nothing else.

The state itself is small. There is one catalog of decks, one progress store,
one set of settings, one list of profiles, and a drill session that lives only
as long as its screen.

## Decision

**`AppState extends ChangeNotifier`** (`lib/app/app_state.dart`) holds the
app's state and takes its services through the constructor: a `DeckCatalog`,
a `ProgressStore`, a `TtsEngine`, a `FeatureRegistry` and a clock. Nothing
constructs a service inside it, so a test builds the whole app from fakes:
`AppState.test()` runs on the real bundled decks, no voices, empty in-memory
progress and a fixed clock.

**It notifies only on app-level changes**: the catalog loading, voices being
checked, the current profile or the profile list changing. Things that change
often have notifiers of their own, read with `ListenableBuilder` where they are
shown:

- `AppState.settings`, a `SettingsNotifier`;
- `AppState.progress`, a `ProgressStore`, which is `Listenable`;
- `AppState.shellTab`, a `ValueNotifier` for the tab the shell shows.

**`AppScope extends InheritedNotifier<AppState>`** (`lib/app/app_scope.dart`)
puts it in the tree, above `MaterialApp`. `AppScope.of(context)` subscribes the
caller to `AppState`'s notifications; `AppScope.read(context)` does not, for
callbacks and `initState`.

**Screens never import a concrete service.** Only `lib/main.dart` names
`SystemTtsEngine`, `DeckCatalog.bundled()` and `MemoryProgress`. Everything else
goes through `AppState`: `buildSession`, `record`, `speak`, `voiceStatus`,
`deckById`.

**A drill session belongs to its route.** A drill page's `State` owns its
session controller, a `ChangeNotifier`, and disposes it with the route. Nothing
about a session lives in `AppState` except what it records.

**Every answer is recorded the moment it is given**, through
`AppState.record`, never batched at the end of a session. A session that is
interrupted loses nothing that was answered (and, until #5, nothing survives the
app closing, which Today says).

## Consequences

There is no package and no code generation, and there are three classes to
learn: `AppState`, `AppScope`, and the fine-grained notifiers. Anyone who knows
Flutter already knows all three.

Tests are simple: pump `AppScope(state: AppState.test(...), child: ...)`, or the
whole app with `FluenoughApp(state: AppState.test(...))`. Nothing needs
overriding, mocking or a provider container.

What a package would do for us is now ours to get right. Disposing a
controller, and choosing between `of` and `read` so that a widget does not
rebuild for changes it does not show, are the developer's job. A widget that
calls `AppScope.of` rebuilds on every app-level change; a widget that listens
to `settings` rebuilds on every settings change. At this app's size that is
cheap, but it is a cost nobody is checking automatically.

There are no devtools for this state, no time travel and no inspector beyond
Flutter's own.

`AppState` is one class that many screens depend on, which makes it a
contention point in the same way `app_en.arb` is. Keeping it thin — services
behind interfaces, queries as extensions on `ProgressStore`, per-screen state
in the screen — is what keeps it from becoming a god object.

## Alternatives considered

**provider.** A dependency for sugar over exactly this: `InheritedNotifier` and
`ChangeNotifier` are what it wraps. Rejected under rule 6.

**riverpod, bloc.** A dependency, plus either code generation or a layer of
boilerplate (events, states, providers) that the app's state is too small to
justify. Rejected.

**get_it, or another service locator.** Hides a widget's dependencies instead
of passing them, which is the property that makes the tests simple. Rejected.

**Globals.** Untestable: every test would share one app. Rejected.
