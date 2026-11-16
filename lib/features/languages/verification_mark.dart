import 'package:flutter/material.dart';

import '../../core/data/course_path.dart' show Milestone;
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../placement/course_line.dart';

/// The word of a verification state: "Not at all", "Somewhat", "Completely".
String verificationWord(AppLocalizations l10n, NativeVerification state) =>
    switch (state) {
      NativeVerification.none => l10n.languagesVerifiedNone,
      NativeVerification.some => l10n.languagesVerifiedSome,
      NativeVerification.full => l10n.languagesVerifiedFull,
    };

/// The sentence the language's details put under the state.
String verificationDetail(AppLocalizations l10n, NativeVerification state) =>
    switch (state) {
      NativeVerification.none => l10n.languagesVerifiedNoneDetail,
      NativeVerification.some => l10n.languagesVerifiedSomeDetail,
      NativeVerification.full => l10n.languagesVerifiedFullDetail,
    };

/// A flag that says a verification state by its shape, never by colour
/// alone (the approved mockup `language-level-verification.html`): an
/// outlined flag for Not at all, a half-filled one for Somewhat, a solid one
/// for Completely. Only the colour differs too: muted for Not at all, the
/// primary colour for the others.
class VerificationFlag extends StatelessWidget {
  const VerificationFlag({super.key, required this.state});

  final NativeVerification state;

  /// The icon's size.
  static const double size = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = state == NativeVerification.none
        ? scheme.onSurfaceVariant
        : scheme.primary;
    final icon = switch (state) {
      NativeVerification.none => Icon(
        Icons.flag_outlined,
        size: size,
        color: color,
      ),
      NativeVerification.full => Icon(Icons.flag, size: size, color: color),
      NativeVerification.some => Stack(
        children: <Widget>[
          Icon(Icons.flag_outlined, size: size, color: color),
          // The start half of the solid flag over the outline.
          ClipRect(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.5,
              child: Icon(Icons.flag, size: size, color: color),
            ),
          ),
        ],
      ),
    };
    return ExcludeSemantics(child: icon);
  }
}

/// A language's verification state in Add a language's list, as the flag
/// alone, 40 dp square so that it is an easy target. A tap shows a tooltip
/// bubble only, "Verified: Somewhat", no sheet; the key above the list names
/// the three states once. One label for a screen reader, "Verified by native
/// speakers: somewhat", which the flag leaves out.
class VerificationFlagButton extends StatelessWidget {
  const VerificationFlagButton({super.key, required this.state});

  final NativeVerification state;

  /// The button's width and height.
  static const double extent = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final word = verificationWord(l10n, state);
    return Tooltip(
      message: '${l10n.languagesVerifiedShort} $word',
      triggerMode: TooltipTriggerMode.tap,
      excludeFromSemantics: true,
      child: Semantics(
        label: l10n.languagesVerifiedLabel(word.toLowerCase()),
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: extent,
          child: Center(child: VerificationFlag(state: state)),
        ),
      ),
    );
  }
}

/// The key at the top of Add a language's full list, one card that says
/// everything once: "How much of the course is made" with a sample bar and
/// the names of its four parts (A1, A2, B1, Culture), then "Verified by
/// native speakers:" and the three flags with their words. The rows under it
/// carry no labels of their own.
class VerificationKey extends StatelessWidget {
  const VerificationKey({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall!;
    final names = <String>[
      Milestone.a1.name.toUpperCase(),
      Milestone.a2.name.toUpperCase(),
      Milestone.b1.name.toUpperCase(),
      l10n.pickerLevelCulture,
    ];
    return Semantics(
      container: true,
      label: <String>[
        l10n.languagesCourseMadeKey,
        names.join(l10n.commonListSeparator),
        l10n.languagesVerifiedKey,
        for (final state in NativeVerification.values)
          verificationWord(l10n, state),
      ].join(' '),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('languages-key'),
        margin: const EdgeInsetsDirectional.only(top: 10),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.languagesCourseMadeKey,
              style: theme.textTheme.labelMedium!.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // A sample: A1 and A2 written, B1 half, Culture still to come.
            const CourseLine(
              levels: <double>[1, 1, 0.5],
              culture: 0,
              compact: true,
            ),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                for (final (i, name) in names.indexed) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  l10n.languagesVerifiedKey,
                  style: small.copyWith(color: scheme.onSurfaceVariant),
                ),
                for (final state in NativeVerification.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      VerificationFlag(state: state),
                      const SizedBox(width: 4),
                      Text(
                        verificationWord(l10n, state),
                        style: small.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The row of a language's details: "Verified by native speakers", the state
/// with its flag, and one plain sentence under it.
class VerificationRow extends StatelessWidget {
  const VerificationRow({super.key, required this.state});

  final NativeVerification state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final word = verificationWord(l10n, state);
    return Semantics(
      container: true,
      label:
          '${l10n.languagesVerifiedLabel(word.toLowerCase())}. '
          '${verificationDetail(l10n, state)}',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('language-verified'),
        margin: const EdgeInsetsDirectional.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.languagesVerifiedHeading,
              style: theme.textTheme.labelLarge!.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: <Widget>[
                VerificationFlag(state: state),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    word,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              verificationDetail(l10n, state),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
