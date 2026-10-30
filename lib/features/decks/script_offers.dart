import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/models/deck.dart';
import '../../core/search/script_of.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../profiles/spoken_languages_picker.dart';

/// What the search says about a query typed in a script the course does not
/// read (#527, mockup section 7): the courses the learner has that use it
/// (Switch), and, when none does, the courses of the catalog written in it
/// (Add the course); and, for a script that is not yet one of the learner's
/// own, each language written in it to add to the languages they know, one
/// row per language, leaving out those they already have a course in.
class ScriptOffers extends StatefulWidget {
  const ScriptOffers({
    super.key,
    required this.script,
    required this.shown,
    this.spokenList,
  });

  /// The script the query is typed in, as deck files name it.
  final String script;

  /// The course the search is in.
  final LanguageInfo shown;

  /// The catalog of languages, in place of the asset: for tests.
  final List<SpokenLanguage>? spokenList;

  @override
  State<ScriptOffers> createState() => _ScriptOffersState();
}

class _ScriptOffersState extends State<ScriptOffers> {
  Future<List<SpokenLanguage>>? _catalog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalog ??= widget.spokenList != null
        ? Future<List<SpokenLanguage>>.value(widget.spokenList)
        : DefaultAssetBundle.of(context)
              .loadString(SpokenLanguagesPicker.asset)
              .then(parseSpokenLanguages);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final script = widget.script;
    final scriptName = l10n.scriptNameOr(script, widget.shown.name);
    final others = <LanguageInfo>[
      for (final language in state.languageChoices)
        if (language.code != widget.shown.code &&
            scriptBelongsTo(script, language.allScripts))
          language,
    ];
    final learning = state.learningCodes;
    final spoken = state.settings.spokenLanguages;

    Widget row({
      required String title,
      required String line,
      required String button,
      required VoidCallback onPressed,
    }) => ListTile(
      title: Text(title),
      subtitle: Text(line),
      trailing: FilledButton.tonal(onPressed: onPressed, child: Text(button)),
    );

    return FutureBuilder<List<SpokenLanguage>>(
      future: _catalog,
      builder: (context, snapshot) {
        final catalog = snapshot.data ?? const <SpokenLanguage>[];
        bool writtenIn(SpokenLanguage l) => scriptBelongsTo(script, l.scripts);
        final offered = <String>{
          for (final l in state.languagesOnOffer) l.code,
        };
        final nativeScripts = <String>{
          for (final l in catalog)
            if (spoken.contains(l.code)) ...l.scripts,
        };
        final courses = <SpokenLanguage>[
          if (others.isEmpty)
            for (final l in catalog)
              if (writtenIn(l) &&
                  offered.contains(l.code) &&
                  !learning.contains(l.code))
                l,
        ];
        final known = <SpokenLanguage>[
          if (!scriptBelongsTo(script, nativeScripts))
            for (final l in catalog)
              if (writtenIn(l) &&
                  !spoken.contains(l.code) &&
                  !learning.contains(l.code))
                l,
        ];
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 12),
          child: Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.card),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
                  child: Text(
                    others.isEmpty
                        ? l10n.searchScriptNoCourse
                        : l10n.searchScriptNotHere,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  child: Text(
                    l10n.searchScriptTyped(scriptName),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final language in others)
                  row(
                    title: l10n.searchScriptSwitchTitle(language.name),
                    line: l10n.searchScriptIsTarget(scriptName),
                    button: l10n.searchSwitch,
                    onPressed: () => state.showLanguage(language.code),
                  ),
                for (final course in courses)
                  row(
                    title: l10n.searchAddCourse(course.name),
                    line: l10n.searchAddCourseLine(scriptName),
                    button: l10n.searchAdd,
                    onPressed: () => AppNavigator.openLearnLanguages(context),
                  ),
                for (final language in known)
                  row(
                    title: l10n.searchAddKnown(language.name),
                    line: l10n.searchAddKnownLine(language.name, scriptName),
                    button: l10n.searchAdd,
                    onPressed: () => state.settings.spokenLanguages = <String>[
                      ...state.settings.spokenLanguages,
                      language.code,
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
