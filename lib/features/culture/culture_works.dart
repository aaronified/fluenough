import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/item_search.dart' show coreIdOfDeck;
import '../../app/routes.dart';
import '../../core/decks/recommendation_list.dart';
import '../../core/models/creator.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import 'culture_parts.dart';
import 'work_page.dart';

/// The icon of a kind of work.
IconData recommendationIcon(RecommendationMedium medium) => switch (medium) {
  RecommendationMedium.book => Icons.menu_book_outlined,
  RecommendationMedium.film => Icons.movie_outlined,
  RecommendationMedium.series => Icons.tv_outlined,
  RecommendationMedium.song => Icons.music_note_outlined,
  RecommendationMedium.play => Icons.theater_comedy_outlined,
  RecommendationMedium.podcast => Icons.podcasts,
  RecommendationMedium.comic => Icons.auto_stories_outlined,
};

/// What a kind of work is called.
String recommendationMediumName(
  AppLocalizations l10n,
  RecommendationMedium medium,
) => switch (medium) {
  RecommendationMedium.book => l10n.recMediumBook,
  RecommendationMedium.film => l10n.recMediumFilm,
  RecommendationMedium.series => l10n.recMediumSeries,
  RecommendationMedium.song => l10n.recMediumSong,
  RecommendationMedium.play => l10n.recMediumPlay,
  RecommendationMedium.podcast => l10n.recMediumPodcast,
  RecommendationMedium.comic => l10n.recMediumComic,
};

/// The first sentence of a briefing: the one line a closed row shows.
String briefingLine(String briefing) {
  final text = briefing.trim();
  final end = text.indexOf(RegExp(r'[.!?](\s|$)'));
  return end < 0 ? text : text.substring(0, end + 1);
}

/// One recommended work as a row of the culture list on the Decks screen
/// (approved mockup `culture-in-decks`): its kind, level and, for a
/// public-domain work, a badge, and a short briefing. Its poster is the thumb
/// when it has a free one and the language's "Show pictures" switch is on, else
/// the icon of its medium (approved mockup `culture-media`). A tap opens the
/// work's page ([WorkPage]). Every work opens and can be marked completed
/// whatever the learner's level; nothing is locked.
class CultureWorkRow extends StatelessWidget {
  const CultureWorkRow({
    super.key,
    required this.work,
    required this.language,
    required this.file,
  });

  final Recommendation work;
  final String language;
  final CreatorsFile? file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final info = cultureLanguage(state, language);
    final spoken = cultureSpoken(context, state);
    final done = state.recommendationProgress.isCompleted(work.id);
    final who = <String>[
      for (final id in work.creators)
        if (file?.byId(id) case final c?)
          c.nameFor(spoken, target: language).text,
      ?(work.year == null ? null : '${work.year}'),
    ].join(' · ');
    final briefing = work.briefingFor(spoken);
    final quoting = _quotingDeck(state);
    final poster =
        work.image != null && state.settings.cultureFor(language).pictures;
    return ResultRow(
      icon: recommendationIcon(work.medium),
      leading: poster ? WorkThumb(work: work, language: language) : null,
      title: work.title,
      titleWidget: TargetText(
        work.title,
        language: info,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        textAlign: TextAlign.start,
      ),
      trailing: done
          ? Icon(
              Icons.check_circle,
              color: scheme.primary,
              semanticLabel: l10n.recCompleted,
            )
          : null,
      lines: <Widget>[
        if (work.titleReading != null) RowLine(work.titleReading!),
        if (who.isNotEmpty) RowLine(who),
      ],
      tags: <Widget>[
        ResultTag(
          text: recommendationMediumName(l10n, work.medium),
          style: ResultTagStyle.kind,
        ),
        LevelTag(level: work.level),
        if (isPublicDomainWork(work))
          ResultTag(
            text: l10n.recPublicDomain,
            style: ResultTagStyle.publicDomain,
          ),
      ],
      onTap: () => AppNavigator.openWork(context, language, work.id),
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (quoting != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 6),
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: () => AppNavigator.openCulture(context, language),
                  child: Text(
                    l10n.recAlsoInDeck(quoting),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (briefing.isNotEmpty)
            Text(
              briefingLine(briefing),
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// The name of the culture deck that quotes the work, when the learner's
  /// course has it.
  String? _quotingDeck(AppState state) {
    final id = work.quotedIn;
    if (id == null) return null;
    for (final entry in state.catalogView.decks) {
      if (entry.language.code == language &&
          (entry.id == id || coreIdOfDeck(entry) == id)) {
        return entry.deck.name;
      }
    }
    return null;
  }
}
