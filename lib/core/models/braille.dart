/// Braille cells as Unicode writes them (ADR-0043): the block U+2800 to
/// U+28FF, where dot n of a cell is bit n − 1 of the code point's offset
/// from U+2800, so that ⠃ (b), dots 1 and 2, is U+2803.
library;

/// The first code point of the braille block, the blank cell.
const int brailleBlank = 0x2800;

/// The cell with [dots], each 1 to 6 (or to 8, for eight-dot braille).
String brailleCell(Iterable<int> dots) {
  var bits = 0;
  for (final dot in dots) {
    if (dot < 1 || dot > 8) {
      throw ArgumentError.value(dot, 'dots', 'a dot is 1 to 8');
    }
    bits |= 1 << (dot - 1);
  }
  return String.fromCharCode(brailleBlank + bits);
}

/// The dots of [cell], one braille character, in order; empty for the
/// blank cell or for a character that is not braille.
List<int> brailleDots(String cell) {
  if (cell.length != 1) return const <int>[];
  final bits = cell.codeUnitAt(0) - brailleBlank;
  if (bits < 0 || bits > 0xFF) return const <int>[];
  return <int>[
    for (var dot = 1; dot <= 8; dot++)
      if (bits & (1 << (dot - 1)) != 0) dot,
  ];
}
