import 'dart:math' as math;

import 'cognate_score.dart';
import 'placement_questions.dart';

// The script gate of "Find my level" V3 (wiki/Plan-Placement-V3.md, (d)):
// for a language written in a non-Latin script, a check of two to five
// letter items (three on average) at the start that decides whether Read and Write can be
// tested at all. It is a separate small latent, not part of the joint:
//  - none: the learner cannot read the script. Read and Write are not
//    tested (they are placed at `none`, "needs the script first"); the other
//    skills are tested on their own, so that a learner who hears and speaks
//    the language but cannot read it is not placed as knowing no language;
//  - partly: some letters. Read and Write are tested as usual;
//  - all: the script is known. A learner who knows the script but no words
//    gets Read and Write at `none`, which starts the vocabulary at A1.
// A Latin-script language skips the check: Latin known from English is
// "letters known" (and counts as Learn for Read and Write, the 0.9.2 rule).
//
// Items: F12 (a letter, pick its romanisation; needs no audio) and F10 (a
// heard romanisation, pick its letter; only with audio). They are built from
// the script's letter decks (letters, then joined forms such as a vowel sign
// or a conjunct), with the wrong options of the same length as the right one
// so that no cue of length tells the right one. These two formats are not
// admitted into the picker's bank (a class of 75 letters cannot show a
// four-option pick within 0.32 by the admission audit's Wilson bound); the
// gate is judged by what it decides: the share of learners it classifies
// right and the share of guessers it lets through.
//
// Pure Dart, deterministic for a seeded generator.

/// What the gate found of a script.
enum ScriptLevel { none, partly, all }

/// One letter of a script, as the gate reads it from a letter deck.
class ScriptLetter {
  const ScriptLetter(this.glyph, this.reading, {this.joined = false});

  /// The sign as written (a letter, a vowel sign with its consonant, a
  /// conjunct).
  final String glyph;

  /// Its romanisation.
  final String reading;

  /// A joined form (vowel sign, conjunct) rather than a plain letter.
  final bool joined;
}

/// The kinds of gate item.
enum ScriptItemKind {
  /// F12: a letter shown, pick its romanisation.
  letterToSound,

  /// F10: a romanisation heard, pick its letter.
  soundToLetter,
}

/// One item of the gate.
class ScriptGateItem {
  const ScriptGateItem({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.options,
    required this.correct,
    required this.letterIndex,
  });

  final String id;
  final ScriptItemKind kind;

  /// The letter (F12) or the romanisation to be said (F10).
  final String prompt;
  final List<String> options;
  final int correct;
  final int letterIndex;

  String get format => kind == ScriptItemKind.letterToSound ? 'F12' : 'F10';
  bool get needsAudio => kind == ScriptItemKind.soundToLetter;

  /// The time an item takes, in seconds.
  double get seconds => kind == ScriptItemKind.letterToSound ? 4 : 5;
}

/// What the gate decided.
class ScriptGateResult {
  const ScriptGateResult({
    required this.level,
    required this.items,
    required this.skipped,
    required this.posterior,
  });

  final ScriptLevel level;

  /// How many items it asked.
  final int items;

  /// A Latin script: no check was asked.
  final bool skipped;

  final Map<ScriptLevel, double> posterior;

  /// Whether the script can be read at all (Read and Write are testable).
  bool get readable => level != ScriptLevel.none;

  /// Whether the learner knows the letters (all of them, or Latin).
  bool get lettersKnown => level == ScriptLevel.all;

  /// The skills to test: Read and Write are left out when the script cannot
  /// be read, the others are kept (unless none is left).
  List<PlacementSkill> skillsInPlay(List<PlacementSkill> base) {
    final kept = <PlacementSkill>[
      for (final s in base)
        if (readable || (s != PlacementSkill.read && s != PlacementSkill.write))
          s,
    ];
    // With no audio there is nothing else to test: Read and Write stay (the
    // learner is placed at `none` there, which is what the items will find).
    return kept.isEmpty ? base : kept;
  }
}

