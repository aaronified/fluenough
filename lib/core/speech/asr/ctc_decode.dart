/// Greedy CTC decode to text: the port of `ctc_decode` in `tools/asr/ctc.py`.
library;

/// The piece that stands for an unknown word; it is dropped from the text.
const String ctcUnkPiece = '<unk>';

/// SentencePiece's word-start mark; it becomes a space.
const String ctcSpaceMark = '▁';

// Python's str.split() with no argument splits on str.isspace() characters.
final RegExp _whitespace = RegExp(
  "[\\s\\x1c-\\x1f\\x85\\xa0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000]+",
);

/// Collapses repeated ids, drops blanks and `<unk>`, joins the pieces, turns the
/// word-start mark into a space, and collapses and trims the spaces.
///
/// An id that is neither blank nor inside `pieces` is dropped and counted in one
/// line to [log]. Any failure is logged to [log] and rethrown.
String decode(
  List<int> ids,
  List<String> pieces,
  int blank, {
  void Function(String)? log,
}) {
  try {
    final buf = StringBuffer();
    int? prev;
    var outOfRange = 0;
    for (final i in ids) {
      if (i != prev && i != blank) {
        if (i >= 0 && i < pieces.length) {
          if (pieces[i] != ctcUnkPiece) {
            buf.write(pieces[i]);
          }
        } else {
          outOfRange++;
        }
      }
      prev = i;
    }
    if (outOfRange > 0) {
      log?.call(
        'ctc decode dropped $outOfRange id(s) outside the ${pieces.length} pieces',
      );
    }
    return buf
        .toString()
        .replaceAll(ctcSpaceMark, ' ')
        .split(_whitespace)
        .where((w) => w.isNotEmpty)
        .join(' ');
  } catch (e, st) {
    log?.call('ctc decode failed: $e\n$st');
    rethrow;
  }
}
