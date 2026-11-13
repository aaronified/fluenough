import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/culture.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/decks/weave.dart';
import '../../core/models/level.dart';
import '../../core/models/reading.dart' show bestLanguage;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import 'creator_sheet.dart';
import 'culture_parts.dart';

/// What opens a culture item's page: the language and the item's id.
class CultureItemRequest {
  const CultureItemRequest({required this.language, required this.itemId});

  final String language;
  final String itemId;
}

/// A culture item at the learner's level (approved mockup `culture-in-course`,
/// screen 2): the text with its reading and meaning, the words glossed, the
/// source line (author, work, date and the public-domain basis), the creator
/// chip and one legacy line, and a button to practise it. A proverb, a stanza
/// and a passage with its gloss are what the decks hold at A1, A2 and B1.
///
/// An item above the learner's level is never shown (D2): with "Items above my
/// level" at its default the page says it is not shown yet; with support on it
/// shows the item with a lock, not counted and not scheduled for review.
class CultureItemPage extends StatelessWidget {
  const CultureItemPage({super.key, required this.request});

  final CultureItemRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final item = state.cultureItemById(request.language, request.itemId);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: state.status == CatalogStatus.loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoadingDecks,
                ),
              )
            : EmptyState(
                icon: Icons.format_quote,
                title: l10n.cultureItemNotFound,
              ),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) => _build(context, state, item),
    );
  }

  Widget _build(BuildContext context, AppState state, CultureItem item) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = request.language;
    final info = cultureLanguage(state, language);
    final settings = state.settings;
    final learner = state.levelIn(language);
    final above = LevelGate.isAbove(item.level, learner);
    final hidden = above && !settings.cultureAboveSupport;
    final spoken = cultureSpoken(context, state);
    final source = cultureSourceLine(l10n, item.source);
    final creatorId = item.creators.isEmpty ? null : item.creators.first;
    final creator = creatorId == null
        ? null
        : state.creatorsOf(language)?.byId(creatorId);
    final showPerson = settings.cultureCreators;
    final done = state.isCultureItemDone(item);
    final canPlay = !hidden && state.hasVoice(info);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.cultureItemTitle(item.level.label),
          style: theme.textTheme.titleMedium,
        ),
        actions: <Widget>[
          if (canPlay)
            IconButton(
              tooltip: l10n.cultureListen,
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: () =>
                  state.speak(item.target.replaceAll('\n', ' '), info),
            ),
          ReportButton(detail: item.id),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          8,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              ResultTag(
                text: cultureKindName(l10n, item.kind),
                style: ResultTagStyle.kind,
              ),
              LevelTag(level: item.level, above: above),
            ],
          ),
          const SizedBox(height: 12),
          if (hidden)
            AboveLevelNotice(
              title: l10n.cultureNotShownTitle,
              body: l10n.cultureNotShownBody(item.level.label),
            )
          else ...<Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TargetText(
                    item.target,
                    language: info,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.start,
                    card: item.card,
                  ),
                  if (item.reading != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      item.reading!,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.meaning != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(item.meaning!, style: theme.textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
            if (item.glossary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSizes.textInset,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.cultureGlossTitle,
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSizes.textInset,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final gloss in item.glossary)
                      Chip(
                        label: Text(
                          l10n.cultureGlossEntry(
                            gloss.word,
                            gloss.meaning[bestLanguage(
                                  gloss.meaning.keys,
                                  spoken,
                                )] ??
                                gloss.modern,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (source != null) ...<Widget>[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSizes.textInset,
                ),
                child: Text(
                  source,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (showPerson) ...<Widget>[
              const SizedBox(height: 14),
              if (creator != null)
                CreatorChip(language: language, creatorId: creator.id)
              else if (item.creators.isEmpty)
                const _NoSingleAuthor(),
            ],
            const SizedBox(height: 16),
            if (above)
              AboveLevelNotice(
                title: l10n.cultureAboveTitle,
                body: l10n.cultureAboveBody,
              )
            else
              _Practise(item: item, language: language, done: done),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: AppButtonStyles.inline(context),
              onPressed: () => AppNavigator.openCulture(context, language),
              child: Text(l10n.cultureAllItems),
            ),
          ),
        ],
      ),
    );
  }
}

/// An item nobody wrote: a folk saying in use for centuries.
class _NoSingleAuthor extends StatelessWidget {
  const _NoSingleAuthor();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.person_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.cultureNoAuthorTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    l10n.cultureNoAuthorBody,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The practice of an item: its cards drilled, taught and then scheduled like
/// any others, and a mark once it has been met.
class _Practise extends StatelessWidget {
  const _Practise({
    required this.item,
    required this.language,
    required this.done,
  });

  final CultureItem item;
  final String language;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppScope.of(context).settings;
    // With culture off its decks are in no lesson or session, so there is
    // nothing to practise; the item can still be read.
    if (item.cards.isEmpty || !settings.cultureItems) {
      return const SizedBox.shrink();
    }
    // A passage is learned through its questions, a lesson of its deck; any
    // other item is one card, a session of its own.
    final request = item.isPassage
        ? DrillRequest.lesson(language: language, deckId: item.deckId)
        : DrillRequest.sheet(
            <String>{...item.cardIds},
            language: language,
            revise: done,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (done)
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.cultureMet)),
            ],
          ),
        if (!(done && item.isPassage)) ...<Widget>[
          if (done) const SizedBox(height: 8),
          FilledButton(
            onPressed: () => AppNavigator.startDrill(context, request),
            child: Text(
              done ? l10n.culturePractiseAgain : l10n.culturePractise,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          settings.cultureCounts
              ? l10n.cultureCountsNote
              : l10n.cultureBonusNote,
          style: Theme.of(context).textTheme.bodySmall!
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Whether [item] is above the learner: for a row that locks it.
bool cultureItemAbove(AppState state, String language, CultureItem item) =>
    LevelGate.isAbove(item.level, state.levelIn(language));
