import '../models/drill_mode.dart';

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
/// - **Script decks (#556, owner, 2026-10-17: "Both").** An answer in a deck
///   that teaches the alphabet counts for the word skill it was asked in,
///   as above, and also, in full, for a script skill of its own:
///   Recognition for Read script and Write for Write script. The owner
///   gave no other feed, so Say and Hear count for neither. [scriptOf]
///   says which.
///
/// Only a right answer implies anything: a miss in Write says little about
/// Recognition, which is easier. A miss counts against its own skill alone.
class SkillMap {
  const SkillMap({
    this.formHeardIn = const <String>{},
    this.scriptDecks = const <String>{},
  });

  /// The decks where hearing asks for what was heard rather than what it
  /// means: those that teach the alphabet.
  final Set<String> formHeardIn;

  /// The decks listed under `alphabet:` in their language's path: the
  /// script decks, whose answers also feed the script skills (#556).
  final Set<String> scriptDecks;

  /// The script skill an answer in [mode], in [deckId], counts for, and the
  /// share of a review it counts for, always 1: a review of its own. Null
  /// for an answer outside the script decks, and for any mode but
  /// Recognition and Write.
  ({DrillMode skill, double share})? scriptOf(DrillMode mode, String deckId) {
    if (!scriptDecks.contains(deckId)) return null;
    return switch (mode) {
      DrillMode.recognition => (skill: DrillMode.readScript, share: 1.0),
      DrillMode.production => (skill: DrillMode.writeScript, share: 1.0),
      _ => null,
    };
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
      other.scriptDecks.containsAll(scriptDecks);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(formHeardIn),
    Object.hashAllUnordered(scriptDecks),
  );
}
