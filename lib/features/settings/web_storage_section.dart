import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
import 'settings_controls.dart';

/// Storage, the first group of Your data, web build only (#1012, mockup
/// docs/mockups/web-install-hint.html on branch mockup/web-install-hint).
///
/// On the web the progress lives in the browser, and clearing the site's
/// data deletes it. This says so, says whether the browser has agreed to
/// keep it (`navigator.storage.persisted()`), asks it to on a button, and
/// has the how-to for installing, which keeps it for good. It is nothing in
/// the Android and iOS apps, which have no [WebInstall.onWeb].
class WebStorageSection extends StatefulWidget {
  const WebStorageSection({super.key});

  @override
  State<WebStorageSection> createState() => _WebStorageSectionState();
}

class _WebStorageSectionState extends State<WebStorageSection> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(AppScope.read(context).webInstall.load());
  }

  @override
  Widget build(BuildContext context) {
    final install = AppScope.read(context).webInstall;
    if (!install.onWeb) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final help = settingsHelpStyle(Theme.of(context));
    return ListenableBuilder(
      listenable: install,
      builder: (context, _) {
        final kept = install.kept ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsHeading(l10n.webStorageHeading),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
              child: Text(l10n.webStorageIntro, style: help),
            ),
            const SizedBox(height: 12),
            GroupedList.settings(
              children: <Widget>[
                GroupedTile(
                  key: const ValueKey<String>('web-storage-status'),
                  leading: Icon(
                    kept ? Icons.lock_outline : Icons.warning_amber_outlined,
                  ),
                  title: kept ? l10n.webStorageKept : l10n.webStorageMayClear,
                  subtitle: kept
                      ? l10n.webStorageKeptDesc
                      : l10n.webStorageMayClearDesc,
                  trailing: kept
                      ? null
                      : FilledButton.tonal(
                          onPressed: () => _keep(context),
                          child: Text(l10n.webStorageKeepButton),
                        ),
                ),
                if (install.canPrompt)
                  GroupedTile(
                    key: const ValueKey<String>('web-storage-install'),
                    leading: const Icon(Icons.install_mobile_outlined),
                    title: l10n.webInstallTitlePrompt,
                    subtitle: l10n.webInstallBodyPrompt,
                    trailing: FilledButton.tonal(
                      onPressed: install.install,
                      child: Text(l10n.webInstallButton),
                    ),
                  )
                else if (install.canInstall)
                  GroupedTile(
                    key: const ValueKey<String>('web-storage-install'),
                    leading: const Icon(Icons.ios_share),
                    title: l10n.webStorageInstallRowIos,
                    subtitle: l10n.webInstallHowTo,
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<void> _keep(BuildContext context) async {
    final install = AppScope.read(context).webInstall;
    final l10n = AppLocalizations.of(context)!;
    await install.requestPersist();
    if (install.kept != true && context.mounted) {
      showAppSnackBar(context, l10n.webStorageKeepRefused);
    }
  }
}
