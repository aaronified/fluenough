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
///   a figure for a rule's forms (B1 format spec 4.7).
///
/// Only a right answer implies anything: a miss in Write says little about
/// Recognition, which is easier. A miss counts against its own skill alone.
class SkillMap {
  const SkillMap({this.formHeardIn = const <String>{}});

  /// The decks where hearing asks for what was heard rather than what it
  /// means: those that teach the alphabet.
  final Set<String> formHeardIn;

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
        // rule's forms and their meanings (spec 4.7, OPEN-11). Should one
        // appear, produced implying understood is one arm here, as Write's.
        DrillMode.recognition ||
        DrillMode.grammarUnderstood ||
        DrillMode.grammar ||
        DrillMode.reading => const <DrillMode, double>{},
      };

  @override
  bool operator ==(Object other) =>
      other is SkillMap &&
      other.formHeardIn.length == formHeardIn.length &&
      other.formHeardIn.containsAll(formHeardIn);

  @override
  int get hashCode => Object.hashAllUnordered(formHeardIn);
}
