import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/culture.dart';
import '../../app/routes.dart';
import '../../core/decks/recommendation_list.dart';
import '../../core/models/completed_work.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import 'culture_parts.dart';
import 'culture_picture.dart';
import 'culture_works.dart';

/// What opens a work's page.
class WorkRequest {
  const WorkRequest({required this.language, required this.recommendationId});

  final String language;
  final String recommendationId;
}

/// The poster's box on the work page, in dp (approved mockup
/// `culture-media`).
const double workPosterWidth = 200;
const double workPosterHeight = 290;

/// The thumb of a work in the culture list, in dp.
const double workThumbWidth = 48;
const double workThumbHeight = 68;

/// A recommended work's page (approved mockup `culture-media`, screen 2): its
/// poster with the credit line and "Licence and source" link when it has a
/// free picture, else the icon of its medium beside the title; then the
/// reading, creators and year, the kind and level, the briefing, where to get
/// it legally and "I've completed this". Every work opens and can be marked
/// completed at any level.
class WorkPage extends StatelessWidget {
  const WorkPage({super.key, required this.request});

  final WorkRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final work = state.catalogView.recommendations[request.language]?.byId(
      request.recommendationId,
    );
    if (work == null) {
      return Scaffold(
        appBar: AppBar(),
        body: state.status == CatalogStatus.loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoadingDecks,
                ),
              )
            : EmptyState(
                icon: Icons.menu_book_outlined,
                title: l10n.recWorkNotFound,
              ),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.recommendationProgress,
        state.settings,
      ]),
      builder: (context, _) => _body(context, state, work),
    );
  }

  Widget _body(BuildContext context, AppState state, Recommendation work) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = request.language;
    final info = cultureLanguage(state, language);
    final spoken = cultureSpoken(context, state);
    final file = state.creatorsOf(language);
    final progress = state.recommendationProgress;
    final done = progress.isCompleted(work.id);
    final who = <String>[
      for (final id in work.creators)
        if (file?.byId(id) case final c?)
          c.nameFor(spoken, target: language).text,
      ?(work.year == null ? null : '${work.year}'),
    ].join(' · ');
    final briefing = work.briefingFor(spoken);
    final routes = <LegalRoute>[
      for (final route in work.legal)
        if (Uri.tryParse(route.url)?.scheme == 'https') route,
    ];
    final poster =
        work.image != null && state.settings.cultureFor(language).pictures;
    final credit = poster ? cultureImageCredit(l10n, work.image) : null;
    final link = poster ? cultureImageLink(work.image) : null;
    return Scaffold(
      // No title in the bar: the title is below.
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          4,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          if (poster) ...<Widget>[
            Center(
              child: WorkPoster(work: work, language: language),
            ),
            if (credit != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                credit,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (link != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  style: AppButtonStyles.inline(context),
                  onPressed: () =>
                      openLink(context, link, copied: l10n.cultureLinkCopied),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.cultureImageLicenceLink),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!poster) ...<Widget>[
                Semantics(
                  label: recommendationMediumName(l10n, work.medium),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      recommendationIcon(work.medium),
                      size: 28,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: TargetText(
                        work.title,
                        language: info,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        textAlign: TextAlign.start,
                      ),
                    ),
                    if (work.titleReading != null)
                      Text(
                        work.titleReading!,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (who.isNotEmpty)
                      Text(
                        who,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
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
          ),
          if (briefing.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(briefing, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.recNotIncluded,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          for (final route in routes)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                button: true,
                child: TextButton.icon(
                  style: AppButtonStyles.inline(context),
                  onPressed: () => openLink(
                    context,
                    route.url,
                    copied: l10n.cultureLinkCopied,
                  ),
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
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (done)
                FilledButton.tonalIcon(
                  onPressed: () => _unmark(context, state, work),
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
                  onPressed: () => AppNavigator.openWorkQuestions(
                    context,
                    language,
                    work.id,
                  ),
                  child: Text(l10n.recQuestions),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Takes the mark away, with a way back in the toast.
  void _unmark(BuildContext context, AppState state, Recommendation work) {
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
          onPressed: () =>
              progress.complete(work, request.language, completedAt),
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

/// A work's poster at [workPosterWidth] by [workPosterHeight], cropped to fill,
/// in a hairline outline so a light poster does not float on a light surface;
/// the icon of its medium while it comes or when it cannot be had. A tap opens
/// the viewer.
class WorkPoster extends StatelessWidget {
  const WorkPoster({super.key, required this.work, required this.language});

  final Recommendation work;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = l10n.cultureImageOf(work.title);
    Widget placeholder() => Icon(
      recommendationIcon(work.medium),
      size: 56,
      color: scheme.onSecondaryContainer,
    );
    return CulturePictureLoader(
      image: work.image,
      language: language,
      builder: (context, bytes) {
        Widget content = placeholder();
        if (bytes != null) {
          final picture = CultureImageView(
            bytes: bytes,
            width: workPosterWidth,
            height: workPosterHeight,
            label: label,
            placeholder: placeholder(),
          );
          content = ZoomablePicture(
            bytes: bytes,
            image: work.image,
            label: label,
            child: picture,
          );
        }
        return Container(
          width: workPosterWidth,
          height: workPosterHeight,
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: scheme.outlineVariant),
          ),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: content,
        );
      },
    );
  }
}

/// A work's thumb in the culture list: [workThumbWidth] by [workThumbHeight],
/// its poster, or the icon of its medium until the poster is on the phone.
class WorkThumb extends StatelessWidget {
  const WorkThumb({super.key, required this.work, required this.language});

  final Recommendation work;
  final String language;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => Icon(
      recommendationIcon(work.medium),
      size: 22,
      color: scheme.onSecondaryContainer,
    );
    return Container(
      width: workThumbWidth,
      height: workThumbHeight,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: scheme.outlineVariant),
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: CulturePictureLoader(
        image: work.image,
        language: language,
        builder: (context, bytes) => bytes == null
            ? placeholder()
            // The row names the work: the picture adds nothing to read out.
            : ExcludeSemantics(
                child: CultureImageView(
                  bytes: bytes,
                  width: workThumbWidth,
                  height: workThumbHeight,
                  placeholder: placeholder(),
                ),
              ),
      ),
    );
  }
}
