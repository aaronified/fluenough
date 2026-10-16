import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import 'download_text.dart';

/// Asks, once, whether to download a deck update the daily check found
/// (#210): "Update" downloads it; "Not now" leaves it waiting on Languages I'm
/// learning, and it is not asked about again until something else
/// changes. Wraps the app's shell, so it never asks over the first launch.
class DeckUpdatePrompt extends StatefulWidget {
  const DeckUpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  State<DeckUpdatePrompt> createState() => _DeckUpdatePromptState();
}

class _DeckUpdatePromptState extends State<DeckUpdatePrompt> {
  DeckDownloads? _downloads;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final downloads = AppScope.read(context).deckDownloads;
    if (identical(downloads, _downloads)) return;
    _downloads?.removeListener(_changed);
    _downloads = downloads?..addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _downloads?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final downloads = _downloads;
    if (downloads == null || !downloads.askToUpdate || _showing) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask(downloads));
  }

  Future<void> _ask(DeckDownloads downloads) async {
    if (!mounted || !downloads.askToUpdate) {
      _showing = false;
      return;
    }
    downloads.markAsked();
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final names = <String, String>{
      for (final language in state.languagesOnOffer)
        language.code: language.name,
    };
    final languages = downloads.updates.keys
        .map((code) => names[code] ?? code)
        .join(l10n.commonListSeparator);
    final update = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deckUpdatePromptTitle),
        content: Text(
          l10n.deckUpdatePromptBody(
            languages,
            formatSize(l10n, downloads.updateBytes),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.deckUpdatePromptLater),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deckUpdatePromptUpdate),
          ),
        ],
      ),
    );
    _showing = false;
    if (update != true) {
      await downloads.declineUpdate();
      return;
    }
    final failure = await downloads.update();
    if (!mounted) return;
    showAppSnackBar(
      context,
      failure == null
          ? l10n.deckDownloadsUpdated
          : downloadFailureText(l10n, failure),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
