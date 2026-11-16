/// A language's culture options (the approved mockup `culture-in-decks`): the
/// four choices the learner makes in the language's details, each language
/// keeping its own. Pure Dart, free of Flutter, so that it is tested in
/// milliseconds; the settings store one per language.
library;

/// The culture options of one language. Immutable: change one with
/// [copyWith] and hand it back to the settings.
class CultureOptions {
  const CultureOptions({
    this.items = true,
    this.showAbove = false,
    this.counts = false,
    this.creators = true,
  });

  /// What a language that has not chosen yet has: items on, those above the
  /// level left out, culture a bonus, creators shown.
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
      showAbove: read('show_above', defaults.showAbove),
      counts: read('counts', defaults.counts),
      creators: read('creators', defaults.creators),
    );
  }

  /// Whether culture items (a proverb, a line of verse, a passage) are in the
  /// path, on Today and in reviews. Off, they can still be read and searched.
  final bool items;

  /// "Items above my level": true shows those above the learner's level in
  /// the path and on Today as previews that open to read but cannot be
  /// learned; false (Hide) leaves them out. Reviews never include one.
  final bool showAbove;

  /// Whether a woven culture item counts as a step of its unit; false makes
  /// it a bonus.
  final bool counts;

  /// Whether an item shows its creator and what still lives today.
  final bool creators;

  CultureOptions copyWith({
    bool? items,
    bool? showAbove,
    bool? counts,
    bool? creators,
  }) => CultureOptions(
    items: items ?? this.items,
    showAbove: showAbove ?? this.showAbove,
    counts: counts ?? this.counts,
    creators: creators ?? this.creators,
  );

  Map<String, Object> toJson() => <String, Object>{
    'items': items,
    'show_above': showAbove,
    'counts': counts,
    'creators': creators,
  };

  @override
  bool operator ==(Object other) =>
      other is CultureOptions &&
      other.items == items &&
      other.showAbove == showAbove &&
      other.counts == counts &&
      other.creators == creators;

  @override
  int get hashCode => Object.hash(items, showAbove, counts, creators);

  @override
  String toString() =>
      'CultureOptions(items: $items, showAbove: $showAbove, '
      'counts: $counts, creators: $creators)';
}
