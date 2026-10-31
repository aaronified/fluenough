import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../profiles/spoken_languages_picker.dart' show SpokenLanguagesPicker;
import '../today/fact_languages_sheet.dart';

/// Settings' Fact languages row (#926): the languages Today's fact is shown
/// in. Its line says the choice, and it opens the same sheet as the button on
/// Today's fact card, so both write the one setting. Always shown, even with
/// one language known (the sheet then lists that one, which stays checked).
class FactLanguagesTile extends StatefulWidget {
  const FactLanguagesTile({super.key, this.spokenList});

  /// The languages of `assets/languages.yaml`, for a test; null reads them
  /// from the asset bundle.
  final List<SpokenLanguage>? spokenList;

  @override
  State<FactLanguagesTile> createState() => _FactLanguagesTileState();
}

class _FactLanguagesTileState extends State<FactLanguagesTile> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final known = state.factLanguageChoices;
        final checked = state.factLanguagesChecked;
        // Null, or a choice that covers every known language: all of them.
        final all =
            state.settings.factLanguages == null ||
            checked.length == known.length;
        String? names;
        if (!all) {
          for (final code in known) {
            if (!checked.contains(code)) continue;
            final name = factLanguageName(state, _all, code);
            names = names == null
                ? name
                : l10n.settingsFactLanguagesJoin(names, name);
          }
        }
        return GroupedTile(
          leading: const Icon(Icons.translate),
          title: l10n.settingsFactLanguages,
          subtitle: names ?? l10n.settingsFactLanguagesAll,
          subtitleMaxLines: 2,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => FactLanguagesSheet.show(context, _all),
        );
      },
    );
  }
}
