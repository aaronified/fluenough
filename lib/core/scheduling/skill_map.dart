import '../models/drill_mode.dart';
import 'ability.dart';
import 'ask.dart';
import 'replay.dart';

/// Which skills one answer judges (ADR-0034; the evidence is in
/// docs/research/skill-evidence.md): the skill it was asked in, in full,
/// and the skills a right answer there implies, in part.
///
/// - **Producing a word implies recognising it,** more than the reverse
///   (Laufer & Goldstein 2004; Webb 2009; Steinel et al. 2007): a right
///   answer in Write or Say counts in part for Recognition.
/// - **Hearing a word and giving its meaning** implies recognising it in
///   writing in part (Milton & Hopkins 2006).
/// - **Hearing a letter or word and writing what was heard,** as script
///   practice asks (dictation), implies writing it in part (Cheng & Matthews
///   2018).
///
/// - **Grammar,** understood or produced, implies nothing: no study gives
///   a figure for a rule's forms (DECK-FORMAT.md, Rules decks).
///
/// - **Script skills, per script (#556, #653).** Each script a course is
///   learned in has a Read and a Write of its own: Hindustani has
///   Devanagari Read and Write and Perso-Arabic Read and Write. An answer
///   counts for the word skill it was asked in, as above, and, shown or
///   typed in a script the learner learns, for a script skill too
///   ([scriptOf]; owner, 2026-10-19):
///   - **Read** from the script decks' Recognition; from choosing script
///     text, any question whose options are written in the script (a word
///     chosen, word-order tiles, a match's words); and from reading a word
///     for its meaning, Recognition anywhere.
///   - **Write** from the script decks' Write, and from a Write answer
///     typed in the script, in any deck.
///
///   In a script deck it counts as a review of its own; elsewhere as half
///   of one, [implied]. Shown or typed in transliteration, it feeds none.
///
/// Only a right answer implies anything: a miss in Write says little about
/// Recognition, which is easier. A miss counts against its own skill alone.
class SkillMap {
  const SkillMap({
    this.formHeardIn = const <String>{},
    this.scriptDecks = const <String>{},
    this.primaryScripts = const <String, String>{},
  });

  /// The decks where hearing asks for what was heard rather than what it
  /// means: those that teach the alphabet.
  final Set<String> formHeardIn;

  /// The decks listed under `alphabet:` in their language's path: the
  /// script decks, whose answers also feed the script skills (#556).
  final Set<String> scriptDecks;

  /// Each course's primary script, by language code: the one most of its
  /// decks are written in (`AppState.primaryScript`). A script-deck answer
  /// from before the script was kept per answer counts for it (#653).
  final Map<String, String> primaryScripts;

  /// The script skill [review] counts for, the script it is in, and the
  /// share of a review it counts for (#653). Null where it feeds none: an
  /// answer shown or typed in transliteration, or in a script not learned,
  /// and any mode or way of asking that neither reads nor writes the script.
  ///
  /// In a script deck, as before (#556): Recognition is Read and Write is
  /// Write, a review of their own, in the script the answer was in, or, for
  /// an answer from before that was kept, the course's primary script; and
  /// a heard letter chosen among written ones is Read too.
  ///
  /// Elsewhere, half a review ([implied]): Recognition, shown in the
  /// script, is Read; Write typed in it is Write; a word chosen, or put in
  /// order, among words written in it is Read, in Write, Hear or grammar.
  ({DrillMode skill, String script, double share})? scriptOf(
    LoggedReview review,
  ) {
    final mode = review.key.mode;
    final asked = review.asked;
    if (scriptDecks.contains(review.deckId)) {
      final script =
          review.script ??
          (asked == null
              ? primaryScripts[Abilities.languageOf(review.key.cardId)]
              : null);
      if (script == null) return null;
      final skill = switch (mode) {
        DrillMode.recognition => DrillMode.readScript,
        DrillMode.production => DrillMode.writeScript,
        DrillMode.listening when asked == Ask.hearAndChoose =>
          DrillMode.readScript,
        _ => null,
      };
      return skill == null ? null : (skill: skill, script: script, share: 1.0);
    }
    final script = review.script;
    if (script == null || asked == null) return null;
    final skill = switch (mode) {
      DrillMode.recognition => DrillMode.readScript,
      DrillMode.production when asked == Ask.own => DrillMode.writeScript,
      DrillMode.production || DrillMode.listening || DrillMode.grammar
          when asked == Ask.chooseWord ||
              asked == Ask.rearrange ||
              asked == Ask.hearAndChoose ||
              asked == Ask.chooseForm =>
        DrillMode.readScript,
      _ => null,
    };
    return skill == null
        ? null
        : (skill: skill, script: script, share: implied);
  }

  /// How much a right answer counts for a skill it implies, against its
  /// own. No study gives the fraction; this is the ratio of the transfer
  /// found when a test is answered differently from practice to when it is
  /// answered the same way, d 0.28 against 0.58 (Pan & Rickard 2018),
  /// rounded. Low confidence: to be fitted, on the phone, from the
  /// learner's own log.
  static const double implied = 0.5;

  /// The skills a right answer in [mode], in [deckId], implies, each with
  /// the share of a review it counts for.
  Map<DrillMode, double> impliedBy(DrillMode mode, String deckId) =>
      switch (mode) {
        DrillMode.production || DrillMode.speaking => const <DrillMode, double>{
          DrillMode.recognition: implied,
        },
        DrillMode.listening =>
          formHeardIn.contains(deckId)
              ? const <DrillMode, double>{DrillMode.production: implied}
              : const <DrillMode, double>{DrillMode.recognition: implied},
        // Grammar understood (a form's meaning chosen) and produced (the
        // form chosen or typed) imply nothing, of each other or of a word's
        // skills: the research finds grammar practice skill-specific
        // (DeKeyser 1997; Shintani et al. 2013) and gives no figure for a
        // rule's forms and their meanings (DECK-FORMAT.md, Rules decks). Should
        // one appear, produced implying understood is one arm here, as Write's.
        DrillMode.recognition ||
        DrillMode.grammarUnderstood ||
        DrillMode.grammar ||
        DrillMode.reading ||
        DrillMode.readScript ||
        DrillMode.writeScript => const <DrillMode, double>{},
      };

  @override
  bool operator ==(Object other) =>
      other is SkillMap &&
      other.formHeardIn.length == formHeardIn.length &&
      other.formHeardIn.containsAll(formHeardIn) &&
      other.scriptDecks.length == scriptDecks.length &&
      other.scriptDecks.containsAll(scriptDecks) &&
      other.primaryScripts.length == primaryScripts.length &&
      primaryScripts.entries.every(
        (e) => other.primaryScripts[e.key] == e.value,
      );

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(formHeardIn),
    Object.hashAllUnordered(scriptDecks),
    Object.hashAllUnordered(<String>[
      for (final e in primaryScripts.entries) '${e.key}=${e.value}',
    ]),
  );
}
