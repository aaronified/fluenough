/// Where the text of a culture or proverb card comes from (wiki
/// Plan-Deck-Kinds-And-Topics.md, D4): the card's `source` mapping, with the
/// rights basis the text is used on.
///
/// Every field is optional here. The parser never refuses a deck over rights:
/// that is the validator's job (`tools/validate_decks.py`), so that a deck it
/// accepts always loads, and an old deck without the block still loads.
library;

/// The rights basis of a [CardSource].
enum SourceBasis {
  publicDomain('public-domain'),
  licensed('licensed'),
  quotation('quotation'),
  oralTradition('oral-tradition');

  const SourceBasis(this.id);

  /// How the deck writes it.
  final String id;

  /// [id] as a basis, or null for any other text.
  static SourceBasis? tryParse(String? id) {
    for (final basis in SourceBasis.values) {
      if (basis.id == id) return basis;
    }
    return null;
  }
}

/// A card's or a passage's `source` block.
class CardSource {
  const CardSource({
    this.author,
    this.work,
    this.collection,
    this.region,
    this.date,
    this.edition,
    this.url,
    this.basis,
    this.authorDied,
    this.jurisdiction,
    this.licence,
    this.licenceUrl,
    this.rightsChecked,
  });

  /// The author's name, or `anonymous`.
  final String? author;

  /// The work the text is from; a proverb names its [collection] instead.
  final String? work;
  final String? collection;

  /// Where an oral tradition belongs.
  final String? region;

  /// When the work was made, as the deck writes it: a year (`1892`), a range
  /// (`1892-1909`) or an estimate (`c. 1750`). See [year].
  final String? date;

  /// The edition the text was taken from, or its [url].
  final String? edition;
  final String? url;

  /// The rights basis as written: `public-domain`, `licensed`, `quotation` or
  /// `oral-tradition`. See [basisKind].
  final String? basis;

  /// The year the author died, for a public-domain basis.
  final int? authorDied;

  /// ISO 3166-1 alpha-2 code of the place the rights status was judged.
  final String? jurisdiction;

  /// An SPDX id for a licensed text, or the note that names the exception for
  /// a quotation.
  final String? licence;
  final String? licenceUrl;

  /// The date the rights were checked, ISO.
  final String? rightsChecked;

  /// [basis] as one of the known bases, or null when it is another text.
  SourceBasis? get basisKind => SourceBasis.tryParse(basis);

  /// The first year in [date], or null when it names none: the year a work
  /// is a point at on a timeline.
  int? get year {
    final match = RegExp(r'-?\d{3,4}').firstMatch(date ?? '');
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  /// Whether the block holds nothing at all.
  bool get isEmpty =>
      author == null &&
      work == null &&
      collection == null &&
      region == null &&
      date == null &&
      edition == null &&
      url == null &&
      basis == null &&
      authorDied == null &&
      jurisdiction == null &&
      licence == null &&
      licenceUrl == null &&
      rightsChecked == null;

  /// The block [tree] holds, a plain YAML mapping, read tolerantly: a field of
  /// the wrong type is left out and named in [problems], an unknown key is
  /// ignored. Null when [tree] is not a mapping, which [problems] says too.
  static CardSource? fromTree(Object? tree, List<String> problems) {
    if (tree is! Map) {
      problems.add('source is not a mapping');
      return null;
    }
    String? text(String key) {
      final value = tree[key];
      if (value == null) return null;
      if (value is String) return value.trim().isEmpty ? null : value;
      if (value is int || value is double) return value.toString();
      if (value is DateTime) return value.toIso8601String();
      problems.add('source.$key is not text');
      return null;
    }

    int? year(String key) {
      final value = tree[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is String && int.tryParse(value.trim()) != null) {
        return int.parse(value.trim());
      }
      problems.add('source.$key is not a year');
      return null;
    }

    return CardSource(
      author: text('author'),
      work: text('work'),
      collection: text('collection'),
      region: text('region'),
      date: text('date'),
      edition: text('edition'),
      url: text('url'),
      basis: text('basis'),
      authorDied: year('author_died'),
      jurisdiction: text('jurisdiction'),
      licence: text('licence'),
      licenceUrl: text('licence_url'),
      rightsChecked: text('rights_checked'),
    );
  }

  @override
  String toString() => 'CardSource(${author ?? '?'}, ${work ?? collection})';
}
