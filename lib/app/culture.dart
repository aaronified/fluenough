import '../core/data/course_path.dart' show PlanUnit;
import '../core/decks/timeline.dart';
import '../core/decks/timeline_entries.dart';
import '../core/decks/weave.dart';
import '../core/models/creator.dart';
import '../core/models/level.dart';
import '../core/models/recommendation.dart';
import 'app_state.dart';
import 'deck_catalog.dart';
import 'item_search.dart' show coreIdOfDeck;

/// Culture in the course (deck-kinds plan, D5, D11, T20; the approved mockup
/// `culture-in-course.html`): the culture and proverbs items of a language,
/// the unit of its path each is woven into at the learner's level, the next
/// one for Today, and the people behind them with their timeline. The rules
/// are the pure functions of `lib/core/decks/weave.dart`; this feeds them from
/// the catalog and the learner's level, and nothing here throws: what cannot
/// be read is logged and left out.
extension CultureState on AppState {
  /// Every culture and proverbs item of [language] that its deck lets weave,
  /// whatever its level, in deck order: the decks taught from the course's
  /// native language first, so that a card two natives write is the course's.
  List<CultureItem> cultureItemsIn(String language) =>
      derived<List<CultureItem>>(('cultureItems', language), () {
        try {
          final catalog = catalogWithAboveLevel;
          final native = courseNative(language);
          final entries = <DeckEntry>[
            for (final entry in catalog.decks)
              if (entry.language.code == language) entry,
          ];
          final first = <DeckEntry>[
            for (final entry in entries)
              if (entry.deck.native.code == native) entry,
          ];
          final rest = <DeckEntry>[
            for (final entry in entries)
              if (entry.deck.native.code != native) entry,
          ];
          return cultureItemsOf(
            <DeckEntry>[...first, ...rest].map((e) => e.deck),
            weaves: catalog.sections.weaves,
            onProblem: log.warning,
          );
        } on Object catch (error, stack) {
          log.error('Culture items of $language failed: $error\n$stack');
          return const <CultureItem>[];
        }
      });

  /// The culture item of [language] with [id], or null.
  CultureItem? cultureItemById(String language, String id) {
    for (final item in cultureItemsIn(language)) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// The culture items of [language] woven into its path for this learner:
  /// the learner's level, the items per unit from Settings. Nothing for a
  /// language with no path or no levels.
  WovenCulture wovenCultureOf(String language) {
    final level = levelIn(language);
    final per = settings.culturePerUnit;
    return derived<WovenCulture>(('woven', language, level, per), () {
      try {
        final plan = languagePathOf(language)?.plan ?? const <PlanUnit>[];
        return weaveCulture(
          plan,
          cultureItemsIn(language),
          level,
          perUnit: per,
        );
      } on Object catch (error, stack) {
        log.error('Culture of $language could not be woven: $error\n$stack');
        return WovenCulture.none;
      }
    });
  }

  /// The index in [language]'s path of the unit holding [unitDecks], or -1.
  int pathIndexOfUnit(String language, List<DeckEntry> unitDecks) {
    final plan = languagePathOf(language)?.plan;
    if (plan == null) return -1;
    final cores = <String>{for (final e in unitDecks) ?coreIdOfDeck(e)};
    return plan.indexWhere((unit) => unit.decks.any(cores.contains));
  }

  /// Whether the learner has met [item]: every card of it is taught.
  bool isCultureItemDone(CultureItem item) =>
      item.cards.isNotEmpty && item.cards.every(isTaught);

  /// The culture item Today offers for [language]: the first woven item not
  /// met yet, or null when culture is off or all are met.
  CultureItem? nextCultureItem(String language) {
    if (!settings.cultureItems) return null;
    return wovenCultureOf(language).next(isCultureItemDone);
  }

  /// The people of [language]'s culture, or null when it has none.
  CreatorsFile? creatorsOf(String language) =>
      catalogWithAboveLevel.creators[language];

  /// Every creator any work of [language] cites: each card and passage of
  /// every deck of the language, hidden or not, woven or not, and every
  /// recommended work, whatever its level. This is the "who is cited" set of
  /// the name-leak rule: a creator cited anywhere but shown by no work at the
  /// learner's level is kept out of People, the timeline and the legacy marks,
  /// so that their name never gives an unreached work away.
  ///
  /// Limit: a hidden deck that is not downloaded cannot be read here, so its
  /// creators are missing from this set (a follow-up could put creator ids in
  /// the index shelves).
  Set<String> creatorsCitedIn(String language) => derived<Set<String>>(
    ('creatorsCited', language),
    () {
      final cited = <String>{};
      try {
        final catalog = catalogWithAboveLevel;
        for (final entry in <DeckEntry>[...catalog.decks, ...catalog.hidden]) {
          if (entry.language.code != language) continue;
          for (final card in entry.deck.cards) {
            cited.addAll(card.creators);
          }
          for (final passage in entry.deck.passages) {
            cited.addAll(passage.creators);
          }
        }
        for (final rec
            in catalog.recommendations[language]?.recommendations ??
                const <Recommendation>[]) {
          cited.addAll(rec.creators);
        }
      } on Object catch (error, stack) {
        log.error('Creators cited in $language failed: $error\n$stack');
      }
      return cited;
    },
  );

  /// The creators of [language] that may be named to this learner: those a
  /// shown item cites, an item of the learner's level in a deck that is not
  /// hidden. With [support] (culture above the level, with support) an item
  /// above the level also shows its creators, unless a hidden deck's card
  /// cites them too.
  Set<String> creatorsShownIn(String language, {required bool support}) {
    final shown = <String>{};
    try {
      final learner = levelIn(language);
      final hiddenCited = <String>{};
      for (final entry in catalogWithAboveLevel.hidden) {
        if (entry.language.code != language) continue;
        for (final card in entry.deck.cards) {
          hiddenCited.addAll(card.creators);
        }
        for (final passage in entry.deck.passages) {
          hiddenCited.addAll(passage.creators);
        }
      }
      for (final item in cultureItemsIn(language)) {
        if (LevelGate.allows(item.level, learner)) {
          shown.addAll(item.creators);
        } else if (support) {
          shown.addAll(item.creators.where((c) => !hiddenCited.contains(c)));
        }
      }
    } on Object catch (error, stack) {
      log.error('Creators shown in $language failed: $error\n$stack');
    }
    return shown;
  }

  /// The timeline of [language]'s culture for this learner, to today.
  Timeline cultureTimelineOf(String language) {
    final file = creatorsOf(language);
    if (file == null) return Timeline.empty;
    try {
      return buildTimeline(
        file,
        timelineWorksOf(cultureItemsIn(language)),
        levelIn(language),
        today: now().year,
        alsoCited: creatorsCitedIn(language),
      );
    } on Object catch (error, stack) {
      log.error('Timeline of $language failed: $error\n$stack');
      return Timeline.empty;
    }
  }

  /// The timeline's events in order, ending with today.
  List<TimelineEntry> cultureTimelineEntriesOf(String language) {
    final file = creatorsOf(language);
    if (file == null) return const <TimelineEntry>[];
    try {
      return timelineEntriesOf(
        cultureTimelineOf(language),
        file,
        <String, CultureItem>{
          for (final item in cultureItemsIn(language)) item.id: item,
        },
      );
    } on Object catch (error, stack) {
      log.error('Timeline entries of $language failed: $error\n$stack');
      return const <TimelineEntry>[];
    }
  }
}
