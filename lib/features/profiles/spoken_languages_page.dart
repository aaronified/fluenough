import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The languages the learner speaks, ticked and ranked (#53): first thing on
/// first launch, and from Settings after. Kept apart from the interface
/// language, which is #46.
///
/// The choices are data, `assets/languages.yaml`, so a new one needs no
/// code. The order of the ticked languages is their rank, best known first;
/// the list is reordered by dragging, and screen readers get its move
/// actions.
class SpokenLanguagesPage extends StatefulWidget {
  const SpokenLanguagesPage({super.key, this.firstRun = false, this.choices});

  /// On first launch there is nothing to go back to, and saving goes on to
  /// the app rather than back.
  final bool firstRun;

  /// For tests and the gallery. Null reads `assets/languages.yaml`.
  final List<SpokenLanguage>? choices;

  static const String asset = 'assets/languages.yaml';

  @override
  State<SpokenLanguagesPage> createState() => _SpokenLanguagesPageState();
}

class _SpokenLanguagesPageState extends State<SpokenLanguagesPage> {
  List<SpokenLanguage>? _choices;
  List<String> _order = const <String>[];
  Set<String> _ticked = const <String>{};

  @override
  void initState() {
    super.initState();
    final given = widget.choices;
    if (given != null) _init(given);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_choices != null) return;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPage.asset)
        .then(parseSpokenLanguages)
        .then((choices) {
          if (mounted) setState(() => _init(choices));
        });
  }

  void _init(List<SpokenLanguage> choices) {
    final current = AppScope.read(context).settings.spokenLanguages;
    final codes = [for (final c in choices) c.code];
    _choices = choices;
    _ticked = {
      for (final code in current)
        if (codes.contains(code)) code,
    };
    _order = [
      for (final code in current)
        if (codes.contains(code)) code,
      for (final code in codes)
        if (!current.contains(code)) code,
    ];
  }

  void _save() {
    AppScope.read(context).settings.spokenLanguages = [
      for (final code in _order)
        if (_ticked.contains(code)) code,
    ];
    if (!widget.firstRun) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final choices = _choices;
    final ranked = [
      for (final code in _order)
        if (_ticked.contains(code)) code,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spokenTitle),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: choices == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSizes.gutter,
                    8,
                    AppSizes.gutter,
                    16,
                  ),
                  child: Text(
                    l10n.spokenBody,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView(
                    onReorderItem: (from, to) => setState(() {
                      final order = List<String>.of(_order);
                      order.insert(to, order.removeAt(from));
                      _order = order;
                    }),
                    children: <Widget>[
                      for (final code in _order)
                        _tile(
                          l10n,
                          choices.firstWhere((c) => c.code == code),
                          ranked.indexOf(code),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.gutter),
                    child: FilledButton(
                      style: AppButtonStyles.tall(context),
                      onPressed: _ticked.isEmpty ? null : _save,
                      child: Text(l10n.commonContinue),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(AppLocalizations l10n, SpokenLanguage language, int rank) =>
      CheckboxListTile(
        key: ValueKey<String>(language.code),
        value: rank >= 0,
        onChanged: (on) => setState(() {
          final ticked = Set<String>.of(_ticked);
          on == true ? ticked.add(language.code) : ticked.remove(language.code);
          _ticked = ticked;
        }),
        title: Text(l10n.spokenOption(language.name, language.ownName)),
        secondary: rank >= 0
            ? CircleAvatar(radius: 14, child: Text(l10n.spokenRank(rank + 1)))
            : const SizedBox(width: 28),
      );
}
