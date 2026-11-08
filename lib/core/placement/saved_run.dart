import 'placement_data.dart';

// A paused "Find my level" run (wiki/Plan-Placement-V3.md): the run is saved
// after every answer and resumed within 7 days with the same deck set and app
// version, else discarded with no answer carried; nothing is written until the
// run ends or the learner stops. The run's state is its events
// (`V3Run.events`), saved by `SavedV3Run`; this file holds what it shares with
// it, the life of a paused run and the key of the decks it was asked from.

/// How long a paused run waits to be resumed.
const Duration savedRunLife = Duration(days: 7);

/// A key of what a run is asked from: the decks in path order with how many
/// cards each has, and the cards left out as already known well. A run saved under another key is discarded,
/// because its answers would not replay onto other questions.
String placementDeckSetKey(PlacementLanguageData data) {
  // FNV-1a over the deck ids and card counts: stable on every platform.
  var hash = 0x811c9dc5;
  void mix(int unit) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }

  for (final deck in data.decks) {
    for (final unit in deck.id.codeUnits) {
      mix(unit);
    }
    mix(0x7c);
    for (final unit in '${deck.cards.length}'.codeUnits) {
      mix(unit);
    }
    mix(0x3b);
  }
  // Cards the learner has since come to know well are left out of the
  // questions, so they are part of the key too.
  for (final id in data.stableCardIds.toList()..sort()) {
    for (final unit in id.codeUnits) {
      mix(unit);
    }
    mix(0x2c);
  }
  return '${data.decks.length}-${hash.toRadixString(16)}';
}
