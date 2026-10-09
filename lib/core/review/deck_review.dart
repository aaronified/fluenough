/// What a reviewer says about cards, kept on the phone until it is sent
/// (docs/plans/deck-browser.md, "Review in the app, by mail"): which cards
/// look right, the changes they suggest, how offensive a rude word is, and
/// whether a word really sounds or looks like a rude one.
///
/// Stored as JSON in the profile's settings ([Reviews.toJson]); sent as one
/// file per deck (`review_file.dart`).
library;

import 'dart:convert';

/// The part of a card a suggestion is about, as "Suggest a change" offers
/// them. The names are written to the review file, so they are permanent.
enum CardPart { word, reading, ipa, meaning, notes, example, picture }

/// Whether a rude word can be friendly among peers, as a rater says
/// (docs/plans/offensive-words.md).
enum Friendly { yes, no, sometimes }

/// How a word is like a rude one: by sound, a care when speaking, or by
/// writing, a care when writing (docs/plans/offensive-words.md).
enum AlikeKind { sound, look }

/// A change suggested to one part of a card: what it says [now], the
/// suggestion, and why.
class Suggestion {
  const Suggestion({
    required this.part,
    required this.now,
    required this.text,
    this.why = '',
  });

  final CardPart part;

  /// What the part said when the suggestion was made, so that the file
  /// stands on its own if the deck changes.
  final String now;
  final String text;
  final String why;

  Map<String, Object?> toJson() => <String, Object?>{
    'part': part.name,
    'now': now,
    'text': text,
    if (why.isNotEmpty) 'why': why,
  };

  static Suggestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final part = CardPart.values.asNameMap()[json['part']];
    final now = json['now'];
    final text = json['text'];
    final why = json['why'];
    if (part == null || now is! String || text is! String) return null;
    return Suggestion(
      part: part,
      now: now,
      text: text,
      why: why is String ? why : '',
    );
  }
}

/// How offensive a rude word is to native speakers in general, 1 to 9
/// (Janschewitz 2008's question, in the owner's wording), where the rater
/// speaks the language, and whether it can be friendly among peers.
class WordRating {
  const WordRating({required this.score, this.region, this.friendly})
    : assert(score >= minScore && score <= maxScore);

  static const int minScore = 1;
  static const int maxScore = 9;

  /// The region id answered, from the language's regions, or [elsewhere].
  /// Null for a language with no regions, or when the rater did not say.
  final String? region;

  /// The answer "Elsewhere" is stored as, after the language's own regions.
  static const String elsewhere = 'elsewhere';

  final int score;
  final Friendly? friendly;

  Map<String, Object?> toJson() => <String, Object?>{
    'score': score,
    'region': ?region,
    'friendly': ?friendly?.name,
  };

  static WordRating? fromJson(Object? json) {
    if (json is! Map) return null;
    final score = json['score'];
    final region = json['region'];
    if (score is! int || score < minScore || score > maxScore) return null;
    return WordRating(
      score: score,
      region: region is String ? region : null,
      friendly: Friendly.values.asNameMap()[json['friendly']],
    );
  }
}

/// A reviewer's answer on a pair the similarity check found: whether the
/// card really sounds (or looks) like the rude word [partner], and if so the
/// care note learners read, at most [careLimit] letters.
class AlikeCheck {
  const AlikeCheck({
    required this.partner,
    required this.kind,
    required this.real,
    this.care = '',
  });

  /// The most letters a care note may have (owner, 2026-10-09).
  static const int careLimit = 40;

  /// The rude word's card id.
  final String partner;
  final AlikeKind kind;

  /// Confirmed: a real risk. False: rejected.
  final bool real;

  /// What to take care of, such as "Keep the long ā". Empty when rejected.
  final String care;

  Map<String, Object?> toJson() => <String, Object?>{
    'with': partner,
    'kind': kind.name,
    'real': real,
    if (care.isNotEmpty) 'care': care,
  };

  static AlikeCheck? fromJson(Object? json) {
    if (json is! Map) return null;
    final partner = json['with'];
    final kind = AlikeKind.values.asNameMap()[json['kind']];
    final real = json['real'];
    final care = json['care'];
    if (partner is! String || kind == null || real is! bool) return null;
    return AlikeCheck(
      partner: partner,
      kind: kind,
      real: real,
      care: care is String ? care : '',
    );
  }
}

/// Everything a reviewer has said about one card, and when they last
/// changed it.
class CardReview {
  const CardReview({
    required this.at,
    this.right = false,
    this.suggestion,
    this.rating,
    this.alike,
  });

  final DateTime at;

  /// "Looks right". Never with a [suggestion].
  final bool right;
  final Suggestion? suggestion;
  final WordRating? rating;
  final AlikeCheck? alike;

  /// Whether the card is marked: right, or with a suggestion.
  bool get marked => right || suggestion != null;

  /// Whether there is anything to send.
  bool get isEmpty => !marked && rating == null && alike == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toUtc().toIso8601String(),
    if (right) 'looks_right': true,
    'suggestion': ?suggestion?.toJson(),
    'rating': ?rating?.toJson(),
    'alike': ?alike?.toJson(),
  };

  static CardReview? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    if (at == null) return null;
    final suggestion = Suggestion.fromJson(json['suggestion']);
    return CardReview(
      at: at,
      right: json['looks_right'] == true && suggestion == null,
      suggestion: suggestion,
      rating: WordRating.fromJson(json['rating']),
      alike: AlikeCheck.fromJson(json['alike']),
    );
  }
}

