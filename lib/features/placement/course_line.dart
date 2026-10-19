import 'package:flutter/material.dart';

import '../../core/data/course_path.dart' show Milestone;
import '../../l10n/app_localizations.dart';

/// A course's A1, A2, B1 and culture line (#626, the approved mockup
/// `docs/mockups/languages-learning.html`): the course card's levels drawn
/// thin, one short bar for each, filled by how much of that level is written
/// (`B1Progress.levels`). The culture part has nothing written yet.
///
/// Its figures are in the text around it, so a screen reader reads one
/// label for the whole line, not four bars.
class CourseLine extends StatelessWidget {
  const CourseLine({super.key, required this.levels, this.culture = 0});

  /// How much of A1, A2 and B1 is written, each 0–1.
  final List<double> levels;

  /// How much of the culture part is written, 0–1.
  final double culture;

  /// The thin bar's height; the course card's is 8.
  static const double thickness = 4;

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
    return Semantics(
      label: l10n.pickerCourseLineLabel(
        <String>[
          for (final (i, name) in names.indexed) '$name ${percent(fills[i])}',
        ].join(l10n.commonListSeparator),
      ),
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
