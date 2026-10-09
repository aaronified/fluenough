import 'package:flutter/material.dart';

import '../../core/scheduling/skill_fit.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Which way the learner's pace moved a skill's reviews from how it
/// started (`SkillFit.direction`). Always words with an arrow, and "more"
/// is never in the error colour: forgetting faster is not a fault.
enum PaceDirection {
  fewer(Icons.south),
  more(Icons.north),
  same(Icons.drag_handle);

  const PaceDirection(this.icon);

  /// From the outlook at the start to the one now.
  factory PaceDirection.of(SkillOutlook start, SkillOutlook now) =>
      switch (SkillFit.direction(start, now)) {
        < 0 => PaceDirection.fewer,
        > 0 => PaceDirection.more,
        _ => PaceDirection.same,
      };

  final IconData icon;

  /// "Fewer reviews", "More reviews", "About the same".
  String mark(AppLocalizations l10n) => switch (this) {
    PaceDirection.fewer => l10n.paceFewer,
    PaceDirection.more => l10n.paceMore,
    PaceDirection.same => l10n.paceSame,
  };

  /// [mark] in one word, for large text.
  String shortMark(AppLocalizations l10n) => switch (this) {
    PaceDirection.fewer => l10n.paceFewerShort,
    PaceDirection.more => l10n.paceMoreShort,
    PaceDirection.same => l10n.paceSameShort,
  };

  /// The plan's sentence for the skill [mode]: "You remember heard words
  /// well: fewer reviews", "Written words slip faster: more reviews".
  String verdict(AppLocalizations l10n, String mode) => switch (this) {
    PaceDirection.fewer => l10n.adjustedFewer(mode),
    PaceDirection.more => l10n.adjustedMore(mode),
    PaceDirection.same => l10n.adjustedSame(mode),
  };
}

/// The "Adjusted to you" strip and the How you learn card (mockup
/// `docs/mockups/adapted-to-you.html`): a round tune mark, a title, a
/// quieter line under it, and a chevron, on `surfaceContainerLowest`.
/// Every line starts at one text edge. Tapped, it opens How you learn.
///
/// With [underTitle], as on Today, the mark and the chevron sit level with
/// the title alone and the line runs on under the chevron; otherwise, as
/// on Progress, they sit level with the title and line together.
class PaceStrip extends StatelessWidget {
  const PaceStrip({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.underTitle = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool underTitle;

  /// The mark's width and the gap after it: where the text starts.
  static const double _textStart = 32 + 12;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = subtitle;
    final heading = Text(
      title,
      style: theme.textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
    final quiet = line == null
        ? null
        : Text(
            line,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
    Widget row(Widget text) => Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tune, size: 18, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(width: _textStart - 32),
        Expanded(child: text),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );
    final content = underTitle
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              row(heading),
              if (quiet != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _textStart,
                    end: 8,
                  ),
                  child: quiet,
                ),
            ],
          )
        : row(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[heading, ?quiet],
            ),
          );
    return MergeSemantics(
      child: Semantics(
        button: true,
        onTapHint: l10n.howYouLearnOpenHint,
        child: Material(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.small),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A skill tile's mark: the arrow, and "Fewer reviews", or in one word
/// when [short]. In `onSurfaceVariant`, whichever way it points.
class PaceMark extends StatelessWidget {
  const PaceMark({super.key, required this.direction, this.short = false});

  final PaceDirection direction;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colour = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: <Widget>[
        Icon(direction.icon, size: 14, color: colour),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            short ? direction.shortMark(l10n) : direction.mark(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        ),
      ],
    );
  }
}
