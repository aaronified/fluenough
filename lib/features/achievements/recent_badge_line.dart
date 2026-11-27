import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/achievements/achievement.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'achievement_texts.dart';
import 'badge_glyph.dart';
import 'badge_view.dart';

/// The quiet line on Progress, under the Level tile (the approved mockup
/// `achievements`, "Summary entry"): the latest badge and its date. Tapping
/// opens the badges. Nothing at all before the first badge: no count, no red
/// dot. Worked out when Progress is opened, never in a lesson.
class RecentBadgeEntry extends StatelessWidget {
  const RecentBadgeEntry({super.key, required this.language});

  /// The language Progress shows, or null for every language together, which
  /// has no badges of its own.
  final String? language;

  @override
  Widget build(BuildContext context) {
    final code = language;
    if (code == null) return const SizedBox.shrink();
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.achievements,
      builder: (context, _) {
        final report = state.achievements.of(code);
        if (report == null) return const SizedBox.shrink();
        final name = state.languages
            .where((l) => l.code == code)
            .map((l) => l.name)
            .firstOrNull;
        return RecentBadgeLine(
          report: report,
          languageName: name,
          onTap: () => AppNavigator.openAchievements(context, language: code),
        );
      },
    );
  }
}

/// The latest earned badge of [report], one line; nothing before the first.
class RecentBadgeLine extends StatelessWidget {
  const RecentBadgeLine({
    super.key,
    required this.report,
    required this.onTap,
    this.languageName,
  });

  final AchievementReport report;
  final VoidCallback onTap;

  /// The language's name, for a badge of the course; a badge of the whole app
  /// shows only its date.
  final String? languageName;

  @override
  Widget build(BuildContext context) {
    final earned = report.earned;
    if (earned.isEmpty) return const SizedBox.shrink();
    final latest = earned.last;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = latest.def.fullName(l10n);
    final date = achievementDate(l10n, latest.earnedAt!);
    final language = languageName;
    final sub = language == null || latest.def.isAppWide
        ? date
        : l10n.achvSubline(language, date);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8),
      child: Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: l10n.achvRecentSemantics(name, date),
        onTap: onTap,
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.field),
          clipBehavior: Clip.antiAlias,
          // hint-ok: shows text
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
              child: Row(
                spacing: 12,
                children: <Widget>[
                  BadgeGlyph(
                    view: BadgeView(latest, BadgeShown.earned),
                    size: BadgeSize.small,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          sub,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
