import 'package:flutter/material.dart';

import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';

/// A suggestion as the Reviewed pages list it (#471, the reviewer mode
/// mockup, section 1): its [title], then Now, Yours and Why, each a labelled
/// line that wraps, so that it holds at the largest text. Not tappable; a
/// [footer] goes below, such as the state of a sent suggestion.
class SuggestionLines extends StatelessWidget {
  const SuggestionLines({
    super.key,
    required this.title,
    required this.yours,
    this.now,
    this.why = '',
    this.footer,
  });

  final String title;

  /// What the part said when suggested, or null to leave the line out.
  final String? now;
  final String yours;
  final String why;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget line(String label, String text) => Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label  ',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          TextSpan(text: text),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          if (now != null) line(l10n.reviewYoursNow, now!),
          line(l10n.reviewYoursYours, yours),
          if (why.isNotEmpty) line(l10n.reviewYoursWhy, why),
          if (footer != null) ...<Widget>[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}

/// What [s] suggests, as text: its text, or for a base added, changed or
/// removed (#476), the base it names.
String yoursOf(Suggestion s) {
  if (s.text.trim().isNotEmpty) return s.text;
  final b = s.base ?? s.was;
  return b?.base ?? b?.meaning ?? b?.ref ?? s.word ?? '';
}
