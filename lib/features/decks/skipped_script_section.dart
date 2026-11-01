import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../languages/language_skills_sheet.dart';
import '../languages/language_views.dart';
import '../profiles/spoken_languages_picker.dart' show SpokenLanguagesPicker;
import 'path_model.dart';

/// The decks of a script the learner does not learn, under the course's
/// path (owner's choice C of `skill-pills-onboarding` screen 4,
/// 2026-11-01): a box naming the script, how many decks and cards it holds,
/// why they are not on the path and an Add it button that opens the
/// language's skills sheet, and the decks listed under it, each opening its
/// own screen.
class SkippedScriptSection extends StatefulWidget {
  const SkippedScriptSection({
    super.key,
    required this.view,
    required this.skipped,
    required this.deckRows,
    this.spokenList,
  });

  final CourseView view;
  final SkippedScript skipped;

  /// The decks' rows, as "Other decks" draws them.
  final List<Widget> deckRows;

  /// The catalog of languages, in place of the asset: for tests.
  final List<SpokenLanguage>? spokenList;

  @override
  State<SkippedScriptSection> createState() => _SkippedScriptSectionState();
}

class _SkippedScriptSectionState extends State<SkippedScriptSection> {
  Future<List<SpokenLanguage>>? _catalog;

  Future<List<SpokenLanguage>> _load(BuildContext context) =>
      _catalog ??= widget.spokenList != null
      ? Future<List<SpokenLanguage>>.value(widget.spokenList)
      : DefaultAssetBundle.of(context)
            .loadString(SpokenLanguagesPicker.asset)
            .then(parseSpokenLanguages);

  Future<void> _add() async {
    final state = AppScope.read(context);
    final code = widget.view.language.code;
    final all = await _load(context);
    if (!mounted) return;
    final views = languageViews(state, all).where((v) => v.code == code);
    if (views.isEmpty) return;
    await showLanguageSkills(context, state, all, views.first);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.view;
    final first = widget.skipped.decks.first;
    final script = l10n.scriptNameOr(widget.skipped.script, view.language.name);
    final learned = <String>[
      for (final s in state.learnedScripts(view.language))
        l10n.scriptNameOr(s, view.language.name),
    ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    DeckGlyph(
                      glyph: first.glyph,
                      language: first.language,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.pathSkippedScriptTitle(script),
                              style: theme.textTheme.titleSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            l10n.pathSkippedScriptCount(
                              widget.skipped.decks.length,
                              widget.skipped.cards,
                            ),
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.pathSkippedScriptWhy(view.language.name, learned),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: l10n.pathSkippedScriptAddSemantics(script),
                  excludeSemantics: true,
                  onTap: _add,
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('skipped-script-add'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.pathSkippedScriptAdd),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GroupedList(
          outerRadius: AppRadii.card,
          gap: 4,
          children: widget.deckRows,
        ),
      ],
    );
  }
}
