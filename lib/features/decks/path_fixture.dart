import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/memory_progress.dart';
import '../../app/profile.dart';
import '../../core/models/drill_mode.dart';
import '../gallery/fixtures.dart';
import 'path_model.dart';

/// The design's Telugu path, for the debug gallery and the decks tests:
/// Aro learning Telugu as well, with the first units done and Family under
/// way, and the plan the design draws, which no path marks yet
/// ([CoursePlan]).
///
/// Built on the real bundled Telugu decks: no card id is invented
/// (AGENTS.md rule 1).
abstract final class PathFixtures {
  /// Aro, learning Telugu as in the design, and Hindi and Spanish.
  static const Profile aro = Profile(
    id: 'aro',
    name: 'Aro',
    languages: <String>{'te', 'hi', 'es'},
    shape: AvatarShape.cookie,
    tone: AvatarTone.primary,
  );

  /// Where A1 and A2 end on the Telugu path, and the B1 units the design
  /// draws as coming. Its titles are the design's mock, shown only in the
  /// debug gallery and tests.
  static const CoursePlan telugu = CoursePlan(
    levelEnds: <CefrLevel, String>{
      CefrLevel.a1: 'te-en-numbers-big',
      CefrLevel.a2: 'te-en-help',
    },
    coming: <ComingUnit>[
      (title: 'Health', level: CefrLevel.b1, words: 60),
      (title: 'Travel', level: CefrLevel.b1, words: 60),
      (title: 'Feelings', level: CefrLevel.b1, words: 50),
      (title: 'Opinions', level: CefrLevel.b1, words: 50),
      (title: 'Events and news', level: CefrLevel.b1, words: 60),
      (title: 'Conditionals', level: CefrLevel.b1, words: null),
      (title: 'Reported speech', level: CefrLevel.b1, words: null),
    ],
  );

  /// [telugu] for Telugu, and nothing for any other course.
  static CoursePlan planOf(String language) =>
      language == 'te' ? telugu : CoursePlan.none;

  /// The unit the design opens: Family.
  static const String familyDeck = 'te-en-family';

  /// The word the design's sheet shows: కాలం (kālam), time, which sounds
  /// almost like కలం (kalam), pen.
  static const String soundAlikeCard = 'te-0111';

  /// A state on [app]'s loaded catalog with Aro learning Telugu: every unit
  /// before [upTo] done over the past weeks, and in that unit, about two
  /// thirds of the words answered, some well and some not, three days ago,
  /// so that some are due. By default the unit up next is Family; with
  /// [upTo] past A1's end, A1 is reached.
  static AppState state(AppState app, {String upTo = familyDeck}) {
    final state = GalleryFixtures.state(
      app,
      profiles: const <Profile>[aro, GalleryFixtures.mira],
      history: false,
    );
    seed(state.progress as MemoryProgress, app, upTo: upTo);
    return state;
  }

  /// Records [app]'s Telugu history into [progress], as [state] describes.
  static void seed(
    MemoryProgress progress,
    AppState app, {
    String upTo = familyDeck,
  }) {
    final units = app.courseUnits('te', alphabet: true);
    final stop = units.indexWhere((u) => u.any((e) => e.id == upTo));
    final now = app.now();
    final days = stop <= 0 ? 1 : stop;
    void answer(DeckEntry entry, int i, DateTime at, int grade) {
      final card = entry.cards[i];
      final modes = card.modesIn(ttsAvailable: true);
      final mode = modes.contains(DrillMode.recognition)
          ? DrillMode.recognition
          : modes.first;
      progress.record(
        deckId: entry.id,
        cardId: card.id,
        mode: mode,
        grade: grade,
        now: at,
      );
    }

    // Each unit before [upTo] a day apart, ending a week ago.
    for (final (u, unit) in units.take(stop < 0 ? 0 : stop).indexed) {
      final at = now.subtract(Duration(days: 7 + 2 * (days - u)));
      for (final entry in unit) {
        for (var i = 0; i < entry.cards.length; i++) {
          answer(entry, i, at, 4);
          answer(entry, i, at.add(const Duration(days: 1)), 4);
        }
      }
    }
    if (stop < 0) return;
    // The unit up next: two thirds of its first deck's words answered three
    // days ago, every third one missed once.
    final entry = units[stop].first;
    final at = now.subtract(const Duration(days: 3));
    final count = (entry.cards.length * 2) ~/ 3;
    for (var i = 0; i < count; i++) {
      answer(entry, i, at.subtract(const Duration(days: 1)), 4);
      answer(entry, i, at, i % 3 == 2 ? 1 : 4);
    }
  }
}
