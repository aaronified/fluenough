import 'dart:math';

import '../core/feedback/report.dart';
import '../core/models/card.dart';
import '../core/models/proposal.dart';
import '../core/review/deck_review.dart';
import '../core/review/rater_code.dart';
import '../core/review/review_file.dart';
import 'app_info.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'mail_share.dart';
import 'settings.dart';

/// What came of sending reviews.
enum ReviewSendOutcome {
  /// The mail app opened with the files; they are marked sent. Only the
  /// reviewer knows whether the mail went: [Reviewing.sendAgain] takes it
  /// back if it did not.
  inMailApp,

  /// Nothing was chosen, or nothing chosen had anything to send.
  nothingToSend,

  /// Nothing on the phone took the mail. Nothing is marked sent.
  noMailApp,

  /// The share could not be asked for. Nothing is marked sent.
  failed,
}

/// Reviewer mode (docs/plans/deck-browser.md, "Review in the app, by
/// mail"): the rater code, each card's review, kept in the profile's
/// settings until sent, and the one mail, with one file per deck, that
/// sends them through the reviewer's own mail app.
///
/// Not a notifier: what it keeps is in [settings], which notifies.
class Reviewing {
  Reviewing({
    required this.settings,
    required this._clock,
    required this._random,
    required this._share,
    required this.address,
    required this._deckById,
    required this._log,
  });

  final SettingsNotifier settings;
  final DateTime Function() _clock;
  final Random _random;
  final MailShare _share;
  final DeckEntry? Function(String id) _deckById;
  final AppLog _log;

  /// Where reviews go: the Fluenough inbox the mail workflow reads.
  final String address;

  /// Whether "Review decks" is on.
  bool get on => settings.reviewDecks;

  /// The rater code, once one has been made.
  RaterCode? get code => RaterCode.tryParse(settings.raterCode ?? '');

  /// Turns reviewing on, making the rater code the first time. True if
  /// this is the first time, when "How reviewing works" opens by itself.
  bool turnOn() {
    if (code == null) {
      settings.raterCode = '${RaterCode.generate(_random)}';
      _log.event('Rater code made');
    }
    settings.reviewDecks = true;
    final first = !settings.reviewIntroShown;
    settings.reviewIntroShown = true;
    return first;
  }

  /// Turns reviewing off. The code and the reviews are kept.
  void turnOff() => settings.reviewDecks = false;

  Reviews get reviews => settings.reviews;

  /// [card]'s review in [deck], or null.
  CardReview? reviewOf(DeckEntry deck, Card card) =>
      reviews.card(deck.id, card.id);

  void _change(
    DeckEntry deck,
    Card card,
    CardReview Function(CardReview? old, DateTime at) change,
  ) {
    final at = _clock();
    settings.reviews = reviews.withCard(
      deck.id,
      deck.language.code,
      card.id,
      at,
      (old) => change(old, at),
    );
  }

