import 'package:flutter/material.dart';

import '../../core/models/level.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The amber of the "Professional" and "above your level" marks, and the
/// colour on it (the approved mockups' `--pl` and `--onPl`; the same amber as
/// the Progress star's placed layer). At least 4.5:1 on the screen and on the
/// card, light and dark.
Color amberOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFE0A458)
    : const Color(0xFF8A5A00);

Color onAmberOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF2B1A00)
    : const Color(0xFFFFFFFF);

/// How a [ResultTag] looks.
enum ResultTagStyle {
  /// A level: outlined, muted text.
  level,

  /// A kind: on the secondary container.
  kind,

  /// "Professional": filled amber.
  professional,

  /// "Above your level": amber outline and text, with a lock.
  above,
}

/// A small rounded label under a result: a kind, a level, "Professional".
/// Never colour alone: the lock and the words carry the meaning too.
class ResultTag extends StatelessWidget {
  const ResultTag({super.key, required this.text, required this.style});

  final String text;
  final ResultTagStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amber = amberOf(context);
    final (background, foreground, border) = switch (style) {
      ResultTagStyle.level => (null, scheme.onSurfaceVariant, scheme.outline),
      ResultTagStyle.kind => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        null,
      ),
      ResultTagStyle.professional => (amber, onAmberOf(context), null),
      ResultTagStyle.above => (null, amber, amber),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: border == null ? null : Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 7,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (style == ResultTagStyle.above) ...<Widget>[
              Icon(Icons.lock_outline, size: 12, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: foreground, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A level as a tag: "A2", or for an item above the learner's level "B1 ·
/// above your level" with a lock. Nothing for an item with no level.
class LevelTag extends StatelessWidget {
  const LevelTag({super.key, required this.level, this.above = false});

  final Level? level;
  final bool above;

  @override
  Widget build(BuildContext context) {
    final level = this.level;
    if (level == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return ResultTag(
      text: above ? l10n.searchAboveYourLevel(level.label) : level.label,
      style: above ? ResultTagStyle.above : ResultTagStyle.level,
    );
  }
}

/// The sheet an item above the learner's level opens instead of starting: its
/// name, its level, and that it opens once the learner reaches it. A preview,
/// never a lesson.
Future<void> showAboveLevelSheet(
  BuildContext context, {
  required String name,
  required Level? level,
}) {
  final l10n = AppLocalizations.of(context)!;
  final label = level?.label ?? '';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline, color: amberOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.searchAboveSheetTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.searchAboveSheetBody(name, label),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One result row's frame: an optional 40 dp icon, a title, lines, tags, and
/// an optional trailing widget; the whole row taps through [onTap]. [actions]
/// sit under the row and are not part of its tap, so that a button in a row
/// stays a button of its own. A [dim] row (above the learner's level) has a
/// regular-weight, muted title.
class ResultRow extends StatelessWidget {
  const ResultRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.leadingText,
    this.lines = const <Widget>[],
    this.tags = const <Widget>[],
    this.trailing,
    this.actions,
    this.onTap,
    this.dim = false,
    this.titleWidget,
  });

  final String title;

  /// Replaces the plain title text, for a title in the language learned.
  final Widget? titleWidget;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;

  /// Text in the icon square instead of an icon ("Aa").
  final String? leadingText;
  final List<Widget> lines;
  final List<Widget> tags;
  final Widget? trailing;
  final Widget? actions;
  final VoidCallback? onTap;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasIcon = icon != null || leadingText != null;
    final main = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (hasIcon) ...<Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground ?? scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(
                        icon,
                        size: 22,
                        color: iconColor ?? scheme.onSecondaryContainer,
                      )
                    : Text(
                        leadingText!,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: iconColor ?? scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  titleWidget ??
                      Text(
                        title,
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: dim ? FontWeight.w400 : FontWeight.w500,
                          color: dim ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                  for (final line in lines) ...<Widget>[
                    const SizedBox(height: 3),
                    line,
                  ],
                  if (tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: tags),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
    final tappable = onTap == null
        ? main
        : Semantics(
            button: true,
            child: InkWell(onTap: onTap, child: main),
          );
    if (actions == null) return tappable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        tappable,
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: hasIcon ? 68 : 16,
            end: 12,
            bottom: 12,
          ),
          child: actions,
        ),
      ],
    );
  }
}

/// A muted one-line caption under a row's title.
class RowLine extends StatelessWidget {
  const RowLine(this.text, {super.key, this.dim = false});

  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall!
        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}
