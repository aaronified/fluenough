import 'package:flutter/material.dart';

import '../../core/data/spoken_languages.dart';
import '../../core/private/private_ids.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// How big [bytes] is, for a package: `6 KB`, `2.4 MB`. The units are the
/// ones the 10 MB limit is written in.
String privateSizeText(int bytes) {
  if (bytes < 1024 * 1024) {
    final kb = (bytes / 1024).ceil();
    return '${kb < 1 ? 1 : kb} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The share of the 10 MB limit [bytes] takes, 0 to 1, never less than a
/// sliver so that the bar shows.
double privateSizeShare(int bytes, {int limit = 10 * 1024 * 1024}) =>
    (bytes / limit).clamp(0.02, 1.0);

/// What a [PrivateTag] is for: its colours.
enum PrivateTagKind { neutral, modified, active, warning, error }

/// A word with an icon in a rounded chip: never colour alone (the mockups'
/// rule). 24 dp tall at least; not a tap target.
class PrivateTag extends StatelessWidget {
  const PrivateTag({
    super.key,
    required this.label,
    this.icon,
    this.kind = PrivateTagKind.neutral,
  });

  final String label;
  final IconData? icon;
  final PrivateTagKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color back, Color front) = switch (kind) {
      PrivateTagKind.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      PrivateTagKind.modified => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      PrivateTagKind.active => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      PrivateTagKind.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      PrivateTagKind.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: back,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: front),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium!
                  .copyWith(color: front),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tag a private language carries in the language lists (Plan-Private-
/// Languages 2.5): "Yours" for a language of the learner's own, "Privately
/// modified" for one the app teaches that a package changes. Draws nothing
/// for any other language.
class PrivateLanguageTag extends StatelessWidget {
  const PrivateLanguageTag({super.key, required this.language});

  final SpokenLanguage language;

  @override
  Widget build(BuildContext context) {
    if (!language.isPrivate) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: isPrivateCode(language.code)
          ? PrivateTag(label: l10n.privateYours, icon: Icons.person_outline)
          : PrivateTag(
              label: l10n.privateModified,
              icon: Icons.edit_outlined,
              kind: PrivateTagKind.modified,
            ),
    );
  }
}

/// The thin bar of a package's size against the 10 MB limit.
class PrivateSizeBar extends StatelessWidget {
  const PrivateSizeBar({super.key, required this.bytes, this.error = false});

  final int bytes;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.privateBarLabel(privateSizeText(bytes)),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.mark),
        child: LinearProgressIndicator(
          value: privateSizeShare(bytes),
          minHeight: 8,
          backgroundColor: scheme.surfaceContainerHighest,
          color: error ? scheme.error : scheme.primary,
        ),
      ),
    );
  }
}

/// A label and its value, one per line pair: the mockups' definition list.
class PrivateFacts extends StatelessWidget {
  const PrivateFacts({super.key, required this.rows});

  /// Label and value, in order.
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 104,
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A short block with an icon, for a notice that matters but does not block.
class PrivateNotice extends StatelessWidget {
  const PrivateNotice({super.key, required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
