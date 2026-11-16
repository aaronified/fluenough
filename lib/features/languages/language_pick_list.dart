import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/decks/language_catalog.dart' show B1Progress;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../downloads/app_update_needed.dart';
import '../placement/course_line.dart';
import '../private/private_widgets.dart';
import 'language_views.dart';
import 'languages_page.dart' show LanguageSection;
import 'verification_mark.dart';

/// How many big tiles the first screen shows.
const int languageTileCount = 8;

/// The list a learner picks a language from (#907), shared by the Add a
/// language page and the first launch (the approved mockup
/// `docs/mockups/language-picker.html`, owner, 2026-11-16).
///
/// It opens on "What do you want to learn?": a search and eight big tiles,
/// the first eight `popular` languages in the order of
/// `assets/languages.yaml`, each with its name in its own script, its English
/// name and one line derived from the course ("A1 to B1 ready", "A1 and A2
/// ready", "A1 ready", "Beginner course", "First words only"), then "See all
/// languages". The full list has one key at the top (how much of the course
/// is made, and what the verification flags mean), then "Languages", A to Z,
/// only those that have a course, each with a slim four-part bar and a
/// verification flag; "Scripts and sounds" (the notations, with neither bar
/// nor flag); and "Coming soon", folded, with the languages that have no
/// course, which cannot be picked. A search, typed on either screen, shows
/// the full list with the matches, Popular ones first, and opens Coming soon
/// where it holds one. A language already on the learner's list shows an
/// "Added" badge, and a course this app is too old to read says which app
/// version it needs.
///
/// A [ListView], so it fills the space it is given; the page around it owns
/// the title and what a pick does ([onPick]).
class LanguagePickList extends StatefulWidget {
  const LanguagePickList({
    super.key,
    required this.views,
    required this.onPick,
    required this.isAdded,
    this.initialQuery,
    this.header,
  });

  /// Every language, with its course where there is one, in the order of
  /// `assets/languages.yaml` (the tiles read their order from it).
  final List<LanguageView> views;

  /// Called with the language a tap picked; not called for a course this app
  /// is too old to read, whose row opens the app's download instead.
  final void Function(LanguageView view) onPick;

  /// Whether the learner's list holds [view] already.
  final bool Function(LanguageView view) isAdded;

  /// What the search holds on opening, such as a course's name (#918).
  final String? initialQuery;

  /// Scrolls with the list, above the search.
  final Widget? header;

  @override
  State<LanguagePickList> createState() => _LanguagePickListState();
}

