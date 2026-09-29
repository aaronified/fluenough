import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import 'incoming.dart';

/// A deck's one character on a rounded `secondaryContainer` tile.
///
/// Sizes in the design: 56 on the deck list, 52 on Today and the import
/// preview, 64 on a deck's screen. [language] sets the locale the glyph is
/// drawn in, so a CJK character takes the right regional form.
class DeckGlyph extends StatelessWidget {
  const DeckGlyph({
    super.key,
    required this.glyph,
    this.language,
    this.size = 56,
  });

  final String glyph;
  final LanguageInfo? language;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = language?.code;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Text(
          glyph,
          locale: code == null ? null : Locale(code),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontSize: size * 0.43,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// The pill at the end of a deck row.
enum DeckBadgeKind {
  /// "9 due", in `primary`.
  due,

  /// "Done", when nothing in a deck the profile learns is due.
  done,

  /// "Feature incoming", for a deck this version cannot drill at all: one
  /// whose cards' drills are all incoming, such as a grammar deck before its
  /// drill (#14). Never "Done", which would claim it had been studied. Drawn as the app's
  /// [IncomingBadge], under the deck's meta line: too wide to share a phone
  /// row with the name.
  incoming,

  /// "Start", for a deck in a language the profile does not learn.
  start,

  /// A deck file that could not be read.
  error,
}

/// The badge on a deck row.
class DeckBadge extends StatelessWidget {
  const DeckBadge({super.key, required this.kind, this.count = 0});

  /// [entry]'s badge on the Decks tab and Today. A deck with nothing this
  /// version can drill is incoming. For a language the current profile
  /// learns: what a session on the deck would drill now, due and new
  /// together, or Done. Otherwise Start. Each deck's new cards are counted
  /// against the whole daily cap, so the badges can add up to more than
  /// Today's number.
  factory DeckBadge.forEntry(AppState state, DeckEntry entry) {
    if (!state.canDrill(entry)) {
      return const DeckBadge(kind: DeckBadgeKind.incoming);
    }
    if (!state.currentProfile.learns(entry.language.code)) {
      return const DeckBadge(kind: DeckBadgeKind.start);
    }
    final counts = state.countsFor(entry);
    final n = counts.due + counts.fresh;
    return n > 0
        ? DeckBadge(kind: DeckBadgeKind.due, count: n)
        : const DeckBadge(kind: DeckBadgeKind.done);
  }

  final DeckBadgeKind kind;

  /// For [DeckBadgeKind.due].
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pill = switch (kind) {
      DeckBadgeKind.due => (
        l10n.commonDueBadge(count),
        scheme.primary,
        scheme.onPrimary,
      ),
      DeckBadgeKind.done => (
        l10n.commonDoneBadge,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      DeckBadgeKind.start => (
        l10n.commonStartBadge,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      DeckBadgeKind.incoming => null,
      DeckBadgeKind.error => (
        l10n.decksBrokenBadge,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    if (pill == null) return const IncomingBadge();
    final (text, bg, fg) = pill;
    return Container(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        softWrap: false,
        style: Theme.of(context).textTheme.labelLarge!
            .copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A deck row, as Today and the deck list draw it: glyph, name, a meta line
/// ("Hindi (hin) · 40 cards"), and a badge: at the end of the row, or under
/// the meta line when it is [DeckBadgeKind.incoming]. Put it inside a
/// `GroupedList`, which gives it its background and corners.
class DeckTile extends StatelessWidget {
  const DeckTile({
    super.key,
    required this.entry,
    required this.badge,
    this.onTap,
    this.glyphSize = 56,
    this.meta,
  });

  final DeckEntry entry;
  final DeckBadge badge;
  final VoidCallback? onTap;

  /// The second line, when it is not [metaFor]'s: a theme deck shows its
  /// place on the path and its progress instead.
  final String? meta;

  /// 56 on the deck list, 52 on Today.
  final double glyphSize;

  /// The meta line for [entry]: its language, ISO 639-3 code and size.
  static String metaFor(AppLocalizations l10n, DeckEntry entry) {
    final language = entry.language;
    return entry.bundled
        ? l10n.deckMeta(language.name, language.iso639_3, entry.itemCount)
        : l10n.deckMetaImported(
            language.name,
            language.iso639_3,
            entry.itemCount,
          );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final incoming = badge.kind == DeckBadgeKind.incoming;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: <Widget>[
              DeckGlyph(
                glyph: entry.glyph,
                language: entry.language,
                size: glyphSize,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(entry.deck.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      meta ?? metaFor(l10n, entry),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (incoming) ...<Widget>[const SizedBox(height: 8), badge],
                  ],
                ),
              ),
              if (!incoming) ...<Widget>[const SizedBox(width: 12), badge],
            ],
          ),
        ),
      ),
    );
  }
}
