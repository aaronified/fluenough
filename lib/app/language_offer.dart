import '../core/decks/language_catalog.dart';
import '../core/decks/language_summary.dart' show SummaryCourse;
import '../core/models/deck.dart';
import 'app_state.dart';
import 'deck_catalog.dart';
import 'learned_cache.dart';

/// The first letters of a script deck, each with its reading: "അ a".
typedef ScriptLetter = ({String letter, String? reading});

/// What the language picker reads of the app (#211): every language on
/// offer as a [CatalogLanguage], the learner's own progress toward B1, and
/// what learning a script includes. Through `AppState`'s public API only,
/// so that the picker needs nothing private.
///
/// The languages on the phone are described by the language directory
/// (`AppState.summaryOf`), not by their decks, so that no unit is loaded to
/// list them (ADR-0062, Plan-Lazy-Language-Loading, 5.1).
extension LanguageOffer on AppState {
  /// Every language the learner can choose, in the order of
  /// [languagesOnOffer]: from the deck index where decks download, with
  /// each course's completeness from its units, else from the directory of
  /// the languages on the phone. Own names come from the index, else from
  /// [ownNames], the spoken languages' list (`assets/languages.yaml`).
  ///
  /// [noCulture] holds the codes of the languages with no culture at all
  /// (`culture: false` in the list), whose course line has no culture bar.
  List<CatalogLanguage> catalogLanguages({
    Map<String, String> ownNames = const <String, String>{},
    Set<String> noCulture = const <String>{},
  }) {
    final spoken = settings.spokenLanguages;
    final index = deckDownloads?.index;
    final onPhone = deckDownloads?.languagesOnPhone ?? const <String>{};
    return <CatalogLanguage>[
      for (final offered in languagesOnOffer)
        if (index?.language(offered.code) case final entry?)
          _withPhoneSize(
            CatalogLanguage.fromIndex(
              entry,
              spoken: spoken,
              ownNames: ownNames,
              hasCulture: !noCulture.contains(offered.code),
            ),
            onPhone.contains(offered.code),
          )
        else
          catalogLanguageFromDirectory(
            offered.code,
            ownNames: ownNames,
            hasCulture: !noCulture.contains(offered.code),
          ),
    ];
  }

  CatalogLanguage _withPhoneSize(CatalogLanguage language, bool onPhone) =>
      onPhone
      ? CatalogLanguage(
          code: language.code,
          name: language.name,
          ownName: language.ownName,
          icon: language.icon,
          script: language.script,
          scriptDecks: language.scriptDecks,
          natives: language.natives,
          size: deckDownloads!.sizeOnPhone(language.code),
          needsApp: language.needsApp,
          hasCulture: language.hasCulture,
        )
      : language;

  /// [code] as the language directory describes it: its natives from the
  /// decks that teach it, and each course's completeness from its path's
  /// B1 plan and the words its decks have, counted as
  /// `tools/deck_index.py` counts them, so that both give the same figure.
  CatalogLanguage catalogLanguageFromDirectory(
    String code, {
    Map<String, String> ownNames = const <String, String>{},
    bool hasCulture = true,
  }) {
    final summary = summaryOf(code);
    final info = summary?.info;
    return CatalogLanguage(
      hasCulture: hasCulture,
      code: code,
      name: info?.name ?? code,
      ownName: ownNames[code],
      icon: info?.icon,
      script: info?.script,
      scriptDecks: hasAlphabet(code),
      natives: <CatalogNative>[
        for (final course in summary?.courses ?? <SummaryCourse>[])
          (
            code: course.native,
            name: course.nativeName,
            progress: B1Progress.of(
              course.units,
              isNotation: info?.isNotation ?? false,
              cultureCards: course.cultureCards,
            ),
          ),
      ],
    );
  }

  /// The units of [language]'s course from [native], as completeness counts
  /// them: each unit of its path with the words its decks have, script
  /// decks and grammar tables left out. Without a path, each deck as a unit
  /// with no plan, so that only the course's size is known. From the
  /// directory.
  List<B1Unit> b1Units(String language, String native) {
    for (final course in summaryOf(language)?.courses ?? <SummaryCourse>[]) {
      if (course.native == native) return course.units;
    }
    return const <B1Unit>[];
  }

  /// How far the learner is toward B1 in [language], 0–1, as its course
  /// from [courseNative] is taught: each unit's words learned, at most what
  /// it plans. Null when its path has no B1 plan, or no deck of it is on
  /// the phone. Kept with what it was worked out from: a language whose unit
  /// is not loaded shows the figure last worked out (null before the first),
  /// and is worked out again in the background when it is stale (4.3).
  double? learnedShare(String language) => _learned(language)?.share;

  /// The words of [language] the learner has learned, where its path has
  /// no B1 plan: distinct word cards answered right at least once. Kept as
  /// [learnedShare] is.
  int learnedWords(String language) => _learned(language)?.words ?? 0;

  LearnedFigures? _learned(String language) {
    final stamp = learnedStampOf(language);
    final kept = learnedCache.fresh(language, stamp);
    if (kept != null) return kept;
    if (languageLoad(language).isLoaded) {
      final figures = learnedFiguresOf(this, language);
      learnedCache.keep(language, stamp, figures);
      return figures;
    }
    if (progress.index.reviewsIn(language) == 0) {
      // Nothing answered in it: nothing learned, which the directory alone
      // says, so that no unit is read for a language not started.
      final native = courseNative(language);
      final planned =
          native != null && B1Progress.of(b1Units(language, native)).hasPlan;
      final figures = (share: planned ? 0.0 : null, words: 0);
      learnedCache.keep(language, stamp, figures);
      return figures;
    }
    queueLearnedRefresh(language);
    return learnedCache.last(language);
  }

