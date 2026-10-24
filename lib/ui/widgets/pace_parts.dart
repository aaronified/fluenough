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

/// A skill tile's mark: the arrow alone, in `onSurfaceVariant` whichever way
/// it points, named for a screen reader by [PaceDirection.mark] ("Fewer
/// reviews", "More reviews", "About the same").
class PaceMark extends StatelessWidget {
  const PaceMark({super.key, required this.direction});

  final PaceDirection direction;

  /// The arrow's size, and the room a tile keeps for it.
  static const double size = 16;

  @override
  Widget build(BuildContext context) => Semantics(
    label: direction.mark(AppLocalizations.of(context)!),
    child: Icon(
      direction.icon,
      size: size,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
