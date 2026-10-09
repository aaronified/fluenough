import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/incoming.dart';
import 'path_model.dart';

/// The card at the top of a course's path: the course, how much of it is
/// done, with the levels marked on the bar where the path has them, and the
/// two rows the design adds that are not built yet: deck updates (#210) and
/// hours left to B1 (#227), each with "Feature incoming".
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.view, required this.glyph});

  final CourseView view;

  /// The language's character, as its chip shows it.
  final String glyph;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = view.unitCount;
    final done = view.doneCount;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: Row(
              children: <Widget>[
                DeckGlyph(glyph: glyph, language: view.language, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.decksCourseHeading(
                          view.language.name,
                          view.native.name,
                        ),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        l10n.pathCourseProgress(done, total),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProgressBar(view: view),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Column(
              children: <Widget>[
                _IncomingRow(
                  feature: Feature.deckUpdates,
                  icon: Icons.sync,
                  title: l10n.pathUpdatesTitle,
                  body: l10n.pathUpdatesBody,
                  // Off until decks download: nothing to update from yet.
                  action: FilledButton.tonal(
                    onPressed: null,
                    child: Text(l10n.pathUpdatesButton),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                _IncomingRow(
                  feature: Feature.hoursLeft,
                  icon: Icons.schedule,
                  title: l10n.pathHoursTitle,
                  body: l10n.pathHoursBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The share of the course's units done, with each level the path marks
/// written under the bar where it ends.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.view});

  final CourseView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = view.unitCount + view.plan.coming.length;
    final value = total == 0 ? 0.0 : view.doneCount / total;
    // Where each level ends, as a share of the bar.
    final ends = <(String, double)>[];
    var count = 0;
    for (final step in view.steps) {
      if (step is UnitStep || step is ComingStep) count++;
      if (step is AchievementStep && total > 0) {
        ends.add((step.level.label, count / total));
      }
    }
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          if (ends.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return SizedBox(
                  height: 22 * MediaQuery.textScalerOf(context).scale(1),
                  child: Stack(
                    children: <Widget>[
                      for (final (label, at) in ends)
                        PositionedDirectional(
                          top: 4,
                          start: (at * width - 24).clamp(0, width - 48),
                          width: 48,
                          child: Text(
                            label,
                            textAlign: at >= 0.99
                                ? TextAlign.end
                                : TextAlign.center,
                            style: theme.textTheme.labelSmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A row of the course card for a feature not built yet: dimmed, with the
/// "Feature incoming" badge, until [feature] is on.
class _IncomingRow extends StatelessWidget {
  const _IncomingRow({
    required this.feature,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final Feature feature;
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      child: IncomingFeature(
        feature: feature,
        label: title,
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...<Widget>[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

/// "Beyond the course", at the end of the path: songs, films and books to
/// pick by interest, which hold nothing back. Not built yet (#215): shown
/// with "Feature incoming".
class BeyondTheCourse extends StatelessWidget {
  const BeyondTheCourse({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IncomingFeature(
      feature: Feature.beyondCourse,
      label: l10n.pathBeyondTitle,
      badge: IncomingBadgePlacement.below,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.pathBeyondTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.pathBeyondBody,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final (kind, icon) in <(String, IconData)>[
                (l10n.pathBeyondSong, Icons.music_note_outlined),
                (l10n.pathBeyondFilm, Icons.movie_outlined),
                (l10n.pathBeyondBook, Icons.menu_book_outlined),
              ])
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(kind, style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
