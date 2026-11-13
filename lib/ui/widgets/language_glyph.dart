import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';
import '../theme.dart';

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

/// How much larger [language]'s glyph is set than the others' (#681). The
/// IPA course's icon, a schwa, is drawn at the height of a lower-case
/// letter, so beside the capital-height glyphs of the other languages it
/// looks small and offset; it is set larger so that it reaches their height,
/// cap height to baseline.
double glyphScaleOf(LanguageInfo language) => language.isIpa ? 1.4 : 1.0;

/// The small dot in the theme's accent colour that marks a language with
/// something to do: a review due now or a new card waiting (#681). Not read
/// out on its own: the language's label says "has cards to do".
class LanguageDot extends StatelessWidget {
  const LanguageDot({super.key});

  /// The dot's width and height.
  static const double size = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey<String>('language-dot'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          // The ring keeps it apart from the glyph it sits on, in both themes.
          border: Border.all(color: scheme.surface),
        ),
      ),
    );
  }
}

/// [child] with the [LanguageDot] at its top end, while [show].
class LanguageDotted extends StatelessWidget {
  const LanguageDotted({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) => show
      ? Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            child,
            const PositionedDirectional(top: -3, end: -5, child: LanguageDot()),
          ],
        )
      : child;
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
    this.hasWork = false,
  });

  final String glyph;
  final LanguageInfo language;
  final Color background;
  final Color foreground;

  /// Whether to draw the dot at the tile's top end (#681).
  final bool hasWork;

  @override
  Widget build(BuildContext context) =>
      LanguageDotted(show: hasWork, child: _tile());

  Widget _tile() => ExcludeSemantics(
    // A rounded square of a fixed height, wider only for a glyph that needs
    // it. Never stretched to its parent's height: not in the bar's chip, and
    // not in the label under the bar (owner, 2026-10-17).
    child: Container(
      height: 24,
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          glyph,
          locale: Locale(language.code),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 14 * glyphScaleOf(language),
            height: 22 / 14 / glyphScaleOf(language),
            color: foreground,
          ),
        ),
      ),
    ),
  );
}
