import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';

/// The language's icon, the first letter of its own name (ADR-0027), or for
/// a language that names none, the glyph of its first deck in [decks].
String languageGlyph(LanguageInfo language, List<DeckEntry> decks) {
  if (language.icon case final icon?) return icon;
  for (final entry in decks) {
    if (entry.language.code == language.code) {
      return entry.language.icon ?? entry.glyph;
    }
  }
  return '';
}

/// A language's character on a small tile, as inside its chip: filled with
/// [background], in [foreground]. The size does not follow the text size,
/// as no language glyph tile does.
class LanguageGlyphTile extends StatelessWidget {
  const LanguageGlyphTile({
    super.key,
    required this.glyph,
    required this.language,
    required this.background,
    required this.foreground,
  });

  final String glyph;
  final LanguageInfo language;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // A rounded square of a fixed height, wider only for a glyph that needs
    // it. Never stretched to its parent's height: not in the bar's chip, and
    // not in the label under the bar (owner, 2026-10-17).
    child: Container(
      height: 24,
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          glyph,
          locale: Locale(language.code),
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: 14, height: 22 / 14, color: foreground),
        ),
      ),
    ),
  );
}
