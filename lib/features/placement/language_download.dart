import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/deck_downloads.dart';
import '../../core/decks/deck_index.dart' show decksBeforeReady;
import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../downloads/download_text.dart';

/// A chosen language's download, inside its card in the language picker
/// (`language-picker.md`, "A download progress indicator"): a bar by
/// bytes with "12 of 58 decks", a mark where the first five decks end,
/// "Ready to start" once they are in, Cancel, and on a failure why, and
/// Try again.
///
/// A screen reader is told once each that it started, that it is ready,
/// that it is done and that it failed, not every percent, as the app
/// update's download does.
class LanguageDownloadBlock extends StatefulWidget {
  const LanguageDownloadBlock({
    super.key,
    required this.name,
    required this.download,
    required this.downloading,
    required this.paused,
    required this.onCancel,
    required this.onRetry,
    this.failure,
  });

  /// The language's English name, for what is announced.
  final String name;

  /// How much of it is in.
  final LanguageDownload download;

  /// Whether its files are downloading now.
  final bool downloading;

  /// Whether its download was cancelled: the rest waits on Settings.
  final bool paused;

  /// Why its last download failed, until it is tried again.
  final DeckDownloadFailure? failure;

  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  State<LanguageDownloadBlock> createState() => _LanguageDownloadBlockState();
}

class _LanguageDownloadBlockState extends State<LanguageDownloadBlock> {
  bool _started = false;
  bool _ready = false;
  bool _done = false;
  DeckDownloadFailure? _failed;

  @override
  void initState() {
    super.initState();
    // What was so before the block was shown is not news, but for a
    // download that starts with it: the block shows as it starts.
    final d = widget.download;
    _ready = d.ready;
    _done = _isDone(d);
    _started = widget.downloading;
    _failed = widget.failure;
    // A failure that came before the block could show is told too.
    final failure = widget.failure;
    if ((widget.downloading && d.bytes == 0) || failure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        _announce(
          failure != null
              ? downloadFailureText(l10n, failure)
              : l10n.deckDownloadsProgressLabel(widget.name),
        );
      });
    }
  }

  static bool _isDone(LanguageDownload d) =>
      d.totalDecks > 0 && d.decks >= d.totalDecks;

  @override
  void didUpdateWidget(LanguageDownloadBlock old) {
    super.didUpdateWidget(old);
    final l10n = AppLocalizations.of(context)!;
    final d = widget.download;
    if (widget.downloading && !_started) {
      _started = true;
      _announce(l10n.deckDownloadsProgressLabel(widget.name));
    }
    if (d.ready && !_ready) {
      _ready = true;
      _announce(l10n.pickerAnnounceReady(widget.name));
    }
    if (_isDone(d) && !_done) {
      _done = true;
      _announce(l10n.pickerAnnounceDone(widget.name));
    }
    final failure = widget.failure;
    if (failure != null && failure != _failed) {
      _announce(downloadFailureText(l10n, failure));
    }
    _failed = failure;
  }

  void _announce(String text) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = widget.download;
    final failure = widget.failure;
    final share = d.totalBytes == 0 ? 0.0 : d.bytes / d.totalBytes;
    final mark = d.totalBytes == 0 ? 0.0 : d.readyBytes / d.totalBytes;
    final small = theme.textTheme.bodyMedium!;
    final Widget status;
    if (failure != null) {
      status = _Line(
        icon: Icons.cloud_off_outlined,
        color: scheme.error,
        text: l10n.pickerDownloadFailed(
          failure == DeckDownloadFailure.offline
              ? l10n.pickerNoConnection
              : downloadFailureText(l10n, failure),
          l10n.pickerDecksOnPhone(d.decks),
        ),
      );
    } else if (_isDone(d)) {
      status = _Line(
        icon: Icons.check,
        color: scheme.primary,
        text: l10n.pickerDownloaded,
      );
    } else if (widget.paused && d.ready) {
      status = _Line(
        icon: Icons.pause_circle_outline,
        color: scheme.onSurfaceVariant,
        text: l10n.pickerCancelled,
      );
    } else if (d.ready) {
      status = _Line(
        icon: Icons.check,
        color: scheme.primary,
        text: l10n.pickerReady,
      );
    } else {
      // The line starts under the mark, as far as leaves it room.
      status = LayoutBuilder(
        builder: (context, box) => Padding(
          padding: EdgeInsetsDirectional.only(
            start: (box.maxWidth * mark).clamp(0, box.maxWidth * 0.4),
          ),
          child: Text(
            l10n.pickerReadyAfter(decksBeforeReady),
            style: small.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: l10n.pickerDownloadDecks(
                      B1Progress.percentOf(share),
                      d.decks,
                      d.totalDecks,
                    ),
                  ),
                ],
              ),
              style: small,
            ),
            Text(
              l10n.pickerDownloadSize(
                d.bytes == 0
                    ? l10n.downloadsSizeKb(0)
                    : formatSize(l10n, d.bytes),
                formatSize(l10n, d.totalBytes),
              ),
              style: small.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MarkedBar(
          value: share,
          mark: mark,
          color: failure == null ? scheme.primary : scheme.error,
          label: l10n.deckDownloadsProgressLabel(widget.name),
        ),
        const SizedBox(height: 8),
        // Not a live region: what changes here is announced once each.
        status,
        if (widget.downloading || failure != null) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              // Named with the language: with two downloading, a screen
              // reader would otherwise meet two of each.
              TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  l10n.commonCancel,
                  semanticsLabel: l10n.pickerCancelDownloadLabel(widget.name),
                ),
              ),
              if (failure != null)
                FilledButton.tonalIcon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    l10n.commonRetry,
                    semanticsLabel: l10n.pickerRetryDownloadLabel(widget.name),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

/// The download bar, with a mark where the first decks end.
class _MarkedBar extends StatelessWidget {
  const _MarkedBar({
    required this.value,
    required this.mark,
    required this.color,
    required this.label,
  });

  final double value;
  final double mark;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: 14,
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
                semanticsLabel: label,
              ),
            ),
            PositionedDirectional(
              start: (box.maxWidth * mark).clamp(0, box.maxWidth - 2),
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  borderRadius: BorderRadius.circular(AppRadii.innerRow),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
