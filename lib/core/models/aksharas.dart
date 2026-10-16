/// Where a long word may break across lines (owner, 2026-10-16, #515:
/// "Break between syllables"): only between aksharas, never inside one. A
/// word in a joined script, such as Urdu, never breaks: it shrinks to fit
/// ("Shrink Urdu instead").
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

/// Whether [text] is in a script whose words are made of aksharas, the
/// Brahmic scripts from Devanagari to Sinhala, and Myanmar: where a long
/// word may break between them. Never a joined script such as Arabic,
/// whose letters a break between them would tear apart.
bool hasAksharas(String text) => _brahmic.hasMatch(text);

final RegExp _brahmic = RegExp(r'[\u0900-\u0DFF\u1000-\u109F]');

/// Whether [text] is in a joined script, whose letters join the next
/// within a word: Arabic script, as Urdu writes it. A word in it too long
/// for its line shrinks to fit rather than break (owner, 2026-10-16,
/// #515: "Shrink Urdu instead").
bool isJoinedScript(String text) => _joined.hasMatch(text);

final RegExp _joined = RegExp(
  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);

/// [word] with a break opportunity between each of its aksharas, so that a
/// word too long for its line breaks only there; text in a script without
/// aksharas, and a word of fewer than [least] of them, as it is. Text with
/// a space in it breaks between its words.
String breakableWord(String word, {int least = 3}) {
  if (word.contains(RegExp(r'\s')) || !hasAksharas(word)) return word;
  final pieces = aksharasOf(word);
  return pieces.length < least ? word : pieces.join(breakOpportunity);
}
