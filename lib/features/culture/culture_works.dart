import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/item_search.dart' show coreIdOfDeck;
import '../../app/routes.dart';
import '../../core/decks/recommendation_list.dart';
import '../../core/models/completed_work.dart';
import '../../core/models/creator.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import 'culture_parts.dart';

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
/// public-domain work, a badge, and a short briefing. [open] shows the whole
/// briefing, that the work is not included in the app, where to get it legally
/// and "I've completed this". Every work opens and can be marked completed
/// whatever the learner's level; nothing is locked.
class CultureWorkRow extends StatelessWidget {
  const CultureWorkRow({
    super.key,
    required this.work,
    required this.language,
    required this.file,
    required this.open,
    required this.onTap,
  });

  final Recommendation work;
  final String language;
  final CreatorsFile? file;
  final bool open;
  final VoidCallback onTap;

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
    return ResultRow(
      icon: recommendationIcon(work.medium),
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
      onTap: onTap,
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
          if (!open && briefing.isNotEmpty)
            Text(
              briefingLine(briefing),
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (open)
            _OpenWork(work: work, language: language, briefing: briefing),
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

/// The open row's body: the whole briefing, the year, that the work is not in
/// the app, the legal routes, and the "I've completed this" action.
class _OpenWork extends StatelessWidget {
  const _OpenWork({
    required this.work,
    required this.language,
    required this.briefing,
  });

  final Recommendation work;
  final String language;
  final String briefing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final progress = state.recommendationProgress;
    final spoken = cultureSpoken(context, state);
    final done = progress.isCompleted(work.id);
    final routes = <LegalRoute>[
      for (final route in work.legal)
        if (Uri.tryParse(route.url)?.scheme == 'https') route,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (briefing.isNotEmpty)
          Text(briefing, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          l10n.recNotIncluded,
          style: theme.textTheme.bodySmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        for (final route in routes)
          Semantics(
            button: true,
            child: TextButton.icon(
              style: AppButtonStyles.inline(context),
              onPressed: () =>
                  openLink(context, route.url, copied: l10n.cultureLinkCopied),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                route.noteFor(spoken).isEmpty
                    ? _legalKind(l10n, route.kind)
                    : l10n.recLegalLine(
                        _legalKind(l10n, route.kind),
                        route.noteFor(spoken),
                      ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (done)
              FilledButton.tonalIcon(
                onPressed: () => _unmark(context, state),
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.recCompleted),
              )
            else
              FilledButton(
                onPressed: () {
                  state.haptics.confirm();
                  progress.complete(work, language, state.now());
                },
                child: Text(l10n.recIComplete),
              ),
            if (done && work.questions.isNotEmpty)
              TextButton(
                onPressed: () =>
                    AppNavigator.openWorkQuestions(context, language, work.id),
                child: Text(l10n.recQuestions),
              ),
          ],
        ),
      ],
    );
  }

  /// Takes the mark away, with a way back in the toast.
  void _unmark(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final progress = state.recommendationProgress;
    // Undo gives back the same completion date, not a new one.
    final was = <CompletedWork>[
      for (final w in progress.completed)
        if (w.recommendationId == work.id) w,
    ];
    final completedAt = was.isEmpty ? state.now() : was.first.completedAt;
    progress.unmark(work.id);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.recNotCompleted),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () => progress.complete(work, language, completedAt),
        ),
      ),
    );
  }

  String _legalKind(AppLocalizations l10n, String kind) => switch (kind) {
    'library' => l10n.recLegalLibrary,
    'publisher' => l10n.recLegalPublisher,
    'store' => l10n.recLegalStore,
    'stream' => l10n.recLegalStream,
    'archive' => l10n.recLegalArchive,
    'public-domain' => l10n.recLegalPublicDomain,
    _ => kind,
  };
}
