/// Who can review what (#462): decks are reviewed by target–native pair,
/// such as Bengali taught from English, and a reviewer can review a pair
/// only if they know both languages and read both scripts.
///
/// Pure Dart, like the rest of `lib/core`: the screens ask here, and the
/// rules are tested without a device.
library;

/// A language as taught from another: the decks of [target] whose cards
/// are explained in [native].
class ReviewPair {
  const ReviewPair(this.target, this.native);

  /// Reads [key], as [key] writes it, or null when it is not a pair.
  static ReviewPair? parse(String key) {
    final parts = key.split('/');
    if (parts.length != 2) return null;
    if (!_code.hasMatch(parts[0]) || !_code.hasMatch(parts[1])) return null;
    return ReviewPair(parts[0], parts[1]);
  }

  static final RegExp _code = RegExp(r'^[a-z]{2,3}$');

  /// The language reviewed, by code, such as `bn`.
  final String target;

  /// The language its decks are taught from, by code, such as `en`.
  final String native;

  /// `bn/en`: how settings keep it.
  String get key => '$target/$native';

  @override
  bool operator ==(Object other) =>
      other is ReviewPair && other.target == target && other.native == native;

  @override
  int get hashCode => Object.hash(target, native);

  @override
  String toString() => key;
}

/// Why a reviewer cannot review a pair, the first that applies.
enum PairBlock {
  /// They have not said which scripts they read (existing users, #462):
  /// nothing can be reviewed until they do.
  scriptsUnanswered,

  /// They do not know the language reviewed.
  unknownTarget,

  /// They do not know the language its decks are taught from.
  unknownNative,

  /// They do not read the script of the language reviewed.
  targetScript,

  /// They do not read the script of the language it is taught from.
  nativeScript,
}

/// What a reviewer has said about themselves: the languages they know, and
/// for each, whether they read its script.
class ReviewerLanguages {
  const ReviewerLanguages({required this.known, required this.readsScript});

  /// The languages they know, by code.
  final Set<String> known;

  /// Whether they read each known language's script, by code. A language
  /// missing here has not been answered.
  final Map<String, bool> readsScript;

  /// Whether every known language's script has been answered. Until it
  /// has, no pair can be reviewed (#462, "Existing users").
  bool get scriptsAnswered =>
      known.isNotEmpty && known.every(readsScript.containsKey);

  /// Why [pair] cannot be reviewed, or null when it can.
  PairBlock? blockOf(ReviewPair pair) {
    if (!scriptsAnswered) return PairBlock.scriptsUnanswered;
    if (!known.contains(pair.target)) return PairBlock.unknownTarget;
    if (!known.contains(pair.native)) return PairBlock.unknownNative;
    if (readsScript[pair.target] != true) return PairBlock.targetScript;
    if (readsScript[pair.native] != true) return PairBlock.nativeScript;
    return null;
  }

  /// Whether [pair] can be reviewed: both languages known, both scripts
  /// read.
  bool canReview(ReviewPair pair) => blockOf(pair) == null;
}

/// The pairs reviewed, from what was chosen: [chosenPairs] where the
/// reviewer has chosen pairs, else their earlier choice of languages,
/// [chosenLanguages], each turned into its pairs among [offered]; and
/// before either, the languages they know. Only pairs [reviewer] can
/// review are kept, so a script they stop reading takes its pairs away.
Set<ReviewPair> reviewedPairs({
  required Set<String>? chosenPairs,
  required Set<String>? chosenLanguages,
  required Iterable<ReviewPair> offered,
  required ReviewerLanguages reviewer,
}) {
  final Iterable<ReviewPair> chosen;
  if (chosenPairs != null) {
    chosen = <ReviewPair>[
      for (final key in chosenPairs) ?ReviewPair.parse(key),
    ];
  } else {
    // Language-level choices from before pairs (#462): every pair with
    // that language as the one reviewed.
    final languages = chosenLanguages ?? reviewer.known;
    chosen = offered.where((p) => languages.contains(p.target));
  }
  return <ReviewPair>{
    for (final pair in chosen)
      if (reviewer.canReview(pair)) pair,
  };
}
