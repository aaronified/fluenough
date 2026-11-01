import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/links.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';

// What the app says when a language or deck needs a newer app than the one
// installed (`min_app`, ADR-0052): calm, with one way out, the newest
// release's page on GitHub. Not every phone updates as soon as a release is
// out, and a deck an old app cannot read is never downloaded.

/// Opens the newest release's page, where the app is downloaded; copies the
/// link when nothing on the phone can open it.
Future<void> openAppUpdate(BuildContext context) => openLink(
  context,
  AppLinks.latestRelease,
  copied: AppLocalizations.of(context)!.appUpdateLinkCopied,
);

/// The quiet notice at the top of the deck updates ([DeckUpdateControls]):
/// how many new decks wait for an app update, with Update. Nothing where none
/// does.
class AppUpdateNotice extends StatelessWidget {
  const AppUpdateNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    if (downloads == null) return const SizedBox.shrink();
    final count = downloads.decksNeedingApp(state.settings.spokenLanguages);
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.appUpdateDecksNotice(count),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            key: const ValueKey<String>('app-update-notice'),
            onPressed: () => openAppUpdate(context),
            icon: const Icon(Icons.system_update_outlined, size: 20),
            label: Text(l10n.appUpdateAction),
          ),
        ],
      ),
    );
  }
}