/// The chance of a right answer to a gate item: a guess (a four-option pick)
/// for a learner who cannot read the script, a slip away from certain for one
/// who can. The gate is a sequential test of the two (a learner with some
/// letters answers in between and is told apart less well, see the plan).
const Map<ScriptLevel, double> kScriptRight = <ScriptLevel, double>{
  ScriptLevel.none: 0.25,
  ScriptLevel.partly: 0.6,
  ScriptLevel.all: 0.95,
};

/// What a declaration moves the start of the test: the log-odds of 1 (about
/// three to one) for a learner who says they read the script, against for one
/// who says they do not.
const double kScriptDeclared = 1.0;

/// The log-likelihood ratio of a right answer (all against none), and of a
/// wrong one.
final double kScriptRightLlr = math.log(0.95 / 0.25);
final double kScriptWrongLlr = math.log(0.05 / 0.75);

/// The gate of one run over [letters] of a script.
class ScriptGate {
  ScriptGate(
    List<ScriptLetter> letters, {
    required this.rng,
    this.audio = false,
    this.minItems = 2,
    this.maxItems = 5,
    this.decide = 3.5,
    this.declaredReads,
  }) : _letters = letters,
       skipped = false {
    _llr = declaredReads == null
        ? 0
        : (declaredReads! ? kScriptDeclared : -kScriptDeclared);
    _plan();
  }

  /// The gate of a Latin script (known from English, or the language's own):
  /// nothing is asked, the letters count as known.
  ScriptGate.latin()
    : _letters = const <ScriptLetter>[],
      rng = math.Random(0),
      audio = false,
      minItems = 0,
      maxItems = 0,
      decide = 3.5,
      declaredReads = null,
      skipped = true;

  final math.Random rng;
  final bool audio;
  final int minItems;
  final int maxItems;

  /// The log-likelihood ratio (all against none) at which the gate stops
  /// after [minItems], either way.
  final double decide;

  /// The learner's answer to "do you read this script?" (null: not asked).
  /// It moves where the test starts, by [kScriptDeclared], and never decides:
  /// two wrong answers still send a learner who said yes to `none`.
  final bool? declaredReads;
  final bool skipped;
  final List<ScriptLetter> _letters;

  final List<ScriptGateItem> asked = <ScriptGateItem>[];
  final List<ScriptGateItem> _plan_ = <ScriptGateItem>[];
  double _llr = 0;
  ScriptGateItem? _pending;

  /// Whether the check is asked at all (a script with letters to ask).
  bool get needed => !skipped && _letters.length >= 6;

  /// The posterior over what the learner knows of the script.
  Map<ScriptLevel, double> get posterior {
    final pa = 1 / (1 + math.exp(-_llr));
    return <ScriptLevel, double>{
      ScriptLevel.none: 1 - pa,
      ScriptLevel.partly: 0,
      ScriptLevel.all: pa,
    };
  }

  bool get done {
    if (!needed) return true;
    if (asked.length >= maxItems || asked.length >= _plan_.length) return true;
    if (asked.length < minItems) return false;
    return _llr.abs() >= decide;
  }

  /// The next item, or null when the gate is over.
  ScriptGateItem? next() {
    assert(_pending == null, 'the last gate item was not recorded');
    if (done) return null;
    final item = _plan_[asked.length];
    asked.add(item);
    _pending = item;
    return item;
  }

  /// The answer to the item [next] returned.
  void record({required bool right}) {
    final item = _pending;
    if (item == null) return;
    _pending = null;
    _llr += right ? kScriptRightLlr : kScriptWrongLlr;
  }

  /// The item [next] returned could not be shown: it is left out, and counts
  /// for nothing either way.
  void skip() {
    _pending = null;
  }

  /// What the gate found. Before it is over, what it would say now.
  ScriptGateResult get result {
    if (skipped) {
      return const ScriptGateResult(
        level: ScriptLevel.all,
        items: 0,
        skipped: true,
        posterior: <ScriptLevel, double>{
          ScriptLevel.none: 0,
          ScriptLevel.partly: 0,
          ScriptLevel.all: 1,
        },
      );
    }
    if (!needed) {
      // No letters to ask about: the script is assumed readable.
      return const ScriptGateResult(
        level: ScriptLevel.partly,
        items: 0,
        skipped: false,
        posterior: <ScriptLevel, double>{
          ScriptLevel.none: 0,
          ScriptLevel.partly: 1,
          ScriptLevel.all: 0,
        },
      );
    }
    // None below even odds; all from nine in ten; in between (only when the
    // items ran out undecided) some letters.
    final pa = 1 / (1 + math.exp(-_llr));
    final level = pa < 0.5
        ? ScriptLevel.none
        : pa >= 0.9
        ? ScriptLevel.all
        : ScriptLevel.partly;
    return ScriptGateResult(
      level: level,
      items: asked.length,
      skipped: false,
      posterior: posterior,
    );
  }

