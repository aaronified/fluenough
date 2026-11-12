/// The timeline's events in the order a screen draws them (wiki
/// Plan-Deck-Kinds-And-Topics.md, D5c, T20): the works of the culture items
/// at the learner's level, a creator's legacy items with a year, and "today"
/// at the right end. [buildTimeline] works out what is on the line; this turns
/// it into one chronological list with the era each event falls in, so that
/// the strip and the full screen read the same. Pure, free of Flutter.
library;

import '../models/creator.dart';
import 'timeline.dart';
import 'weave.dart';

/// What a timeline event is.
enum TimelineEntryKind { work, legacy, today }

/// One event of the line.
class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.year,
    this.item,
    this.creator,
    this.legacy,
    this.era,
  });

  final TimelineEntryKind kind;
  final int year;

  /// The culture item of a work.
  final CultureItem? item;

  /// The creator of a work or of a legacy item.
  final Creator? creator;
  final LegacyItem? legacy;

  /// The era the event falls in: the creator's, else the band holding the
  /// year.
  final CreatorEra? era;
}

/// The works [items] hold, as [buildTimeline] reads them.
List<TimelineWork> timelineWorksOf(Iterable<CultureItem> items) =>
    <TimelineWork>[
      for (final item in items)
        if (item.source?.year != null && item.creators.isNotEmpty)
          TimelineWork(
            cardId: item.id,
            creatorIds: item.creators,
            year: item.source!.year!,
            level: item.level,
            deckId: item.deckId,
          ),
    ];

/// The events of [timeline] in order, ending with "today". A work is matched
/// to its culture item by [itemsById]; one with no item is left out.
List<TimelineEntry> timelineEntriesOf(
  Timeline timeline,
  CreatorsFile file,
  Map<String, CultureItem> itemsById,
) {
  if (timeline.isEmpty) return const <TimelineEntry>[];
  CreatorEra? eraAt(int year, Creator? creator) {
    final own = file.eraById(creator?.era);
    if (own != null) return own;
    for (final band in timeline.bands) {
      if (year >= band.from && year <= band.to) return band.era;
    }
    return null;
  }

  final entries = <TimelineEntry>[];
  for (final mark in timeline.works) {
    final item = itemsById[mark.work.cardId];
    if (item == null) continue;
    final creator = mark.work.creatorIds
        .map(file.byId)
        .where((c) => c != null)
        .firstOrNull;
    entries.add(
      TimelineEntry(
        kind: TimelineEntryKind.work,
        year: mark.year,
        item: item,
        creator: creator,
        era: eraAt(mark.year, creator),
      ),
    );
  }
  for (final mark in timeline.legacy) {
    final creator = file.byId(mark.creatorId);
    entries.add(
      TimelineEntry(
        kind: TimelineEntryKind.legacy,
        year: mark.year,
        creator: creator,
        legacy: mark.item,
        era: eraAt(mark.year, creator),
      ),
    );
  }
  entries.sort((a, b) => a.year.compareTo(b.year));
  entries.add(TimelineEntry(kind: TimelineEntryKind.today, year: timeline.end));
  return List<TimelineEntry>.unmodifiable(entries);
}
