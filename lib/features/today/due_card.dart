import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/scheduling/script_split.dart';
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

/// Above this many cards a tile drops its pace arrow, for room for the number.
const int _arrowMax = 99;

/// The skill tiles under Today's one button (#521): what is due in each
/// skill, and a tile starts a review of its skill alone (ADR-0030). The
/// start and the count moved to the button ([DailyCard]). A Script tile
/// follows the skills when a learned course has script decks: script
/// reading and writing together, kept out of Recognition's and Write's
/// (owner, 2026-10-24).
///
/// Once some skill is adjusted to the learner ([TodayNumbers.pace]), the
/// settled "Adjusted to you" strip sits above the tiles, with the 30-day
/// change, and opens How you learn; each adjusted skill's tile carries an
/// arrow, up for more reviews and down for fewer. Before the
/// first fit, neither shows. With nothing due, the card holds the strip
/// alone, or nothing.
///
/// Design screen `today`, the `primaryContainer` section named "Due now".
class DueCard extends StatelessWidget {
  const DueCard({super.key, required this.numbers});

  final TodayNumbers numbers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pace = numbers.pace;
    if (numbers.allDone && pace == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.todayDueSection,
        child: Container(
          padding: const EdgeInsetsDirectional.all(24),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.hero),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (pace != null) _AdjustedStrip(pace: pace),
              if (pace != null && !numbers.allDone) const SizedBox(height: 16),
              if (!numbers.allDone) _SkillGrid(numbers: numbers),
            ],
          ),
        ),
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

/// The skill tiles, three to a row, thin, in two lines: the skill's icon, the
/// number due and its pace arrow if adjusted, then the name in small type
/// (owner, 2026-10-24, 2026-10-26). A row's tiles are as tall as each other; the last
/// row's missing tiles keep their place.
class _SkillGrid extends StatelessWidget {
  const _SkillGrid({required this.numbers});

  final TodayNumbers numbers;

  /// Tiles to a row.
  static const int _perRow = 3;

  @override
  Widget build(BuildContext context) {
    final pace = numbers.pace;
    final tiles = <Widget>[
      for (final MapEntry(key: skill, value: count) in numbers.bySkill.entries)
        _SkillTile(
          skill: skill,
          count: count,
          due: numbers.dueIn[skill] ?? 0,
          revisable: numbers.revisable[skill] ?? 0,
          noVoice: skill.needsVoice && numbers.noVoice,
          mark: pace?.marks[skill],
        ),
      if (numbers.script case final script?)
        _SkillTile(
          count: script.count,
          due: script.due,
          revisable: script.revisable,
          noVoice: false,
          mark: pace?.scriptMark,
        ),
    ];
    Widget row(List<Widget> tiles) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          for (var i = 0; i < _perRow; i++)
            Expanded(child: i < tiles.length ? tiles[i] : const SizedBox()),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        for (var i = 0; i < tiles.length; i += _perRow)
          row(tiles.sublist(i, math.min(i + _perRow, tiles.length))),
      ],
    );
  }
}

/// One skill: its icon, the arrow of its pace, how many of today's cards
/// drill it, and its name under them. Without a [skill] it is the Script
/// tile. Tapped, it reviews what is due in the skill, in every language
/// learned. With nothing due, it asks whether to revise every word known in
/// the skill (ADR-0030).
///
/// Three other looks, kept apart as ADR-0008 asks:
/// - **nothing due:** dimmed, as the design draws it;
/// - **no voice on this phone** (listening only): a chevron where the count
///   would be and the reason under the name, and the tile opens Voices,
///   where one is set up;
/// - **incoming** (grammar until #2): dimmed, an hourglass where the count
///   would be, and "Feature incoming" when tapped.
class _SkillTile extends StatelessWidget {
  const _SkillTile({
    this.skill,
    required this.count,
    required this.due,
    required this.revisable,
    required this.noVoice,
    this.mark,
  });

  /// The skill, or null for the Script tile.
  final Skill? skill;

  /// The arrow: which way the skill's pace moved; null if not adjusted.
  final PaceDirection? mark;

  /// Today's cards in this skill, as the tile shows.
  final int count;