  /// "Looks right", or with [right] false, the mark taken back. Takes the
  /// place of a suggestion.
  void markRight(DeckEntry deck, Card card, {bool right = true}) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: right,
      rating: old?.rating,
      alike: old?.alike,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
    ),
  );

  /// A suggested change, in place of "Looks right"; null takes it back.
  void suggest(DeckEntry deck, Card card, Suggestion? suggestion) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: suggestion == null && (old?.right ?? false),
      suggestion: suggestion,
      rating: old?.rating,
      alike: old?.alike,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
    ),
  );

  /// How offensive the rude word [card] is, by this rater.
  void rate(DeckEntry deck, Card card, WordRating rating) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: old?.right ?? false,
      suggestion: old?.suggestion,
      rating: rating,
      alike: old?.alike,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
    ),
  );

  /// Whether [card] really sounds or looks like its rude partner.
  void checkAlike(DeckEntry deck, Card card, AlikeCheck check) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: old?.right ?? false,
      suggestion: old?.suggestion,
      rating: old?.rating,
      alike: check,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
    ),
  );

  /// The answer to [proposal] on [card], or with [verdict] null, the answer
  /// taken back (ADR-0038). Sent with the review, like any mark.
  void answer(
    DeckEntry deck,
    Card card,
    Proposal proposal,
    ProposalVerdict? verdict,
  ) => _change(deck, card, (old, at) {
    final answers = Map<String, ProposalAnswer>.of(
      old?.answers ?? const <String, ProposalAnswer>{},
    );
    if (verdict == null) {
      answers.remove(proposal.id);
    } else {
      answers[proposal.id] = ProposalAnswer(
        id: proposal.id,
        verdict: verdict,
        field: proposal.field.name,
        text: proposal.text,
      );
    }
    return CardReview(
      at: at,
      right: old?.right ?? false,
      suggestion: old?.suggestion,
      rating: old?.rating,
      alike: old?.alike,
      answers: Map<String, ProposalAnswer>.unmodifiable(answers),
    );
  });

  /// [proposal]'s answer on [card], or null.
  ProposalVerdict? answerTo(DeckEntry deck, Card card, Proposal proposal) =>
      reviewOf(deck, card)?.answers[proposal.id]?.verdict;

  /// Signs [deck] off: the reviewer has checked every card.
  void signOff(DeckEntry deck) =>
      settings.reviews = reviews.signOff(deck.id, deck.language.code, _clock());

  /// The decks with reviews not sent yet.
  List<DeckReview> get unsent => reviews.unsent;

  /// Sends [decks]' unsent reviews in one mail, one file each, through the
  /// reviewer's mail app, with [body], which is for people only. Once the
  /// mail app has opened with them they are marked sent; they stay on the
  /// phone. The phone cannot tell whether the mail then went, so the send
  /// can be taken back with [sendAgain].
  Future<ReviewSendOutcome> send(
    Iterable<DeckReview> decks, {
    required String body,
  }) async {
    final code = this.code;
    final chosen = <DeckReview>[
      for (final deck in decks)
        if (deck.hasUnsent) deck,
    ];
    if (code == null || chosen.isEmpty) {
      return ReviewSendOutcome.nothingToSend;
    }
    final made = _clock();
    final files = <AttachedFile>[
      for (final deck in chosen)
        AttachedFile(
          name: ReviewFile.name(deck.deckId),
          mimeType: ReviewFile.mimeType,
          text: ReviewFile.encode(
            deck,
            code: code,
            appVersion: AppInfo.version,
            made: made,
            order: <String>[
              for (final card
                  in _deckById(deck.deckId)?.cards ?? const <Card>[])
                card.id,
            ],
          ),
        ),
    ];
    bool shared;
    try {
      shared = await _share.share(
        to: <String>[address],
        subject: ReviewMail.subject(code, chosen),
        body: body,
        files: files,
      );
    } catch (error) {
      _log.warning('Review not shared: ${error.runtimeType}');
      return ReviewSendOutcome.failed;
    }
    if (!shared) return ReviewSendOutcome.noMailApp;
    settings.reviews = reviews.sentAt(<String>[
      for (final deck in chosen) deck.deckId,
    ], made);
    _log.event('Reviews of ${chosen.length} deck(s) shared to the mail app');
    return ReviewSendOutcome.inMailApp;
  }

  /// The decks of the last send, while it can be taken back: what "Send
  /// the last mail again" puts back. Empty when there is none.
  List<DeckReview> get lastSent => reviews.lastSend;

  /// Takes the last send back, for a mail the reviewer did not send or
  /// lost: what it carried waits to send again, with anything reviewed
  /// since. Once per send.
  void sendAgain() {
    final last = lastSent;
    if (last.isEmpty) return;
    settings.reviews = reviews.unsend(<String>[
      for (final deck in last) deck.deckId,
    ]);
    _log.event('Last send of ${last.length} deck(s) taken back');
  }

  /// Whether [deck] lists this reviewer's code among the codes that
  /// checked it: in a card's `checked_by`, which the review bot writes once
  /// the review is in (#449), or among its `authors`, as decks did before.
  bool helpedBuild(DeckEntry deck) {
    final code = this.code;
    if (code == null) return false;
    return _codesIn(deck).contains(code);
  }

  /// How many reviewers' codes [deck] lists, this one's among them or not:
  /// every code in its cards' `checked_by`, each once, and any among its
  /// authors.
  int reviewerCount(DeckEntry deck) => _codesIn(deck).length;

  /// The rater codes [deck] lists: those in its cards' `checked_by`, and
  /// among its authors names written as a code is, starting `FL-`, so that
  /// a person's name is never read as one.
  static Set<RaterCode> _codesIn(DeckEntry deck) => <RaterCode>{
    for (final codes in deck.deck.checkedBy.values)
      for (final code in codes) ?RaterCode.tryParse(code),
    for (final author in deck.deck.authors)
      if (author.name.trim().toUpperCase().startsWith('${RaterCode.prefix}-'))
        ?RaterCode.tryParse(author.name),
  };
}
