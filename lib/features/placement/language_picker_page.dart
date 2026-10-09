import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../app/language_offer.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/decks/deck_index.dart' show decksBeforeReady;
import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../downloads/download_text.dart';
import '../profiles/spoken_languages_picker.dart';
import 'language_card.dart';
import 'language_download.dart';
import 'placement_page.dart';

/// The languages the learner learns (#211, `docs/plans/language-picker.md`
/// and its approved mockup): asked on first launch, after the languages
/// they speak, and from Settings.
///
/// Search at the top; "Learning", the languages chosen, then "Available".
/// Each language is a card with how much of its course is written toward
/// B1, the learner's own progress where they learn it, the languages it is
/// taught from and its Alpha or Beta tag. Choosing a new one opens its card
/// in place: "Learn the script", on to start with, which tells placement
/// not to ask; which of the learner's languages to learn it from, when more
/// than one teaches it; and with deck downloads, its download, which starts
/// as it is chosen. Continue waits only for each new language's first five
/// decks, then runs placement for the new ones (ADR-0013) and saves; a
/// language already learned needs none. Un-ticking a language the learner
/// learns asks first: its progress is kept, but its decks leave Today.
class LanguagePickerPage extends StatefulWidget {
  const LanguagePickerPage({
    super.key,
    this.firstRun = false,
    this.ownNames,
    this.initialQuery = '',
    this.initialChosen = const <String>{},
    this.initialScript = const <String, bool>{},
  });

  /// On first launch there is nothing to go back to, and finishing goes on
  /// to the app.
  final bool firstRun;

  /// Each language's own name, by code, for those the deck index does not
  /// name. Null reads them from `assets/languages.yaml`.
  final Map<String, String>? ownNames;

  /// For the gallery and tests: the search to open with, languages chosen
  /// besides those learned, and their "Learn the script" switches.
  final String initialQuery;
  final Set<String> initialChosen;
  final Map<String, bool> initialScript;

  @override
  State<LanguagePickerPage> createState() => _LanguagePickerPageState();
}

class _LanguagePickerPageState extends State<LanguagePickerPage> {
  late final Set<String> _learning = _learningOf(AppScope.read(context));
  late Set<String> _ticked = <String>{..._learning, ...widget.initialChosen};

  /// "Learn the script", for each language newly chosen with script decks.
  late final Map<String, bool> _script = <String, bool>{
    ...widget.initialScript,
  };

