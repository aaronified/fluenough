/// Where a long word may break across lines (owner, 2026-10-16, #515:
/// "Break between syllables"): only between aksharas, never inside one.
library;

/// The viramas of the scripts that join a consonant to the next with one,
/// so that an akshara such as స్తా (stā) is one piece.
const Set<int> _viramas = <int>{
  0x094D, // Devanagari
  0x09CD, // Bengali, Assamese
  0x0A4D, // Gurmukhi
  0x0ACD, // Gujarati
  0x0B4D, // Odia
  0x0BCD, // Tamil
  0x0C4D, // Telugu
  0x0CCD, // Kannada
  0x0D4D, // Malayalam
  0x0DCA, // Sinhala
  0x1039, // Myanmar
};

final RegExp _mark = RegExp(r'\p{M}', unicode: true);

/// [text] split into its grapheme clusters, a cluster ending in a virama
/// joined to the one after it: its aksharas, in a script that has them. A
/// combining mark, a zero-width joiner or non-joiner, and a variation
/// selector stay with the letter before them. Joined, the pieces are
/// [text].
List<String> aksharasOf(String text) {
  final pieces = <String>[];
  final current = StringBuffer();
  var joinNext = false;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final joiner = rune == 0x200C || rune == 0x200D;
    final attaches =
        joiner || _mark.hasMatch(char) || (rune >= 0xFE00 && rune <= 0xFE0F);
    if (current.isNotEmpty && !attaches && !joinNext) {
      pieces.add(current.toString());
      current.clear();
    }
    current.writeCharCode(rune);
    // A virama joins the next letter to this akshara; a joiner after it
    // keeps the join; anything else ends it.
    if (_viramas.contains(rune)) {
      joinNext = true;
    } else if (!joiner) {
      joinNext = false;
    }
  }
  if (current.isNotEmpty) pieces.add(current.toString());
  return pieces;
}

/// The zero-width space a line may break at.
const String breakOpportunity = '​';

/// [word] with a break opportunity between each of its aksharas, so that a
/// word too long for its line breaks only there; any other text, and a
/// word of fewer than [least] aksharas, as it is. Text with a space in it
/// breaks between its words.
String breakableWord(String word, {int least = 3}) {
  if (word.contains(RegExp(r'\s'))) return word;
  final pieces = aksharasOf(word);
  return pieces.length < least ? word : pieces.join(breakOpportunity);
}
