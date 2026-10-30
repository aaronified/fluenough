import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/language_skills.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'language_skills_sheet.dart';
import 'language_views.dart';

/// "Add a language" (#907): a search over every language, grouped by family.
/// Picking one opens its sheet as a draft: nothing is saved until "Add".
/// Adding pops this page, back to the list.
class AddLanguagePage extends StatefulWidget {
  const AddLanguagePage({super.key, required this.spokenList});

  final List<SpokenLanguage> spokenList;

  @override
  State<AddLanguagePage> createState() => _AddLanguagePageState();
}

class _AddLanguagePageState extends State<AddLanguagePage> {
  final TextEditingController _search = TextEditingController();

  /// The order families are listed in; a language with none, or an unknown
  /// one, goes last.
  static const List<String> _families = <String>[
    'indo_aryan',
    'dravidian',
    'tibeto_burman',
    'austroasiatic',
    'germanic',
    'romance',
    'sinitic',
    'koreanic',
    'japonic',
    'constructed',
  ];

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

  Future<void> _pick(LanguageView view) async {
    final state = AppScope.read(context);
    final all = widget.spokenList;
    final held = <LanguageView>[
      for (final v in languageViews(state, all))
        if (!state.skillsOf(v.language).isAllLeave) v,
    ];
    final added = held.any((v) => v.code == view.code);
    final added2 = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LanguageSkillsSheet(
        view: view,
        draft: !added,
        others: <String, LanguageSkills>{
          for (final v in held)
            if (v.code != view.code) v.name: state.skillsOf(v.language),
        },
        names: <String, String>{for (final l in all) l.code: l.name},
      ),
    );
    if (added2 == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final views = languageViews(state, widget.spokenList);
    final query = _search.text.trim();
    final matching = <LanguageView>[
      for (final v in views)
        if (query.isEmpty || v.language.matches(query)) v,
    ];
    final groups = <String?, List<LanguageView>>{};
    for (final v in matching) {
      final family = _families.contains(v.language.family)
          ? v.language.family
          : null;
      groups.putIfAbsent(family, () => <LanguageView>[]).add(v);
    }
    final order = <String?>[..._families, null];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languagesAddTitle)),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: state.settings,
          builder: (context, _) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
            children: <Widget>[
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
                    padding: const EdgeInsetsDirectional.only(
                      top: 12,
                      bottom: 2,
                    ),
                    child: Text(
                      l10n.knownFamily(family ?? 'other'),
                      style: theme.textTheme.titleSmall!.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final v in list) _row(context, state, v),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppState state, LanguageView view) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final added = !state.skillsOf(view.language).isAllLeave;
    final own = view.language.ownName;
    return InkWell(
      key: ValueKey<String>('add-${view.code}'),
      onTap: () => _pick(view),
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
                  color: added ? scheme.primary : scheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  view.glyph,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1,
                    color: added
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
            if (added)
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
