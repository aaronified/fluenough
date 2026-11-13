import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/reading.dart';
import '../core/models/recommendation.dart';
import 'app_state.dart';
import 'deck_catalog.dart';
import 'recommendation_feed.dart';

/// The questions of completed recommended works as reading items (deck-kinds
/// plan, D13, T25): once a learner marks a work completed, its authored
/// comprehension questions join their lessons and reviews as `reading`-mode
/// items, graded like a reading deck's and scheduled under the question's own
/// permanent id (`<recommendation id>#<question id>`). Un-marking stops them:
/// the work's questions are in no deck any more, and their history stays.
///
/// The questions live in one reading deck per language that is made here, not
/// in any file: `<language>-<native>-works`, hidden from every list a learner
/// is given. [AppState.deckById], [AppState.deckOf] and [AppState.drillDecks]
/// know it, so a session, a review and the drill find it as they find any
/// deck, and the work's title is the passage its questions are about.
extension RecommendationQuestions on AppState {
  /// The id of the questions deck of [language] taught from [native].
  static String worksDeckId(String language, String native) =>
      '$language-$native-works';

  /// The works of [language] the learner marked completed that they are still
  /// offered (their level and the books rule hold) and that have questions,
  /// in the file's order.
  List<Recommendation> completedWorksOf(String language) => <Recommendation>[
    for (final work in recommendationsFor(language))
      if (recommendationProgress.isCompleted(work.id) &&
          work.questions.isNotEmpty)
        work,
  ];

  /// The deck of the open questions of [language]'s completed works, or null
  /// when there are none or no deck teaches the language.
  DeckEntry? worksDeckOf(String language) =>
      worksDecks.where((e) => e.language.code == language).firstOrNull;

  /// Every language's questions deck: one for each language with a completed
  /// work whose questions are open.
  List<DeckEntry> get worksDecks =>
      derived<List<DeckEntry>>('worksDecks', _buildWorksDecks);

  /// The questions deck with [id], or null.
  DeckEntry? worksDeckById(String id) {
    if (!id.endsWith('-works')) return null;
    for (final entry in worksDecks) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// The questions of [language]'s completed works as cards, in the order of
  /// the works, for a lesson to take after the path's own cards.
  List<Card> workQuestionCards(String language) =>
      worksDeckOf(language)?.cards ?? const <Card>[];

  List<DeckEntry> _buildWorksDecks() {
    final entries = <DeckEntry>[];
    try {
      final done = recommendationProgress.completedIds;
      if (done.isEmpty) return entries;
      final languages = <String>{
        for (final work in recommendationProgress.completed) work.language,
      };
      for (final code in languages) {
        try {
          final entry = _worksDeck(code);
          if (entry != null) entries.add(entry);
        } on Object catch (error, stack) {
          log.error(
            'Questions of the completed works in $code could not be built: '
            '$error\n$stack',
          );
        }
      }
    } on Object catch (error, stack) {
      log.error('Questions of completed works failed: $error\n$stack');
    }
    return entries;
  }

  DeckEntry? _worksDeck(String code) {
    final works = completedWorksOf(code);
    if (works.isEmpty) return null;
    final taught = <DeckEntry>[
      for (final entry in decks)
        if (entry.language.code == code) entry,
    ];
    if (taught.isEmpty) return null;
    final native = courseNative(code);
    final course =
        taught.where((e) => e.deck.native.code == native).firstOrNull ??
        taught.first;
    final language = course.language;
    final nativeInfo = course.deck.native;
    final id = worksDeckId(code, nativeInfo.code);
    final passages = <Passage>[];
    final cards = <Card>[];
    for (final work in works) {
      final questions = <ReadingQuestion>[
        for (final q in work.questions)
          ReadingQuestion(
            id: work.questionKey(q),
            prompt: q.prompt,
            options: q.options,
            answer: q.answer,
          ),
      ];
      final passage = Passage(
        id: work.id,
        title: work.title,
        sentences: <PassageSentence>[
          PassageSentence(
            text: work.title,
            reading: work.titleReading,
            ipa: work.titleIpa,
          ),
        ],
        questions: questions,
        level: work.level,
        creators: work.creators,
      );
      passages.add(passage);
      for (final q in questions) {
        cards.add(QuestionCard(deckId: id, passage: passage, question: q));
      }
    }
    if (cards.isEmpty) return null;
    final deck = Deck(
      id: id,
      // Shown in the drill's frame: the language's own name for what it is.
      name: language.name,
      kind: DeckKind.reading,
      language: language,
      native: nativeInfo,
      license: 'CC-BY-SA-4.0',
      cards: cards,
      passages: passages,
      hidden: true,
    );
    return DeckEntry(path: 'works/$id', deck: deck);
  }
}
