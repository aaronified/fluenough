import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../app/deck_downloads.dart';
import '../../l10n/app_localizations.dart';

/// [bytes] as a download size: "310 KB", or "1.2 MB" from a megabyte up.
String formatSize(AppLocalizations l10n, int bytes) {
  const kb = 1024;
  if (bytes < 1000 * kb) {
    return l10n.downloadsSizeKb(math.max(1, (bytes / kb).ceil()));
  }
  final mb = NumberFormat('#,##0.0', l10n.localeName).format(bytes / kb / kb);
  return l10n.downloadsSizeMb(mb);
}

/// Why decks could not be downloaded, and what to do about it.
String downloadFailureText(
  AppLocalizations l10n,
  DeckDownloadFailure? failure,
) => switch (failure) {
  DeckDownloadFailure.rateLimited => l10n.downloadsRateLimited,
  DeckDownloadFailure.badFile => l10n.downloadsBadFile,
  DeckDownloadFailure.invalid => l10n.downloadsInvalid,
  DeckDownloadFailure.storage => l10n.downloadsStorage,
  DeckDownloadFailure.appTooOld => l10n.downloadsAppTooOld,
  DeckDownloadFailure.notOffered => l10n.downloadsNotOffered,
  DeckDownloadFailure.offline || null => l10n.downloadsOffline,
};