  /// The language each newly chosen one is learned from, where the learner
  /// had a choice.
  final Map<String, String> _native = <String, String>{};

  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery,
  );
  late Map<String, String> _ownNames =
      widget.ownNames ?? const <String, String>{};
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  /// What the current profile learns, once the learner has chosen;
  /// nothing on first launch.
  static Set<String> _learningOf(AppState state) => <String>{
    if (state.settings.learningChosen)
      for (final language in state.languagesOnOffer)
        if (state.currentProfile.learns(language.code)) language.code,
  };

  @override
  void initState() {
    super.initState();
    // The list of courses, read from GitHub the first time (#210).
    final state = AppScope.read(context);
    final downloads = state.deckDownloads;
    if (downloads != null && downloads.index == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => downloads.refreshIndex(),
      );
    }
    for (final code in widget.initialChosen) {
      _startDownload(state, code);
    }
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.ownNames != null || _ownNames.isNotEmpty) return;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPicker.asset)
        .then(parseSpokenLanguages)
        .then((languages) {
          if (!mounted) return;
          setState(
            () => _ownNames = <String, String>{
              for (final l in languages) l.code: l.ownName,
            },
          );
        }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _spoken => AppScope.read(context).settings.spokenLanguages;

  // ---------------------------------------------------------------------------
  // Choosing

  Future<void> _toggle(AppState state, CatalogLanguage language) async {
    final code = language.code;
    if (!_ticked.contains(code)) {
      setState(() => _ticked = <String>{..._ticked, code});
      _startDownload(state, code);
      _showCard(code);
      return;
    }
    if (_learning.contains(code) && !await _confirmStop(state, language)) {
      return;
    }
    if (!mounted) return;
    final downloads = state.deckDownloads;
    if (!_learning.contains(code) &&
        downloads != null &&
        downloads.isDownloading(code)) {
      unawaited(downloads.cancel(code));
    }
    setState(() => _ticked = <String>{..._ticked}..remove(code));
  }

  /// A language not on the phone starts downloading as it is chosen.
  void _startDownload(AppState state, String code) {
    final downloads = state.deckDownloads;
    if (downloads == null || downloads.isReady(code, _spoken)) return;
    // One under way goes on; one that failed waits for Try again.
    if (downloads.isDownloading(code) || downloads.failureOf(code) != null) {
      return;
    }
    unawaited(state.downloadLanguage(code));
  }

  /// Keeps a card in view after it moves to "Learning".
  void _showCard(String code) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _cardKeys[code]?.currentContext;
      if (context != null && context.mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Future<bool> _confirmStop(AppState state, CatalogLanguage language) async {
    final l10n = AppLocalizations.of(context)!;
    final share = state.learnedShare(language.code);
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pickerStopTitle(language.name)),
        content: Text(
          share == null
              ? l10n.pickerStopBodyPlain
              : l10n.pickerStopBody(B1Progress.percentOf(share)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pickerStopConfirm),
          ),
        ],
      ),
    );
    return stop ?? false;
  }

  void _cancel(AppState state, String code) {
    final downloads = state.deckDownloads!;
    final ready = downloads.isReady(code, _spoken);
    unawaited(downloads.cancel(code));
    // Before its first decks are in, a cancelled language cannot be
    // started, so it is no longer chosen. After, the course works with
    // what arrived, and the rest comes from Settings > Deck downloads.
    if (!ready) setState(() => _ticked = <String>{..._ticked}..remove(code));
  }

  void _retry(AppState state, String code) {
    final downloads = state.deckDownloads!;
    if (downloads.isReady(code, _spoken)) {
      unawaited(downloads.downloadRest(code, _spoken));
    } else {
      unawaited(state.downloadLanguage(code));
    }
  }

  // ---------------------------------------------------------------------------
  // Continue

  /// The newly chosen languages, in the catalog's order.
  List<String> _added(List<CatalogLanguage> all) => <String>[
    for (final language in all)
      if (_ticked.contains(language.code) && !_learning.contains(language.code))
        language.code,
  ];

  /// Those of [added] whose first decks are not on the phone yet.
  List<String> _waiting(AppState state, List<String> added) {
    final downloads = state.deckDownloads;
    if (downloads == null) return const <String>[];
    return <String>[
      for (final code in added)
        if (!downloads.isReady(code, _spoken)) code,
    ];
  }

  void _continue(AppState state, List<CatalogLanguage> all) {
    final chosen = <String>[
      for (final language in all)
        if (_ticked.contains(language.code)) language.code,
    ];
    final added = _added(all);
    if (added.isEmpty) {
      _save(state, chosen, const <String, Set<String>>{});
      return;
    }
    final byCode = <String, CatalogLanguage>{for (final l in all) l.code: l};
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/placement'),
        builder: (_) => PlacementPage(
          languages: added,
          alphabet: <String, bool>{
            for (final code in added)
              if (byCode[code]?.scriptDecks ?? false)
                code: _script[code] ?? true,
          },
          natives: <String, String>{
            for (final code in added) code: ?_native[code],
          },
          onFinished: (found) => _save(
            state,
            chosen,
            found.placed,
            alphabet: found.alphabet,
            natives: found.natives,
          ),
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

  // ---------------------------------------------------------------------------
  // The page

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    return Scaffold(
      appBar: widget.firstRun
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context)!.pickerSettingsTitle),
              actions: const <Widget>[ReportButton()],
            ),
      body: SafeArea(
        bottom: false,
        top: widget.firstRun,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.firstRun)
              TabHeader(title: AppLocalizations.of(context)!.learnTitle),
            Expanded(
              child: downloads == null
                  ? _body(context, state)
                  : ListenableBuilder(
                      listenable: downloads,
                      builder: (context, _) =>
                          _body(context, state, indexing: downloads),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
    if (indexing != null &&
        state.languagesOnOffer.isEmpty &&
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
      CatalogStatus.ready => _list(context, state),
    };
  }

  Widget _list(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final spoken = state.settings.spokenLanguages;
    final all = state.catalogLanguages(ownNames: _ownNames);
    final query = _search.text;
    final shown = <CatalogLanguage>[
      for (final language in all)
        if (LanguageSearch.matches(language, query)) language,
    ];
    final learning = pickerOrder(
      shown.where((l) => _ticked.contains(l.code)),
      spoken,
    );
    final available = pickerOrder(
      shown.where((l) => !_ticked.contains(l.code)),
      spoken,
    );
    final added = _added(all);
    final waiting = _waiting(state, added);
    final names = <String, String>{for (final l in all) l.code: l.name};
    String join(List<String> codes) =>
        <String>[for (final code in codes) names[code] ?? code]
            .join(l10n.commonListSeparator);
    final hint = _ticked.isEmpty
        ? l10n.pickerHintChoose
        : waiting.isNotEmpty
        ? l10n.pickerHintWaiting(decksBeforeReady, join(waiting))
        : added.isNotEmpty
        ? l10n.pickerHintNext(join(added))
        : null;
    final canGo = _ticked.isNotEmpty && waiting.isEmpty;

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSizes.gutter + 8,
        16,
        AppSizes.gutter,
        8,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall!.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    Widget card(CatalogLanguage language) => Padding(
      key: _cardKeys.putIfAbsent(language.code, GlobalKey.new),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSizes.gutter,
        0,
        AppSizes.gutter,
        12,
      ),
      child: _card(context, state, language, query),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSizes.gutter,
            8,
            AppSizes.gutter,
            4,
          ),
          child: SearchBar(
            controller: _search,
            hintText: l10n.pickerSearchHint,
            elevation: const WidgetStatePropertyAll<double>(0),
            leading: const Icon(Icons.search),
            trailing: <Widget>[
              if (query.isNotEmpty)
                IconButton(
                  tooltip: l10n.pickerClearSearch,
                  icon: const Icon(Icons.close),
                  onPressed: _search.clear,
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(
                  icon: Icons.search,
                  title: l10n.pickerNoMatchTitle(query.trim()),
                  body: l10n.pickerNoMatchBody,
                )
              : ListView(
                  padding: const EdgeInsetsDirectional.only(bottom: 16),
                  children: <Widget>[
                    // The intro scrolls with the list: at large text sizes,
                    // it and the button would not leave the list any room.
                    if (widget.firstRun && query.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSizes.gutter + 8,
                          8,
                          AppSizes.gutter,
                          0,
                        ),
                        child: Text(
                          l10n.learnBody,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (learning.isNotEmpty) ...<Widget>[
                      heading(l10n.pickerGroupLearning(learning.length)),
                      for (final language in learning) card(language),
                    ],
                    if (available.isNotEmpty) ...<Widget>[
                      heading(l10n.pickerGroupAvailable(available.length)),
                      for (final language in available) card(language),
                    ],
                  ],
                ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSizes.gutter,
                12,
                AppSizes.gutter,
                AppSizes.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (hint != null) ...<Widget>[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    style: AppButtonStyles.tall(context),
                    onPressed: canGo ? () => _continue(state, all) : null,
                    child: Text(l10n.commonContinue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    AppState state,
    CatalogLanguage language,
    String query,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final spoken = state.settings.spokenLanguages;
    final code = language.code;
    final ticked = _ticked.contains(code);
    final learns = _learning.contains(code);
    final options = language.spokenNatives(spoken);
    final chosenNative = !learns && options.length > 1
        ? _native[code] ??
              state.courseNative(code) ??
              language.nativeFor(spoken)?.code
        : null;
    final native = learns ? state.courseNative(code) : chosenNative;
    final progress = language.progressFor(spoken, native: native);
    final downloads = state.deckDownloads;
    final download = downloads?.languageDownload(code, spoken);
    final onPhone = downloads?.languagesOnPhone.contains(code) ?? false;
    final share = learns && progress != null && progress.hasPlan
        ? state.learnedShare(code)
        : null;
    final expanded = <Widget>[
      if (ticked && !learns) ...<Widget>[
        if (language.scriptDecks)
          ScriptChoice(
            language: language,
            on: _script[code] ?? true,
            onChanged: (on) => setState(() => _script[code] = on),
            preview: state.scriptPreview(code),
          ),
        if (chosenNative != null)
          NativeChoiceField(
            language: language,
            options: options,
            chosen: chosenNative,
            onChosen: (picked) => setState(() => _native[code] = picked),
          ),
        if (progress?.stage == CourseStage.alpha)
          CardNotice(text: l10n.pickerAlphaNotice(language.name)),
        if (downloads != null &&
            download != null &&
            (downloads.isDownloading(code) ||
                downloads.failureOf(code) != null ||
                (download.decks > 0 && download.decks < download.totalDecks)))
          LanguageDownloadBlock(
            name: language.name,
            download: download,
            downloading: downloads.isDownloading(code),
            paused: downloads.isPaused(code),
            failure: downloads.failureOf(code),
            onCancel: () => _cancel(state, code),
            onRetry: () => _retry(state, code),
          ),
      ],
    ];
    return LanguageCard(
      key: ValueKey<String>('language-$code'),
      language: language,
      ticked: ticked,
      onToggle: () => _toggle(state, language),
      spoken: spoken,
      progress: progress,
      you: share,
      youWords: learns && share == null && !(progress?.hasPlan ?? false)
          ? state.learnedWords(code)
          : null,
      storage: downloads == null || download == null
          ? null
          : (
              onPhone: onPhone,
              size: formatSize(
                l10n,
                onPhone ? downloads.sizeOnPhone(code) : download.totalBytes,
              ),
            ),
      query: query,
      expanded: expanded,
    );
  }
}
