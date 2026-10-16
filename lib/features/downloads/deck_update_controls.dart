import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import 'download_text.dart';
import 'language_download_row.dart';

/// The top of Languages I'm learning (#467), which took over from the Deck
/// downloads page: "Check for deck updates", with when GitHub was last
/// asked, the switch for checking by itself, and, while updates wait,
/// Update all. Each language's own row is on its card.
class DeckUpdateControls extends StatefulWidget {
  const DeckUpdateControls({super.key, required this.downloads});

  final DeckDownloads downloads;

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
    final downloads = widget.downloads;
    final material = MaterialLocalizations.of(context);
    final checked = downloads.checkedAt;
    final when = checked == null
        ? l10n.deckDownloadsNeverChecked
        : l10n.deckDownloadsChecked(
            '${material.formatMediumDate(checked)}'
            '${l10n.commonListSeparator}'
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(checked))}',
          );
    final checking = _checking || downloads.indexStatus == IndexStatus.loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
                  onTap: checking ? null : _check,
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
            onPressed: downloads.updating
                ? null
                : () => runDeckUpdate(context, downloads),
            child: Text(
              l10n.deckDownloadsUpdateAll(
                formatSize(l10n, downloads.updateBytes),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
