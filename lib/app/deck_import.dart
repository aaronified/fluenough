import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../core/data/deck_parser.dart';
import '../core/data/pattern_expander.dart';
import '../core/models/deck.dart';
import 'deck_catalog.dart';

/// What adding a deck file would do (#22): add it, replace a deck added
/// before, or nothing, and why.
sealed class DeckCheck {
  const DeckCheck();
}

/// The file is a deck that can be added.
final class DeckAccepted extends DeckCheck {
  const DeckAccepted(
    this.deck, {
    required this.cardCount,
    required this.replaces,
  });

  final Deck deck;

  /// Its cards, as its row will count them: a grammar deck's cells, and the
  /// cards it lists by ref.
  final int cardCount;

  /// Whether a deck added before has its id, and adding this replaces it.
  final bool replaces;
}

/// The file is not a deck the parser can read: its file, line and message.
final class DeckUnreadable extends DeckCheck {
  const DeckUnreadable(this.error);

  final DeckParseException error;
}

/// A deck that comes with the app has the file's deck id.
final class DeckIdBundled extends DeckCheck {
  const DeckIdBundled(this.deckId);

  final String deckId;
}

/// Another deck already has a card with one of the file's card ids. A card
/// id is one word's schedule (ADR-0018), so it cannot be two words.
final class DeckCardTaken extends DeckCheck {
  const DeckCardTaken(this.cardId, this.deckName);

  final String cardId;

  /// The name of a deck that has the card.
  final String deckName;
}

/// Checks [text], the file [fileName], as a deck to add beside [decks].
///
/// A deck may list another deck's card by `ref`, but may not write a card
/// with an id another deck has. An id a deck added before has replaces that
/// deck; the id of a deck that comes with the app is refused.
DeckCheck checkAddedDeck(
  String text, {
  required String fileName,
  required Iterable<DeckEntry> decks,
}) {
  final Deck deck;
  try {
    deck = DeckParser.parse(text, source: fileName);
  } on DeckParseException catch (e) {
    return DeckUnreadable(e);
  }
  DeckEntry? same;
  final owner = <String, DeckEntry>{};
  for (final entry in decks) {
    if (entry.id == deck.id) {
      same = entry;
      continue;
    }
    for (final card in entry.cards) {
      owner.putIfAbsent(card.id, () => entry);
    }
  }
  if (same != null && same.bundled) return DeckIdBundled(deck.id);
  final cards = deck.kind == DeckKind.grammar
      ? expandPattern(deck)
      : deck.cards;
  for (final card in cards) {
    final other = owner[card.id];
    if (other != null) return DeckCardTaken(card.id, other.deck.name);
  }
  return DeckAccepted(
    deck,
    cardCount: cards.length + deck.refs.length,
    replaces: same != null,
  );
}

/// Where a deck file is read from and the deck template saved to: the
/// phone's own file dialogs. An interface so that tests need no platform.
abstract interface class DeckFiles {
  /// Offers [contents] to save as [fileName]. Whether it was saved.
  Future<bool> save(String fileName, String contents);

  /// Asks for a deck file, under [title]: its name and text, or null if
  /// none was picked.
  Future<({String name, String text})?> open({required String title});
}

/// [DeckFiles] through `file_picker`.
class PickerDeckFiles implements DeckFiles {
  const PickerDeckFiles();

  @override
  Future<bool> save(String fileName, String contents) async =>
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(contents)),
        mimeType: 'application/yaml',
      ) !=
      null;

  @override
  Future<({String name, String text})?> open({required String title}) async {
    final file = await FilePicker.pickFile(dialogTitle: title);
    if (file == null) return null;
    return (name: file.name, text: await file.xFile.readAsString());
  }
}
