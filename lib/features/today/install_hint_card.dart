import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';

/// A quiet card on Today, web build only: Fluenough can be installed, and a
/// browser may clear the data of a site that is not (#1012, mockup
/// docs/mockups/web-install-hint.html on branch mockup/web-install-hint).
///
/// It is in `_NotSavedBanner`'s slot and container. On an iPhone or iPad it
/// says how (Share, then Add to Home Screen); where the browser offers its
/// own prompt it has an Install button. Got it hides it for good on this
/// device, Later for a week; Your data keeps the how-to. It takes no room
/// where the app is installed, in the Android and iOS apps (they have no
/// [WebInstall.onWeb]) or in a browser that cannot install.
class InstallHintCard extends StatelessWidget {
  const InstallHintCard({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final install = state.webInstall;
    return ListenableBuilder(
      listenable: install,
      builder: (context, _) {
        if (!install.hintVisible) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final prompt = install.canPrompt;
        void hide(VoidCallback action) {
          action();
          showAppSnackBar(context, l10n.webInstallHidden);
        }

        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 16),
          child: Container(
            key: const ValueKey<String>('install-hint'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.install_mobile_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        prompt
                            ? l10n.webInstallTitlePrompt
                            : l10n.webInstallTitleIos,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prompt
                            ? l10n.webInstallBodyPrompt
                            : l10n.webInstallBodyIos,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (!prompt) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          l10n.webInstallHowTo,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          if (prompt)
                            FilledButton(
                              onPressed: install.install,
                              child: Text(l10n.webInstallButton),
                            )
                          else
                            FilledButton.tonal(
                              onPressed: () => hide(install.gotIt),
                              child: Text(l10n.webInstallGotIt),
                            ),
                          TextButton(
                            onPressed: () => hide(install.later),
                            child: Text(l10n.webInstallLater),
                          ),
                          if (prompt)
                            TextButton(
                              onPressed: () => hide(install.gotIt),
                              child: Text(l10n.webInstallGotIt),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
