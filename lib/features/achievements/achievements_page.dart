import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/achievements/achievement.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../l10n/app_localizations.dart';
import '../stats/stats_numbers.dart';
import 'achievements_view.dart';
import 'badge_sheet.dart';

/// The badges of a language and of the app (#323, #324; the approved mockup
/// `achievements`), opened from the latest-badge line on Progress and from
/// the session summary: four tabs, Levels, Skills, Sets and Other, and a
/// sheet for each badge. The badges are worked out when this page opens, off
/// the main thread, and are never in the way of a lesson.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({
    super.key,
    this.language,
    this.initialTab = AchievementTab.levels,
  });

  /// The language's code; the language the app shows when null.
  final String? language;

  final AchievementTab initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final code = language ?? state.shownLanguage;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achvTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state.achievements,
          builder: (context, _) {
            final report = state.achievements.of(code);
            if (report == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final info = _languageOf(state, code);
            return AchievementsView(
              report: report,
              language: info,
              initialTab: initialTab,
              onBadge: (view) => showBadgeSheet(
                context,
                view: view,
                language: info,
                cards: _cardsOf(state, info, view.result),
              ),
              onLevels: (levels) =>
                  showLevelsSheet(context, levels: levels, language: info),
            );
          },
        ),
      ),
    );
  }
}

/// The language [code], or a bare one when the profile has none.
LanguageInfo _languageOf(AppState state, String? code) {
  for (final language in state.languages) {
    if (language.code == code) return language;
  }
  return LanguageInfo(
    code: code ?? 'und',
    iso639_3: code ?? 'und',
    name: code ?? '',
  );
}

/// The cards [result] lists, found in [language]'s decks, each with whether
/// the learner has started it.
List<BadgeCardRow> _cardsOf(
  AppState state,
  LanguageInfo language,
  AchievementResult result,
) {
  final lookup = cardLookupOf(state, language: language.code);
  final rows = <BadgeCardRow>[];
  for (final id in result.cards) {
    final card = lookup(id);
    if (card == null) continue;
    rows.add(
      BadgeCardRow(
        card: card,
        language: language,
        started: DrillMode.values.any(
          (mode) => state.progress.stateOf(card.id, mode) != null,
        ),
      ),
    );
  }
  return rows;
}
