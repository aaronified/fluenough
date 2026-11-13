import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/item_search.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/situations.dart';
import '../../app/topics.dart';
import '../../app/unlocks.dart';
import '../../core/decks/topic_resolver.dart';
import '../../core/models/deck.dart' show LanguageInfo;
import '../../core/models/level.dart';
import '../../core/models/topic.dart';
import '../../core/progress/recent_answers.dart'
    show MasteryLevel, RecentAnswers;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import '../decks/unit_labels.dart';
import '../decks/unit_page.dart' show CardRow;
import '../decks/word_sheet.dart';
import '../situations/situation_page.dart' show SituationRequest;
import 'topic_drill_sheet.dart';

/// What opens a topic's page: the topic's id and its language's code.
class TopicRequest {
  const TopicRequest({required this.language, required this.topicId});

  final String language;
  final String topicId;
}

/// How many cards a topic page lists before "Show all".
const int topicFirstCards = 8;

/// A topic's page (the approved mockup `topic-page.html`, default variant: one
/// scroll, a sticky drill button with "Choose…", an above-level topic shown
/// and its drill limited): its name, language and level, how much of it the
/// learner knows, its units, decks and cards each with their level and
/// mastery, and "Drill this topic", a session over the topic's cards alone.
/// A script topic lists its characters.
///
/// Level rule (deck-kinds plan, D2): a card above the learner's level is
/// never listed with its text nor drilled; the page counts them and says so.
class TopicPage extends StatefulWidget {
  const TopicPage({super.key, required this.request});

