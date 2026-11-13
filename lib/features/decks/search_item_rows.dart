import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart' show DeckDownloadFailure;
import '../../app/item_search.dart';
import '../../app/routes.dart';
import '../../app/topics.dart';
import '../../app/unlocks.dart';
import '../../core/data/sections.dart' show nameIn;
import '../../core/decks/topic_resolver.dart';
import '../../core/logs/log_entry.dart' show describeError;
import '../../core/models/level.dart';
import '../../core/progress/recent_answers.dart' show MasteryLevel;
import '../../core/search/search_items.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/target_text.dart';
import '../downloads/download_text.dart';
import '../situations/situation_page.dart' show SituationRequest;
import 'deck_content.dart';
import 'result_marks.dart';
import 'unit_labels.dart';
import 'word_sheet.dart';

/// The interface locale's language code, then the languages the learner
/// speaks: what a name or a title in the data is read in.
List<String> spokenFor(BuildContext context, AppState state) => <String>[
  Localizations.localeOf(context).languageCode,
  ...state.settings.spokenLanguages,
];

/// The row of [result], drawn by its type (the approved mockup
/// `search-results-tabs.html`: a distinct row per type), or null for a result
/// whose item is no longer there. A result above the learner's level is
/// marked, dimmed and opens a preview instead of starting.
Widget? itemResultRow(
  BuildContext context,
  ItemSearchIndex index,
  ItemResult result,
) {
  final state = AppScope.of(context);
  try {
    switch (result.row.type) {
      case SearchItemType.situation:
        return _situationRow(context, state, index, result);
      case SearchItemType.deck:
        return _DeckResultRow(index: index, result: result);
      case SearchItemType.topic:
        return _topicRow(context, state, index, result);
      case SearchItemType.concept:
        return _conceptRow(context, state, index, result);
      case SearchItemType.unit:
        return _unitRow(context, state, index, result);
      case SearchItemType.card:
        return _cultureRow(context, state, index, result);
    }
  } on Object catch (error, stack) {
    // One row that cannot be drawn costs itself, not the results.
    state.log.error(
      describeError('Search row ${result.row.key} failed', error, stack),
    );
    return null;
  }
}

String _languageName(AppState state, String code) =>
    state.languageByCode(code)?.name ?? code;

Widget _situationRow(
  BuildContext context,
  AppState state,
  ItemSearchIndex index,
  ItemResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final sheet = index.situationOf(result.row);
  if (sheet == null) return const SizedBox.shrink();
  final language = index.language;
  return ResultRow(
    icon: Icons.place_outlined,
    title: sheet.titleFor(spokenFor(context, state)),
    lines: <Widget>[RowLine(l10n.searchPhraseCount(sheet.cardIds.length))],
    tags: <Widget>[
      ResultTag(text: l10n.searchTagSituation, style: ResultTagStyle.kind),
      LevelTag(level: result.row.level, above: result.aboveLevel),
    ],
    dim: result.aboveLevel,
    onTap: result.aboveLevel
        ? () => showAboveLevelSheet(
            context,
            name: sheet.titleFor(spokenFor(context, state)),
            level: result.row.level,
          )
        : () => Navigator.of(context).pushNamed(
            AppRoutes.situation,
            arguments: SituationRequest(
              language: language,
              situationId: sheet.id,
            ),
          ),
  );
}

Widget _topicRow(
  BuildContext context,
  AppState state,
  ItemSearchIndex index,
  ItemResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final language = index.language;
  final topics = state.topicsOf(language);
  final resolved = topics.byId(result.row.id);
  final topic = resolved?.topic ?? index.source.topics?.byId(result.row.id);
  if (topic == null) return const SizedBox.shrink();
  final spoken = spokenFor(context, state);
  var cards = 0;
  var known = 0;
  if (resolved != null) {
    final every = topicDrillCards(resolved, topics.world, Level.c2);
    final answers = state.recentAnswers;
    cards = every.length;
    known = every
        .where((id) => answers.of(id).level == MasteryLevel.known)
        .length;
  }
  final percent = cards == 0 ? 0 : (known * 100 / cards).round();
  final title = topic.term == null
      ? topic.nameFor(spoken)
      : '${topic.nameFor(spoken)} (${topic.term!.text})';
  return ResultRow(
    icon: Icons.sell_outlined,
    title: title,
    dim: result.aboveLevel,
    lines: <Widget>[
      RowLine(
        l10n.searchTopicSummary(
          _languageName(state, language),
          l10n.commonCardCount(cards),
          l10n.searchUnitsCount(resolved?.units.length ?? 0),
          l10n.searchDecksCount(resolved?.decks.length ?? 0),
        ),
      ),
      if (cards > 0) ...<Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2),
          child: Semantics(
            label: l10n.searchTopicKnownLabel(percent),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: known / cards,
                minHeight: 6,
              ),
            ),
          ),
        ),
        RowLine(l10n.searchTopicKnown(percent)),
      ],
    ],
    tags: <Widget>[LevelTag(level: topic.level, above: result.aboveLevel)],
    trailing: const Icon(Icons.chevron_right),
    onTap: () => AppNavigator.openTopic(context, language, topic.id),
  );
}

