import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/culture.dart';
import '../../app/routes.dart';
import '../../core/decks/weave.dart';
import '../../core/models/creator.dart';
import '../../core/models/level.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/result_marks.dart';
import 'creator_sheet.dart';
import 'culture_parts.dart';

/// The full culture deck of a course (approved mockup `culture-in-course`,
/// screen 8): every culture and proverbs item the course holds with its kind,
/// source and level, the ones above the learner's level locked ("Unlocks at
/// B1", or shown with support when Settings says so), and a People list of the
/// creators behind them, each opening their card.
///
/// Reached from an item, from the culture settings and from the recommendations
/// list; "Show culture items" off leaves it here, as it leaves search.
class CultureDeckPage extends StatelessWidget {
  const CultureDeckPage({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
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
      ]),
      builder: (context, _) => _build(context, state),
    );
  }

  /// The creators to list: those a shown item cites, and those no work cites
  /// anywhere; never one only a work out of sight cites (above the level, in a
  /// hidden deck, in a deck that does not weave, or a recommended work), whose
  /// name would give it away (the timeline's rule, from the same two sets).
  List<Creator> _people(AppState state, CreatorsFile? file, bool support) {
    if (file == null) return const <Creator>[];
    final cited = state.creatorsCitedIn(language);
    final shown = state.creatorsShownIn(language, support: support);
    return <Creator>[
      for (final c in file.creators)
        if (!cited.contains(c.id) || shown.contains(c.id)) c,
    ];
  }

  Widget _build(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = cultureLanguage(state, language);
    final learner = state.levelIn(language);
    final support = state.settings.cultureAboveSupport;
    final items = state.cultureItemsIn(language);
    final file = state.creatorsOf(language);
    final atLevel = items
        .where((i) => LevelGate.allows(i.level, learner))
        .length;
    final people = _people(state, file, support);
    final showPeople = state.settings.cultureCreators;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.cultureDeckTitle(info.name),
          style: theme.textTheme.titleMedium,
        ),
        actions: const <Widget>[ReportButton()],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.format_quote,
              title: l10n.cultureDeckEmpty,
              body: l10n.cultureDeckEmptyBody,
            )
          : ListView(
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
                  child: Text(
                    l10n.cultureDeckCount(items.length, atLevel),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GroupedList(
                  outerRadius: AppRadii.card,
                  gap: 4,
                  children: <Widget>[
                    for (final item in items)
                      _ItemRow(
                        item: item,
                        language: language,
                        above: LevelGate.isAbove(item.level, learner),
                        support: support,
                      ),
                  ],
                ),
                if (showPeople && people.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  GroupedList(
                    header: l10n.culturePeople,
                    outerRadius: AppRadii.card,
                    gap: 4,
                    children: <Widget>[
                      for (final person in people)
                        CreatorRow(language: language, creator: person),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                GroupedList(
                  outerRadius: AppRadii.card,
                  gap: 4,
                  children: <Widget>[
                    GroupedTile(
                      leading: const Icon(Icons.timeline),
                      title: l10n.cultureTimelineTitle,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          AppNavigator.openCultureTimeline(context, language),
                    ),
                    GroupedTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: l10n.recTitle,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          AppNavigator.openRecommendations(context, language),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSizes.textInset,
                  ),
                  child: Text(
                    l10n.cultureDeckSourcesNote,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// One item of the culture deck: its first line, its kind, who and when, and
/// its level; locked while above the learner, with the level it unlocks at.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.language,
    required this.above,
    required this.support,
  });

  final CultureItem item;
  final String language;
  final bool above;
  final bool support;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final info = cultureLanguage(state, language);
    final locked = above && !support;
    final source = item.source;
    final who = <String>[
      if (source?.author != null)
        source!.author!.toLowerCase() == 'anonymous'
            ? l10n.cultureNoKnownAuthor
            : source.author!,
      ?(source?.work ?? source?.collection),
      ?source?.date,
    ].join(' · ');
    return ResultRow(
      icon: locked ? Icons.lock_outline : Icons.format_quote,
      iconColor: locked ? amberOf(context) : null,
      title: locked
          ? l10n.cultureUnlocksAt(item.level.label)
          : item.target.split('\n').first,
      titleWidget: locked
          ? null
          : TargetText(
              item.target.split('\n').first,
              language: info,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              textAlign: TextAlign.start,
              card: item.card,
            ),
      dim: locked,
      lines: <Widget>[
        if (!locked)
          RowLine(
            who.isEmpty
                ? cultureKindName(l10n, item.kind)
                : l10n.cultureRowKindSource(
                    cultureKindName(l10n, item.kind),
                    who,
                  ),
          )
        else
          RowLine(cultureKindName(l10n, item.kind)),
      ],
      tags: <Widget>[LevelTag(level: item.level, above: above)],
      onTap: locked
          ? () => showAboveLevelSheet(
              context,
              name: cultureKindName(l10n, item.kind),
              level: item.level,
            )
          : () => AppNavigator.openCultureItem(context, language, item.id),
    );
  }
}
