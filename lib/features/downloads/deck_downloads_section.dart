import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import 'deck_downloads_page.dart';

/// Settings' Decks group (#210): one row, Deck downloads, saying whether
/// updates are waiting, that opens [DeckDownloadsPage]. Draws nothing where
/// decks do not download. Its own section, followed by its own gap, so that
/// it sits apart from the rest of Settings.
class DeckDownloadsSection extends StatelessWidget {
  const DeckDownloadsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final downloads = state.deckDownloads;
    if (downloads == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final waiting = downloads.updates.length;
        final busy = downloads.languagesOnPhone.any(downloads.isDownloading);
        final line = busy || downloads.updating
            ? l10n.deckDownloadsRowDownloading
            : waiting > 0
            ? l10n.deckDownloadsRowWaiting(waiting)
            : downloads.languagesOnPhone.isEmpty
            ? l10n.deckDownloadsRowNone
            : l10n.deckDownloadsRowUpToDate;
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 20),
          child: GroupedList.settings(
            header: l10n.settingsSectionDecks,
            children: <Widget>[
              GroupedTile(
                leading: Badge(
                  isLabelVisible: waiting > 0,
                  child: const Icon(Icons.cloud_download_outlined),
                ),
                title: l10n.deckDownloadsTitle,
                subtitle: line,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => DeckDownloadsPage.open(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
