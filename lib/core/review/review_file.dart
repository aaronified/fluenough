import 'dart:convert';

import 'deck_review.dart';
import 'rater_code.dart';

/// The file a deck's review is sent as, one per deck, attached to one mail
/// (docs/plans/deck-browser.md, "Review in the app, by mail").
///
/// **The files are the record, not the mail:** a reviewer may change or
/// delete the mail's subject or body, so each file carries the rater code,
/// the language, the deck id, the app version and when it was made, and
/// stands on its own. `tools/mail_to_issues.py` reads the code and the
/// languages from the files, and [format] is how it knows one.
abstract final class ReviewFile {
  /// What a review file says it is, under `format`.
  static const String format = 'fluenough-review';

  /// The file format's version, under `version`. Raised only when a field
  /// changes meaning; a new field does not need it.
  static const int version = 1;

  static const String mimeType = 'application/json';

  /// The name it is attached as.
  static String name(String deckId) => 'fluenough-review-$deckId.json';

  /// [deck]'s unsent reviews as the file's text, made at [made] by [code]
  /// with app [appVersion]. Cards come in [order], their deck's order,
  /// then any the deck no longer has.
  static String encode(
    DeckReview deck, {
    required RaterCode code,
    required String appVersion,
    required DateTime made,
    List<String> order = const <String>[],
  }) {
    final unsent = deck.unsentCards;
    final ids = <String>[
      for (final id in order)
        if (unsent.containsKey(id)) id,
      for (final id in unsent.keys)
        if (!order.contains(id)) id,
    ];
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'format': format,
      'version': version,
      'rater_code': '$code',
      'language': deck.language,
      'deck': deck.deckId,
      'app_version': appVersion,
      'made': made.toUtc().toIso8601String(),
      'signed_off': deck.unsentSignOff,
      'cards': <Object?>[
        for (final id in ids)
          <String, Object?>{'card': id, ...?unsent[id]?.toJson()},
      ],
    });
  }
}

/// The mail the review files go in: to Fluenough, with a subject that
/// carries the rater code and the languages, which the files carry too.
abstract final class ReviewMail {
  /// What a review mail's subject starts with. English, whatever the
  /// app's language, as the mail workflow reads it.
  static const String subjectPrefix = '[Fluenough review]';

  /// `[Fluenough review] FL-7K3M-Q9TD-6 (te, bn)`: the code and every
  /// language in [decks], in their order.
  static String subject(RaterCode code, Iterable<DeckReview> decks) {
    final languages = <String>{for (final deck in decks) deck.language};
    return '$subjectPrefix $code (${languages.join(', ')})';
  }
}
