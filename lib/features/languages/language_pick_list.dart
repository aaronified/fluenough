import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../downloads/app_update_needed.dart';
import '../placement/course_line.dart';
import 'language_views.dart';
import 'languages_page.dart' show LanguageSection;
import 'verification_mark.dart';

/// The list a learner picks a language from (#907), shared by the Add a
/// language page and the first launch (owner, 2026-11-01): a search over each
/// language's name, own name and aliases, a key to the verification marks,
/// the Popular languages (`popular` in `assets/languages.yaml`), then every
/// language in one alphabetical list by the name shown (not grouped by
/// family: owner, 2026-11-06). Each is a glyph row marked "No course yet"
/// where nothing can be learned, or with the app version its course needs,
/// and under its names the course's A1, A2, B1 line and whether native
/// speakers have checked it. A language already on the learner's list shows
/// an "Added" badge. A search collapses the two sections into one list,
/// Popular matches first.
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

  /// Every language, with its course where there is one.
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

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _search.text.trim();
    final searching = query.isNotEmpty;
    final matching = <LanguageView>[
      for (final v in widget.views)
        if (!searching || v.language.matches(query)) v,
    ]..sort(_byName);
    final popular = <LanguageView>[
      for (final v in matching)
        if (v.language.popular) v,
    ];
    // Every side of the list is padded by its children, so that the key's
    // row can run edge to edge and fade at the screen's edges.
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
    return ListView(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 24),
      children: <Widget>[
        if (widget.header case final header?) pad(header),
        pad(
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
        ),
        const VerificationKey(),
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
          )
        else if (searching) ...<Widget>[
          // One list, Popular matches first, each language once, no headings.
          for (final v in popular) pad(_row(context, v)),
          for (final v in matching)
            if (!v.language.popular) pad(_row(context, v)),
        ] else ...<Widget>[
          if (popular.isNotEmpty) ...<Widget>[
            heading(l10n.languagesPopular),
            pad(
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 2),
                child: Text(
                  l10n.languagesPopularNote,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // Their own keys: a Popular language is in the full list too.
            for (final v in popular) pad(_row(context, v, popular: true)),
          ],
          heading(l10n.languagesAllLanguages, top: popular.isEmpty ? 0 : 8),
          for (final v in matching) pad(_row(context, v)),
        ],
      ],
    );
  }

  /// How much of A1, A2 and B1 is written for [view], and what a screen
  /// reader reads for a line with nothing in it: no decks yet, or only first
  /// words (a course, no path written).
  (List<double>, String?) _line(BuildContext context, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final progress = view.course?.progressFor(
      state.settings.spokenLanguages,
      native: state.courseNative(view.code),
    );
    final levels = progress?.levels ?? const <double>[0, 0, 0];
    if (view.course == null) return (levels, l10n.languagesNoDecksLabel);
    if (levels.every((x) => x == 0)) {
      return (levels, l10n.languagesFirstWordsLabel);
    }
    return (levels, null);
  }

  Widget _row(BuildContext context, LanguageView view, {bool popular = false}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final added = widget.isAdded(view);
    final own = view.language.ownName;
    // A course this app is too old to read is shown greyed, with the app
    // version it needs; a tap opens where the app is downloaded (ADR-0052).
    final needs = view.needsApp;
    final haptics = AppScope.maybeRead(context)?.haptics;
    final (levels, lineLabel) = _line(context, view);
    // hint-ok: shows text
    return InkWell(
      key: ValueKey<String>(
        popular ? 'add-popular-${view.code}' : 'add-${view.code}',
      ),
      enableFeedback: haptics?.takesOverFeedback != true,
      onTap: () {
        if (needs == null) {
          widget.onPick(view);
        } else {
          openAppUpdate(context);
        }
        haptics?.tap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConstrainedBox(
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
                          color: needs != null ? scheme.onSurfaceVariant : null,
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
                  )
                else if (!view.canLearn)
                  Text(
                    l10n.languagesNoCourse,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          // The two markers, under the names (the glyph's 36 dp and its gap
          // indent them): the course's line, the one new state of which is
          // the empty line, and whether native speakers have checked it.
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 48,
              top: 2,
              bottom: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CourseLine(levels: levels, label: lineLabel),
                // A notation has no native speakers to have checked it.
                if (!view.language.isNotation) ...<Widget>[
                  const SizedBox(height: 6),
                  VerificationMark(state: view.language.verification),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