  // ------------------------------------------------------------------ plan

  void _plan() {
    if (!needed) return;
    final plain = <int>[
      for (var i = 0; i < _letters.length; i++)
        if (!_letters[i].joined) i,
    ];
    final joined = <int>[
      for (var i = 0; i < _letters.length; i++)
        if (_letters[i].joined) i,
    ];
    // Three plain letters from the early, middle and late third of the
    // letter deck, then a joined form when there is one, then two more plain
    // letters for the rare undecided run.
    int pick(List<int> from, int third) {
      final n = from.length;
      final lo = n * third ~/ 3;
      final hi = math.max(lo + 1, n * (third + 1) ~/ 3);
      return from[lo + rng.nextInt(hi - lo)];
    }

    final chosen = <int>[];
    final source = plain.length >= 3 ? plain : <int>[...plain, ...joined];
    for (var t = 0; t < 3; t++) {
      chosen.add(pick(source, t));
    }
    if (joined.isNotEmpty) {
      chosen.add(joined[rng.nextInt(joined.length)]);
    } else {
      var extra = pick(source, 1);
      for (var k = 0; k < 10 && chosen.contains(extra); k++) {
        extra = pick(source, rng.nextInt(3));
      }
      chosen.add(extra);
    }
    for (var k = 0; k < 2; k++) {
      var extra = pick(source, rng.nextInt(3));
      for (var t = 0; t < 12 && chosen.contains(extra); t++) {
        extra = pick(source, rng.nextInt(3));
      }
      if (!chosen.contains(extra)) chosen.add(extra);
    }
    // The heard item (when there is audio) is the third.
    for (var i = 0; i < chosen.length; i++) {
      final heard = audio && i == 2;
      final item = _build(
        chosen[i],
        heard ? ScriptItemKind.soundToLetter : ScriptItemKind.letterToSound,
      );
      if (item != null) _plan_.add(item);
    }
  }

  ScriptGateItem? _build(int index, ScriptItemKind kind) {
    final letter = _letters[index];
    final reading = foldAccents(letter.reading);
    // Wrong options: other letters of the same kind whose reading differs
    // from the right one (after folding marks) and has the same length, and
    // (to pick a letter) a glyph of the same length. Equal lengths leave no
    // cue of length.
    final chosen = <int>[];
    for (final sameLength in const <bool>[true, false]) {
      final pool = <int>[
        for (var i = 0; i < _letters.length; i++)
          if (i != index &&
              _letters[i].joined == letter.joined &&
              foldAccents(_letters[i].reading) != reading &&
              _letters[i].glyph != letter.glyph &&
              (!sameLength ||
                  (kind == ScriptItemKind.letterToSound
                      ? _letters[i].reading.length == letter.reading.length
                      : _letters[i].glyph.runes.length ==
                            letter.glyph.runes.length)))
            i,
      ]..shuffle(rng);
      chosen.clear();
      final seen = <String>{reading};
      for (final i in pool) {
        final r = foldAccents(_letters[i].reading);
        if (seen.add(r)) chosen.add(i);
        if (chosen.length == 3) break;
      }
      if (chosen.length == 3) break;
    }
    if (chosen.length < 3) return null;
    final all = <int>[index, ...chosen]..shuffle(rng);
    final options = <String>[
      for (final i in all)
        kind == ScriptItemKind.letterToSound
            ? _letters[i].reading
            : _letters[i].glyph,
    ];
    return ScriptGateItem(
      id: 'script:${kind.name}:$index',
      kind: kind,
      prompt: kind == ScriptItemKind.letterToSound
          ? letter.glyph
          : letter.reading,
      options: options,
      correct: all.indexOf(index),
      letterIndex: index,
    );
  }
}
