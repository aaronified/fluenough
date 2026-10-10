import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/review/review_pairs.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../downloads/download_text.dart';
import '../downloads/language_download_row.dart';
import '../profiles/spoken_languages_picker.dart';
import '../settings/settings_controls.dart';
import 'review_waiting.dart';

/// Opens Languages you review.
Future<void> showReviewLanguages(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/review-languages'),
        builder: (_) => const ReviewLanguagesPage(),
      ),
    );

/// Languages you review (#462): every course in the deck index, a language
/// and the one it is taught from, such as "Bengali from English",
/// downloaded or not. A course can be ticked only when the reviewer knows
/// both languages and reads both scripts; the others are greyed, with the
/// reason. Ticking a course whose decks are not on the phone offers their
/// download, for reviewing only: the language is not learned, so it stays
/// out of Today, the language menu and lessons.
///
/// A course on the phone shows its size and state, with Update and Remove
/// (#467). A button opens Languages you know; until the reviewer has said
/// there which scripts they read, nothing can be ticked.
class ReviewLanguagesPage extends StatefulWidget {
  const ReviewLanguagesPage({super.key});

  @override
  State<ReviewLanguagesPage> createState() => _ReviewLanguagesPageState();
}

class _ReviewLanguagesPageState extends State<ReviewLanguagesPage> {
  /// Each known language's script, from `assets/languages.yaml`, for the
  /// languages a course is taught from, which the deck index does not
  /// describe.
  Map<String, String> _knownScripts = const <String, String>{};

  /// Each known language's English name, from the same list.
  Map<String, String> _knownNames = const <String, String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_knownScripts.isNotEmpty) return;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPicker.asset)
        .then(parseSpokenLanguages)
        .then((languages) {
          if (!mounted) return;
          setState(() {
            _knownScripts = <String, String>{
              for (final l in languages) l.code: ?l.script,
            };
            _knownNames = <String, String>{
              for (final l in languages) l.code: l.name,
            };
          });
        }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewSettingsLanguages),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          state.settings,
          ?state.deckDownloads,
        ]),
        builder: (context, _) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final reviewer = reviewerOf(state);
    final offered = offeredPairs(state);
    final reviewed = reviewPairsOf(state);
    final names = <String, String>{...languageNamesOf(state), ..._knownNames};
    String name(String code) => names[code] ?? code;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
          child: Text(
            l10n.reviewLanguagesBody,
            style: settingsHelpStyle(theme),
          ),
        ),
        if (!reviewer.scriptsAnswered)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 12),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Card.filled(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      Text(
                        l10n.reviewScriptsGateTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.reviewScriptsGateBody,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => AppNavigator.openSpokenLanguages(context),
            icon: const Icon(Icons.translate_outlined),
            label: Text(l10n.reviewOpenKnown),
          ),
        ),
        const SizedBox(height: 16),
        if (offered.isEmpty)
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.reviewPairsNone,
          )
        else
          GroupedList.settings(
            children: <Widget>[
              for (final pair in offered)
                _row(
                  context,
                  state,
                  pair,
                  block: reviewer.blockOf(pair),
                  ticked: reviewed.contains(pair),
                  reviewed: reviewed,
                  name: name,
                ),
            ],
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppState state,
    ReviewPair pair, {
    required PairBlock? block,
    required bool ticked,
    required Set<ReviewPair> reviewed,
    required String Function(String) name,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final downloads = state.deckDownloads;
    final spoken = state.settings.spokenLanguages;
    final target = name(pair.target);
    final onPhone = _onPhone(state, pair);
    String script(String code) =>
        l10n.reviewPairNoScript(_scriptOf(state, code) ?? '', name(code));
    final line = switch (block) {
      PairBlock.scriptsUnanswered => null,
      PairBlock.unknownTarget => l10n.reviewPairUnknown(target),
      PairBlock.unknownNative => l10n.reviewPairUnknown(name(pair.native)),
      PairBlock.targetScript => script(pair.target),
      PairBlock.nativeScript => script(pair.native),
      null when downloads != null && hasDownloadRow(downloads, pair.target) =>
        languageDownloadLine(l10n, downloads, pair.target, spoken),
      null when !onPhone && downloads != null => l10n.reviewPairNotOnPhone(
        formatSize(l10n, _downloadSize(state, pair)),
      ),
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          enabled: block == null,
          value: block == null && ticked,
          title: Text(l10n.reviewPairName(target, name(pair.native))),
          subtitle: line == null ? null : Text(line),
          onChanged: (on) => _tick(context, state, pair, on ?? false, reviewed),
        ),
        if (block == null &&
            downloads != null &&
            hasDownloadRow(downloads, pair.target))
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: LanguageDownloadActions(code: pair.target, name: target),
          ),
      ],
    );
  }

  /// Whether [pair]'s decks are on the phone, or on their way.
  static bool _onPhone(AppState state, ReviewPair pair) {
    final downloads = state.deckDownloads;
    if (downloads == null) return true;
    return downloads.languagesOnPhone.contains(pair.target) ||
        downloads.isDownloading(pair.target) ||
        state.decks.any(
          (d) =>
              d.language.code == pair.target &&
              d.deck.native.code == pair.native,
        );
  }

  /// [code]'s script, as decks name it: from the deck index, else the
  /// decks on the phone, else the list of languages known.
  String? _scriptOf(AppState state, String code) {
    if (state.deckDownloads?.index?.language(code)?.script case final s?) {
      return s;
    }
    for (final language in state.languages) {
      if (language.code == code) return language.script;
    }
    return _knownScripts[code];
  }

  /// What downloading [pair]'s language for review takes, in bytes.
  static int _downloadSize(AppState state, ReviewPair pair) {
    final index = state.deckDownloads?.index?.language(pair.target);
    if (index == null) return 0;
    return index
        .filesFor(index.nativesFor(state.settings.spokenLanguages))
        .fold(0, (sum, file) => sum + file.size);
  }

  Future<void> _tick(
    BuildContext context,
    AppState state,
    ReviewPair pair,
    bool on,
    Set<ReviewPair> reviewed,
  ) async {
    if (on && !_onPhone(state, pair)) {
      final l10n = AppLocalizations.of(context)!;
      final name = languageNamesOf(state)[pair.target] ?? pair.target;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.reviewDownloadTitle(name)),
          content: Text(
            l10n.reviewDownloadBody(
              formatSize(l10n, _downloadSize(state, pair)),
              name,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.reviewDownload),
            ),
          ],
        ),
      );
      if (yes != true) return;
      // For review only: never added to the languages learned.
      unawaited(state.downloadLanguage(pair.target));
    }
    state.settings.reviewPairs = <String>{
      for (final p in reviewed)
        if (p != pair) p.key,
      if (on) pair.key,
    };
  }
}
