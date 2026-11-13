import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/culture.dart';
import '../../app/item_search.dart' show coreIdOfDeck;
import '../../app/recommendation_feed.dart';
import '../../app/routes.dart';
import '../../core/decks/recommendation_list.dart';
import '../../core/models/completed_work.dart';
import '../../core/models/creator.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import 'culture_parts.dart';

/// What opens the recommendations: the language, and a work to open at once.
class RecommendationsRequest {
  const RecommendationsRequest({required this.language, this.openId});

  final String language;
  final String? openId;
}

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

/// The recommendations of a language (approved mockup
/// `culture-recommendations`, screen 1, variant A): popular works the app
/// points to and never reproduces. Kind chips with counts; a row for each work
/// with its kind, level and, for a public-domain work, a badge, and a short
/// briefing; the open row shows the whole briefing, that it is not included in
/// the app, where to get it legally, and "I've completed this". A work above
/// the learner's level is not listed, only counted; books are listed only for a
/// learner who learns scripts, and a script-only learner sees only books in
/// that script (`recommendationOffered`).
class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key, required this.request});

  final RecommendationsRequest request;

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  RecommendationMedium? _kind;
  String? _open;

  @override
  void initState() {
    super.initState();
    _open = widget.request.openId;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (state.status == CatalogStatus.loading) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.commonLoadingDecks,
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
        state.recommendationProgress,
      ]),
      builder: (context, _) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.request.language;
    final file = state.catalogWithAboveLevel.recommendations[language];
    final course = state.recommendationCourseOf(language);
    final list = recommendationList(
      file?.recommendations ?? const <Recommendation>[],
      course,
      state.levelIn(language),
    );
    final kinds = list.media;
    final kind = _kind != null && kinds.contains(_kind) ? _kind : null;
    final shown = list.of(kind);
    // A row the learner closed stays closed ('' is none); otherwise the one
    // they opened, or the first.
    final open = _open == ''
        ? null
        : shown.any((w) => w.id == _open)
        ? _open
        : (shown.isEmpty ? null : shown.first.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recTitle, style: theme.textTheme.titleMedium),
        actions: const <Widget>[ReportButton()],
      ),
      body: file == null || (list.offered.isEmpty && list.hiddenAbove == 0)
          ? EmptyState(
              icon: Icons.auto_stories_outlined,
              title: l10n.recEmpty,
              body: l10n.recEmptyBody,
            )
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                0,
                0,
                0,
                24,
              ).clearingSystemBar(context),
              children: <Widget>[
                if (kinds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 16,
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          label: Text(l10n.recChipAll(list.offered.length)),
                          selected: kind == null,
                          onSelected: (_) => setState(() => _kind = null),
                        ),
                        for (final medium in kinds)
                          ChoiceChip(
                            label: Text(
                              l10n.recChipKind(
                                recommendationMediumName(l10n, medium),
                                list.count(medium),
                              ),
                            ),
                            selected: kind == medium,
                            onSelected: (_) => setState(() => _kind = medium),
                          ),
                      ],
                    ),
                  ),
                if (course.scriptOnly)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      12,
                      16,
                      0,
                    ),
                    child: AboveLevelNotice(
                      title: l10n.recScriptOnlyTitle,
                      body: l10n.recScriptOnlyBody(
                        cultureLanguage(state, language).name,
                        list.otherScript,
                      ),
                    ),
                  )
                else if (list.hiddenAbove > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSizes.textInset + 16,
                      12,
                      AppSizes.textInset + 16,
                      0,
                    ),
                    child: Text(
                      l10n.recHiddenAbove(
                        list.hiddenAbove,
                        list.unlocksAt?.label ?? '',
                      ),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSizes.textInset + 16,
                    8,
                    AppSizes.textInset + 16,
                    8,
                  ),
                  child: Text(
                    l10n.recIntro,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSizes.textInset + 16,
                    ),
                    child: Text(l10n.recNothingAtLevel),
                  ),
                for (final work in shown)
                  _WorkRow(
                    work: work,
                    language: language,
                    file: state.creatorsOf(language),
                    open: work.id == open,
                    onTap: () =>
                        setState(() => _open = work.id == _open ? '' : work.id),
                  ),
              ],
            ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({
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
    for (final entry in state.catalogWithAboveLevel.decks) {
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
