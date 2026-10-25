import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/decks/deck_index.dart';
import '../../core/decks/font_check.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/widgets/grouped_list.dart';
import '../downloads/download_text.dart';
import '../settings/settings_section_page.dart';
import '../../ui/theme.dart';
import 'font_check_sheet.dart';

/// Settings, Look and language, Script fonts (#611, docs/mockups/
/// font-check.html): one row per script of the learner's courses that has a
/// font to download, with where it stands and "Check" or "Check again".
class ScriptFontsPage extends StatelessWidget {
  const ScriptFontsPage({super.key});

  /// The scripts to list: those of the courses the learner learns or has on
  /// the phone that have a font and a sample, and any with a font on the
  /// phone or an answer, each once.
  static List<String> scriptsOf(AppState state) {
    final downloads = state.deckDownloads;
    final codes = <String>{
      ...state.learningCodes,
      ...?downloads?.languagesOnPhone,
    };
    final scripts = <String>[];
    for (final code in codes) {
      for (final font
          in downloads?.index?.language(code)?.fonts ?? const <IndexFont>[]) {
        if (!scripts.contains(font.script)) scripts.add(font.script);
      }
    }
    for (final script in scriptSamples.keys) {
      if (!scripts.contains(script) &&
          (state.settings.fontChoice(script) != null ||
              (downloads?.hasFont(script) ?? false))) {
        scripts.add(script);
      }
    }
    return <String>[
      for (final script in scripts)
        if (scriptSamples.containsKey(script)) script,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return SettingsSectionPage(
      title: l10n.fontsRowTitle,
      listenable: Listenable.merge(<Listenable>[
        state.settings,
        state.fontCheck,
        ?state.deckDownloads,
      ]),
      builder: (context) {
        final scripts = scriptsOf(state);
        final theme = Theme.of(context);
        return <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(
              l10n.fontsPageHelp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (scripts.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
              child: Text(l10n.fontsEmpty, style: theme.textTheme.bodyLarge),
            )
          else ...<Widget>[
            OutlinedButton(
              onPressed: () {
                for (final script in scripts) {
                  state.fontCheck.askAgain(script);
                }
              },
              child: Text(l10n.fontsCheckAll),
            ),
            GroupedList.settings(
              children: <Widget>[
                for (final script in scripts) _ScriptRow(script: script),
              ],
            ),
          ],
        ];
      },
    );
  }
}

class _ScriptRow extends StatelessWidget {
  const _ScriptRow({required this.script});

  final String script;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final check = state.fontCheck;
    final status = check.stateOf(script);
    final font = state.deckDownloads?.fontOffered(script);
    final name = l10n.scriptNameOr(script, script);
    final sample = scriptSamples[script]!;
    final onPhone = status == FontCheckState.downloaded;
    final line = <String>[
      l10n.fontsState(status.name),
      if (font != null)
        l10n.fontsFontSize(
          font.family.isEmpty ? name : font.family,
          formatSize(l10n, font.size),
        ),
    ].join(' · ');
    final busy = status == FontCheckState.downloading;
    return GroupedTile(
      title: name,
      subtitle: '${sample.text}\n$line',
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : status == FontCheckState.notChecked
          ? Text(
              l10n.fontsCheck,
              style: TextStyle(color: theme.colorScheme.primary),
            )
          : Text(
              l10n.fontsCheckAgain,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
      onTap: busy ? null : () => _open(context, onPhone),
    );
  }

  Future<void> _open(BuildContext context, bool onPhone) async {
    if (!onPhone) return showFontCheckSheet(context, script);
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final name = l10n.scriptNameOr(script, script);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n.fontsCheckAgain),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.fontsRemove,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice) return showFontCheckSheet(context, script);
    await state.deckDownloads?.removeFont(script);
    state.settings.setFontChoice(script, null);
    messenger.showSnackBar(SnackBar(content: Text(l10n.fontsRemoved(name))));
  }
}
