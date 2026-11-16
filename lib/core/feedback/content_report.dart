import '../models/deck.dart';
import 'report.dart';

/// What a content report is about.
enum ContentSubject {
  /// A card, from a drill, a walkthrough or a word sheet.
  card('Card'),

  /// A deck, from its page.
  deck('Deck'),

  /// A unit, from its page.
  unit('Unit'),

  /// A topic, from its page.
  topic('Topic'),

  /// A culture item, from its page.
  item('Item');

  const ContentSubject(this.label);

  /// The name of the id's line in the report, English whatever the app's
  /// language: the issue's reader needs it, not the learner.
  final String label;
}

/// What a content report names: the thing that is wrong, and where it
/// sits, so that the report needs no screenshot and no device details.
class ContentTarget {
  const ContentTarget({
    required this.subject,
    required this.id,
    this.deckId,
    this.pair,
    this.listsOptions = false,
  });

  /// A card, with the deck it was asked from, whose [Deck.language] and
  /// [Deck.native] are the language pair.
  factory ContentTarget.card(
    String id, {
    Deck? deck,
    bool listsOptions = false,
  }) => ContentTarget(
    subject: ContentSubject.card,
    id: id,
    deckId: deck?.id,
    pair: deck == null
        ? null
        : languagePair(deck.language.code, deck.native.code),
    listsOptions: listsOptions,
  );

  /// The deck [deck], on its own page.
  factory ContentTarget.deck(Deck deck) => ContentTarget(
    subject: ContentSubject.deck,
    id: deck.id,
    deckId: deck.id,
    pair: languagePair(deck.language.code, deck.native.code),
  );

  /// The unit made of the decks [id] names, taught as [deck] is.
  factory ContentTarget.unit(String id, Deck deck) => ContentTarget(
    subject: ContentSubject.unit,
    id: id,
    pair: languagePair(deck.language.code, deck.native.code),
  );

  final ContentSubject subject;

  /// The card's, deck's, unit's, topic's or item's id.
  final String id;

  /// The deck a card was asked from.
  final String? deckId;

  /// The language learned and the one it is taught from, [languagePair].
  final String? pair;

  /// Whether the screen lists options to choose from, so that "No correct
  /// option is listed" and "More than one option is correct" make sense.
  final bool listsOptions;

  /// This target, asked with or without options to choose from.
  ContentTarget withOptions(bool value) => ContentTarget(
    subject: subject,
    id: id,
    deckId: deckId,
    pair: pair,
    listsOptions: value,
  );

  @override
  bool operator ==(Object other) =>
      other is ContentTarget &&
      other.subject == subject &&
      other.id == id &&
      other.deckId == deckId &&
      other.pair == pair &&
      other.listsOptions == listsOptions;

  @override
  int get hashCode => Object.hash(subject, id, deckId, pair, listsOptions);

  /// What the report carries by itself, in order: the id, the deck, the
  /// language pair and the app's [version]. Never a screen, a screenshot
  /// or the device.
  Map<String, String> context(String version) => <String, String>{
    subject.label: id,
    if (deckId != null && subject == ContentSubject.card) 'Deck': deckId!,
    'Languages': ?pair,
    'App': version,
  };
}

/// `te from en`: the language learned, then the one it is taught from.
String languagePair(String language, String? native) =>
    '$language from ${native ?? '?'}';

/// One thing that can be wrong. [title] is English: it ends the mail's
/// subject, which the Action reads.
enum ContentReason {
  translationWrong('The translation is wrong'),
  noCorrectOption('No correct option is listed'),
  moreThanOneCorrect('More than one option is correct'),
  readingWrong('The reading or IPA is wrong'),
  audioWrong('The audio is wrong or missing'),
  pictureWrong('The picture is wrong'),
  exampleWrong('The example sentence is wrong'),
  offensive('Offensive or inappropriate'),
  somethingElse('Something else');

  const ContentReason(this.title);

  final String title;
}

/// The five rows of the report sheet.
enum ContentCategory {
  wrongOptions('Wrong options'),
  readingOrSound('Reading or sound'),
  pictureOrExample('Picture or example'),
  offensive('Offensive or inappropriate'),
  somethingElse('Something else');

  const ContentCategory(this.title);

  final String title;

  /// What can be wrong under this row for [target]. Wrong options is the one
  /// that depends on the screen: a drill that lists options has three,
  /// every other screen only the translation.
  List<ContentReason> reasons(ContentTarget target) => switch (this) {
    wrongOptions =>
      target.listsOptions
          ? const <ContentReason>[
              ContentReason.translationWrong,
              ContentReason.noCorrectOption,
              ContentReason.moreThanOneCorrect,
            ]
          : const <ContentReason>[ContentReason.translationWrong],
    readingOrSound => const <ContentReason>[
      ContentReason.readingWrong,
      ContentReason.audioWrong,
    ],
    pictureOrExample => const <ContentReason>[
      ContentReason.pictureWrong,
      ContentReason.exampleWrong,
    ],
    offensive => const <ContentReason>[ContentReason.offensive],
    somethingElse => const <ContentReason>[ContentReason.somethingElse],
  };

  /// Whether the row opens a popup to say exactly what is wrong. A row with
  /// one reason is the answer itself.
  bool hasPopup(ContentTarget target) => reasons(target).length > 1;

  /// The row's reason when it has just one.
  ContentReason only(ContentTarget target) => reasons(target).first;
}

/// The longest note, one line.
const int contentNoteLength = 140;

/// The report for [reason], picked under [category]: the mail's title is
/// `Content: Wrong options: No correct option is listed`, the note is the
/// details, and the context is [target]'s ids, the language pair and the
/// [version]. A row with no popup is titled by its reason alone.
Report contentReport({
  required ContentTarget target,
  required ContentCategory category,
  required ContentReason reason,
  required String note,
  required String version,
}) => Report(
  kind: ReportKind.content,
  title: category.hasPopup(target)
      ? '${category.title}: ${reason.title}'
      : reason.title,
  details: note.trim(),
  context: target.context(version),
);
