/// Where a typed IPA answer divides into the symbols a reader sees (#1221).
/// Pure Dart: the keyboard's backspace and the tests use it.
///
/// A symbol as the learner sees it is a base letter and everything written
/// on it: combining marks (`ã`, `n̩`), the modifier letters that follow a
/// letter (`kʰ`, `ɑ̃ː`, an ejective `ʼ`, a tone letter), and a tie bar with
/// the letter it joins (`t͡ʃ`, `ɡ͡b`). Stress marks (`ˈ`, `ˌ`) begin the
/// syllable they stand before, so they are symbols of their own: in `ˈa`
/// the `a` goes first.
library;

/// The start offset, in UTF-16 code units, of the symbol that ends at
/// [offset] in [text]: what a backspace with the cursor at [offset] removes
/// is `text.substring(ipaClusterStart(text, offset), offset)`. A cursor
/// inside a symbol (between a letter and its mark) takes the part before it.
/// An [offset] of 0 or less gives 0; one past the end counts as the end.
int ipaClusterStart(String text, int offset) {
  if (offset <= 0) return 0;
  final end = offset > text.length ? text.length : offset;
  var start = 0;
  var i = 0;
  while (i < end) {
    final symbolStart = i;
    i = _symbolEnd(text, i);
    if (i >= end) return symbolStart;
    start = i;
  }
  return start;
}

/// The offset where the symbol that starts at [from] ends.
int _symbolEnd(String text, int from) {
  var i = _next(text, from);
  while (i < text.length) {
    final rune = _rune(text, i);
    if (_isTie(rune)) {
      i += _width(rune);
      // The tie joins the letter after it, with that letter's own marks.
      if (i < text.length && !_isTrailing(_rune(text, i))) {
        i = _next(text, i);
      }
    } else if (_isTrailing(rune)) {
      i += _width(rune);
    } else {
      break;
    }
  }
  return i;
}

int _next(String text, int i) => i + _width(_rune(text, i));

int _rune(String text, int i) {
  final unit = text.codeUnitAt(i);
  if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < text.length) {
    final low = text.codeUnitAt(i + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return unit;
}

int _width(int rune) => rune > 0xFFFF ? 2 : 1;

/// The tie bars, above and below, which join two letters into one symbol.
bool _isTie(int rune) => rune == 0x0361 || rune == 0x035C;

/// A code point that goes on the letter before it: a combining mark, or a
/// modifier letter other than the stress marks.
bool _isTrailing(int rune) {
  if (rune >= 0x0300 && rune <= 0x036F) return true;
  if (rune >= 0x1AB0 && rune <= 0x1AFF) return true;
  if (rune >= 0x1DC0 && rune <= 0x1DFF) return true;
  if (rune >= 0x20D0 && rune <= 0x20FF) return true;
  if (rune >= 0xFE20 && rune <= 0xFE2F) return true;
  if (rune >= 0x02B0 && rune <= 0x02FF) {
    return rune != 0x02C8 && rune != 0x02CC;
  }
  if (rune >= 0x1D2C && rune <= 0x1DBF) return true;
  return rune == 0x207F;
}
