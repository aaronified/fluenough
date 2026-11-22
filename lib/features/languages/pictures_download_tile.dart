import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../downloads/download_text.dart';

/// The "Download pictures" row of a language's Culture group (approved mockup
/// `culture-media`, screen 6): the size of the language's portraits and
/// posters at the right; a ring while they download one by one, then a tick.
/// Gone when the language lists none (or the index is not known yet).
class PicturesDownloadTile extends StatefulWidget {
  const PicturesDownloadTile({super.key, required this.language});

  final String language;

  @override
  State<PicturesDownloadTile> createState() => _PicturesDownloadTileState();
}

class _PicturesDownloadTileState extends State<PicturesDownloadTile> {
  bool _busy = false;
  bool _done = false;
  int _finished = 0;
  int _total = 0;

  Future<void> _start() async {
    final downloads = AppScope.read(context).deckDownloads;
    if (downloads == null || _busy) return;
    setState(() {
      _busy = true;
      _done = false;
      _finished = 0;
      _total = 0;
    });
    final failed = await downloads.downloadPictures(
      widget.language,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _finished = done;
          _total = total;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      // A picture that could not come leaves the row ready for another try.
      _done = failed == 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final downloads = AppScope.of(context).deckDownloads;
    if (downloads == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final listed = downloads.picturesOf(widget.language);
        if (listed.isEmpty) return const SizedBox.shrink();
        final bytes = listed.fold<int>(0, (sum, media) => sum + media.size);
        final Widget trailing;
        if (_busy) {
          trailing = SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: _total == 0 ? null : _finished / _total,
              strokeWidth: 3,
              semanticsLabel: l10n.culturePicturesDownloading,
            ),
          );
        } else if (_done) {
          trailing = Icon(
            Icons.check_circle_outline,
            semanticLabel: l10n.culturePicturesDownloaded,
          );
        } else {
          trailing = Text(
            formatSize(l10n, bytes),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        return GroupedTile(
          key: const ValueKey<String>('pictures-download'),
          leading: const Icon(Icons.download_outlined),
          title: l10n.culturePicturesDownload,
          trailing: trailing,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          leadingGap: 12,
          onTap: _busy || _done ? null : () => _start().ignore(),
        );
      },
    );
  }
}
