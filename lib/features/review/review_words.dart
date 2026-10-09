import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/data/course_path.dart' show Region;
import '../../core/models/card.dart';
import '../../core/review/deck_review.dart';
import '../decks/card_notes.dart';
import '../decks/word_sheet.dart' show isRude;

/// One of a language's regions, as a rater answers "Where you speak
/// Telugu" (docs/plans/offensive-words.md).
typedef RaterRegion = ({String id, String name});

/// [language]'s regions, in the order its path lists them (ADR-0036), each
/// named in [code], else in English; none for a language whose path lists
/// none, which asks no region question. The rating sheet offers them
/// before Elsewhere. The names are the decks' data, not interface text.
List<RaterRegion> raterRegions(
  AppState state,
  String language, {
  String code = 'en',
}) => <RaterRegion>[
  for (final region
      in state.languagePathOf(language)?.regions ?? const <Region>[])
    (id: region.id, name: region.nameIn(code)),
];

/// The regions [card]'s region note names, as [raterRegions] names them,
/// with the note's text: what a rude word's card says under "Region".
/// Null when it has no region note. A region its path does not list is
/// named by its id.
({String text, List<String> regions})? regionNote(
  AppState state,
  String language,
  Card card, {
  String code = 'en',
}) {
  final note = regionNoteOf(card);
  if (note == null) return null;
  final names = <String, String>{
    for (final r in raterRegions(state, language, code: code)) r.id: r.name,
  };
  return (
    text: note.text,
    regions: <String>[for (final id in note.regions) names[id] ?? id],
  );
}

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
