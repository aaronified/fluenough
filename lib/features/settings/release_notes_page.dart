import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/links.dart';
import '../../core/updates/markdown_subset.dart';
import '../../core/updates/release_check.dart';
import '../../core/updates/release_notes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import 'markdown_view.dart';

/// What changed in each release of the app: Settings' "What's new"
/// (ADR-0031).
///
/// Opening the page asks GitHub for the notes, once, and nothing before it:
/// the app asks for nothing at launch. While GitHub answers there is a
/// spinner; if it cannot be reached, or its answer cannot be read, a plain
/// message and Try again, which asks once more. The releases come newest
/// first, each with its tag, its date and its notes, and the one that is the
/// version running now is marked Installed. "See all releases on GitHub"
/// stays at the foot in every state, for the releases not listed and for
/// when this page cannot reach them.
class ReleaseNotesPage extends StatefulWidget {
  const ReleaseNotesPage({super.key});

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  /// What GitHub answered, or null while it is being asked.
  ReleaseNotes? _notes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks GitHub. Try again is shown only once an answer is in, and the
  /// spinner replaces it, so there is never more than one ask at a time.
  Future<void> _load() async {
    final engine = AppScope.read(context).releaseNotes;
    if (_notes != null) setState(() => _notes = null);
    final notes = await engine.fetch();
    if (mounted) setState(() => _notes = notes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notes = _notes;

    final Widget content = switch (notes) {
      null => Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.releaseNotesLoading,
          ),
        ),
      ),
      ReleaseNotes(:final failure?) => _Failure(
        message: switch (failure) {
          ReleaseCheckFailure.offline => l10n.releaseNotesOffline,
          ReleaseCheckFailure.rateLimited => l10n.releaseNotesRateLimited,
          ReleaseCheckFailure.badReply => l10n.releaseNotesBadReply,
        },
        onRetry: _load,
      ),
      ReleaseNotes(releases: final releases) when releases.isEmpty => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 32,
        ),
        child: Text(
          l10n.releaseNotesNone,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ),
      ReleaseNotes(:final releases) => GroupedList(
        children: <Widget>[
          for (final release in releases) _ReleaseRow(release: release),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.releaseNotesTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: <Widget>[
          content,
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              textStyle: theme.textTheme.titleMedium,
            ),
            onPressed: () => openLink(
              context,
              AppLinks.releases,
              copied: l10n.releaseNotesLinkCopied,
            ),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              l10n.releaseNotesOpenGitHub,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the notes are not here, and Try again. The message is a live region,
/// so a screen reader hears it arrive in place of the spinner.
class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.sync_problem_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.commonRetry),
          ),
        ],
      ),
    );
  }
}

/// One release: its tag as a heading, Installed beside it when it is this
/// build, its date, and its notes.
class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.release});

  final PublishedRelease release;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final published = release.publishedAt;
    final blocks = parseMarkdownSubset(release.body);
    final quiet = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: GroupedTile.defaultPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // One heading for a screen reader: "v0.3.3, Installed".
          MergeSemantics(
            child: Semantics(
              header: true,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(release.tag, style: theme.textTheme.titleLarge),
                  if (release.isVersion(AppInfo.version))
                    _InstalledBadge(label: l10n.releaseNotesInstalled),
                ],
              ),
            ),
          ),
          if (published != null)
            Text(
              DateFormat.yMMMd(locale).format(published.toLocal()),
              style: quiet,
            ),
          const SizedBox(height: 12),
          if (blocks.isEmpty)
            Text(l10n.releaseNotesNoNotes, style: quiet)
          else
            MarkdownView(blocks: blocks),
        ],
      ),
    );
  }
}

/// "Installed": a pill in `primaryContainer`. Words, not colour alone.
class _InstalledBadge extends StatelessWidget {
  const _InstalledBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.badge.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
