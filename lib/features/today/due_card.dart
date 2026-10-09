import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/mode_pill.dart';
import '../../ui/widgets/pace_parts.dart';
import 'today_numbers.dart';

/// The design's opacity for a skill tile with nothing due: its fill and
/// its content, but not its pace mark, which is the only place Today shows
/// a skill's pace and keeps its full contrast.
const double _emptyTileOpacity = 0.55;

/// Above this text scale the skill tiles stack in one column, so that a
/// skill's name keeps room to be read.
const double _twoColumnMaxScale = 1.5;

/// From this text scale, while the tiles are two to a row, a tile's mark
/// shortens to its arrow and one word ("Fewer"); the strip and the screen
/// reader keep the full words.
const double _shortMarkScale = 1.3;

/// Today's first card: how many words are due and roughly how long they take,
/// the four skills, and Start review. Or, with nothing due, "All done".
///
/// Once some skill is adjusted to the learner ([TodayNumbers.pace]), the
/// settled "Adjusted to you" strip sits under the count, with the 30-day
/// change, and opens How you learn; each adjusted skill's tile carries a
/// mark (mockup `docs/mockups/adapted-to-you.html`, screen 2). Before the
/// first fit, neither shows.
///
/// Design screen `today`, the `primaryContainer` section named "Due now".
class DueCard extends StatelessWidget {
  const DueCard({super.key, required this.numbers});

