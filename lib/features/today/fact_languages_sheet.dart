import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';
import '../profiles/spoken_languages_picker.dart' show SpokenLanguagesPicker;

/// The small button at the top left of Today's fact card (#926): it opens
/// the choice of the languages the fact is shown in. Icon only, so it has a
/// hint and a screen-reader label; its tap target is 48 dp.
class FactLanguagesButton extends StatelessWidget {
  const FactLanguagesButton({super.key, this.spokenList});

  /// The languages of `assets/languages.yaml`, for a test; null reads them
  /// from the asset bundle when the sheet opens.
  final List<SpokenLanguage>? spokenList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Hint(
      message: l10n.hintFactLanguages,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: l10n.factLanguagesLabel,
        excludeSemantics: true,
        child: Material(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: InkWell(
            key: const ValueKey<String>('fact-languages-button'),
            borderRadius: BorderRadius.circular(AppRadii.field),
            onTap: () => FactLanguagesSheet.show(context, spokenList),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.translate,
                size: 22,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The name of the language [code]: from [all] (the languages of
/// `assets/languages.yaml`), else from the courses, else the code itself.
String factLanguageName(
  AppState state,
  List<SpokenLanguage>? all,
  String code,
) {
  for (final language in all ?? const <SpokenLanguage>[]) {
    if (language.code == code) return language.name;
  }
  for (final language in state.languages) {
    if (language.code == code) return language.name;
  }
  return code;
}

/// The languages the learner knows, each with a box; the fact is shown in
/// the checked ones. The last checked box cannot be unchecked.
class FactLanguagesSheet extends StatefulWidget {
  const FactLanguagesSheet({super.key, this.spokenList});

  final List<SpokenLanguage>? spokenList;

  /// Opens the sheet over [context]: from Today's fact card and from the
  /// Settings row, which write the same setting.
  static Future<void> show(
    BuildContext context, [
    List<SpokenLanguage>? spokenList,
  ]) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FactLanguagesSheet(spokenList: spokenList),
  );

  @override
  State<FactLanguagesSheet> createState() => _FactLanguagesSheetState();
}

class _FactLanguagesSheetState extends State<FactLanguagesSheet> {
  List<SpokenLanguage>? _all;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    _all = widget.spokenList;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked || _all != null) return;
    _asked = true;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPicker.asset)
        .then(parseSpokenLanguages)
        .then((list) {
          if (mounted) setState(() => _all = list);
        }, onError: (Object _) {});
  }

  String _name(AppState state, String code) =>
      factLanguageName(state, _all, code);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final known = state.factLanguageChoices;
        final checked = state.factLanguagesChecked;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 8,
                    bottom: 8,
                  ),
                  child: Text(
                    l10n.factLanguagesTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final code in known)
                  CheckboxListTile(
                    key: ValueKey<String>('fact-language-$code'),
                    value: checked.contains(code),
                    title: Text(_name(state, code)),
                    subtitle: checked.length == 1 && checked.contains(code)
                        ? Text(l10n.factLanguagesLast)
                        : null,
                    // The last checked box stays: the fact is always shown.
                    onChanged: checked.length == 1 && checked.contains(code)
                        ? null
                        : (_) => state.toggleFactLanguage(code),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
