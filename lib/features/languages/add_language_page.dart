import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/language_skills.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import 'language_pick_list.dart';
import 'language_skills_sheet.dart';
import 'language_views.dart';

/// "Add a language" (#907): a search over every language, grouped by family
/// ([LanguagePickList]). Picking one opens its sheet as a draft: nothing is
/// saved until "Add". Adding pops this page, back to the list.
class AddLanguagePage extends StatefulWidget {
  const AddLanguagePage({
    super.key,
    required this.spokenList,
    this.initialQuery,
  });

  final List<SpokenLanguage> spokenList;

  /// What the search holds on opening, such as a course's name (#918).
  final String? initialQuery;

  @override
  State<AddLanguagePage> createState() => _AddLanguagePageState();
}

class _AddLanguagePageState extends State<AddLanguagePage> {
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
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languagesAddTitle)),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: state.settings,
          builder: (context, _) => LanguagePickList(
            views: languageViews(state, widget.spokenList),
            initialQuery: widget.initialQuery,
            isAdded: (v) => !state.skillsOf(v.language).isAllLeave,
            onPick: _pick,
          ),
        ),
      ),
    );
  }
}
