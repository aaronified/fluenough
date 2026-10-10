import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import 'spoken_languages_picker.dart';

/// The languages the learner knows, ticked and ranked (#53), each with
/// whether they read its script (#462), opened from Settings. Kept apart from the interface language, which is #46. The first
/// launch asks the same question inside `OnboardingFlow`.
///
/// The choices are data, `assets/languages.yaml`, so a new one needs no
/// code. The order of the ticked languages is their rank, best known first;
/// the list is reordered by dragging, and screen readers get its move
/// actions.
/// Whether every language in [known] has an explicit script answer in
/// [given] (#462): until then, Languages you know cannot be saved.
bool scriptsAnswered(List<String> known, Map<String, bool> given) =>
    known.every(given.containsKey);

class SpokenLanguagesPage extends StatefulWidget {
  const SpokenLanguagesPage({super.key, this.choices});

  /// For tests and the gallery. Null reads `assets/languages.yaml`.
  final List<SpokenLanguage>? choices;

  static const String asset = SpokenLanguagesPicker.asset;

  @override
  State<SpokenLanguagesPage> createState() => _SpokenLanguagesPageState();
}

class _SpokenLanguagesPageState extends State<SpokenLanguagesPage> {
  late List<String> _ranked = AppScope.read(context).settings.spokenLanguages;
  late Map<String, bool> _scripts = AppScope.read(context).settings.scriptsRead;

  void _save() {
    final settings = AppScope.read(context).settings;
    settings
      ..scriptsRead = _scripts
      ..spokenLanguages = _ranked;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spokenTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SpokenLanguagesPicker(
              initial: _ranked,
              choices: widget.choices,
              onChanged: (ranked) => setState(() => _ranked = ranked),
              readsScript: _scripts,
              onScriptChanged: (code, reads) => setState(
                () => _scripts = <String, bool>{..._scripts, code: reads},
              ),
              header: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
                child: Text(
                  l10n.spokenBody,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Why the button waits: a script not yet answered.
                  if (_ranked.isNotEmpty && !scriptsAnswered(_ranked, _scripts))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Text(
                        l10n.knownScriptsNeeded,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  FilledButton(
                    style: AppButtonStyles.tall(context),
                    onPressed:
                        _ranked.isEmpty || !scriptsAnswered(_ranked, _scripts)
                        ? null
                        : _save,
                    child: Text(l10n.commonContinue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
