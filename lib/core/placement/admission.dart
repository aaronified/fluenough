import 'dart:math' as math;

import '../models/card.dart';
import 'placement_data.dart';
import 'sentence_gate.dart' show isNonLatinCourse;

// What the offline admission audit decided for a course language
// (wiki/Plan-Placement-V3.md, "The question bank"): the item classes it
// excluded and the number of decoy units its word tiles carry, for the items
// the app makes (`ItemBank.buildItems`) from one set of decks. The app takes
// this instead of running the audit (the slow part of making a bank, which
// gives the same answer for the same decks and generators); a language with no
// entry, or whose decks are not the ones audited, is audited when its bank is
// made, and its run begins on the whole bank.
//
// The entries are checked against the real audit of the app's own output by
// `test/placement_v3_real_bank_test.dart`: a change of what the audit reads or
// of a generator that changes the audit's answer fails it until the entry is
// regenerated (`dart run tool/placement_audit.dart --runtime`, which prints
// the entry).
//
// A language holds one verdict per deck source (`AdmissionProfile.source`): the
// frozen decks bundled under main's `decks/` and the live decks the apps
// download from `decks-live` (#1270). Each has its own key, so a change of one
// source's decks leaves the other's verdict intact, and a phone on live decks
// is not left without one.
//
// Pure Dart.

/// Whether the admission audit reads [card]: the generators and the sentence
/// gate (`ItemGenerators._read`, `sentenceRejections`) skip a card with a
/// rule, a grammar cell or a letter or digit (`pos: letter|digit`). The
/// cards of a rules deck, a letters deck and the like are not read.
bool admissionReads(Card card) =>
    card.rule == null && !card.isGrammarCell && !card.isLetterOrDigit;

/// A key of what the audit reads of [data], and nothing else (#1270): the
/// language, whether the course is written in a non-Latin script
/// ([isNonLatinCourse], the one thing the audit takes from the cards it
/// otherwise skips), the near-span of the decks, and, in path order and with
/// the distance of its deck from the first deck holding a read card, every
/// card the audit reads ([admissionReads]) with the fields it reads (id,
/// target, native, reading, pos, gender, practice-only mark, alternative
/// targets, the word split and the bases' word and base), hashed with
/// FNV-1a. A change to any of these changes the key; a card or deck the
/// audit never reads (culture, situations, proverbs, notes, facts, topics,
/// phonetic fields, rules and letters cards) does not, and neither does a
/// deck added before every read card or after the last one; a deck inserted
/// between read cards does, as it moves their distances. It does not include
/// what a learner has already learned (`stableCardIds`), which a verdict does
/// not depend on. Format: `<cards read>-<hex>`.
String admissionKey(PlacementLanguageData data) {
  var hash = 0x811c9dc5;
  void mix(String text) {
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    hash = ((hash ^ 0x1f) * 0x01000193) & 0xffffffff;
  }

  // A null and an empty text differ.
  void mixOpt(String? text) => mix(text == null ? '~' : 'v$text');

  void mixAll(Iterable<String>? texts) {
    mix(texts == null ? '~' : '[');
    for (final t in texts ?? const <String>[]) {
      mix(t);
    }
    mix('|');
  }

  mix(data.language);
  mix(isNonLatinCourse(data) ? 'nonlatin' : 'latin');
  // `ItemGenerators.near`: the span of decks a word's neighbours lie within.
  mix('${math.max(6, data.deckCount ~/ 12)}');
  var read = 0;
  int? first;
  for (final (index, deck) in data.decks.indexed) {
    for (final card in deck.cards) {
      if (!admissionReads(card)) continue;
      read++;
      first ??= index;
      mix('${index - first}');
      mix(card.id);
      mix(card.target);
      mix(card.native);
      mixOpt(card.reading);
      mixOpt(card.pos);
      // The gender article vote reads it (`genderArticle`).
      mixOpt(card.gender);
      mix(card.practiceOnly ? '1' : '0');
      mixAll(card.altTarget);
      mixAll(card.words);
      for (final base in card.bases) {
        mix(base.word);
        mixOpt(base.base);
      }
      mix('|');
    }
  }
  return '$read-${hash.toRadixString(16)}';
}

/// The audit's verdict for one language on one set of decks.
class AdmissionProfile {
  const AdmissionProfile({
    required this.deckKey,
    required this.excluded,
    required this.decoys,
    this.source = kFrozenDecks,
  });

  /// Which decks the verdict was made on: [kFrozenDecks] (main's `decks/`) or
  /// [kLiveDecks] (`decks-live`). Only a label for people; [of] picks by
  /// [deckKey], so a source nobody has audited costs nothing.
  /// An audited-but-stale live entry (same key, changed generator) is not
  /// detected by CI on decks-live, so the audit must be rerun when live decks
  /// change.
  final String source;

  /// [admissionKey] of the decks it was made on.
  final String deckKey;

  /// The classes (`format:class`) the app makes that failed the audit, in
  /// the order `ItemBank.excluded` lists them (sorted as text: `F14` before
  /// `F1:`). Classes the app never makes (word order, matching, cloze,
  /// gender) are not here.
  final List<String> excluded;

  /// The decoy units of the word tiles (0 when none passed).
  final int decoys;

  bool admits(String auditClass) => !excluded.contains(auditClass);

  /// The verdict stored for [data]'s language, if one was made on these decks
  /// (whichever source). Two entries may share a key (the frozen and the live
  /// decks the audit reads alike) only with the same verdict; the first is
  /// returned. [profiles] is for tests; the app uses
  /// [kAdmissionProfiles].
  static AdmissionProfile? of(
    PlacementLanguageData data, [
    Map<String, List<AdmissionProfile>> profiles = kAdmissionProfiles,
  ]) {
    final entries = profiles[data.language];
    if (entries == null || entries.isEmpty) return null;
    final key = admissionKey(data);
    for (final profile in entries) {
      if (profile.deckKey == key) return profile;
    }
    return null;
  }
}

/// [AdmissionProfile.source] of main's frozen `decks/`.
const String kFrozenDecks = 'frozen';

/// [AdmissionProfile.source] of the live decks (`decks-live`).
const String kLiveDecks = 'live';

/// The verdicts of the languages audited so far, by language code: one entry
/// per deck source that has been audited.
const Map<String, List<AdmissionProfile>> kAdmissionProfiles =
    <String, List<AdmissionProfile>>{
      // Step 2 of #1270 pastes the entries printed by the "Placement audit"
      // workflow (frozen and live, es and hi) here; the keys of the earlier
      // scheme (every card of every deck) no longer match anything.
    };
