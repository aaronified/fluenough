import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_downloads.dart';
import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/card_text_scale.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/snack.dart';
import '../downloads/download_text.dart';
import 'course_hours.dart';
import 'path_model.dart';

/// The card at the top of a course's path: the course, how much of it is
/// done, with the levels marked on the bar where the path has them, and one
/// line for the hours left in the decks written so far, with the hours spent
/// (#227). Its sync button looks for deck updates for the course's language
/// and downloads them (#464, owner, 2026-10-26); while that runs the bar
/// shows the download, then the levels come back.
class CourseCard extends StatefulWidget {
  const CourseCard({
    super.key,
    required this.view,
    required this.glyph,
    this.hours = (spent: 0, left: 0),
  });

  final CourseView view;

  /// The language's hours spent, and about how many are left in the decks
  /// its course has ([courseHours]).
  final CourseHours hours;

  /// The language's character, as its chip shows it.
  final String glyph;

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool _checking = false;

  /// Asks GitHub for changes, then downloads what waits for this course's
  /// language, saying in a toast what came of it.
  Future<void> _update() async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final downloads = state.deckDownloads;
    final language = widget.view.language.code;
    if (downloads == null) {
      showAppSnackBar(context, l10n.deckDownloadsNoUpdates);
      return;
    }
    final spoken = state.settings.spokenLanguages;
    setState(() => _checking = true);
    String message;
    try {
      await downloads.checkForUpdates(spoken, force: true);
      if (downloads.updates.containsKey(language)) {
        final failure = await downloads.update(<String>[language]);
        message = failure == null
            ? l10n.deckDownloadsUpdated
            : downloadFailureText(l10n, failure);
      } else if (downloads.indexStatus == IndexStatus.failed) {
        message = downloadFailureText(l10n, downloads.indexFailure);
      } else {
        message = l10n.deckDownloadsNoUpdates;
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (mounted) showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final downloads = AppScope.read(context).deckDownloads;
    final language = view.language.code;
    Widget body(bool busy) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MergeSemantics(
                child: Row(
                  children: <Widget>[
                    DeckGlyph(
                      glyph: widget.glyph,
                      language: view.language,
                      size: 52,
                    ),
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
                            l10n.pathCourseProgress(
                              view.doneCount,
                              view.unitCount,
                            ),
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
            ),
            IncomingFeature(
              feature: Feature.deckUpdates,
              label: l10n.deckDownloadsCheck,
              badge: IncomingBadgePlacement.none,
              child: IconButton(
                icon: const Icon(Icons.sync),
                tooltip: l10n.hintUpdate,
                onPressed: _checking ? null : _update,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        busy
            ? _DownloadBar(downloads: downloads, language: language)
            : _ProgressBar(view: view),
        const SizedBox(height: 14),
        _IncomingRow(
          feature: Feature.hoursLeft,
          icon: Icons.schedule,
          text: l10n.pathHoursBody(
            l10n.pathHoursLeft(widget.hours.left.ceil()),
            l10n.pathHoursSpent(widget.hours.spent),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: downloads == null
          ? body(_checking)
          : ListenableBuilder(
              listenable: downloads,
              builder: (context, _) => body(
                _checking ||
                    downloads.updating ||
                    downloads.isDownloading(language),
              ),
            ),
    );
  }
}

/// The bar while the course's decks are looked for and downloaded, in the
/// place of the levels' bar and its labels, so that the card keeps its size.
class _DownloadBar extends StatelessWidget {
  const _DownloadBar({required this.downloads, required this.language});

  final DeckDownloads? downloads;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = downloads?.progressOf(language);
    final value = progress == null || progress.total == 0
        ? null
        : progress.done / progress.total;
    return Semantics(
      liveRegion: true,
      label: l10n.deckDownloadsRowDownloading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.mark),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          SizedBox(
            height: 22 * phoneTextScaleOf(context),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 4),
              child: Text(
                l10n.deckDownloadsRowDownloading,
                style: theme.textTheme.labelSmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
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
            borderRadius: BorderRadius.circular(AppRadii.mark),
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
                  height: 22 * phoneTextScaleOf(context),
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

/// The course card's hours line: its icon and one sentence, dimmed with the
/// "Feature incoming" badge until [feature] is on.
class _IncomingRow extends StatelessWidget {
  const _IncomingRow({
    required this.feature,
    required this.icon,
    required this.text,
  });

  final Feature feature;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IncomingFeature(
      feature: feature,
      label: text,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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
                    borderRadius: BorderRadius.circular(AppRadii.field),
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
