import '../core/models/deck.dart';
import 'app_state.dart';
import 'deck_catalog.dart';
import 'placement.dart';

/// One script a course is placed in (#481): [script], its decks that need
/// the alphabet in path order, the language its script decks are written
/// as (for the voice that says a word in it), and the course's words
/// spelled in it.
typedef PlacementScript = ({
  String script,
  List<DeckEntry> decks,
  LanguageInfo language,
  List<ScriptWord> words,
});

/// What placement reads of a course (#481, `docs/plans/placement-v2.md`).
extension PlacementPlan on AppState {
  /// [code]'s course from [native], or the language it is learned from,
  /// with every one of its scripts' decks, in path order.
  List<DeckEntry> _wholeCourse(String code, {String? native}) {
    final scripts = <String>{
      for (final entry in decks)
        if (entry.language.code == code) ...<String>[
          entry.language.script,
          ...entry.language.allScripts,
        ],
    };
    return <DeckEntry>[
      for (final unit in courseUnits(code, scripts: scripts, native: native))
        ...unit,
    ];
  }

  /// The scripts of [code]'s course that a script check asks about: each
  /// with script decks on its path, in path order. None for a course
  /// written in Latin letters, which has none, and for a notation, which
  /// placement does not place.
  List<PlacementScript> placementScripts(String code, {String? native}) {
    final course = _wholeCourse(code, native: native);
    final byScript = <String, List<DeckEntry>>{};
    for (final entry in course) {
      if (!needsAlphabet(entry)) continue;
      byScript
          .putIfAbsent(entry.language.script, () => <DeckEntry>[])
          .add(entry);
    }
    final words = walkDecks(code, native: native);
    return <PlacementScript>[
      for (final MapEntry(key: script, value: scriptDecks) in byScript.entries)
        if (script != 'latin' && scriptDecks.any((e) => e.isScript))
          (
            script: script,
            decks: scriptDecks,
            language: scriptDecks.firstWhere((e) => e.isScript).language,
            words: <ScriptWord>[
              ...scriptWordsOf(words, script),
              ...scriptWordsOf(<DeckEntry>[
                for (final e in scriptDecks)
                  if (scriptDeckKind(e) == ScriptDeckKind.reading) e,
              ], script),
            ],
          ),
    ];
  }

  /// [code]'s word decks, in path order: every deck of its course but those
  /// that need the alphabet, which the script checks place.
  List<DeckEntry> walkDecks(String code, {String? native}) => <DeckEntry>[
    for (final entry in _wholeCourse(code, native: native))
      if (!needsAlphabet(entry)) entry,
  ];
}
