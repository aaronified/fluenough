/// The timeline of a language's culture, derived from its creators and the
/// works its cards quote (wiki/Plan-Deck-Kinds-And-Topics.md, D5c): a creator
/// is a span from their birth to their death, open for a living creator, a
/// work is a point (or a span for a range of years), a legacy item is a mark
/// after the span, the eras are the axis bands, and the line runs to the
/// present year, so "today" is its right end. A learner's level limits it as
/// every levelled item is limited (D2): only works at or below the level are
/// points. Pure functions, free of Flutter, so that it is tested without a
/// device; its screen is a later task.
library;

import '../models/card.dart';
import '../models/creator.dart';
import '../models/level.dart';

/// One work a card quotes, as the timeline needs it.
class TimelineWork {
  const TimelineWork({
    required this.cardId,
    required this.creatorIds,
    required this.year,
    this.yearEnd,
    this.level,
    this.deckId,
  });

  /// The work a [card] of a deck whose level is [deckLevel] quotes, or null
  /// for a card with no creator or no year in its source.
  static TimelineWork? fromCard(Card card, {Level? deckLevel, String? deckId}) {
    final year = card.sourceBlock?.year;
    if (card.creators.isEmpty || year == null) return null;
    return TimelineWork(
      cardId: card.id,
      creatorIds: card.creators,
      year: year,
      yearEnd: _rangeEnd(card.sourceBlock?.date, year),
      level: card.level ?? deckLevel,
      deckId: deckId,
    );
  }

  final String cardId;
  final String? deckId;
  final List<String> creatorIds;
  final int year;

  /// The last year of a range (`1892-1909`), else null.
  final int? yearEnd;

  /// The level the work suits: the card's, else its deck's.
  final Level? level;
}

int? _rangeEnd(String? date, int first) {
  if (date == null) return null;
  final years = RegExp(r'\d{3,4}')
      .allMatches(date)
      .map((m) => int.parse(m.group(0)!))
      .toList();
  if (years.length < 2) return null;
  return years[1] > first ? years[1] : null;
}

/// A creator's span.
class TimelineSpan {
  const TimelineSpan({
    required this.creator,
    required this.from,
    required this.to,
    required this.open,
    this.era,
  });

  final Creator creator;

  /// The birth year (the first year a work or the era gives when unknown).
  final int from;

  /// The death year, or today for a living creator.
  final int to;

  /// Whether the span runs to today (a living creator).
  final bool open;
  final String? era;
}

/// A work: a point, or a span when [yearEnd] is given.
class TimelineWorkMark {
  const TimelineWorkMark({
    required this.work,
    required this.year,
    this.yearEnd,
  });

  final TimelineWork work;
  final int year;
  final int? yearEnd;
}

/// A legacy item placed by its year.
class TimelineLegacyMark {
  const TimelineLegacyMark({
    required this.creatorId,
    required this.item,
    required this.year,
  });

  final String creatorId;
  final LegacyItem item;
  final int year;
}

/// An era of the axis, its open end drawn to today.
class TimelineBand {
  const TimelineBand({required this.era, required this.from, required this.to});

  final CreatorEra era;
  final int from;
  final int to;
}

class Timeline {
  const Timeline({
    required this.start,
    required this.end,
    required this.bands,
    required this.spans,
    required this.works,
    required this.legacy,
  });

  static const Timeline empty = Timeline(
    start: 0,
    end: 0,
    bands: <TimelineBand>[],
    spans: <TimelineSpan>[],
    works: <TimelineWorkMark>[],
    legacy: <TimelineLegacyMark>[],
  );

  /// The first year drawn and the last: the present year, "today".
  final int start;
  final int end;
  final List<TimelineBand> bands;
  final List<TimelineSpan> spans;
  final List<TimelineWorkMark> works;
  final List<TimelineLegacyMark> legacy;

  bool get isEmpty => spans.isEmpty && works.isEmpty;
}

/// The timeline of [file]'s creators and [works] for a learner at [level]
/// (null: a language with no levels, which is offered no levelled work).
/// [today] is the present year, the line's right end.
///
/// A work above the level is no point, and a creator only those works cite is
/// not shown (so that their name does not give the item away); a creator no
/// work cites is shown. A legacy item is a mark only for a shown creator and
/// only when it has a year no later than [today]. A work with an unknown
/// creator is left out.
Timeline buildTimeline(
  CreatorsFile file,
  Iterable<TimelineWork> works,
  Level? level, {
  required int today,
}) {
  final cited = <String>{};
  final visible = <TimelineWorkMark>[];
  for (final work in works) {
    final known = <String>[
      for (final id in work.creatorIds)
        if (file.byId(id) != null) id,
    ];
    if (known.isEmpty) continue;
    cited.addAll(known);
  }
  final shownIds = <String>{};
  for (final work in works) {
    if (!LevelGate.allows(work.level, level)) continue;
    final known = <String>[
      for (final id in work.creatorIds)
        if (file.byId(id) != null) id,
    ];
    if (known.isEmpty) continue;
    shownIds.addAll(known);
    visible.add(
      TimelineWorkMark(work: work, year: work.year, yearEnd: work.yearEnd),
    );
  }
  final spans = <TimelineSpan>[];
  final legacy = <TimelineLegacyMark>[];
  for (final creator in file.creators) {
    if (cited.contains(creator.id) && !shownIds.contains(creator.id)) continue;
    final born = creator.born?.year;
    if (born == null) continue;
    final died = creator.died?.year;
    final open = died == null && creator.living;
    final to = died ?? (open ? today : born);
    spans.add(
      TimelineSpan(
        creator: creator,
        from: born,
        to: to < born ? born : to,
        open: open,
        era: creator.era,
      ),
    );
    for (final item in creator.legacy?.items ?? const <LegacyItem>[]) {
      final year = item.year;
      if (year != null && year <= today) {
        legacy.add(
          TimelineLegacyMark(creatorId: creator.id, item: item, year: year),
        );
      }
    }
  }
  if (spans.isEmpty && visible.isEmpty) return Timeline.empty;
  spans.sort((a, b) => a.from.compareTo(b.from));
  visible.sort((a, b) => a.year.compareTo(b.year));
  legacy.sort((a, b) => a.year.compareTo(b.year));
  final years = <int>[
    for (final span in spans) span.from,
    for (final mark in visible) mark.year,
  ];
  final start = years.reduce((a, b) => a < b ? a : b);
  final bands = <TimelineBand>[
    for (final era in file.eras)
      if ((era.to ?? today) >= start)
        TimelineBand(
          era: era,
          from: era.from < start ? start : era.from,
          to: era.to ?? today,
        ),
  ];
  return Timeline(
    start: start,
    end: today,
    bands: List<TimelineBand>.unmodifiable(bands),
    spans: List<TimelineSpan>.unmodifiable(spans),
    works: List<TimelineWorkMark>.unmodifiable(visible),
    legacy: List<TimelineLegacyMark>.unmodifiable(legacy),
  );
}
