import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'achievement_texts.dart';
import 'badge_glyph.dart';
import 'badge_view.dart';

/// What a badge says under its name: its date once earned, how far it has got
/// in progress ("312 of 500"), Locked, or that it is not part of the plan.
String badgeStatus(AppLocalizations l10n, BadgeView view) {
  final result = view.result;
  switch (view.shown) {
    case BadgeShown.earned:
      final at = result.earnedAt;
      return at == null ? '' : achievementDate(l10n, at);
    case BadgeShown.progress:
      return l10n.achvProgressOf(
        achievementCount(l10n, result.have),
        achievementCount(l10n, result.need),
      );
    case BadgeShown.locked:
      return l10n.achvLocked;
    case BadgeShown.left:
      return l10n.achvNotInPlan;
  }
}

/// A badge's label for a screen reader: its name and state, and for a locked
/// one how to earn it.
String badgeSemantics(AppLocalizations l10n, BadgeView view) {
  final name = view.def.fullName(l10n);
  switch (view.shown) {
    case BadgeShown.earned:
      return l10n.achvSemEarned(name, badgeStatus(l10n, view));
    case BadgeShown.progress:
      return l10n.achvSemProgress(name, badgeStatus(l10n, view));
    case BadgeShown.locked:
      return l10n.achvSemLocked(name, view.def.how(l10n));
    case BadgeShown.left:
      return l10n.achvSemLeft(name);
  }
}

/// One badge of the grid: its picture, its name and its state. A tap opens
/// its sheet, where how to earn it is written, so that the grid stays three
/// even columns at 1.4x text.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.view, required this.onTap});

  final BadgeView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: badgeSemantics(l10n, view),
      onTap: onTap,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.field),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: <Widget>[
                BadgeGlyph(view: view),
                Text(
                  view.def.name(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  badgeStatus(l10n, view),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