class _LanguagePickListState extends State<LanguagePickList> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery,
  );

  /// "See all languages" was tapped.
  bool _showAll = false;

  /// What a tap on the Coming soon header chose; null follows the search
  /// (open where it holds a match), else folded.
  bool? _soonOverride;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _soonOverride = null));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static int _byName(LanguageView a, LanguageView b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.code.compareTo(b.code);
  }

  /// What a tap on [view] does: picks it, or opens the app's download for a
  /// course this app is too old to read.
  void _pick(BuildContext context, LanguageView view) {
    final haptics = AppScope.maybeRead(context)?.haptics;
    if (view.needsApp == null) {
      widget.onPick(view);
    } else {
      openAppUpdate(context);
    }
    haptics?.tap();
  }

  /// How much of [view]'s course is written, as the learner would take it.
  B1Progress? _progress(BuildContext context, LanguageView view) {
    final state = AppScope.read(context);
    return view.course?.progressFor(
      state.settings.spokenLanguages,
      native: state.courseNative(view.code),
    );
  }

  /// The one line of a tile, from the levels the course has written to
  /// their end.
  String _status(BuildContext context, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final progress = _progress(context, view);
    if (progress == null) return l10n.languagesNoDecksLabel;
    if (progress.builtLevel >= 3) return l10n.languagesTileStatusA1B1;
    if (progress.builtLevel == 2) return l10n.languagesTileStatusA1A2;
    if (progress.builtLevel == 1) return l10n.languagesTileStatusA1;
    final started = progress.levels.isNotEmpty && progress.levels.first > 0;
    return started
        ? l10n.languagesTileStatusBeginner
        : l10n.languagesFirstWordsLabel;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _search.text.trim();
    final searching = query.isNotEmpty;
    var matching = <LanguageView>[
      for (final v in widget.views)
        if (!searching || v.language.matches(query)) v,
    ]..sort(_byName);
    // A search lists the popular languages first, as it always has.
    if (searching) {
      matching = <LanguageView>[
        for (final v in matching)
          if (v.language.popular) v,
        for (final v in matching)
          if (!v.language.popular) v,
      ];
    }
    final withCourse = <LanguageView>[
      for (final v in matching)
        if (v.course != null && !v.language.isNotation) v,
    ];
    final notations = <LanguageView>[
      for (final v in matching)
        if (v.language.isNotation) v,
    ];
    final soon = <LanguageView>[
      for (final v in matching)
        if (v.course == null && !v.language.isNotation) v,
    ];
    // A search that finds a language in Coming soon opens the group; a tap
    // on its header still closes or opens it.
    final soonOpen = _soonOverride ?? (searching && soon.isNotEmpty);
    // Every side of the list is padded by its children.
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: child,
    );
    Widget heading(String text, {double top = 0}) => pad(
      Padding(
        padding: EdgeInsetsDirectional.only(top: top),
        child: Semantics(header: true, child: LanguageSection(text: text)),
      ),
    );
    final searchField = pad(
      TextField(
        key: const ValueKey<String>('languages-add-search'),
        controller: _search,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: l10n.languagesAddSearch,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    // The tiles: the first eight popular languages, in the file's order.
    final tiles = <LanguageView>[
      for (final v in widget.views)
        if (v.language.popular && !v.language.isNotation && v.course != null) v,
    ].take(languageTileCount).toList();
    final showTiles = !_showAll && !searching && tiles.isNotEmpty;
    final children = <Widget>[
      if (widget.header case final header?) pad(header),
      if (showTiles) ...<Widget>[
        pad(
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, bottom: 12),
            child: Semantics(
              header: true,
              child: Text(
                l10n.languagesAddQuestion,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
        ),
        searchField,
        pad(
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 16, bottom: 8),
            child: _tileGrid(context, tiles),
          ),
        ),
        Center(
          child: TextButton.icon(
            key: const ValueKey<String>('languages-see-all'),
            onPressed: () => setState(() => _showAll = true),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right),
            label: Text(l10n.languagesSeeAll),
          ),
        ),
      ] else ...<Widget>[
        // A slot where the question was, so the search field keeps its place
        // in the list and its focus while the learner types.
        const SizedBox.shrink(),
        searchField,
        if (withCourse.isNotEmpty) pad(const VerificationKey()),
        if (matching.isEmpty)
          pad(
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 24),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.languagesAddNoMatch(query),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        if (withCourse.isNotEmpty) ...<Widget>[
          heading(l10n.languagesAllLanguages, top: 4),
          for (final v in withCourse) pad(_row(context, v)),
        ],
        if (notations.isNotEmpty) ...<Widget>[
          heading(l10n.languagesScriptsAndSounds, top: 8),
          pad(
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 2),
              child: Text(
                l10n.languagesScriptsAndSoundsNote,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final v in notations) pad(_row(context, v)),
        ],
        if (soon.isNotEmpty) ...<Widget>[
          pad(_soonHeader(context, soonOpen)),
          if (soonOpen) for (final v in soon) pad(_soonRow(context, v)),
        ],
      ],
    ];
    return PopScope(
      // Back from the full list goes back to the tiles, not out of the page.
      canPop: !_showAll,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _search.clear();
          setState(() => _showAll = false);
        }
      },
      child: ListView(
        padding: const EdgeInsetsDirectional.only(top: 8, bottom: 24),
        children: children,
      ),
    );
  }

  /// The tiles, two even columns, the two of a row of equal height.
  Widget _tileGrid(BuildContext context, List<LanguageView> tiles) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final second = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _tile(context, tiles[i])),
                const SizedBox(width: 8),
                Expanded(
                  child: second == null
                      ? const SizedBox.shrink()
                      : _tile(context, second),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  /// A big tile: the name in its own script, the English name and one line;
  /// a language already added is filled and says so.
  Widget _tile(BuildContext context, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final added = widget.isAdded(view);
    final needs = view.needsApp;
    final haptics = AppScope.maybeRead(context)?.haptics;
    final own = view.language.ownName.split(' · ').first;
    final native = own.isEmpty ? view.name : own;
    final status = needs != null
        ? l10n.appUpdateNeeded(needs)
        : _status(context, view);
    final onColor = added ? scheme.onPrimaryContainer : scheme.onSurface;
    final muted = added ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: <String>[
        view.name,
        if (native != view.name) native,
        status,
        if (added) l10n.languagesAdded,
      ].join(l10n.commonListSeparator),
      onTap: () => _pick(context, view),
      excludeSemantics: true,
      child: Material(
        color: added ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: added
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('tile-${view.code}'),
          enableFeedback: haptics?.takesOverFeedback != true,
          onTap: () => _pick(context, view),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    native,
                    style: theme.textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: onColor,
                    ),
                  ),
                  if (native != view.name)
                    Text(
                      view.name,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: onColor,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        if (added)
                          TextSpan(
                            text: '${l10n.languagesAdded} · ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: status),
                      ],
                    ),
                    style: theme.textTheme.bodySmall!.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The header of Coming soon: its label and a chevron, no count.
  Widget _soonHeader(BuildContext context, bool open) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            expanded: open,
            // hint-ok: shows text
            child: InkWell(
              key: const ValueKey<String>('languages-coming-soon'),
              onTap: () => setState(() => _soonOverride = !open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.languagesComingSoon,
                          style: theme.textTheme.titleSmall!.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(open ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A language in Coming soon: its names only, muted but readable, with no
  /// chevron and no press, because nothing can be learned yet.
  Widget _soonRow(BuildContext context, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final own = view.language.ownName;
    return Semantics(
      label: l10n.languagesNoCourseLabel(view.name),
      excludeSemantics: true,
      child: ConstrainedBox(
        key: ValueKey<String>('soon-${view.code}'),
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  view.glyph,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      view.name,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (own.isNotEmpty && own != view.name)
                      Text(
                        own,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One language of the list: a glyph, its names, "Added" where it is, and
  /// for a language with a course the four-part bar and the verification
  /// flag on a line under the names (the glyph's 36 dp and its gap indent
  /// it). A notation is no language to measure against A1, A2 and B1 and has
  /// no native speakers, so it has neither.
  Widget _row(BuildContext context, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final added = widget.isAdded(view);
    final own = view.language.ownName;
    // A course this app is too old to read is shown greyed, with the app
    // version it needs; a tap opens where the app is downloaded (ADR-0052).
    final needs = view.needsApp;
    final haptics = AppScope.maybeRead(context)?.haptics;
    final progress = _progress(context, view);
    final levels = progress?.levels ?? const <double>[0, 0, 0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // One button for a screen reader, reading the names and the badge.
        MergeSemantics(
          child: Semantics(
            button: true,
            // hint-ok: shows text
            child: InkWell(
              key: ValueKey<String>('add-${view.code}'),
              enableFeedback: haptics?.takesOverFeedback != true,
              onTap: () => _pick(context, view),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: needs != null
                              ? scheme.surfaceContainerHighest
                              : added
                              ? scheme.primary
                              : scheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          view.glyph,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1,
                            color: needs != null
                                ? scheme.onSurfaceVariant
                                : added
                                ? scheme.onPrimary
                                : scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            view.name,
                            style: theme.textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: needs != null
                                  ? scheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          if (needs != null)
                            Text(
                              l10n.appUpdateNeeded(needs),
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          if (own.isNotEmpty && own != view.name)
                            Text(
                              own,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          PrivateLanguageTag(language: view.language),
                        ],
                      ),
                    ),
                    if (needs != null)
                      Text(
                        l10n.appUpdateAction,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (added)
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.check,
                              size: 16,
                              color: scheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.languagesAdded,
                              style: theme.textTheme.labelMedium!.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!view.language.isNotation && view.course != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: CourseLine(
                    key: ValueKey<String>('course-line-${view.code}'),
                    compact: true,
                    levels: levels,
                    culture: progress?.culture ?? 0,
                    // A course with nothing written but first words says so.
                    label: levels.every((x) => x == 0)
                        ? l10n.languagesFirstWordsLabel
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                VerificationFlagButton(
                  key: ValueKey<String>('flag-${view.code}'),
                  state: view.language.verification,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