  /// The cards a review of this skill alone holds, which tapping starts.
  final int due;

  /// With nothing [due], how many words the skill can revise; with none,
  /// the tile starts nothing.
  final int revisable;
  final bool noVoice;

  String _label(AppLocalizations l10n) =>
      skill?.label(l10n) ?? l10n.skillScript;

  /// What each tap starts: Script's own tiles' sessions are the script
  /// decks' Recognition and Write; a skill's leave those out.
  DrillRequest get _review => skill == null
      ? const DrillRequest.script()
      : DrillRequest(skill: skill, script: ScriptScope.without);

  DrillRequest get _revision => skill == null
      ? const DrillRequest.script(revise: true)
      : DrillRequest.reviseSkill(skill!, script: ScriptScope.without);

  Future<void> _revise(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final label = _label(l10n);
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
      await AppNavigator.startDrill(context, _revision);
    }
  }

  /// The Script tile's pill: a letter form, in the theme's secondary pair
  /// (the word skills have fixed colours of their own).
  Widget _scriptPill(ColorScheme scheme) => ExcludeSemantics(
    child: Container(
      width: 36,
      height: 28,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.abc, size: 22, color: scheme.onSecondaryContainer),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = _label(l10n);
    final incoming = skill != null && isIncoming(context, skill!.feature);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final small = theme.textTheme.bodySmall!;

    Widget fitted(Widget child, {AlignmentGeometry? alignment}) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment ?? AlignmentDirectional.centerStart,
      child: child,
    );
    final Widget number = incoming
        ? Icon(Icons.hourglass_empty, size: 18, color: scheme.onSurfaceVariant)
        : noVoice
        ? Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant)
        : Text(
            NumberFormat.decimalPattern(locale).format(count),
            maxLines: 1,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          );

    // Incoming and voiceless tiles have their own look, never dimmed.
    final opacity = count == 0 && !incoming && !noVoice
        ? _emptyTileOpacity
        : 1.0;
    final moved = mark;
    final body = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The icon, the number and the arrow share a row (owner,
          // 2026-10-26). The arrow keeps its full contrast on a dimmed tile,
          // the only place Today shows a skill's pace; its room is kept when
          // there is none, so that the tiles sit level, and given to the
          // number above 99.
          Row(
            spacing: 4,
            children: <Widget>[
              Opacity(
                opacity: opacity,
                child: skill == null
                    ? _scriptPill(scheme)
                    : ModePill(
                        skill: skill!,
                        size: ModePillSize.small,
                        muted: noVoice,
                      ),
              ),
              Expanded(
                child: Opacity(
                  opacity: opacity,
                  child: fitted(
                    number,
                    alignment: AlignmentDirectional.centerEnd,
                  ),
                ),
              ),
              if (count <= _arrowMax || incoming || noVoice)
                SizedBox.square(
                  dimension: PaceMark.size,
                  child: moved == null ? null : PaceMark(direction: moved),
                ),
            ],
          ),
          // The name is pinned to the bottom of the tile, so that the names
          // in a row share a baseline whatever else a tile holds (#849,
          // owner, 2026-10-25): a voiceless tile's note sits above its name.
          const SizedBox(height: 4),
          const Spacer(),
          if (noVoice)
            Opacity(
              opacity: opacity,
              child: fitted(
                Text(
                  l10n.commonNoVoice,
                  maxLines: 1,
                  softWrap: false,
                  style: small.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          Opacity(
            opacity: opacity,
            child: fitted(
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final radius = BorderRadius.circular(AppRadii.small);
    void setUp() => AppNavigator.openVoices(context);
    final VoidCallback? start = due > 0
        ? () => AppNavigator.startDrill(context, _review)
        : revisable > 0
        ? () => _revise(context)
        : null;
    final onTap = incoming ? null : (noVoice ? setUp : start);
    // The fill is dimmed as the content is, so that the tile looks as one
    // dimmed whole, while the arrow keeps its contrast.
    final tile = Material(
      color: scheme.surfaceContainerLowest.withValues(alpha: opacity),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );

    if (incoming) {
      return IncomingFeature(
        feature: skill!.feature,
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
