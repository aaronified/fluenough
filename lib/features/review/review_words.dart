import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/review/deck_review.dart';
import '../decks/card_notes.dart';
import '../decks/word_sheet.dart' show isRude;

/// One of a language's regions, as a rater answers "Where you speak
/// Telugu" (docs/plans/offensive-words.md).
typedef RaterRegion = ({String id, String name});

/// [language]'s regions, in the order the rating sheet offers them, before
/// Elsewhere; none for a language without them, which asks no region
/// question.
///
/// **A fixed list until feat/b1-format's regions land.** That branch lists
/// a language's regions in its path (ADR-0036, `CoursePath.regions`); the
/// ids and names here are copied from its `te-path.yaml` and
/// `bn-path.yaml`, so that a rating made now names the same region ids.
/// Once it is merged, this reads `state.pathOf(entry)?.regions` instead.
/// The names are the decks' data, in English, not interface text.
List<RaterRegion> raterRegions(String language) => switch (language) {
  'te' => const <RaterRegion>[
    (id: 'telangana', name: 'Telangana'),
    (id: 'coastal-andhra', name: 'Coastal Andhra'),
    (id: 'rayalaseema', name: 'Rayalaseema'),
  ],
  'bn' => const <RaterRegion>[
    (id: 'rarhi', name: 'Rāṛhī (west-central: Kolkata, Nadia, Bardhaman)'),
    (id: 'vangiya', name: 'Vaṅgīya (east: Dhaka, Mymensingh, Barishal)'),
    (
      id: 'varendri',
      name: 'Varendrī (north-central: Rajshahi, Malda, Dinajpur)',
    ),
    (
      id: 'kamrupi',
      name: 'Kāmarūpī or Rangpuri (north: Rangpur, Cooch Behar, Jalpaiguri)',
    ),
    (
      id: 'manbhumi',
      name: 'Mānbhūmī (west: Purulia, Bankura, Bengali-speaking Jharkhand)',
    ),
    (
      id: 'south-eastern',
      name:
          'South-eastern (Chittagong, Noakhali, Sylhet, Tripura, '
          'Assam\'s Barak Valley)',
    ),
  ],
  _ => const <RaterRegion>[],
};

/// A rude word that [card] sounds or looks like: the pair a learner is
/// warned of, and a reviewer confirms or rejects, with the pair note's
/// text where it has one, what to take care of.
typedef RudeAlike = ({Card partner, AlikeKind kind, String? care});

/// The rude words [card] is like (docs/plans/offensive-words.md): each of
/// its pairs ([pairsOf]), its `pair` and its pair notes' partners, that is
/// rude, in order.
///
/// A pair is a word that sounds almost the same, a sound-alike. The deck
/// format has no look-alike note yet; [AlikeKind.look] is ready for one.
List<RudeAlike> rudeAlikesOf(AppState state, Card card) {
  final pairs = pairsOf(card);
  if (pairs.isEmpty) return const <RudeAlike>[];
  final out = <RudeAlike>[];
  for (final pair in pairs) {
    found:
    for (final entry in state.decks) {
      for (final other in entry.cards) {
        if (other.id == pair.id && isRude(other, entry)) {
          out.add((partner: other, kind: AlikeKind.sound, care: pair.care));
          break found;
        }
      }
    }
  }
  return out;
}

/// Whether [card] in [deck] is rude: recognition only, and shown to a
/// reviewer only with adult content on.
bool isRudeIn(DeckEntry deck, Card card) => isRude(card, deck);
