import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/item_search.dart' show coreIdOfDeck;
import '../../core/decks/levels.dart' show levelOfUnit;
import '../../core/models/level.dart';
import 'path_model.dart';

/// A unit of a language's path as a result or a topic page lists it.
class PathUnitView {
  const PathUnitView({
    required this.index,
    required this.number,
    required this.title,
    required this.level,
    required this.decks,
    this.openDeckId,
  });

  /// Its place in the language's path, from 0.
  final int index;

  /// Its number as the unit screen shows it.
  final int number;
  final String title;
  final Level? level;

  /// How many decks it lists.
  final int decks;

  /// A deck of it the learner is given, which opens its screen; null while
  /// the unit is above the learner's level or none of its decks is on the
  /// phone: it is then not startable.
  final String? openDeckId;
}

/// Unit [index] of [language]'s path, or null where the path has no such unit.
PathUnitView? pathUnitView(AppState state, String language, int index) {
  final catalog = state.catalogWithAboveLevel;
  final plan = catalog.languagePaths[language]?.plan;
  if (plan == null || index < 0 || index >= plan.length) return null;
  final unit = plan[index];
  final native = state.courseNative(language);
  final entries = <DeckEntry>[];
  for (final core in unit.decks) {
    for (final entry in catalog.decks) {
      if (entry.language.code != language ||
          (native != null && entry.deck.native.code != native) ||
          coreIdOfDeck(entry) != core) {
        continue;
      }
      entries.add(entry);
      break;
    }
  }
  String? open;
  int? number;
  var title = '';
  for (final entry in entries) {
    final loaded = state.deckById(entry.id);
    if (loaded == null) continue;
    final found = unitOfDeck(state, loaded.id);
    if (found == null) continue;
    open = loaded.id;
    number = found.number;
    title = unitTitle(state, found.decks);
    break;
  }
  if (title.isEmpty) {
    title = entries.isNotEmpty
        ? entries.first.deck.name
        : (unit.planned?.id.replaceAll('-', ' ') ?? '');
  }
  return PathUnitView(
    index: index,
    number: number ?? index + 1,
    title: title,
    level: levelOfUnit(plan, index),
    decks: unit.decks.length,
    openDeckId: open,
  );
}