  final TopicRequest request;

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  bool _allCards = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final request = widget.request;
    final topics = state.topicsOf(request.language);
    final resolved = topics.byId(request.topicId);
    if (resolved == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: state.status == CatalogStatus.loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoadingDecks,
                ),
              )
            : EmptyState(icon: Icons.sell_outlined, title: l10n.topicNotFound),
      );
    }
    final info = _languageInfo(state, request.language);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) => _build(context, state, topics, resolved, info),
    );
  }

  static LanguageInfo? _languageInfo(AppState state, String code) {
    final found = state.languageByCode(code);
    if (found != null) return found;
    for (final language in state.languages) {
      if (language.code == code) return language;
    }
    return null;
  }

  List<String> _spoken(BuildContext context, AppState state) => <String>[
    Localizations.localeOf(context).languageCode,
    ...state.settings.spokenLanguages,
  ];

  Widget _build(
    BuildContext context,
    AppState state,
    Topics topics,
    ResolvedTopic resolved,
    LanguageInfo? info,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.request.language;
    final topic = resolved.topic;
    final spoken = _spoken(context, state);
    final name = topic.nameFor(spoken);
    final learner = state.levelIn(language);
    final above = LevelGate.isAbove(topic.level, learner);
    final answers = state.recentAnswers;
    // Every card the topic names that the language has, whatever its level
    // (every level is open to a c2 learner), and those the learner may have.
    final every = topicDrillCards(resolved, topics.world, Level.c2);
    final allowed = topics.drillCards(topic.id, learner);
    final cards = state.sheetCards(language, allowed);
    final known = every
        .where((id) => answers.of(id).level == MasteryLevel.known)
        .length;
    final aboveCards = every.length - allowed.length;
    final fresh = cards.any((c) => c.isNew);
    final ids = <String>{for (final c in cards) c.card.id};
    final drillable = ids.isEmpty
        ? 0
        : _drillCount(state, language, ids, fresh);
    final languageName = info?.name ?? language;
    final kind = switch (topic.kind) {
      TopicKind.grammar => l10n.topicKindGrammar,
      TopicKind.verbs => l10n.topicKindVerbs,
      TopicKind.words => l10n.topicKindWords,
      TopicKind.script => l10n.topicKindScript,
      TopicKind.register => l10n.topicKindRegister,
      TopicKind.profession => l10n.topicKindProfession,
      TopicKind.other => l10n.topicKindOther,
    };
    final summary = topic.summaryFor(spoken);
    final shown = _allCards ? cards : cards.take(topicFirstCards).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: theme.textTheme.titleMedium),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          0,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.topicSubtitle(languageName, kind),
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  header: true,
                  child: Text(name, style: theme.textTheme.headlineMedium),
                ),
                if (topic.term != null) ...<Widget>[
                  const SizedBox(height: 6),
                  if (info == null)
                    Text(topic.term!.text, style: theme.textTheme.titleLarge)
                  else
                    TargetText(
                      topic.term!.text,
                      language: info,
                      fontSize: 20,
                      textAlign: TextAlign.start,
                    ),
                  if (topic.term!.reading != null)
                    Text(
                      topic.term!.reading!,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    LevelTag(level: topic.level, above: above),
                    ResultTag(
                      text: l10n.commonCardCount(every.length),
                      style: ResultTagStyle.kind,
                    ),
                    ResultTag(
                      text: l10n.searchUnitsCount(resolved.units.length),
                      style: ResultTagStyle.kind,
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(summary, style: theme.textTheme.bodyLarge),
                ],
                if (every.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Semantics(
                    label: l10n.topicKnownBarLabel(known, every.length),
                    excludeSemantics: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.mark),
                      child: LinearProgressIndicator(
                        value: known / every.length,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.topicKnownOf(known, every.length),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (above) ...<Widget>[
            const SizedBox(height: 12),
            _Notice(
              title: l10n.topicAboveTitle,
              body: learner == null || allowed.isEmpty
                  ? l10n.topicAboveBodyNoLevel(topic.level!.label)
                  : l10n.topicAboveBody(
                      topic.level!.label,
                      learner.label,
                      allowed.length,
                    ),
            ),
          ],
          ..._units(context, state, resolved, learner),
          ..._decks(context, state, resolved, learner, every),
          ..._cards(
            context,
            state,
            info,
            shown: shown,
            total: cards.length,
            aboveCards: aboveCards,
            answers: answers,
          ),
          if (topic.chars.isNotEmpty) ..._characters(context, topic, info),
          ..._concepts(context, resolved),
          ..._situations(context, state, resolved),
          ..._related(context, state, topics, resolved, spoken),
        ],
      ),
      bottomNavigationBar: BottomActions(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: drillable == 0
                  ? null
                  : () => AppNavigator.startDrill(
                      context,
                      DrillRequest.sheet(
                        ids,
                        language: language,
                        revise: !fresh,
                      ),
                    ),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                above && allowed.isNotEmpty
                    ? l10n.topicDrillCountLimited(allowed.length)
                    : l10n.topicDrillCount(drillable),
                textAlign: TextAlign.center,
              ),
            ),
            if (drillable == 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(
                  l10n.topicNothingToDrill,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => _choose(
                  context,
                  name: name,
                  language: language,
                  ids: ids,
                  revise: !fresh,
                ),
                child: Text(l10n.topicChoose),
              ),
          ],
        ),
      ),
    );
  }

  /// How many distinct cards the drill would use right now.
  int _drillCount(
    AppState state,
    String language,
    Set<String> ids,
    bool fresh,
  ) {
    try {
      final items = state.sheetSession(
        DrillRequest.sheet(ids, language: language, revise: !fresh),
      );
      return <String>{for (final item in items) item.card.id}.length;
    } on Object catch (error) {
      state.log.warning('A topic drill could not be counted: $error');
      return ids.length;
    }
  }

  Future<void> _choose(
    BuildContext context, {
    required String name,
    required String language,
    required Set<String> ids,
    required bool revise,
  }) async {
    final request = await showTopicDrillSheet(
      context,
      topicName: name,
      language: language,
      cardIds: ids,
      revise: revise,
    );
    if (request != null && context.mounted) {
      await AppNavigator.startDrill(context, request);
    }
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 24, 8, 10),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );

  List<Widget> _units(
    BuildContext context,
    AppState state,
    ResolvedTopic resolved,
    Level? learner,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final language = widget.request.language;
    final views = <PathUnitView>[
      for (final i in resolved.units) ?pathUnitView(state, language, i),
    ];
    if (views.isEmpty) return const <Widget>[];
    return <Widget>[
      _heading(context, l10n.topicUnits),
      GroupedList(
        outerRadius: AppRadii.card,
        gap: 4,
        children: <Widget>[
          for (final view in views)
            _unitRow(context, view, LevelGate.isAbove(view.level, learner)),
        ],
      ),
    ];
  }

  Widget _unitRow(BuildContext context, PathUnitView view, bool above) {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.searchUnitTitle(view.number, view.title);
    return ResultRow(
      icon: Icons.flag_outlined,
      title: title,
      dim: above,
      tags: <Widget>[LevelTag(level: view.level, above: above)],
      onTap: above
          ? () => showAboveLevelSheet(context, name: title, level: view.level)
          : view.openDeckId == null
          ? null
          : () => AppNavigator.openUnit(context, view.openDeckId!),
    );
  }

  List<Widget> _decks(
    BuildContext context,
    AppState state,
    ResolvedTopic resolved,
    Level? learner,
    List<String> every,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final language = widget.request.language;
    final native = state.courseNative(language);
    final catalog = state.catalogWithAboveLevel;
    final rows = <Widget>[];
    for (final core in resolved.decks) {
      DeckEntry? entry;
      for (final candidate in <DeckEntry>[
        ...catalog.decks,
        ...catalog.hidden,
      ]) {
        if (candidate.language.code == language &&
            (native == null || candidate.deck.native.code == native) &&
            coreIdOfDeck(candidate) == core) {
          entry = candidate;
          break;
        }
      }
      // A hidden deck the learner has not added is never listed (it only
      // counts and drills through [resolved]).
      if (entry == null) continue;
      final inDeck = <String>{for (final c in entry.cards) c.id};
      final topicCards = every.where(inDeck.contains).length;
      final deckAbove = LevelGate.isAbove(entry.deck.level, learner);
      final startable = !deckAbove && state.deckById(entry.id) != null;
      final deck = entry;
      rows.add(
        ResultRow(
          icon: Icons.style_outlined,
          title: entry.deck.name,
          dim: deckAbove,
          lines: <Widget>[
            RowLine(l10n.topicDeckCards(topicCards, entry.itemCount)),
          ],
          tags: <Widget>[LevelTag(level: entry.deck.level, above: deckAbove)],
          onTap: deckAbove
              ? () => showAboveLevelSheet(
                  context,
                  name: deck.deck.name,
                  level: deck.deck.level,
                )
              : startable
              ? () => AppNavigator.openDeck(context, deck.id)
              : null,
        ),
      );
    }
    if (rows.isEmpty) return const <Widget>[];
    return <Widget>[
      _heading(context, l10n.topicDecks),
      GroupedList(outerRadius: AppRadii.card, gap: 4, children: rows),
    ];
  }

  List<Widget> _cards(
    BuildContext context,
    AppState state,
    LanguageInfo? info, {
    required List<SheetCard> shown,
    required int total,
    required int aboveCards,
    required RecentAnswers answers,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if ((total == 0 && aboveCards == 0) || info == null) {
      return const <Widget>[];
    }
    return <Widget>[
      _heading(context, l10n.topicCardsHeading(shown.length, total)),
      if (shown.isNotEmpty)
        GroupedList(
          outerRadius: AppRadii.card,
          gap: 4,
          children: <Widget>[
            for (final sheet in shown)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CardRow(
                    card: sheet.card,
                    language: sheet.deck.language,
                    mastery: answers.of(sheet.card.id),
                    onTap: () => showWordSheet(
                      context,
                      card: sheet.card,
                      language: sheet.deck.language,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LevelTag(
                        level: sheet.card.level ?? sheet.deck.deck.level,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      if (total == 0)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Text(l10n.topicNoCards, style: theme.textTheme.bodyMedium),
        ),
      if (total > topicFirstCards)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            style: AppButtonStyles.inline(context),
            onPressed: () => setState(() => _allCards = !_allCards),
            child: Text(
              _allCards ? l10n.topicShowFewer : l10n.topicShowAll(total),
            ),
          ),
        ),
      if (aboveCards > 0)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.topicCardsAbove(aboveCards),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _characters(
    BuildContext context,
    Topic topic,
    LanguageInfo? info,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return <Widget>[
      _heading(context, l10n.topicCharacters),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final char in topic.chars)
              Semantics(
                label: char.reading == null
                    ? char.text
                    : '${char.text}, ${char.reading}',
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 72,
                    minHeight: 72,
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      info == null
                          ? Text(char.text, style: theme.textTheme.titleLarge)
                          : TargetText(char.text, language: info, fontSize: 26),
                      if (char.reading != null)
                        Text(
                          char.reading!,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _concepts(BuildContext context, ResolvedTopic resolved) {
    if (resolved.concepts.isEmpty) return const <Widget>[];
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final index = state.itemSearchFor(widget.request.language);
    return <Widget>[
      _heading(context, l10n.topicConcepts),
      GroupedList(
        outerRadius: AppRadii.card,
        gap: 4,
        children: <Widget>[
          for (final id in resolved.concepts)
            ResultRow(
              leadingText: 'Aa',
              title: index.conceptName(id),
              tags: <Widget>[
                ResultTag(
                  text: l10n.searchTagGrammar,
                  style: ResultTagStyle.kind,
                ),
              ],
            ),
        ],
      ),
    ];
  }

  List<Widget> _situations(
    BuildContext context,
    AppState state,
    ResolvedTopic resolved,
  ) {
    if (resolved.situations.isEmpty) return const <Widget>[];
    final l10n = AppLocalizations.of(context)!;
    final language = widget.request.language;
    final file = state.situationsOf(language);
    final spoken = _spoken(context, state);
    return <Widget>[
      _heading(context, l10n.topicSituations),
      GroupedList(
        outerRadius: AppRadii.card,
        gap: 4,
        children: <Widget>[
          for (final id in resolved.situations)
            if (file?.byId(id) case final sheet?)
              ResultRow(
                icon: Icons.place_outlined,
                title: sheet.titleFor(spoken),
                lines: <Widget>[
                  RowLine(l10n.searchPhraseCount(sheet.cardIds.length)),
                ],
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.situation,
                  arguments: SituationRequest(
                    language: language,
                    situationId: id,
                  ),
                ),
              ),
        ],
      ),
    ];
  }

  List<Widget> _related(
    BuildContext context,
    AppState state,
    Topics topics,
    ResolvedTopic resolved,
    List<String> spoken,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final language = widget.request.language;
    final learner = state.levelIn(language);
    final rows = <Widget>[];
    for (final id in resolved.related) {
      final other = topics.byId(id);
      if (other == null) continue;
      final above = LevelGate.isAbove(other.topic.level, learner);
      if (above && state.settings.hideAboveLevel) continue;
      rows.add(
        ResultRow(
          icon: Icons.sell_outlined,
          title: other.topic.nameFor(spoken),
          dim: above,
          tags: <Widget>[LevelTag(level: other.topic.level, above: above)],
          onTap: () => AppNavigator.openTopic(context, language, id),
        ),
      );
    }
    if (rows.isEmpty) return const <Widget>[];
    return <Widget>[
      _heading(context, l10n.topicRelated),
      GroupedList(outerRadius: AppRadii.card, gap: 4, children: rows),
    ];
  }
}

/// The notice on an above-level topic: a lock, what it means for the learner.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline, color: amberOf(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
