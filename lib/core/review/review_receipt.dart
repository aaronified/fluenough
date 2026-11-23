/// A receipt for one facet answer: what a reviewer saw and what they
/// decided, so that a second speaker's digest and the bot can tell a review
/// of the current text from a review of text that has since changed
/// (ADR-0058, decision 7; the stale-review rule of wiki/Plan-Review-Staging).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'facets.dart';
import 'fix_text.dart';
import 'review_problems.dart';

/// What was decided about a facet.
enum ReceiptDecision {
  /// Marked right.
  right('right'),

  /// Flagged, with or without a proposed fix.
  flagged('flagged'),

  /// Another reviewer's proposed fix, accepted.
  accepted('accepted'),

  /// Another reviewer's proposed fix, rejected.
  rejected('rejected'),

  /// Another reviewer's proposed fix, rejected in favour of a fix of their
  /// own.
  offeredOther('other');

  const ReceiptDecision(this.wire);
  final String wire;

  static ReceiptDecision? fromWire(Object? wire) {
    for (final decision in values) {
      if (decision.wire == wire) return decision;
    }
    return null;
  }
}

/// How many hex characters of the SHA-256 a receipt keeps: 64 bits, enough
/// to tell a changed text from the one seen, short enough to travel in
/// every mail.
const int receiptHashLength = 16;

/// The hash of [text] as a receipt stores it: SHA-256 of the UTF-8 of
/// [normalizeFixText]'d [text], so two spellings of one text hash alike,
/// cut to [receiptHashLength] hex characters. `null` text (a card without
/// the facet) hashes as the empty text.
String hashOfSeen(String? text) {
  final bytes = utf8.encode(normalizeFixText(text ?? ''));
  return sha256.convert(bytes).toString().substring(0, receiptHashLength);
}

class ReviewReceipt {
  const ReviewReceipt({
    required this.cardId,
    required this.facet,
    required this.seenHash,
    required this.decision,
    this.reason,
  });

  /// Made from the [seen] text of [facet] on card [cardId].
  factory ReviewReceipt.of({
    required String cardId,
    required Facet facet,
    required String? seen,
    required ReceiptDecision decision,
    String? reason,
  }) => ReviewReceipt(
    cardId: cardId,
    facet: facet,
    seenHash: hashOfSeen(seen),
    decision: decision,
    reason: reason,
  );

  final String cardId;
  final Facet facet;

  /// [hashOfSeen] of the text the reviewer was shown.
  final String seenHash;
  final ReceiptDecision decision;

  /// Optional advisory words ("why"); never decisive.
  final String? reason;

  /// Whether this receipt is for the text [current] now: the review is not
  /// stale.
  bool isCurrent(String? current) => seenHash == hashOfSeen(current);

  Map<String, Object?> toJson() => <String, Object?>{
    'card': cardId,
    'facet': facet.wire,
    'hash': seenHash,
    'decision': decision.wire,
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
  };

  /// The receipt [json] holds, or null (reported) when it is not one.
  /// [cardId] stands in for a missing `card`.
  static ReviewReceipt? fromJson(Object? json, {String? cardId}) {
    try {
      if (json is! Map) {
        ReviewProblems.report('receipt is not an object');
        return null;
      }
      final facet = Facet.fromWire(json['facet']);
      final decision = ReceiptDecision.fromWire(json['decision']);
      final hash = json['hash'];
      final card = json['card'] is String ? json['card'] as String : cardId;
      final reason = json['reason'];
      if (facet == null ||
          decision == null ||
          hash is! String ||
          hash.isEmpty ||
          card == null ||
          card.isEmpty) {
        ReviewProblems.report('receipt incomplete or unknown (card $card)');
        return null;
      }
      return ReviewReceipt(
        cardId: card,
        facet: facet,
        seenHash: hash,
        decision: decision,
        reason: reason is String ? reason : null,
      );
    } on Object catch (e) {
      ReviewProblems.report('receipt unreadable: $e');
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewReceipt &&
      other.cardId == cardId &&
      other.facet == facet &&
      other.seenHash == seenHash &&
      other.decision == decision &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(cardId, facet, seenHash, decision, reason);
}
