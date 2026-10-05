import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';
import '../theme.dart';

/// A row of language chips, scrolling sideways: one chip per language in
/// [languages], each with its glyph, and "All" first when [allLabel] is
/// given, or last with [allLast]. The Decks tab filters its list with it,
/// and Progress its numbers.
class LanguageChips extends StatelessWidget {
  const LanguageChips({
    super.key,
    required this.languages,
    required this.decks,
    required this.semanticLabel,
    required this.selected,
    required this.onSelected,
    this.allLabel,
    this.allLast = false,
  });

  final List<LanguageInfo> languages;

  /// Where a language that names no icon takes its glyph from: its first
  /// deck here.
  final List<DeckEntry> decks;

  /// The row's name for a screen reader: "Filter by language".
  final String semanticLabel;

  /// The chosen language's code, or null for All.
  final String? selected;
  final ValueChanged<String?> onSelected;

  /// The chip that chooses every language, or null for none.
  final String? allLabel;

  /// Puts the [allLabel] chip after the languages instead of before them.
  final bool allLast;

  /// The language's icon, the first letter of its own name (ADR-0027),
  /// or for a language that names none, the glyph of its first deck here.
  String _glyphOf(LanguageInfo language) {
    if (language.icon case final icon?) return icon;
    for (final entry in decks) {
      if (entry.language.code == language.code) {
        return entry.language.icon ?? entry.glyph;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final label = allLabel;
    final all = label == null
        ? null
        : FilterChip(
            label: Text(label),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          );
    final chips = <Widget>[
      if (!allLast) ?all,
      for (final language in languages)
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ChipGlyph(
                glyph: _glyphOf(language),
                language: language,
                selected: selected == language.code,
              ),
              const SizedBox(width: 6),
              Text(language.name),
            ],
          ),
          selected: selected == language.code,
          onSelected: (_) => onSelected(language.code),
        ),
      if (allLast) ?all,
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSizes.gutter,
        ),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < chips.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A language's character on a small tile inside its chip.
class _ChipGlyph extends StatelessWidget {
  const _ChipGlyph({
    required this.glyph,
    required this.language,
    required this.selected,
  });

  final String glyph;
  final LanguageInfo language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.surfaceContainerLowest
              : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          glyph,
          locale: Locale(language.code),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 14,
            height: 22 / 14,
            color: selected ? scheme.onSurface : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