Widget _conceptRow(
  BuildContext context,
  AppState state,
  ItemSearchIndex index,
  ItemResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final id = index.conceptIdOf(result.row);
  final at = index.conceptUnit(id);
  final view = at < 0 ? null : pathUnitView(state, index.language, at);
  final open = view?.openDeckId;
  return ResultRow(
    leadingText: 'Aa',
    title: index.conceptName(id),
    tags: <Widget>[
      ResultTag(text: l10n.searchTagGrammar, style: ResultTagStyle.kind),
      LevelTag(level: view?.level),
    ],
    onTap: open == null ? null : () => AppNavigator.openUnit(context, open),
  );
}

Widget _unitRow(
  BuildContext context,
  AppState state,
  ItemSearchIndex index,
  ItemResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final unit = index.unitOf(result.row);
  if (unit == null) return const SizedBox.shrink();
  final view = pathUnitView(state, index.language, unit.$1);
  if (view == null) return const SizedBox.shrink();
  final title = l10n.searchUnitTitle(view.number, view.title);
  final open = view.openDeckId;
  return ResultRow(
    icon: Icons.flag_outlined,
    title: title,
    dim: result.aboveLevel,
    lines: <Widget>[
      RowLine(l10n.searchUnitPath(l10n.searchDecksCount(view.decks))),
    ],
    tags: <Widget>[LevelTag(level: view.level, above: result.aboveLevel)],
    onTap: result.aboveLevel
        ? () => showAboveLevelSheet(context, name: title, level: view.level)
        : open == null
        ? null
        : () => AppNavigator.openUnit(context, open),
  );
}

Widget _cultureRow(
  BuildContext context,
  AppState state,
  ItemSearchIndex index,
  ItemResult result,
) {
  final card = index.cardOf(result.row.id);
  final entry = index.deckOfCard(result.row.id);
  if (card == null || entry == null) return const SizedBox.shrink();
  final language = state.languageByCode(index.language) ?? entry.language;
  final sections = state.catalogWithAboveLevel.sections;
  final kind = sections.searchKind(result.row.kind);
  final kindName = kind == null
      ? result.row.kind
      : nameIn(kind.names, spokenFor(context, state));
  return ResultRow(
    title: card.target,
    titleWidget: TargetText(
      card.target,
      language: language,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      textAlign: TextAlign.start,
      card: card,
    ),
    lines: <Widget>[
      if (card.reading != null) RowLine(card.reading!),
      Text(card.native, style: Theme.of(context).textTheme.bodyMedium),
      RowLine(entry.deck.name),
    ],
    tags: <Widget>[
      ResultTag(text: kindName, style: ResultTagStyle.kind),
      LevelTag(level: card.level ?? entry.deck.level),
    ],
    onTap: () => showWordSheet(context, card: card, language: language),
  );
}

/// A deck found: an ordinary deck, a genre deck, or a professional situation,
/// which only search shows and which "Add to my courses" downloads.
class _DeckResultRow extends StatefulWidget {
  const _DeckResultRow({required this.index, required this.result});

  final ItemSearchIndex index;
  final ItemResult result;

  @override
  State<_DeckResultRow> createState() => _DeckResultRowState();
}

class _DeckResultRowState extends State<_DeckResultRow> {
  bool _adding = false;

