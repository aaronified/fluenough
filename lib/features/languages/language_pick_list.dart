import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../downloads/app_update_needed.dart';
import 'language_views.dart';

/// The list a learner picks a language from (#907), shared by the Add a
/// language page and the first launch (owner, 2026-11-01): a search over each
/// language's name, own name and aliases, then the languages grouped by
/// family, each a glyph row marked "No course yet" where nothing can be
/// learned, or with the app version its course needs. A language already on
/// the learner's list shows an "Added" badge.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _search.text.trim();
    final matching = <LanguageView>[
      for (final v in widget.views)
        if (query.isEmpty || v.language.matches(query)) v,
    ];
    final groups = <String?, List<LanguageView>>{};
    for (final v in matching) {
      final family = languageFamilies.contains(v.language.family)
          ? v.language.family
          : null;
      groups.putIfAbsent(family, () => <LanguageView>[]).add(v);
    }
    final order = <String?>[...languageFamilies, null];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: <Widget>[
        ?widget.header,
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
        if (matching.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 24),
            child: Text(
              l10n.languagesAddNoMatch(query),
              textAlign: TextAlign.center,
            ),
          ),
        for (final family in order)
          if (groups[family] case final list?) ...<Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 12, bottom: 2),
              child: Text(
                l10n.knownFamily(family ?? 'other'),
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final v in list) _row(context, v),
          ],
      ],
    );
  }

  Widget _row(BuildContext context, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final added = widget.isAdded(view);
    final own = view.language.ownName;
    // A course this app is too old to read is shown greyed, with the app
    // version it needs; a tap opens where the app is downloaded (ADR-0052).
    final needs = view.needsApp;
    // hint-ok: shows text
    return InkWell(
      key: ValueKey<String>('add-${view.code}'),
      onTap: needs == null
          ? () => widget.onPick(view)
          : () => openAppUpdate(context),
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
    );
  }
}
