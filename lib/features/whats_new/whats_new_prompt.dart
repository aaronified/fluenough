import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../core/updates/whats_new.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// Shows [WhatsNewSheet] once, on the first launch after an update (#944;
/// owner, 2026-10-31): the headline of each CHANGELOG entry of the new
/// version. Wraps the app's shell, so it never shows over the first-launch
/// setup.
///
/// The last version seen is `settings.lastSeenVersion`. Nothing stored means
/// a fresh install (or one from before this existed): the current version
/// is stored and nothing shows. A stored version earlier than [version]
/// shows the sheet, or, if that version's CHANGELOG section has no entry to
/// list, nothing, and stores [version] either way, so it is asked once per
/// version and never again after the app is killed with the sheet open. The
/// CHANGELOG is the bundled asset: no request to GitHub (ADR-0017).
class WhatsNewPrompt extends StatefulWidget {
  const WhatsNewPrompt({
    super.key,
    required this.child,
    this.version = AppInfo.version,
    this.loadChangelog = _bundledChangelog,
  });

  final Widget child;

  /// The installed version. Tests give another.
  final String version;

  /// Reads the CHANGELOG's text. Tests give their own.
  final Future<String> Function() loadChangelog;

  static Future<String> _bundledChangelog() =>
      rootBundle.loadString('CHANGELOG.md');

  @override
  State<WhatsNewPrompt> createState() => _WhatsNewPromptState();
}

class _WhatsNewPromptState extends State<WhatsNewPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (!mounted) return;
    final settings = AppScope.read(context).settings;
    final seen = settings.lastSeenVersion;
    if (seen == widget.version) return;
    if (!isNewVersionSinceSeen(seen, widget.version)) {
      // A fresh install, or a version going back: nothing to show. Only a
      // fresh install records where it started.
      if (seen == null) settings.lastSeenVersion = widget.version;
      return;
    }
    var headlines = const <String>[];
    try {
      headlines = whatsNewHeadlines(
        await widget.loadChangelog(),
        widget.version,
      );
    } on Object {
      // Unreadable: skipped, like a version with nothing to list.
    }
    settings.lastSeenVersion = widget.version;
    if (headlines.isEmpty || !mounted) return;
    await showWhatsNewSheet(context, widget.version, headlines);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The sheet: the heading, [version], a bullet for each of [headlines] and
/// one button that closes it.
Future<void> showWhatsNewSheet(
  BuildContext context,
  String version,
  List<String> headlines,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => WhatsNewSheet(version: version, headlines: headlines),
);

class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({
    super.key,
    required this.version,
    required this.headlines,
  });

  final String version;
  final List<String> headlines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.whatsNewTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(
              l10n.whatsNewVersion(version),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final headline in headlines)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: 9,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                headline,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.whatsNewDone),
            ),
          ],
        ),
      ),
    );
  }
}
