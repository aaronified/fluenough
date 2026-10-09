import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../downloads/download_page.dart';
import '../downloads/download_text.dart';
import 'placement_page.dart';

/// The languages the learner wants to learn (#117): asked on first launch,
/// after the languages they speak, and from Settings after.
///
/// A language newly ticked goes on to placement (ADR-0013), which finds how
/// far into its course to start. Only once that is done are the choice and
/// what placement found saved, so leaving part-way changes nothing. The
/// choices are the languages on GitHub's deck index and those on the
/// phone (#210), never a list in code. A language not on the phone
/// downloads its first decks before placement ([DownloadPage]).
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
      for (final language in state.languagesOnOffer)
        if (state.currentProfile.learns(language.code)) language.code,
  };

  @override
  void initState() {
    super.initState();
    // The list of courses, read from GitHub the first time (#210).
    final downloads = AppScope.read(context).deckDownloads;
    if (downloads != null && downloads.index == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => downloads.refreshIndex(),
      );
    }
  }

  void _continue(AppState state) {
    final before = _learning(state);
    final chosen = <String>[
      for (final language in state.languagesOnOffer)
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
    // A language not on the phone downloads its first decks first, and
    // the download page then gives way to placement.
    final needed = state.languagesToDownload(added);
    if (needed.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/downloads'),
          builder: (_) => DownloadPage(
            languages: needed,
            onReady: () => _place(state, chosen, added, replace: true),
          ),
        ),
      );
      return;
    }
    _place(state, chosen, added);
  }

  /// Opens placement for [added], which saves [chosen] once it ends:
  /// in place of the page on top, the download page, when [replace].
  void _place(
    AppState state,
    List<String> chosen,
    List<String> added, {
    bool replace = false,
  }) {
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/placement'),
      builder: (_) => PlacementPage(
        languages: added,
        onFinished: (found) => _save(
          state,
          chosen,
          found.placed,
          alphabet: found.alphabet,
          natives: found.natives,
        ),
      ),
    );
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  /// Saves [chosen], with [placed] replacing what placement found before for
  /// each language in it, and goes back to where this page was opened from:
  /// the app, on first launch.
  void _save(
    AppState state,
    List<String> chosen,
    Map<String, Set<String>> placed, {
    Map<String, bool> alphabet = const <String, bool>{},
    Map<String, String> natives = const <String, String>{},
  }) {
    final settings = state.settings;
    for (final MapEntry(:key, :value) in alphabet.entries) {
      settings.setLearnsAlphabet(key, value);
    }
    for (final MapEntry(:key, :value) in natives.entries) {
      state.chooseNative(key, value);
    }
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
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    if (downloads != null) {
      return ListenableBuilder(
        listenable: downloads,
        builder: (context, _) =>
            _scaffold(context, _body(context, state, indexing: downloads)),
      );
    }
    return _scaffold(context, _body(context, state));
  }

  Widget _scaffold(BuildContext context, Widget body) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context)!.learnTitle),
      automaticallyImplyLeading: !widget.firstRun,
      actions: const <Widget>[ReportButton()],
    ),
    body: body,
  );

  /// The list, or why there is none yet. With [indexing], the list of
  /// courses on GitHub, which is read before anything else: while there is
  /// none and nothing on the phone, the page waits for it, or says why it
  /// could not be read and offers Try again.
  Widget _body(
    BuildContext context,
    AppState state, {
    DeckDownloads? indexing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final offered = state.languagesOnOffer;
    if (indexing != null &&
        offered.isEmpty &&
        state.status != CatalogStatus.loading) {
      if (indexing.indexStatus == IndexStatus.failed) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.downloadsIndexFailed,
          body: downloadFailureText(l10n, indexing.indexFailure),
          action: FilledButton(
            onPressed: indexing.refreshIndex,
            child: Text(l10n.commonRetry),
          ),
        );
      }
      return Center(
        child: CircularProgressIndicator(
          semanticsLabel: l10n.downloadsIndexLoading,
        ),
      );
    }
    return switch (state.status) {
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
                for (final language in offered)
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
                    subtitle: _line(l10n, language),
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
  }

  /// What a language's tile says under its name: the language it is taught
  /// from, when the learner speaks none it is taught from, and what
  /// choosing it downloads. Null when there is nothing to say.
  static Widget? _line(AppLocalizations l10n, OfferedLanguage language) {
    final parts = <String>[
      if (language.taughtFrom case final from?) l10n.downloadsTaughtFrom(from),
      if (language.size > 0)
        l10n.downloadsToDownload(formatSize(l10n, language.size)),
    ];
    return parts.isEmpty ? null : Text(parts.join(l10n.commonListSeparator));
  }
}
