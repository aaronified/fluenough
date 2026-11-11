/// Greedy CTC decode to text: the port of `ctc_decode` in `tools/asr/ctc.py`.
library;

/// The piece that stands for an unknown word; it is dropped from the text.
const String ctcUnkPiece = '<unk>';

/// SentencePiece's word-start mark; it becomes a space.
const String ctcSpaceMark = '▁';

// Python's str.split() with no argument splits on str.isspace() characters.
bool _isSpace(int c) =>
    (c >= 0x09 && c <= 0x0d) ||
    (c >= 0x1c && c <= 0x20) ||
    c == 0x85 ||
    c == 0xa0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200a) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202f ||
    c == 0x205f ||
    c == 0x3000;

/// Splits [s] on runs of whitespace (see [_isSpace]), dropping empty words.
List<String> _splitWords(String s) {
  final words = <String>[];
  final cur = StringBuffer();
  for (final c in s.runes) {
    if (_isSpace(c)) {
      if (cur.isNotEmpty) {
        words.add(cur.toString());
        cur.clear();
      }
    } else {
      cur.write(String.fromCharCode(c));
    }
  }
  if (cur.isNotEmpty) {
    words.add(cur.toString());
  }
  return words;
}

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
    return _splitWords(buf.toString().replaceAll(ctcSpaceMark, ' ')).join(' ');
  } catch (e, st) {
    log?.call('ctc decode failed: $e\n$st');
    rethrow;
  }
}
