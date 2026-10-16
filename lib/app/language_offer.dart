import '../core/decks/language_catalog.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import 'app_state.dart';
import 'deck_catalog.dart';

/// The first letters of a script deck, each with its reading: "അ a".
typedef ScriptLetter = ({String letter, String? reading});

/// What the language picker reads of the app (#211): every language on
/// offer as a [CatalogLanguage], the learner's own progress toward B1, and
/// what learning a script includes. Through `AppState`'s public API only,
/// so that the picker needs nothing private.
extension LanguageOffer on AppState {
  /// Every language the learner can choose, in the order of
  /// [languagesOnOffer]: from the deck index where decks download, with
  /// each course's completeness from its units, else from the decks on the
  /// phone. Own names come from the index, else from [ownNames], the
  /// spoken languages' list (`assets/languages.yaml`).
  List<CatalogLanguage> catalogLanguages({
    Map<String, String> ownNames = const <String, String>{},
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
            ),
            onPhone.contains(offered.code),
          )
        else
          catalogLanguageFromDecks(offered.code, ownNames: ownNames),
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
        )
      : language;

  /// [code] as the decks on the phone describe it: its natives from the
  /// decks that teach it, and each course's completeness from its path's
  /// B1 plan and the words its decks have, counted as
  /// `tools/deck_index.py` counts them, so that both give the same figure.
  CatalogLanguage catalogLanguageFromDecks(
    String code, {
    Map<String, String> ownNames = const <String, String>{},
  }) {
    final teaching = <DeckEntry>[
      for (final entry in decks)
        if (entry.language.code == code) entry,
    ];
    final first = teaching.firstOrNull;
    final natives = <String, LanguageInfo>{
      for (final entry in teaching) entry.deck.native.code: entry.deck.native,
    };
    return CatalogLanguage(
      code: code,
      name: first?.language.name ?? code,
      ownName: ownNames[code],
      icon: first?.language.icon,
      script: first?.language.script,
      scriptDecks: hasAlphabet(code),
      natives: <CatalogNative>[
        for (final native in natives.values)
          (
            code: native.code,
            name: native.name,
            progress: B1Progress.of(b1Units(code, native.code)),
          ),
      ],
    );
  }

  /// The units of [language]'s course from [native], as completeness counts
  /// them: each unit of its path with the words its decks have, script
  /// decks and grammar tables left out. Without a path, each deck as a unit
  /// with no plan, so that only the course's size is known.
  List<B1Unit> b1Units(String language, String native) {
    final course = <DeckEntry>[
      for (final entry in decks)
        if (entry.language.code == language && entry.deck.native.code == native)
          entry,
    ];
    if (course.isEmpty) return const <B1Unit>[];
    final path = pathOf(course.first);
    final byId = <String, DeckEntry>{for (final e in course) e.id: e};
    if (path == null) {
      return <B1Unit>[
        for (final entry in course)
          B1Unit(has: _words(<DeckEntry>[entry], const <String>{}).length),
      ];
    }
    return <B1Unit>[
      for (final unit in path.plan)
        B1Unit(
          planned: unit.isPlanned,
          words: unit.words,
          milestone: unit.milestone,
          grammar: unit.grammar,
          has: unit.isComing || (unit.decks.isEmpty && unit.open)
              ? null
              : _words(<DeckEntry>[
                  for (final id in unit.decks) ?byId[id],
                ], path.alphabet).length,
        ),
    ];
  }

  /// The ids of the cards of [entries] that count as words, the decks in
  /// [alphabet] left out.
  static Set<String> _words(List<DeckEntry> entries, Set<String> alphabet) =>
      <String>{
        for (final entry in entries)
          if (!alphabet.contains(entry.id))
            for (final card in entry.cards)
              if (countsAsWord(card, entry.deck.kind)) card.id,
      };

  /// How far the learner is toward B1 in [language], 0–1, as its course
  /// from [courseNative] is taught: each unit's words learned, at most what
  /// it plans. Null when its path has no B1 plan, or no deck of it is on
  /// the phone.
  double? learnedShare(String language) {
    final native = courseNative(language);
    if (native == null) return null;
    final units = b1Units(language, native);
    final progress = B1Progress.of(units);
    if (!progress.hasPlan) return null;
    final learned = _learnedCards();
    final course = <DeckEntry>[
      for (final entry in decks)
        if (entry.language.code == language && entry.deck.native.code == native)
          entry,
    ];
    final path = pathOf(course.first)!;
    final byId = <String, DeckEntry>{for (final e in course) e.id: e};
    return progress.learnedShare(<int>[
      for (final unit in path.plan)
        _words(<DeckEntry>[
          for (final id in unit.decks) ?byId[id],
        ], path.alphabet).where(learned.contains).length,
    ]);
  }

  /// The words of [language] the learner has learned, where its path has
  /// no B1 plan: distinct word cards answered right at least once.
  int learnedWords(String language) {
    final learned = _learnedCards();
    return <String>{
      for (final entry in decks)
        if (entry.language.code == language)
          for (final card in entry.cards)
            if (countsAsWord(card, entry.deck.kind) &&
                learned.contains(card.id))
              card.id,
    }.length;
  }

  Set<String> _learnedCards() => <String>{
    for (final MapEntry(:key, :value) in progress.states.entries)
      if (value.repetitions > 0) key.cardId,
  };

  /// What learning [language]'s script includes, from the decks on the
  /// phone: how many decks its path marks as needing the alphabet, and the
  /// first three letters of the first, with their readings. Null when its
  /// path is not on the phone.
  ({int decks, List<ScriptLetter> letters})? scriptPreview(String language) {
    final path = languagePathOf(language);
    if (path == null || path.alphabet.isEmpty) return null;
    final native = courseNative(language);
    DeckEntry? firstDeck;
    for (final unit in path.plan) {
      for (final core in unit.decks) {
        if (!path.alphabet.contains(core)) continue;
        firstDeck ??= native == null
            ? null
            : deckById(path.deckFor(native, core));
      }
    }
    return (
      decks: path.alphabet.length,
      letters: <ScriptLetter>[
        for (final card in firstDeck?.cards.take(3) ?? const <Card>[])
          (letter: card.target, reading: card.reading),
      ],
    );
  }
}
