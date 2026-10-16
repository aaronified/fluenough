import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'deck_content.dart';

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

/// The course chips on the Decks tab, scrolling sideways: one per language,
/// each with its glyph and, for a course with reviews due, how many. The
/// chosen one shows its course's path.
class CourseChips extends StatelessWidget {
  const CourseChips({
    super.key,
    required this.languages,
    required this.decks,
    required this.due,
    required this.selected,
    required this.onSelected,
  });

  final List<LanguageInfo> languages;
  final List<DeckEntry> decks;

  /// Reviews due by language code; a language not in it has none.
  final Map<String, int> due;

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.decksCoursesLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSizes.gutter,
        ),
        child: Row(
          children: <Widget>[
            for (final (i, language) in languages.indexed) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final on = selected == language.code;
                  final count = due[language.code] ?? 0;
                  return Semantics(
                    label: count > 0
                        ? l10n.decksCourseChipDue(language.name, count)
                        : language.name,
                    selected: on,
                    button: true,
                    excludeSemantics: true,
                    onTap: () => onSelected(language.code),
                    child: FilterChip(
                      showCheckmark: false,
                      selected: on,
                      onSelected: (_) => onSelected(language.code),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _Glyph(
                            glyph: languageGlyph(language, decks),
                            language: language,
                            selected: on,
                          ),
                          const SizedBox(width: 6),
                          Text(language.name),
                          if (count > 0) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 5,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                formatCount(context, count),
                                style: Theme.of(context).textTheme.labelSmall!
                                    .copyWith(
                                      color: scheme.onPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A language's character on a small tile inside its chip.
class _Glyph extends StatelessWidget {
  const _Glyph({
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
    return Container(
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
    );
  }
}