/// One deck's review: its cards' reviews by card id, when the reviewer
/// signed it off, and when it was last sent.
class DeckReview {
  const DeckReview({
    required this.deckId,
    required this.language,
    this.cards = const <String, CardReview>{},
    this.signedOff,
    this.sent,
  });

  final String deckId;

  /// The deck's language code, which the file and the mail's subject carry.
  final String language;
  final Map<String, CardReview> cards;

  /// When the reviewer signed off every card, or null.
  final DateTime? signedOff;

  /// When the review was last sent, or null if never.
  final DateTime? sent;

  bool _unsent(DateTime at) => sent == null || at.isAfter(sent!);

  /// The card reviews made or changed since the last send, by card id.
  Map<String, CardReview> get unsentCards => <String, CardReview>{
    for (final MapEntry(:key, :value) in cards.entries)
      if (!value.isEmpty && _unsent(value.at)) key: value,
  };

  /// Whether a sign-off has not been sent yet.
  bool get unsentSignOff => signedOff != null && _unsent(signedOff!);

  /// Whether there is anything to send.
  bool get hasUnsent => unsentCards.isNotEmpty || unsentSignOff;

  /// How many of the deck's cards are marked right or with a suggestion.
  int get markedCount => cards.values.where((c) => c.marked).length;

  DeckReview copyWith({
    Map<String, CardReview>? cards,
    DateTime? signedOff,
    bool clearSignOff = false,
    DateTime? sent,
  }) => DeckReview(
    deckId: deckId,
    language: language,
    cards: Map<String, CardReview>.unmodifiable(cards ?? this.cards),
    signedOff: clearSignOff ? null : signedOff ?? this.signedOff,
    sent: sent ?? this.sent,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'language': language,
    'cards': <String, Object?>{
      for (final MapEntry(:key, :value) in cards.entries) key: value.toJson(),
    },
    'signed_off': ?signedOff?.toUtc().toIso8601String(),
    'sent': ?sent?.toUtc().toIso8601String(),
  };

  static DeckReview? fromJson(String deckId, Object? json) {
    if (json is! Map) return null;
    final language = json['language'];
    final cards = json['cards'];
    if (language is! String) return null;
    return DeckReview(
      deckId: deckId,
      language: language,
      cards: Map<String, CardReview>.unmodifiable(<String, CardReview>{
        if (cards is Map)
          for (final MapEntry(:key, :value) in cards.entries)
            if (key is String) key: ?CardReview.fromJson(value),
      }),
      signedOff: DateTime.tryParse('${json['signed_off']}'),
      sent: DateTime.tryParse('${json['sent']}'),
    );
  }
}

/// Every deck's review on this phone, by deck id. Immutable: each change
/// makes a new one.
class Reviews {
  const Reviews([this.decks = const <String, DeckReview>{}]);

  final Map<String, DeckReview> decks;

  DeckReview? of(String deckId) => decks[deckId];

  /// The card's review in [deckId], or null.
  CardReview? card(String deckId, String cardId) =>
      decks[deckId]?.cards[cardId];

  /// The decks with something not sent yet, in the order they were first
  /// reviewed.
  List<DeckReview> get unsent => <DeckReview>[
    for (final deck in decks.values)
      if (deck.hasUnsent) deck,
  ];

  /// With [cardId]'s review in [deckId] replaced by what [change] makes of
  /// it (null when there is none yet), at [at]. A change that leaves
  /// nothing removes the card's review. Any change after a sign-off takes
  /// the sign-off back, since it no longer covers every card as it is.
  Reviews withCard(
    String deckId,
    String language,
    String cardId,
    DateTime at,
    CardReview Function(CardReview? old) change,
  ) {
    final deck =
        decks[deckId] ?? DeckReview(deckId: deckId, language: language);
    final next = change(deck.cards[cardId]);
    final cards = Map<String, CardReview>.of(deck.cards);
    if (next.isEmpty) {
      cards.remove(cardId);
    } else {
      cards[cardId] = next;
    }
    return _with(deck.copyWith(cards: cards, clearSignOff: true));
  }

  /// With [deckId] signed off at [at].
  Reviews signOff(String deckId, String language, DateTime at) {
    final deck =
        decks[deckId] ?? DeckReview(deckId: deckId, language: language);
    return _with(deck.copyWith(signedOff: at));
  }

  /// With [deckIds] marked sent at [at]: what they held stays on the phone,
  /// to show what the reviewer has done, but is not sent again.
  Reviews sentAt(Iterable<String> deckIds, DateTime at) {
    var next = this;
    for (final id in deckIds) {
      final deck = decks[id];
      if (deck != null) next = next._with(deck.copyWith(sent: at));
    }
    return next;
  }

  Reviews _with(DeckReview deck) => Reviews(
    Map<String, DeckReview>.unmodifiable(<String, DeckReview>{
      ...decks,
      deck.deckId: deck,
    }),
  );

  String toJson() => jsonEncode(<String, Object?>{
    for (final MapEntry(:key, :value) in decks.entries) key: value.toJson(),
  });

  /// [text] as [toJson] wrote it, or null if it is not that. A deck or card
  /// that cannot be read is left out rather than losing the rest.
  static Reviews? fromJson(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    return Reviews(
      Map<String, DeckReview>.unmodifiable(<String, DeckReview>{
        for (final MapEntry(:key, :value) in json.entries)
          if (key is String) key: ?DeckReview.fromJson(key, value),
      }),
    );
  }
}
