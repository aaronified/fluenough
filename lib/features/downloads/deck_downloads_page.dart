import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../settings/settings_controls.dart';
import 'download_text.dart';

/// Settings > Deck downloads (#210, ADR-0037): each language
/// on the phone, its size and state, with Update when an update waits,
/// Try again when a download or update failed, and Remove, which asks
/// first. Above them, "Check for deck updates", with when GitHub was last
/// asked, the switch for checking by itself, and Update all.
///
/// An update a learner answered "Not now" to waits here. Card ids are
/// permanent (AGENTS.md), so an update keeps every card's progress, and
/// removing a language keeps it too, in the review log.
class DeckDownloadsPage extends StatefulWidget {
  const DeckDownloadsPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/deck-downloads'),
      builder: (_) => const DeckDownloadsPage(),
    ),
  );

  @override
  State<DeckDownloadsPage> createState() => _DeckDownloadsPageState();
}

class _DeckDownloadsPageState extends State<DeckDownloadsPage> {
  bool _checking = false;

  Future<void> _check(AppState state, DeckDownloads downloads) async {
    setState(() => _checking = true);
    await downloads.checkForUpdates(
      state.settings.spokenLanguages,
      force: true,
    );
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _update(
    DeckDownloads downloads, [
    Iterable<String>? languages,
  ]) async {
    final l10n = AppLocalizations.of(context)!;
    final failure = await downloads.update(languages);
    if (!mounted) return;
    showAppSnackBar(
      context,
      failure == null
          ? l10n.deckDownloadsUpdated
          : downloadFailureText(l10n, failure),
    );
  }

  Future<void> _remove(AppState state, String code, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deckDownloadsRemoveTitle(name)),
        content: Text(l10n.deckDownloadsRemoveBody(name)),
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
    if (mounted) showAppSnackBar(context, l10n.deckDownloadsRemoved(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deckDownloadsTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: downloads == null
          ? const SizedBox.shrink()
          : ListenableBuilder(
              listenable: downloads,
              builder: (context, _) => _list(context, state, downloads),
            ),
    );
  }

  Widget _list(BuildContext context, AppState state, DeckDownloads downloads) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final spoken = state.settings.spokenLanguages;
    final names = <String, String>{
      for (final language in state.languagesOnOffer)
        language.code: language.name,
    };
    final codes = <String>[
      for (final code in names.keys)
        if (downloads.languagesOnPhone.contains(code) ||
            downloads.isDownloading(code) ||
            downloads.failureOf(code) != null)
          code,
    ];
    final checked = downloads.checkedAt;
    final when = checked == null
        ? l10n.deckDownloadsNeverChecked
        : l10n.deckDownloadsChecked(
            '${MaterialLocalizations.of(context).formatMediumDate(checked)}'
            '${l10n.commonListSeparator}'
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(checked))}',
          );
    final checking = _checking || downloads.indexStatus == IndexStatus.loading;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          child: Text(l10n.deckDownloadsIntro, style: settingsHelpStyle(theme)),
        ),
        GroupedList.settings(
          children: <Widget>[
            MergeSemantics(
              child: Semantics(
                liveRegion: true,
                child: GroupedTile(
                  leading: const Icon(Icons.sync),
                  title: l10n.deckDownloadsCheck,
                  subtitle: checking
                      ? l10n.deckDownloadsChecking
                      : downloads.indexStatus == IndexStatus.failed
                      ? downloadFailureText(l10n, downloads.indexFailure)
                      : when,
                  onTap: checking ? null : () => _check(state, downloads),
                ),
              ),
            ),
            GroupedTile.toggle(
              leading: const Icon(Icons.update),
              title: l10n.deckDownloadsAuto,
              subtitleOn: l10n.deckDownloadsAutoOn,
              subtitleOff: l10n.deckDownloadsAutoOff,
              value: downloads.checksAutomatically,
              onChanged: downloads.setChecksAutomatically,
            ),
          ],
        ),
        if (downloads.updates.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: downloads.updating ? null : () => _update(downloads),
            child: Text(
              l10n.deckDownloadsUpdateAll(
                formatSize(l10n, downloads.updateBytes),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (codes.isEmpty)
          EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.deckDownloadsEmpty,
          )
        else
          GroupedList.settings(
            children: <Widget>[
              for (final code in codes)
                _languageRow(
                  context,
                  state,
                  downloads,
                  code,
                  names[code]!,
                  spoken,
                ),
            ],
          ),
      ],
    );
  }

  Widget _languageRow(
    BuildContext context,
    AppState state,
    DeckDownloads downloads,
    String code,
    String name,
    List<String> spoken,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final size = formatSize(l10n, downloads.sizeOnPhone(code));
    final progress = downloads.progressOf(code);
    final status = downloads.stateOf(code, spoken);
    var line = switch (status) {
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
    if (downloads.needsNewerApp(code, spoken)) {
      line = '$line\n${l10n.deckDownloadsNeedsNewerApp}';
    }
    final busy = downloads.isDownloading(code) || downloads.updating;
    final Widget? action = switch (status) {
      LanguageDownloadState.updateWaiting => TextButton(
        onPressed: busy ? null : () => _update(downloads, <String>[code]),
        child: Text(l10n.deckDownloadsUpdate),
      ),
      LanguageDownloadState.failed ||
      LanguageDownloadState.partial => TextButton(
        onPressed: busy
            ? null
            : () => downloads.languagesOnPhone.contains(code)
                  ? downloads.retry(code, spoken)
                  : state.downloadLanguage(code),
        child: Text(
          status == LanguageDownloadState.failed
              ? l10n.commonRetry
              : l10n.deckDownloadsGetRest,
        ),
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GroupedTile(
          leading: const Icon(Icons.translate),
          title: name,
          subtitle: line,
          trailing: downloads.languagesOnPhone.contains(code)
              ? IconButton(
                  tooltip: l10n.deckDownloadsRemove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy ? null : () => _remove(state, code, name),
                )
              : null,
        ),
        // Under the row, not beside it: beside the remove button, "Download
        // the rest" left the name no room on a phone and overflowed.
        if (action != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSizes.gutter,
              0,
              AppSizes.gutter,
              8,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: action,
            ),
          ),
        if (progress != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSizes.gutter,
              0,
              AppSizes.gutter,
              12,
            ),
            child: LinearProgressIndicator(
              value: progress.totalBytes == 0
                  ? null
                  : progress.bytes / progress.totalBytes,
              semanticsLabel: l10n.deckDownloadsProgressLabel(name),
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }
}
