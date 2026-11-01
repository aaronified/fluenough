import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';
import 'app_update_needed.dart';
import 'download_text.dart';
import 'language_download_row.dart';

/// The top of Languages I'm learning (#467, #626), which took over from the
/// Deck downloads page: one contextual button, "Check for deck updates"
/// until updates are found, "Checking…" while GitHub is asked, then "Update
/// all (N)" (owner, 2026-10-18); a line under it saying when GitHub was last
/// asked or what was found, and how many new decks need an app update
/// (ADR-0052); and the switch for checking by itself. Each language's own
/// row is on its row.
class DeckUpdateControls extends StatefulWidget {
  const DeckUpdateControls({
    super.key,
    required this.downloads,
    this.names = const <String, String>{},
  });

  final DeckDownloads downloads;

  /// The languages' English names, by code, for the line that lists the
  /// updates found.
  final Map<String, String> names;

  @override
  State<DeckUpdateControls> createState() => _DeckUpdateControlsState();
}

class _DeckUpdateControlsState extends State<DeckUpdateControls> {
  bool _checking = false;

  Future<void> _check() async {
    final spoken = AppScope.read(context).settings.spokenLanguages;
    setState(() => _checking = true);
    await widget.downloads.checkForUpdates(spoken, force: true);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.downloads,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final downloads = widget.downloads;
    final material = MaterialLocalizations.of(context);
    final checked = downloads.checkedAt;
    final found = downloads.updates.keys.toList()..sort();
    final checking = _checking || downloads.indexStatus == IndexStatus.loading;
    final String say;
    if (found.isNotEmpty) {
      say = l10n.deckDownloadsFound(
        found.length,
        <String>[for (final code in found) widget.names[code] ?? code]
            .join(l10n.commonListSeparator),
        formatSize(l10n, downloads.updateBytes),
      );
    } else if (checking) {
      say = l10n.deckDownloadsAsking;
    } else if (downloads.indexStatus == IndexStatus.failed) {
      say = downloadFailureText(l10n, downloads.indexFailure);
    } else if (checked == null) {
      say = l10n.deckDownloadsNeverChecked;
    } else {
      say = l10n.deckDownloadsChecked(
        '${material.formatMediumDate(checked)}'
        '${l10n.commonListSeparator}'
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(checked))}',
      );
    }
    final button = found.isNotEmpty
        ? FilledButton.icon(
            key: const ValueKey<String>('update-all'),
            icon: const Icon(Icons.download),
            onPressed: downloads.updating
                ? null
                : () => runDeckUpdate(context, downloads),
            label: Text(l10n.deckDownloadsUpdateAllCount(found.length)),
          )
        : FilledButton.tonalIcon(
            key: const ValueKey<String>('check-updates'),
            icon: const Icon(Icons.sync),
            onPressed: checking ? null : _check,
            label: Text(
              checking ? l10n.deckDownloadsChecking : l10n.deckDownloadsCheck,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(alignment: AlignmentDirectional.centerStart, child: button),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Text(
            say,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // New decks this app is too old to read (ADR-0052).
        const AppUpdateNotice(),
        SwitchListTile(
          contentPadding: EdgeInsetsDirectional.zero,
          dense: true,
          title: Text(l10n.deckDownloadsAuto),
          subtitle: Text(
            downloads.checksAutomatically
                ? l10n.deckDownloadsAutoOn
                : l10n.deckDownloadsAutoOff,
          ),
          value: downloads.checksAutomatically,
          onChanged: downloads.setChecksAutomatically,
        ),
      ],
    );
  }
}
