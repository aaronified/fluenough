// What makes two options of a question look alike, so that no surface cue
// (the longest option, the one with more words) can give the right one away.
// Pure Dart, shared by the placement generators and the review generators.

/// How many letters (runes) [text] holds.
int runeLength(String text) => text.runes.length;

/// How many words [text] holds, words being runs of non-space characters.
int wordCount(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// The most the length of an option may differ from the right one's, in
/// letters: a quarter of it, and never less than [floor].
int lengthBand(String reference, {int floor = 5}) {
  final quarter = (runeLength(reference) / 4).round();
  return quarter < floor ? floor : quarter;
}

/// Whether [a] and [b] are in one length band: their lengths differ by at
/// most [lengthBand] of the shorter, and their word counts by at most
/// [wordSlack].
bool inOneBand(String a, String b, {int wordSlack = 2, int floor = 5}) {
  final shorter = runeLength(a) <= runeLength(b) ? a : b;
  final gap = (runeLength(a) - runeLength(b)).abs();
  if (gap > lengthBand(shorter, floor: floor)) return false;
  return (wordCount(a) - wordCount(b)).abs() <= wordSlack;
}
