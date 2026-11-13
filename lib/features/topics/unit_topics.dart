import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/item_search.dart' show coreIdOfDeck;
import '../../app/routes.dart';
import '../../app/topics.dart';
import '../../core/decks/topic_resolver.dart';
import '../../core/models/level.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// At most this many topics a unit lists as chips (the approved mockup's
/// proposal).
const int maxUnitTopics = 4;

/// The topics a unit teaches or revisits, at most [maxUnitTopics]: those that
/// name one of its decks, its place on the path, or a card of its decks. A
/// topic above the learner's level is left out when "Hide what is above my
/// level" is on, and is listed marked otherwise.
List<ResolvedTopic> topicsOfUnit(
  AppState state,
  String language,
  List<DeckEntry> unitDecks,
) {
  final topics = state.topicsOf(language);
  if (topics.resolved.isEmpty || unitDecks.isEmpty) {
    return const <ResolvedTopic>[];
  }
  final cores = <String>{for (final entry in unitDecks) ?coreIdOfDeck(entry)};
  final cards = <String>{
    for (final entry in unitDecks)
      for (final card in entry.cards) card.id,
  };
  var place = -1;
  for (final core in cores) {
    place = topics.world.unitIndex(core);
    if (place >= 0) break;
  }
  final learner = state.levelIn(language);
  final hide = state.settings.hideAboveLevel;
  final found = <ResolvedTopic>[];
  for (final r in topics.resolved) {
    final named =
        r.decks.any(cores.contains) ||
        (place >= 0 && r.units.contains(place)) ||
        r.cards.any(cards.contains);
    if (!named) continue;
    if (hide && LevelGate.isAbove(r.topic.level, learner)) continue;
    found.add(r);
    if (found.length == maxUnitTopics) break;
  }
  return found;
}

/// "Topics in this unit": a chip for each, which opens its topic page
/// (approved mockup `topic-page.html`, screen 4). Nothing for a unit with none.
class UnitTopicChips extends StatelessWidget {
  const UnitTopicChips({
    super.key,
    required this.language,
    required this.decks,
  });

  final String language;
  final List<DeckEntry> decks;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    List<ResolvedTopic> found;
    try {
      found = topicsOfUnit(state, language, decks);
    } on Object catch (error) {
      state.log.warning('Topics of a unit could not be listed: $error');
      return const SizedBox.shrink();
    }
    if (found.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learner = state.levelIn(language);
    final spoken = <String>[
      Localizations.localeOf(context).languageCode,
      ...state.settings.spokenLanguages,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.topicOnUnit,
                style: theme.textTheme.titleSmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
              runSpacing: 4,
              children: <Widget>[
                for (final r in found)
                  ActionChip(
                    avatar: LevelGate.isAbove(r.topic.level, learner)
                        ? Icon(
                            Icons.lock_outline,
                            size: 18,
                            semanticLabel: l10n.topicAboveYourLevelCue,
                          )
                        : const Icon(Icons.sell_outlined, size: 18),
                    label: Text(r.topic.nameFor(spoken)),
                    onPressed: () =>
                        AppNavigator.openTopic(context, language, r.topic.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
