import '../../core/models/deck.dart';

/// One side of a minimal pair: the sound as the deck writes it, and how it
/// reads.
class PairSound {
  const PairSound({required this.target, required this.reading});

  final String target;
  final String reading;
}

/// Two sounds a learner must tell apart, and what the difference is.
///
/// Shaped as #31 specifies, `{a, b, contrast}`, not as the design's
/// `opts`/`ans` on a card (decision 9 in the UI plan). There is no pair model
/// or `DrillMode` in core yet, so this lives with the drill until #31 adds
/// one; the drill needs only each side's target and reading, and the note.
class MinimalPair {
  const MinimalPair({required this.a, required this.b, required this.contrast});

  final PairSound a;
  final PairSound b;

  /// What tells the two apart, shown after choosing. Deck content.
  final String contrast;
}

/// One question: a [pair], and which side is played. A live session would
/// choose the side; the fixture fixes it.
class PairRound {
  const PairRound(this.pair, {required this.playsB});

  final MinimalPair pair;
  final bool playsB;

  PairSound get heard => playsB ? pair.b : pair.a;
}

/// The fixture's language: Hindi, as the design draws the drill. No Hindi
/// deck is on this branch (#41), so this is never looked up in the catalog.
const LanguageInfo pairFixtureLanguage = LanguageInfo(
  code: 'hi',
  iso639_3: 'hin',
  name: 'Hindi',
  script: 'devanagari',
  tts: 'hi-IN',
);

/// The name the drill's frame shows for the fixture's deck.
const String pairFixtureDeckName = 'Hindi Devanagari';

/// The design's two pairs, aspirated or not: ख is played from क / ख, and ग
/// from ग / घ. The notes are the design's own.
const List<PairRound> pairFixtureRounds = <PairRound>[
  PairRound(
    MinimalPair(
      a: PairSound(target: 'क', reading: 'ka'),
      b: PairSound(target: 'ख', reading: 'kha'),
      contrast:
          'ख is aspirated: a puff of air follows the k. English does not '
          'tell these two apart.',
    ),
    playsB: true,
  ),
  PairRound(
    MinimalPair(
      a: PairSound(target: 'ग', reading: 'ga'),
      b: PairSound(target: 'घ', reading: 'gha'),
      contrast: 'ग has no breath after it. घ does.',
    ),
    playsB: false,
  ),
];
