import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import 'download_text.dart';

/// A downloaded language's state, as Languages I'm learning and Languages
/// you review show it on its row (#467), which took over from the Deck
/// downloads page: its size and whether it is up to date or has an update
/// waiting, with Update, Try again or Download the rest, and Remove, which
/// asks first.
///
/// Card ids are permanent (AGENTS.md), so an update keeps every card's
/// progress, and removing a language keeps it too, in the review log.

/// [code]'s line: its size and state, or while it downloads, how far.
String languageDownloadLine(
  AppLocalizations l10n,
  DeckDownloads downloads,
  String code,
  List<String> spoken,
) {
  final size = formatSize(l10n, downloads.sizeOnPhone(code));
  final progress = downloads.progressOf(code);
  final line = switch (downloads.stateOf(code, spoken)) {
    LanguageDownloadState.downloading when progress != null =>
      l10n.downloadsProgress(progress.done, progress.total),
    LanguageDownloadState.failed => downloadFailureText(
      l10n,
      downloads.failureOf(code),
    ),
    LanguageDownloadState.updateWaiting => l10n.deckDownloadsWaiting(
      formatSize(l10n, downloads.updates[code]!.bytes),
    ),
    LanguageDownloadState.partial => l10n.deckDownloadsPartial(size),
    LanguageDownloadState.notOffered => l10n.deckDownloadsNotOffered(size),
    _ => l10n.deckDownloadsUpToDate(size),
  };
  return downloads.needsNewerApp(code, spoken)
      ? '$line\n${l10n.deckDownloadsNeedsNewerApp}'
      : line;
}

/// Whether [code] has a row to show: on the phone, downloading, or failed.
bool hasDownloadRow(DeckDownloads downloads, String code) =>
    downloads.languagesOnPhone.contains(code) ||
    downloads.isDownloading(code) ||
    downloads.failureOf(code) != null;

/// Runs the updates waiting for [languages], or every one, and says how it
/// went.
Future<void> runDeckUpdate(
  BuildContext context,
  DeckDownloads downloads, [
  Iterable<String>? languages,
]) async {
  final l10n = AppLocalizations.of(context)!;
  final failure = await downloads.update(languages);
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    failure == null
        ? l10n.deckDownloadsUpdated
        : downloadFailureText(l10n, failure),
  );
}

/// [code]'s buttons, at the end of its row, and while it downloads, a bar.
class LanguageDownloadActions extends StatelessWidget {
  const LanguageDownloadActions({
    super.key,
    required this.code,
    required this.name,
    this.onRemoved,
  });

  final String code;

  /// Its English name, for the remove dialog and the bar's label.
  final String name;

  /// Called once it is removed, which also stops it being learned.
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    if (downloads == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) => _build(context, state, downloads),
    );
  }

  Widget _build(BuildContext context, AppState state, DeckDownloads downloads) {
    final l10n = AppLocalizations.of(context)!;
    final spoken = state.settings.spokenLanguages;
    final status = downloads.stateOf(code, spoken);
    final progress = downloads.progressOf(code);
    final onPhone = downloads.languagesOnPhone.contains(code);
    final busy = downloads.isDownloading(code) || downloads.updating;
    final buttons = <Widget>[
      if (status == LanguageDownloadState.updateWaiting)
        TextButton(
          onPressed: busy
              ? null
              : () => runDeckUpdate(context, downloads, <String>[code]),
          child: Text(l10n.deckDownloadsUpdate),
        ),
      if (status == LanguageDownloadState.failed ||
          status == LanguageDownloadState.partial)
        TextButton(
          onPressed: busy
              ? null
              : () => onPhone
                    ? downloads.retry(code, spoken)
                    : state.downloadLanguage(code),
          child: Text(
            status == LanguageDownloadState.failed
                ? l10n.commonRetry
                : l10n.deckDownloadsGetRest,
          ),
        ),
      if (onPhone)
        TextButton(
          onPressed: busy ? null : () => _remove(context, state),
          child: Text(l10n.deckDownloadsRemove),
        ),
    ];
    if (buttons.isEmpty && progress == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (progress != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, bottom: 4),
            child: LinearProgressIndicator(
              value: progress.totalBytes == 0
                  ? null
                  : progress.bytes / progress.totalBytes,
              semanticsLabel: l10n.deckDownloadsProgressLabel(name),
            ),
          ),
        // Wraps rather than overflowing beside a long name at large text.
        Wrap(alignment: WrapAlignment.end, spacing: 4, children: buttons),
      ],
    );
  }

  Future<void> _remove(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    // A language only reviewed leaves no course behind.
    final learned = state.learningCodes.contains(code);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deckDownloadsRemoveTitle(name)),
        content: Text(
          learned
              ? l10n.deckDownloadsRemoveBody(name)
              : l10n.deckDownloadsRemoveReviewBody(name),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deckDownloadsRemove),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await state.removeLanguage(code);
    onRemoved?.call();
    if (context.mounted) {
      showAppSnackBar(context, l10n.deckDownloadsRemoved(name));
    }
  }
}
