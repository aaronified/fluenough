import 'package:flutter/material.dart';

import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/faded_row.dart';

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

/// One verification state as a list row draws it: its flag and "Verified:"
/// before its word. One label for a screen reader, "Verified by
/// native speakers: somewhat", which the icon and the text leave out.
class VerificationMark extends StatelessWidget {
  const VerificationMark({super.key, required this.state, this.style});

  final NativeVerification state;

  /// The text's style; the theme's small body text by default.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final base = (style ?? theme.textTheme.bodySmall!).copyWith(
      color: theme.colorScheme.onSurface,
    );
    final word = verificationWord(l10n, state);
    return Semantics(
      container: true,
      label: l10n.languagesVerifiedLabel(word.toLowerCase()),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          VerificationFlag(state: state),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: '${l10n.languagesVerifiedShort} '),
                  TextSpan(
                    text: word,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              style: base,
            ),
          ),
        ],
      ),
    );
  }
}

/// The key above Add a language's list: "Verified by native speakers:" and
/// the three states, one row that scrolls sideways, faded at both edges.
class VerificationKey extends StatelessWidget {
  const VerificationKey({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall!;
    return Semantics(
      container: true,
      label: <String>[
        l10n.languagesVerifiedKey,
        for (final state in NativeVerification.values)
          verificationWord(l10n, state),
      ].join(' '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 8, bottom: 2),
        child: FadedScrollRow(
          gap: 14,
          children: <Widget>[
            Text(
              l10n.languagesVerifiedKey,
              softWrap: false,
              style: small.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            for (final state in NativeVerification.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  VerificationFlag(state: state),
                  const SizedBox(width: 6),
                  Text(
                    verificationWord(l10n, state),
                    softWrap: false,
                    style: small.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