  /// What learning [language]'s script includes, from the directory: how
  /// many decks its path marks as needing the alphabet, and the first three
  /// letters of the first the course has, with their readings. Null when its
  /// path is not on the phone.
  ({int decks, List<ScriptLetter> letters})? scriptPreview(String language) {
    final summary = summaryOf(language);
    if (summary == null || !summary.hasPath || summary.scriptCount == 0) {
      return null;
    }
    final native = courseNative(language);
    final letters = <ScriptLetter>[];
    for (final course in summary.courses) {
      if (course.native != native) continue;
      for (final letter in course.scriptLetters.take(3)) {
        letters.add((letter: letter.letter, reading: letter.reading));
      }
    }
    return (decks: summary.scriptCount, letters: letters);
  }
}

/// [language]'s figures from the decks loaded now: the share toward B1 and
/// the words learned. The unit of [language] must be loaded.
LearnedFigures learnedFiguresOf(AppState state, String language) {
  final learned = _learnedCardsOf(state);
  return (
    share: _learnedShareOf(state, language, learned),
    words: _learnedWordsOf(state, language, learned),
  );
}

double? _learnedShareOf(AppState state, String language, Set<String> learned) {
  final native = state.courseNative(language);
  if (native == null) return null;
  final progress = B1Progress.of(state.b1Units(language, native));
  if (!progress.hasPlan) return null;
  final course = <DeckEntry>[
    for (final entry in state.decks)
      if (entry.language.code == language && entry.deck.native.code == native)
        entry,
  ];
  if (course.isEmpty) return null;
  final path = state.pathOf(course.first);
  if (path == null) return null;
  final byId = <String, DeckEntry>{for (final e in course) e.id: e};
  return progress.learnedShare(<int>[
    for (final unit in path.plan)
      _wordsOf(<DeckEntry>[
        for (final id in unit.decks) ?byId[id],
      ], path.alphabet).where(learned.contains).length,
  ]);
}

int _learnedWordsOf(AppState state, String language, Set<String> learned) {
  final words = <String>{
    for (final entry in state.decks)
      if (entry.language.code == language)
        for (final card in entry.cards)
          if (countsAsWord(card, entry.deck.kind) && learned.contains(card.id))
            card.id,
  };
  return words.length;
}

/// The ids of the cards of [entries] that count as words, the decks in
/// [alphabet] left out.
Set<String> _wordsOf(List<DeckEntry> entries, Set<String> alphabet) {
  return <String>{
    for (final entry in entries)
      if (!alphabet.contains(entry.id))
        for (final card in entry.cards)
          if (countsAsWord(card, entry.deck.kind)) card.id,
  };
}

/// The ids of the cards [state]'s learner has answered right at least once.
Set<String> _learnedCardsOf(AppState state) => <String>{
  for (final MapEntry(:key, :value) in state.progress.states.entries)
    if (value.repetitions > 0) key.cardId,
};

/// The script test (#554), as the language picker reads it of the app.
extension ScriptLessons on AppState {
  /// [language]'s script lessons in its course from [native], or the course
  /// it is learned from: the decks its path marks as needing the alphabet
  /// that teach the script itself, in path order. Not its spelling or
  /// reading decks, which teach words. Empty while its decks are not on the
  /// phone.
  List<DeckEntry> scriptLessons(String language, {String? native}) {
    final path = languagePathOf(language);
    final from = native ?? courseNative(language);
    if (path == null || path.alphabet.isEmpty || from == null) {
      return const <DeckEntry>[];
    }
    return <DeckEntry>[
      for (final unit in path.plan)
        for (final core in unit.decks)
          if (path.alphabet.contains(core))
            if (deckById(path.deckFor(from, core)) case final entry?
                when entry.isScript)
              entry,
    ];
  }

  /// Whether [language]'s script lessons are skipped: each placed, as a
  /// passed script test places them.
  bool scriptLessonsSkipped(String language, {String? native}) {
    final lessons = scriptLessons(language, native: native);
    return lessons.isNotEmpty && lessons.every(isPlaced);
  }

  /// Skips [language]'s script lessons, placing them as known, after a
  /// passed script test; or, after a failed one, teaches them again.
  void skipScriptLessons(String language, bool skip, {String? native}) {
    final ids = <String>{
      for (final entry in scriptLessons(language, native: native)) entry.id,
    };
    final placed = settings.placedDecks;
    settings.placedDecks = skip
        ? <String>{...placed, ...ids}
        : placed.difference(ids);
  }

  /// How far the learner is through [language]'s script lessons (#626): how
  /// many of them there are, how many have every card learned, and the share
  /// of their cards learned, 0–1. Null while the lessons are not on the
  /// phone.
  ({int decks, int learnedDecks, double share})? scriptProgress(
    String language,
  ) {
    final lessons = scriptLessons(language);
    if (lessons.isEmpty) return null;
    final learned = _learnedCardsOf(this);
    var cards = 0;
    var known = 0;
    var done = 0;
    for (final entry in lessons) {
      final ids = <String>[for (final card in entry.cards) card.id];
      final got = ids.where(learned.contains).length;
      cards += ids.length;
      known += got;
      if (ids.isNotEmpty && got == ids.length) done++;
    }
    return (
      decks: lessons.length,
      learnedDecks: done,
      share: cards == 0 ? 0 : known / cards,
    );
  }
}
