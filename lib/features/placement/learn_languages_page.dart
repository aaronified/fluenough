import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import 'placement_page.dart';

/// The languages the learner wants to learn (#117): asked on first launch,
/// after the languages they speak, and from Settings after.
///
/// A language newly ticked goes on to placement (ADR-0013), which finds how
/// far into its course to start. Only once that is done are the choice and
/// what placement found saved, so leaving part-way changes nothing. The
/// choices are the languages the loaded decks teach, never a list in code.
class LearnLanguagesPage extends StatefulWidget {
  const LearnLanguagesPage({super.key, this.firstRun = false});

  /// On first launch there is nothing to go back to, and finishing goes on
  /// to the app.
  final bool firstRun;

  @override
  State<LearnLanguagesPage> createState() => _LearnLanguagesPageState();
}

class _LearnLanguagesPageState extends State<LearnLanguagesPage> {
  // What the current profile learns, as Settings' row shows it, once the
  // learner has chosen; nothing on first launch.
  late Set<String> _ticked = _learning(AppScope.read(context));

  static Set<String> _learning(AppState state) => <String>{
    if (state.settings.learningChosen)
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.code,
  };

  void _continue(AppState state) {
    final before = _learning(state);
    final chosen = <String>[
      for (final language in state.languages)
        if (_ticked.contains(language.code)) language.code,
    ];
    final added = <String>[
      for (final code in chosen)
        if (!before.contains(code)) code,
    ];
    if (added.isEmpty) {
      _save(state, chosen, const <String, Set<String>>{});
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlacementPage(
          languages: added,
          onFinished: (placed) => _save(state, chosen, placed),
        ),
      ),
    );
  }

  /// Saves [chosen], with [placed] replacing what placement found before for
  /// each language in it, and goes back to where this page was opened from:
  /// the app, on first launch.
  void _save(
    AppState state,
    List<String> chosen,
    Map<String, Set<String>> placed,
  ) {
    final settings = state.settings;
    final replaced = <String>{
      for (final entry in state.decks)
        if (placed.containsKey(entry.language.code)) entry.id,
    };
    // Back to the first route first: from Settings that is the app; on
    // first launch it is this page, which saving then swaps for the app.
    Navigator.of(context).popUntil((route) => route.isFirst);
    settings
      ..placedDecks = <String>{
        for (final id in settings.placedDecks)
          if (!replaced.contains(id)) id,
        for (final ids in placed.values) ...ids,
      }
      ..learningChosen = true;
    state.setLearningLanguages(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final Widget body = switch (state.status) {
      CatalogStatus.loading => Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
      ),
      CatalogStatus.failed => EmptyState(
        icon: Icons.error_outline,
        title: l10n.commonDecksFailed,
        body: l10n.commonDecksFailedBody,
        action: FilledButton(
          onPressed: state.reload,
          child: Text(l10n.commonRetry),
        ),
      ),
      CatalogStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The intro scrolls with the list: at large text sizes, it and the
          // button would not leave the list any room.
          Expanded(
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSizes.gutter,
                    8,
                    AppSizes.gutter,
                    16,
                  ),
                  child: Text(
                    l10n.learnBody,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final language in state.languages)
                  CheckboxListTile(
                    value: _ticked.contains(language.code),
                    onChanged: (on) => setState(() {
                      final ticked = Set<String>.of(_ticked);
                      on == true
                          ? ticked.add(language.code)
                          : ticked.remove(language.code);
                      _ticked = ticked;
                    }),
                    title: Text(language.name),
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
                onPressed: _ticked.isEmpty ? null : () => _continue(state),
                child: Text(l10n.commonContinue),
              ),
            ),
          ),
        ],
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learnTitle),
        automaticallyImplyLeading: !widget.firstRun,
        actions: const <Widget>[ReportButton()],
      ),
      body: body,
    );
  }
}
