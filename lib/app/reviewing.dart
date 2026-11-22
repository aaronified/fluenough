import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/feedback/report.dart';
import '../core/models/card.dart';
import '../core/models/proposal.dart';
import '../core/review/deck_review.dart';
import '../core/review/facet_text.dart';
import '../core/review/facets.dart';
import '../core/review/question_log.dart';
import '../core/review/questions_file.dart';
import '../core/review/review_question.dart';
import '../core/review/rater_code.dart';
import '../core/review/review_file.dart';
import '../core/review/review_quorum.dart';
import '../core/review/review_session.dart';
import '../core/review/sent_mail.dart';
import '../core/review/reviewer_key.dart';
import '../core/review/review_receipt.dart';
import 'app_info.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'mail_share.dart';
import 'reviewer_check_records.dart';
import 'settings.dart';

/// What came of sending reviews.
enum ReviewSendOutcome {
  /// The mail app opened with the files; they are marked sent. Only the
  /// reviewer knows whether the mail went: [Reviewing.sendMailAgain] puts it
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
    ReviewerKeyring? keyring,
    AssetBundle? keyringBundle,
  }) : keyringNotifier = ValueNotifier<ReviewerKeyring>(
         keyring ?? ReviewerKeyring(),
       ) {
    // Unless a test hands one over, the shipped public keys and the denylist
    // are read from the app's assets. Until they are, no key is accepted.
    if (keyring == null) unawaited(_loadKeyring(keyringBundle ?? rootBundle));
  }

  /// How many reviewers other than the proposer must accept a change before
  /// learners get it: the review quorum less the proposer's own review. It
  /// derives from the one constant [kReviewQuorum] (ADR-0058; the review bot
  /// reads the same number as `REVIEW_QUORUM` in tools/review_quorum.py, and
  /// it replaced the bot's `REVIEW_AGREEMENTS_NEEDED` setting). Only the
  /// rules read this number: no screen, string or guide shows it, they say
  /// "another speaker checks it".
  static const int agreementsNeeded = kReviewQuorum - 1;

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

  // --- The signed reviewer key (ADR-0058, decision 8; W7) ---

  /// The public keys and the denylist reviewer keys are checked against
  /// (`assets/reviewer/`). Empty until the assets are read, and while the
  /// owner has committed only the placeholder: then no key is accepted and
  /// [keysEnabled] is false. Notifies when it is read.
  final ValueNotifier<ReviewerKeyring> keyringNotifier;

  Future<void> _loadKeyring(AssetBundle bundle) async {
    try {
      keyringNotifier.value = ReviewerKeyring.fromAssets(
        publicKeysJson: await bundle.loadString(
          'assets/reviewer/public_keys.json',
        ),
        denylistText: await bundle.loadString('assets/reviewer/denylist.txt'),
      );
    } catch (_) {
      // No keyring: no key is accepted, and the row is not shown.
    }
  }

  /// Whether signed reviewer keys can be used at all: false until the owner
  /// commits a real public key. The settings row is hidden while it is.
  bool get keysEnabled => keyringNotifier.value.enabled;

  String? _checkedText;
  ReviewerKeyring? _checkedRing;
  ReviewerKeyCheck? _checked;

  /// What the keyring says of the key the reviewer pasted, or null when
  /// none was. Checked again for the denylist whenever the keyring changes;
  /// remembered otherwise, since the check is not free.
  ReviewerKeyCheck? get keyCheck {
    final text = settings.reviewerKey;
    if (text == null || text.isEmpty) return null;
    final ring = keyringNotifier.value;
    if (_checked == null || _checkedText != text || _checkedRing != ring) {
      _checked = ring.check(text);
      _checkedText = text;
      _checkedRing = ring;
    }
    return _checked;
  }

  /// The reviewer's key while it is good: signed by the owner and not
  /// revoked. Null otherwise, and then nothing is unlocked and no proof is
  /// sent.
  ReviewerKey? get key {
    final check = keyCheck;
    return check != null && check.ok ? check.key : null;
  }

  /// What the reviewer's checks are worth: [ReviewerTier.provisional]
  /// without a good key. The bot decides it again from the key and its
  /// binding; this is for the screens.
  ReviewerTier get tier => key?.tier ?? ReviewerTier.provisional;

  /// Takes the key [text] pasted by the reviewer. A good key is kept, and
  /// reviewing is turned on, making the rater code if there is none, so that
  /// someone new needs one paste only. Anything else is kept nowhere. The
  /// key is never written to the log.
  ReviewerKeyCheck unlock(String text) {
    final plain = text.replaceAll(RegExp(r'\s+'), '');
    final result = keyringNotifier.value.check(plain);
    if (!result.ok) return result;
    settings.reviewerKey = plain;
    if (!on || code == null) turnOn();
    _log.event('Reviewer key accepted');
    return result;
  }

  /// The proof the review mail carries: the key's text, only while it is good.
  String? get keyProof => key == null ? null : settings.reviewerKey;

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
      itemsRight: old?.itemsRight ?? const <String>{},
      facets: old?.facets ?? const <Facet, FacetAnswer>{},
      receipts: old?.receipts ?? const <ReviewReceipt>[],
    ),
  );

  /// The changes suggested to [card], one a part at most, in place of
  /// "Looks right": every one the card keeps, so a part left out has its
  /// suggestion taken back, and an empty list takes back them all. With
  /// [itemsRight], the items checked "Looks right" are replaced too (#508);
  /// without, they stay as they were.
  void suggest(
    DeckEntry deck,
    Card card,
    List<Suggestion> suggestions, {
    Set<String>? itemsRight,
  }) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: suggestions.isEmpty && (old?.right ?? false),
      suggestions: List<Suggestion>.unmodifiable(<Suggestion>[
        for (final (i, s) in suggestions.indexed)
          if (!suggestions.take(i).any(s.samePart)) s,
      ]),
      rating: old?.rating,
      alike: old?.alike,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
      itemsRight: itemsRight ?? old?.itemsRight ?? const <String>{},
      facets: old?.facets ?? const <Facet, FacetAnswer>{},
      receipts: old?.receipts ?? const <ReviewReceipt>[],
    ),
  );

  /// How offensive the rude word [card] is, by this rater.
  void rate(DeckEntry deck, Card card, WordRating rating) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: old?.right ?? false,
      suggestions: old?.suggestions ?? const <Suggestion>[],
      rating: rating,
      alike: old?.alike,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
      itemsRight: old?.itemsRight ?? const <String>{},
      facets: old?.facets ?? const <Facet, FacetAnswer>{},
      receipts: old?.receipts ?? const <ReviewReceipt>[],
    ),
  );

  /// Whether [card] really sounds or looks like its rude partner.
  void checkAlike(DeckEntry deck, Card card, AlikeCheck check) => _change(
    deck,
    card,
    (old, at) => CardReview(
      at: at,
      right: old?.right ?? false,
      suggestions: old?.suggestions ?? const <Suggestion>[],
      rating: old?.rating,
      alike: check,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
      itemsRight: old?.itemsRight ?? const <String>{},
      facets: old?.facets ?? const <Facet, FacetAnswer>{},
      receipts: old?.receipts ?? const <ReviewReceipt>[],
    ),
  );

  /// [answer] to [facet] of [card] (ADR-0058, W4): right, or flagged with
  /// pointer tags and perhaps a fix, replacing this reviewer's earlier
  /// answer to the facet. A receipt of the text seen ([seenTextOf], hashed)
  /// and the [decision] goes with it, in place of the facet's earlier one.
  /// Both are sent in the review file (`facets`, `receipts`), beside
  /// whatever the card's review already holds.
  void answerFacet(
    DeckEntry deck,
    Card card,
    Facet facet,
    FacetAnswer answer, {
    ReceiptDecision? decision,
  }) => _change(deck, card, (old, at) {
    final facets = Map<Facet, FacetAnswer>.of(
      old?.facets ?? const <Facet, FacetAnswer>{},
    )..[facet] = answer;
    final receipts = <ReviewReceipt>[
      for (final r in old?.receipts ?? const <ReviewReceipt>[])
        if (!(r.cardId == card.id && r.facet == facet)) r,
      ReviewReceipt.of(
        cardId: card.id,
        facet: facet,
        seen: seenTextOf(card, facet),
        decision:
            decision ??
            (answer.isRight ? ReceiptDecision.right : ReceiptDecision.flagged),
      ),
    ];
    return CardReview(
      at: at,
      right: old?.right ?? false,
      suggestions: old?.suggestions ?? const <Suggestion>[],
      rating: old?.rating,
      alike: old?.alike,
      answers: old?.answers ?? const <String, ProposalAnswer>{},
      itemsRight: old?.itemsRight ?? const <String>{},
      facets: Map<Facet, FacetAnswer>.unmodifiable(facets),
      receipts: List<ReviewReceipt>.unmodifiable(receipts),
    );
  });

  Map<String, Object?> _runs() {
    try {
      final json = jsonDecode(settings.reviewRun ?? '');
      if (json is Map) {
        return <String, Object?>{
          for (final e in json.entries)
            if (e.key is String) e.key as String: e.value,
        };
      }
    } on Object {
      // Anything else is no run.
    }
    return <String, Object?>{};
  }

  /// The queue's run in [course] (a [ReviewPair.key]), the group of cards
  /// the reviewer is going through there, or null when there is none
  /// (ADR-0058, W3). Each course keeps its own.
  ReviewRun? runOf(String course) {
    final run = _runs()[course];
    return run is Map ? ReviewRun.decode(jsonEncode(run)) : null;
  }

  /// The courses that have a run.
  Set<String> get runCourses => _runs().keys.toSet();

  /// Keeps [run] as [course]'s so that a closed review resumes, or with null
  /// forgets it; other courses' runs stay. The answers are not in it:
  /// [answerFacet] keeps them as they are given.
  void keepRun(String course, ReviewRun? run) {
    final runs = _runs();
    if (run == null) {
      runs.remove(course);
    } else {
      runs[course] = run.toJson();
    }
    settings.reviewRun = runs.isEmpty ? null : jsonEncode(runs);
  }

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
        field: proposal.field.wire,
        text: proposal.text,
      );
    }
    return CardReview(
      at: at,
      right: old?.right ?? false,
      suggestions: old?.suggestions ?? const <Suggestion>[],
      rating: old?.rating,
      alike: old?.alike,
      answers: Map<String, ProposalAnswer>.unmodifiable(answers),
      itemsRight: old?.itemsRight ?? const <String>{},
      facets: old?.facets ?? const <Facet, FacetAnswer>{},
      receipts: old?.receipts ?? const <ReviewReceipt>[],
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

  /// Sends [decks]' unsent reviews, and the daily-question [answers] (every
  /// one waiting when null; #519), in one mail, one file each (a file for
  /// each deck, and one for each language of answers), through the
  /// reviewer's mail app, with [body], which is for people only. [held]
  /// names, by deck id, cards left out of the mail: they stay waiting. Once
  /// the mail app has opened with them they are marked sent and the mail is
  /// recorded; they stay on the phone. The phone cannot tell whether the
  /// mail then went, so a mail can be put back with [sendMailAgain].
  Future<ReviewSendOutcome> send(
    Iterable<DeckReview> decks, {
    required String body,
    Iterable<LoggedAnswer>? answers,
    Map<String, Set<String>> held = const <String, Set<String>>{},
  }) async {
    final code = this.code;
    final chosen = <DeckReview>[
      for (final deck in decks)
        if (deck.without(held[deck.deckId] ?? const <String>{}).hasUnsent)
          deck.without(held[deck.deckId] ?? const <String>{}),
    ];
    final given = (answers ?? unsentAnswers).toList();
    if (code == null || (chosen.isEmpty && given.isEmpty)) {
      return ReviewSendOutcome.nothingToSend;
    }
    final made = _clock();
    final answered = QuestionsFile.languagesOf(given);
    // The coarse "passed facets" flag of a reviewer check goes in the first
    // mail of its course, and nothing else of the check ever leaves.
    final flagged = <String, List<String>>{
      for (final deck in chosen)
        if (settings.reviewerCheckOf(deck.language) case final record
            when record.passed && !record.mailed)
          deck.language: record.eligibility.passedFacetsWire,
    };
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
            reviewerKey: keyProof,
            passedFacets: flagged[deck.language] ?? const <String>[],
            order: <String>[
              for (final card
                  in _deckById(deck.deckId)?.cards ?? const <Card>[])
                card.id,
            ],
          ),
        ),
      for (final language in answered)
        AttachedFile(
          name: QuestionsFile.name(language),
          mimeType: QuestionsFile.mimeType,
          text: QuestionsFile.encode(
            given,
            language: language,
            code: code,
            appVersion: AppInfo.version,
            made: made,
          ),
        ),
    ];
    bool shared;
    try {
      shared = await _share.share(
        to: <String>[address],
        subject: ReviewMail.subject(code, chosen, alsoLanguages: answered),
        body: body,
        files: files,
      );
    } catch (error) {
      _log.warning('Review not shared: ${error.runtimeType}');
      return ReviewSendOutcome.failed;
    }
    if (!shared) return ReviewSendOutcome.noMailApp;
    flagged.keys.forEach(settings.markReviewerCheckMailed);
    settings.reviews = reviews.sentAt(
      <String>[for (final deck in chosen) deck.deckId],
      made,
      answerIds: <String>[for (final a in given) a.id],
      held: held,
    );
    if (given.isNotEmpty) {
      settings.reviewQuestions = questions.sentAt(<String>[
        for (final a in given) a.id,
      ], made);
    }
    _log.event(
      'Reviews of ${chosen.length} deck(s) and ${given.length} question '
      'answer(s) shared to the mail app',
    );
    return ReviewSendOutcome.inMailApp;
  }

  /// The mails sent, newest first, each with what it carried.
  List<SentMail> get sentMails => reviews.mails.reversed.toList();

  /// Puts [mail] back for a mail the reviewer did not send or lost: its
  /// [deckIds] (those the deck data does not acknowledge) and its
  /// daily-question answers wait to send again, with anything reviewed since.
  /// Nothing is sent. The answers that went in the mail are those it
  /// recorded, and any marked sent at its time (a mail recorded before the
  /// answers were, which carried them without naming them).
  void sendMailAgain(SentMail mail, Iterable<String> deckIds) {
    final back = deckIds.toSet();
    final ids = <String>{
      ...mail.answers,
      for (final a in questions.answers.values)
        if (a.sentAt?.isAtSameMomentAs(mail.at) ?? false) a.id,
    };
    settings.reviews = reviews.unsendMail(mail, back);
    if (ids.isNotEmpty) settings.reviewQuestions = questions.unsend(ids);
    _log.event(
      'Mail of ${back.length} deck(s) and ${ids.length} answer(s) put back',
    );
  }

  // The daily questions (#519).

  /// How many questions a day the reviewer asked for.
  int get questionsPerDay => settings.reviewQuestionsPerDay;

  set questionsPerDay(int value) => settings.reviewQuestionsPerDay = value;

  /// What the reviewer answered to the daily questions.
  QuestionLog get questions => settings.reviewQuestions;

  /// Today, as the day answers count for: `YYYY-MM-DD`, in the phone's time.
  String get today {
    final now = _clock().toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// How many of today's questions are left to answer.
  int get questionsLeftToday => questions.leftOn(today, questionsPerDay);

  /// [question] answered. A Yes needs no reason; any other may give one of
  /// the question's reasons, and what the reviewer wrote, which goes in the
  /// mail for people and nowhere else.
  void answerQuestion(
    ReviewQuestion question,
    QuestionAnswer answer, {
    String? reason,
    String why = '',
  }) => settings.reviewQuestions = questions
      .since(today)
      .answer(question, answer, today, reason: reason, why: why);

  /// [question] put off to tomorrow.
  void skipQuestion(ReviewQuestion question) =>
      settings.reviewQuestions = questions.since(today).skip(question, today);

  /// The answer to [question] taken back, while it is not sent.
  void undoQuestion(ReviewQuestion question) =>
      settings.reviewQuestions = questions.undo(question);

  /// The answers waiting to send.
  List<LoggedAnswer> get unsentAnswers => questions.unsent;

  /// Sends everything waiting, the answers with the reviews, in the one
  /// mail [send] makes (owner, 2026-10-30: "Send all pending review in that
  /// same mail").
  Future<ReviewSendOutcome> sendQuestions({required String body}) =>
      send(unsent, body: body);

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
