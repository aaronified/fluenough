import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import 'download_text.dart';
import 'update_escape.dart';

/// Downloads the first decks of [languages] before they can be learned
/// (#210, ADR-0037): on first launch after choosing them,
/// when one is added in Settings, and as the app's home while a language
/// the learner learns is not on the phone, as after updating from a
/// version that bundled its decks.
///
/// Each language is ready once its first five decks are in; the rest
/// follow in the background. With no network, or any other failure, it
/// says why and offers Try again. Nothing is bundled to fall back on. As the
/// app's home, nothing else can be reached either, Settings and its update
/// check included, so a failure offers that check too ([UpdateEscape]).
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key, required this.languages, this.onReady});

  /// Language codes, downloaded in this order.
  final List<String> languages;

  /// Called once every language is ready. Null as the app's home, which
  /// moves on by itself once they are.
  final VoidCallback? onReady;

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  DeckDownloadFailure? _failure;
  String? _failedOn;
  bool _running = false;

  /// Failures in a row, for [UpdateEscape]: none once one succeeds.
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_running || !mounted) return;
    final state = AppScope.read(context);
    final l10n = AppLocalizations.of(context)!;
    final view = View.of(context);
    final direction = Directionality.of(context);
    setState(() {
      _running = true;
      _failure = null;
      _failedOn = null;
    });
    for (final code in widget.languages) {
      if (state.languagesToDownload(<String>[code]).isEmpty) continue;
      final failure = await state.downloadLanguage(code);
      if (!mounted) return;
      if (failure != null) {
        setState(() {
          _running = false;
          _failure = failure;
          _failedOn = code;
          _failures++;
        });
        unawaited(
          SemanticsService.sendAnnouncement(
            view,
            downloadFailureText(l10n, failure),
            direction,
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _failures = 0;
    });
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    final names = <String, String>{
      for (final language in state.languagesOnOffer)
        language.code: language.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloadsTitle),
        automaticallyImplyLeading: widget.onReady != null,
        actions: const <Widget>[ReportButton()],
      ),
      body: downloads == null
          ? const SizedBox.shrink()
          : ListenableBuilder(
              listenable: downloads,
              builder: (context, _) => ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSizes.gutter,
                  8,
                  AppSizes.gutter,
                  AppSizes.gutter,
                ),
                children: <Widget>[
                  Text(
                    l10n.downloadsBody,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final code in widget.languages)
                    _LanguageProgress(
                      name: names[code] ?? code,
                      code: code,
                      state: state,
                      downloads: downloads,
                    ),
                  if (_failure case final failure?) ...<Widget>[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        downloadFailureText(l10n, failure),
                        key: ValueKey<String>('failure-$_failedOn'),
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: AppButtonStyles.tall(context),
                      onPressed: _running ? null : _start,
                      child: Text(l10n.commonRetry),
                    ),
                    // As the app's home there is nowhere to go back to: the
                    // learner may choose languages that can be had.
                    if (widget.onReady == null) ...<Widget>[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            AppNavigator.openLearnLanguages(context),
                        child: Text(l10n.downloadsChooseOther),
                      ),
                    ],
                    const SizedBox(height: 8),
                    UpdateEscape(
                      failures: _failures,
                      detail: 'decks of $_failedOn: ${failure.name}',
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// One language's line: its name, a bar, and how far it has got.
class _LanguageProgress extends StatelessWidget {
  const _LanguageProgress({
    required this.name,
    required this.code,
    required this.state,
    required this.downloads,
  });

  final String name;
  final String code;
  final AppState state;
  final DeckDownloads downloads;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = downloads.progressOf(code);
    final ready = state.languagesToDownload(<String>[code]).isEmpty;
    final line = ready
        ? l10n.downloadsReady
        : progress != null
        ? l10n.downloadsProgress(progress.done, progress.total)
        : l10n.downloadsWaiting;
    final value = ready
        ? 1.0
        : progress == null || progress.totalBytes == 0
        ? 0.0
        : progress.bytes / progress.totalBytes;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
              if (ready)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            semanticsLabel: l10n.deckDownloadsProgressLabel(name),
          ),
          const SizedBox(height: 4),
          Text(
            line,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