  Future<void> _add(AppState state, String deckKey) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final downloads = state.deckDownloads;
    setState(() => _adding = true);
    try {
      final failure = downloads == null
          ? DeckDownloadFailure.offline
          : await downloads.fetchHidden(
              widget.index.language,
              deckKey,
              state.settings.spokenLanguages,
            );
      if (failure != null) {
        state.log.warning('Hidden deck $deckKey was not added: $failure');
        messenger?.showSnackBar(
          SnackBar(content: Text(downloadFailureText(l10n, failure))),
        );
      }
    } on Object catch (error, stack) {
      state.log.error('Adding $deckKey from search failed: $error\n$stack');
      messenger?.showSnackBar(
        SnackBar(content: Text(downloadFailureText(l10n, null))),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final index = widget.index;
    final result = widget.result;
    final row = result.row;
    final entry = index.deckEntry(row.id);
    final shelf = index.shelfOf(row.id);
    final sections = state.catalogWithAboveLevel.sections;
    final spoken = spokenFor(context, state);
    final professional = entry?.deck.professional ?? shelf?.professional;
    final genre = sections.genre(entry?.deck.genre ?? shelf?.genre);
    final title = entry?.deck.name ?? shelf?.title ?? row.id;
    final cards = entry?.itemCount ?? shelf?.cards ?? 0;
    final added = entry != null && entry.deck.hidden;
    final above = result.aboveLevel;
    final level = row.level;
    final languageName = _languageName(state, index.language);
    final snippet = result.snippetCard == null
        ? null
        : index.cardOf(result.snippetCard!);
    // Nothing of an item above the learner's level shows its card text.
    final snippetLine = (above || snippet == null)
        ? null
        : '${snippet.target} · ${snippet.native}';
    final isScene = professional != null || row.kind == ResultKind.situations;
    if (isScene) {
      final professionName = professional == null
          ? null
          : (sections.profession(professional) == null
                ? professional
                : nameIn(sections.profession(professional)!.names, spoken));
      final deckKey = shelf?.deckKey;
      return ResultRow(
        icon: Icons.work_outline,
        iconBackground: amberOf(context),
        iconColor: onAmberOf(context),
        title: title,
        dim: above,
        lines: <Widget>[
          if (professionName != null || cards > 0)
            RowLine(
              professionName != null && cards > 0
                  ? l10n.searchSituationProfession(
                      professionName,
                      l10n.searchPhraseCount(cards),
                    )
                  : professionName ?? l10n.searchPhraseCount(cards),
            ),
          if (snippetLine != null) RowLine(snippetLine),
        ],
        tags: <Widget>[
          ResultTag(
            text: professionName == null
                ? l10n.searchTagProfessionalPlain
                : l10n.searchTagProfessional(professionName),
            style: ResultTagStyle.professional,
          ),
          LevelTag(level: level, above: above),
        ],
        onTap: added && !above
            ? () => AppNavigator.openDeck(context, row.id)
            : above
            ? () => showAboveLevelSheet(context, name: title, level: level)
            : null,
        actions: above
            ? null
            : added
            ? Row(
                children: <Widget>[
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.searchAddedToCourses,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => AppNavigator.openDeck(context, row.id),
                    child: Text(l10n.searchOpenDeck),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _adding || deckKey == null
                        ? null
                        : () => _add(state, deckKey),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _adding ? l10n.searchAdding : l10n.searchAddToCourses,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RowLine(l10n.searchProfessionalNote),
                ],
              ),
      );
    }
    final startable = !above && entry != null && state.deckById(row.id) != null;
    return ResultRow(
      icon: Icons.style_outlined,
      title: title,
      dim: above,
      lines: <Widget>[
        RowLine(
          l10n.searchDeckSummary(languageName, l10n.commonCardCount(cards)),
        ),
        if (snippetLine != null) RowLine(snippetLine),
      ],
      tags: <Widget>[
        if (genre != null)
          ResultTag(
            text: nameIn(genre.names, spoken),
            style: ResultTagStyle.kind,
          )
        else if (entry != null)
          ResultTag(
            text: deckKindLabel(l10n, entry),
            style: ResultTagStyle.kind,
          ),
        LevelTag(level: level, above: above),
      ],
      onTap: above
          ? () => showAboveLevelSheet(context, name: title, level: level)
          : startable || added
          ? () => AppNavigator.openDeck(context, row.id)
          : null,
    );
  }
}
