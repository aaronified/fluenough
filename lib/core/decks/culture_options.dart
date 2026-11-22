/// A language's culture options (the approved mockups `culture-in-decks` and
/// `culture-media`): the four choices the learner makes in the language's
/// details, each language keeping its own. Pure Dart, free of Flutter, so that it is tested in
/// milliseconds; the settings store one per language.
library;

/// The culture options of one language. Immutable: change one with
/// [copyWith] and hand it back to the settings.
class CultureOptions {
  const CultureOptions({
    this.items = true,
    this.counts = false,
    this.creators = true,
    this.pictures = true,
  });

  /// What a language that has not chosen yet has: items on, culture a bonus,
  /// creators shown, pictures shown.
  static const CultureOptions defaults = CultureOptions();

  /// The language's own entry read from JSON; a missing or unreadable value
  /// keeps its default, so an entry from an older or newer version still
  /// reads.
  factory CultureOptions.fromJson(Map<Object?, Object?> json) {
    bool read(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    return CultureOptions(
      items: read('items', defaults.items),
      counts: read('counts', defaults.counts),
      creators: read('creators', defaults.creators),
      pictures: read('pictures', defaults.pictures),
    );
  }

  /// Whether culture items (a proverb, a line of verse, a passage) are in the
  /// path, on Today and in reviews. Off, they can still be read and searched.
  final bool items;

  /// Whether a woven culture item counts as a step of its unit; false makes
  /// it a bonus.
  final bool counts;

  /// Whether an item shows its creator and what still lives today.
  final bool creators;

  /// Whether the posters of works and the portraits of people are fetched and
  /// shown (wiki/Plan-Culture-Media.md, ADR-0060). Off, every picture is the
  /// icon it replaces and nothing is downloaded for it.
  final bool pictures;

  CultureOptions copyWith({
    bool? items,
    bool? counts,
    bool? creators,
    bool? pictures,
  }) => CultureOptions(
    items: items ?? this.items,
    counts: counts ?? this.counts,
    creators: creators ?? this.creators,
    pictures: pictures ?? this.pictures,
  );

  Map<String, Object> toJson() => <String, Object>{
    'items': items,
    'counts': counts,
    'creators': creators,
    'pictures': pictures,
  };

  @override
  bool operator ==(Object other) =>
      other is CultureOptions &&
      other.items == items &&
      other.counts == counts &&
      other.creators == creators &&
      other.pictures == pictures;

  @override
  int get hashCode => Object.hash(items, counts, creators, pictures);

  @override
  String toString() =>
      'CultureOptions(items: $items, counts: $counts, creators: $creators, '
      'pictures: $pictures)';
}