  final TodayNumbers numbers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.todayDueSection,
      child: Container(
        padding: const EdgeInsetsDirectional.all(24),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.hero),
        ),
        child: numbers.allDone
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _AllDone(),
                  if (numbers.pace case final pace?) ...<Widget>[
                    const SizedBox(height: 16),
                    _AdjustedStrip(pace: pace),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _DueCount(due: numbers.due, minutes: numbers.minutes),
                  if (numbers.pace case final pace?) ...<Widget>[
                    const SizedBox(height: 16),
                    _AdjustedStrip(pace: pace),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 20),
                  _SkillGrid(numbers: numbers),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: AppButtonStyles.tall(context),
                    onPressed: () =>
                        AppNavigator.startDrill(context, numbers.start),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: Text(
                      numbers.languages.length > 1
                          ? l10n.todayStartLanguage(
                              numbers.languages.first.name,
                            )
                          : l10n.todayStartReview,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// "41 words due, about 14 min": the large number and its two lines, which
/// move under the number when they do not fit beside it.
class _DueCount extends StatelessWidget {
  const _DueCount({required this.due, required this.minutes});

  final int due;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onPrimaryContainer;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return MergeSemantics(
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: <Widget>[
          Text(
            NumberFormat.decimalPattern(locale).format(due),
            style: theme.textTheme.hero.copyWith(color: fg),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.todayWordsDue(due),
                  style: theme.textTheme.sectionTitle.copyWith(color: fg),
                ),
                Text(
                  l10n.todayMinutes(minutes),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: fg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Adjusted to you", settled: one quiet line under it, the next 30 days'
/// reviews beside what they were at the start. Opens How you learn.
class _AdjustedStrip extends StatelessWidget {
  const _AdjustedStrip({required this.pace});

  final TodayPace pace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totals = pace.totals;
    return PaceStrip(
      title: l10n.adjustedTitle,
      subtitle: totals == null
          ? null
          : totals.reviews == totals.was
          ? l10n.paceReviewsSteady(totals.reviews)
          : l10n.paceReviews(totals.reviews, totals.was),
      onTap: () => AppNavigator.openHowYouLearn(context),
      underTitle: true,
    );
  }
}

/// With nothing due: a tick, "All done for now" and when more arrives.
class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onPrimaryContainer;
    return MergeSemantics(
      child: Row(
        children: <Widget>[
          Icon(Icons.task_alt, size: 40, color: fg),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.todayAllDoneTitle,
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.todayAllDoneBody,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: fg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The skill tiles, two by two, or in one column at large text sizes. An
/// odd last tile keeps its half of the row. The two tiles of a row are as
/// tall as each other, and with marks shown, every tile keeps a line for
/// one, so that names and marks sit level across the row.
class _SkillGrid extends StatelessWidget {
  const _SkillGrid({required this.numbers});

  final TodayNumbers numbers;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    final pace = numbers.pace;
    final tiles = <Widget>[
      for (final MapEntry(key: skill, value: count) in numbers.bySkill.entries)
        _SkillTile(
          skill: skill,
          count: count,
          due: numbers.dueIn[skill] ?? 0,
          revisable: numbers.revisable[skill] ?? 0,
          noVoice: skill.needsVoice && numbers.noVoice,
          marked: pace != null,
          mark: pace?.marks[skill],
          // Kept level with the tile beside it; alone in its row, a tile
          // needs no empty line.
          keepMarkLine: scale <= _twoColumnMaxScale,
          shortMark: scale >= _shortMarkScale && scale <= _twoColumnMaxScale,
        ),
    ];
    if (scale > _twoColumnMaxScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: tiles,
      );
    }
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          Expanded(child: a),
          Expanded(child: b),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        for (var i = 0; i < tiles.length; i += 2)
          pair(
            tiles[i],
            i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// One skill: its pill, its name, and how many of today's cards drill it.
/// Tapped, it reviews what is due in the skill, in every language learned.
/// With nothing due, it asks whether to revise every word known in the
/// skill (ADR-0030).
///
/// Three other looks, kept apart as ADR-0008 asks:
/// - **nothing due:** dimmed, as the design draws it;
/// - **no voice on this phone** (listening only): the reason under the name,
///   and the tile opens Voices, where one is set up;
/// - **incoming** (grammar until #2): dimmed, an hourglass where the count
///   would be, and "Feature incoming" when tapped.
class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.skill,
    required this.count,
    required this.due,
    required this.revisable,
    required this.noVoice,
    this.marked = false,
    this.mark,
    this.keepMarkLine = true,
    this.shortMark = false,
  });

  final Skill skill;

  /// Whether the tiles show the learner's pace: then each keeps a line
  /// under its name for a [mark], which an adjusted skill fills.
  final bool marked;
  final PaceDirection? mark;

  /// Whether a tile with no [mark] keeps the line for one.
  final bool keepMarkLine;

  /// The [mark] in one word, for large text.
  final bool shortMark;

  /// Today's cards in this skill, as the tile shows.
  final int count;

  /// The cards a review of this skill alone holds, which tapping starts.
  final int due;

  /// With nothing [due], how many words the skill can revise; with none,
  /// the tile starts nothing.
  final int revisable;
  final bool noVoice;

  Future<void> _revise(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final label = skill.label(l10n);
    final revise = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.todaySkillReviseTitle(label)),
        content: Text(l10n.todaySkillReviseBody(revisable)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.todaySkillNotNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.todaySkillRevise),
          ),
        ],
      ),
    );
    if (revise == true && context.mounted) {
      await AppNavigator.startDrill(context, DrillRequest.reviseSkill(skill));
    }
  }

  /// With marks shown (mockup screen 2): the pill and the count on top,
  /// the name under them, then the mark's line, kept even when empty, at
  /// the foot, so that the lines of the two tiles of a row sit level.
  /// [opacity] dims all but the mark.
  Widget _markedBody(
    BuildContext context,
    Widget name,
    Widget trailing, {
    required double opacity,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final small = theme.textTheme.bodySmall!;
    final markLine =
        MediaQuery.textScalerOf(context).scale(small.fontSize!) *
        (small.height ?? 1.2);
    final moved = mark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Opacity(
            opacity: opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ModePill(
                      skill: skill,
                      size: ModePillSize.small,
                      muted: noVoice,
                    ),
                    const Spacer(),
                    // As tall as a count in every tile, an hourglass's or a
                    // chevron's too, so that the names sit level.
                    Stack(
                      alignment: AlignmentDirectional.centerEnd,
                      children: <Widget>[
                        Visibility.maintain(
                          visible: false,
                          child: Text(
                            NumberFormat.decimalPattern(locale).format(0),
                            style: theme.textTheme.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        trailing,
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                name,
                if (noVoice)
                  Text(
                    l10n.commonNoVoice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: small.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (moved != null || keepMarkLine)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: markLine),
                child: moved == null
                    ? const SizedBox.shrink()
                    : PaceMark(direction: moved, short: shortMark),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = skill.label(l10n);
    final incoming = isIncoming(context, skill.feature);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final name = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
    final Widget trailing = incoming
        ? Icon(Icons.hourglass_empty, size: 18, color: scheme.onSurfaceVariant)
        : noVoice
        ? Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant)
        : Text(
            NumberFormat.decimalPattern(locale).format(count),
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          );

    // Incoming and voiceless tiles have their own look, never dimmed.
    final opacity = count == 0 && !incoming && !noVoice
        ? _emptyTileOpacity
        : 1.0;
    final body = marked
        ? _markedBody(context, name, trailing, opacity: opacity)
        : Opacity(
            opacity: opacity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: <Widget>[
                    ModePill(
                      skill: skill,
                      size: ModePillSize.small,
                      muted: noVoice,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: noVoice
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                name,
                                Text(
                                  l10n.commonNoVoice,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : name,
                    ),
                    const SizedBox(width: 10),
                    trailing,
                  ],
                ),
              ),
            ),
          );

    final radius = BorderRadius.circular(AppRadii.small);
    void setUp() => AppNavigator.openVoices(context);
    final VoidCallback? start = due > 0
        ? () => AppNavigator.startDrill(context, DrillRequest(skill: skill))
        : revisable > 0
        ? () => _revise(context)
        : null;
    final onTap = incoming ? null : (noVoice ? setUp : start);
    // The fill is dimmed as the content is, so that the tile looks as one
    // dimmed whole, while the mark keeps its contrast.
    final tile = Material(
      color: scheme.surfaceContainerLowest.withValues(alpha: opacity),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );

    if (incoming) {
      return IncomingFeature(
        feature: skill.feature,
        label: label,
        badge: IncomingBadgePlacement.none,
        child: tile,
      );
    }
    if (noVoice) {
      return Semantics(
        container: true,
        button: true,
        label: l10n.todaySkillNoVoice(label),
        onTap: setUp,
        onTapHint: l10n.deckSetUpVoice,
        excludeSemantics: true,
        child: tile,
      );
    }
    final moved = mark;
    return Semantics(
      container: true,
      button: start != null,
      label: moved == null
          ? l10n.todaySkillSemantics(label, count)
          : l10n.todaySkillAdjustedSemantics(label, count, moved.name),
      onTap: start,
      onTapHint: start == null
          ? null
          : due > 0
          ? l10n.todaySkillReviewHint
          : l10n.todaySkillRevise,
      excludeSemantics: true,
      child: tile,
    );
  }
}
