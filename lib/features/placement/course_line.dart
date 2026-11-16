import 'package:flutter/material.dart';

import '../../core/data/course_path.dart' show Milestone;
import '../../l10n/app_localizations.dart';

/// A course's A1, A2, B1 and culture line (#626, the approved mockup
/// `docs/mockups/languages-learning.html`): the course card's levels drawn
/// thin, one short bar for each, filled by how much of that level is written
/// (`B1Progress.levels`). The culture part is filled by the cards of the
/// culture decks.
///
/// Its figures are in the text around it, so a screen reader reads one
/// label for the whole line, not four bars.
class CourseLine extends StatelessWidget {
  const CourseLine({
    super.key,
    required this.levels,
    this.culture = 0,
    this.label,
    this.compact = false,
  });

  /// How much of A1, A2 and B1 is written, each 0–1.
  final List<double> levels;

  /// How much of the culture part is written, 0–1.
  final double culture;

  /// What a screen reader reads instead of the figures, for an empty line
  /// (no decks yet, or first words only); null reads the figures.
  final String? label;

  /// Draws the line as Add a language's list does (the approved mockup
  /// `docs/mockups/language-picker.md`): four outlined capsules 8 dp tall,
  /// each filled by its share, with no labels under them (the list's key
  /// names the parts once). A part still to come is a visible hollow
  /// capsule, outlined in the `outline` colour, which passes 3:1 against the
  /// surface where today's track does not. A screen reader reads
  /// "How much of the course is made: ...".
  final bool compact;

  /// The thin bar's height; the course card's is 8.
  static const double thickness = 4;

  /// The compact capsule's height, and the width of its outline.
  static const double compactHeight = 8;
  static const double compactOutline = 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = <String>[
      Milestone.a1.name.toUpperCase(),
      Milestone.a2.name.toUpperCase(),
      Milestone.b1.name.toUpperCase(),
      l10n.pickerLevelCulture,
    ];
    final fills = <double>[...levels, culture];
    String percent(double share) => l10n.commonPercent(share.clamp(0.0, 1.0));
    final figures = <String>[
      for (final (i, name) in names.indexed) '$name ${percent(fills[i])}',
    ].join(l10n.commonListSeparator);
    if (compact) {
      return Semantics(
        container: true,
        label: label ?? l10n.languagesCourseMadeLabel(figures),
        excludeSemantics: true,
        child: Row(
          children: <Widget>[
            for (final (i, _) in names.indexed) ...<Widget>[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _Capsule(
                  key: ValueKey<String>('course-segment-$i'),
                  share: fills[i].clamp(0.0, 1.0),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Semantics(
      label: label ?? l10n.pickerCourseLineLabel(figures),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (i, name) in names.indexed) ...<Widget>[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClipRRect(
                    // A stadium on purpose: the ends follow the line's thickness.
                    borderRadius: BorderRadius.circular(thickness / 2),
                    child: LinearProgressIndicator(
                      value: fills[i].clamp(0.0, 1.0),
                      minHeight: thickness,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One part of the compact line: an outlined capsule that [share] of it, from
/// the start, is filled in the primary colour.
class _Capsule extends StatelessWidget {
  const _Capsule({super.key, required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: CourseLine.compactHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CourseLine.compactHeight / 2),
        border: Border.all(
          color: scheme.outline,
          width: CourseLine.compactOutline,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (CourseLine.compactHeight - 2 * CourseLine.compactOutline) / 2,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: share,
            heightFactor: 1,
            child: ColoredBox(color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
