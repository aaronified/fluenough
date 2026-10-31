import '../models/card.dart';

/// Links from a word to its Wiktionary entry (#422, DECK-FORMAT.md, "The
/// Wiktionary link"). Pure Dart: nothing here fetches anything. A link is
/// built from the word, and shown only for a word a deck marks with
/// `wiktionary: true`, which a tool sets from Wiktionary's extracts.

/// A word and the address of its entry.
typedef WiktionaryLink = ({String word, Uri url});

/// The name of a language's section on English Wiktionary, where it is not
/// the name the deck gives: the Hindustani course's Devanagari words are
/// Wiktionary's Hindi.
const Map<String, String> _sectionNames = <String, String>{'hi': 'Hindi'};

// A lowercase language code, as Wiktionary's subdomains are (`en`, `bn`). A
// code with a script or region (`zh-Hans`) is not one: a caller gives the
// base language (`zh`).
final RegExp _edition = RegExp(r'^[a-z]{2,3}(?:-[a-z]+)*$');

/// The address of [word]'s entry in the Wiktionary of [edition] (`en`, `bn`),
/// or null for a blank word or an [edition] that is not a language code.
///
/// The title is the word as it stands, spaces written as underscores as
/// Wiktionary writes them, and everything outside plain ASCII, or with a
/// meaning in an address (`?`, `#`, `/`, `%`), percent-encoded as UTF-8.
/// [section] is the language's heading on the page, which scrolls the page to
/// that language: `Telugu`, `Toki Pona`. Only English Wiktionary names its
/// sections in English, so a caller gives none for another edition.
Uri? wiktionaryUrl(String word, {required String edition, String? section}) {
  final title = word.trim().replaceAll(RegExp(r'\s+'), '_');
  if (title.isEmpty || !_edition.hasMatch(edition)) return null;
  final heading = section?.trim().replaceAll(RegExp(r'\s+'), '_');
  return Uri(
    scheme: 'https',
    host: '$edition.wiktionary.org',
    pathSegments: <String>['wiki', title],
    fragment: heading == null || heading.isEmpty ? null : heading,
  );
}

/// The links a card shows: its own word where its layer marks it, and each
/// base word that is marked, for a sentence or an inflected form (whose own
/// title is no entry). A base given by `ref` is the card [find] finds for its
/// id, marked or not by its own layer; one written in full carries its mark.
///
/// [edition] is the native language's code, the Wiktionary a learner reads;
/// [languageCode] and [languageName] are the language learned. A link to
/// English Wiktionary names the language's section.
List<WiktionaryLink> wiktionaryLinksOf(
  Card card,
  Card? Function(String id) find, {
  required String edition,
  required String languageCode,
  required String languageName,
}) {
  final section = edition == 'en'
      ? (_sectionNames[languageCode] ?? languageName)
      : null;
  final seen = <String>{};
  final out = <WiktionaryLink>[];
  void add(String word) {
    final url = wiktionaryUrl(word, edition: edition, section: section);
    if (url != null && seen.add(url.toString())) {
      out.add((word: word.trim(), url: url));
    }
  }

  if (card.wiktionary) add(card.target);
  for (final base in card.bases) {
    final written = base.base;
    final ref = base.ref;
    if (written != null && written.trim().isNotEmpty) {
      if (base.wiktionary) add(written);
    } else if (ref != null && ref != card.id) {
      final taught = find(ref);
      if (taught != null && taught.wiktionary) add(taught.target);
    }
  }
  return out;
}
