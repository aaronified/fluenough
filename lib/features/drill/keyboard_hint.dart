import 'package:flutter/material.dart';

import '../../app/links.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';

/// Under the answer field for a script that needs its own keyboard: "No
/// Hindi keyboard? Try HeliBoard.", and "Get HeliBoard", which opens
/// HeliBoard's F-Droid page, or copies its address when nothing can.
class KeyboardHint extends StatelessWidget {
  const KeyboardHint({super.key, required this.language});

  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // At large text sizes the button goes under the text, which would
    // otherwise be squeezed to nothing beside it.
    final large = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final hint = Text(
      l10n.drillKeyboardHint(language.name),
      style: theme.textTheme.bodySmall!.copyWith(
        fontSize: 13,
        height: 18 / 13,
        color: scheme.onSurfaceVariant,
      ),
    );
    final button = TextButton(
      onPressed: () => openLink(
        context,
        AppLinks.heliboard,
        copied: l10n.drillHeliboardCopied,
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        textStyle: theme.textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(l10n.drillGetHeliboard),
    );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: large
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.keyboard_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[hint, const SizedBox(height: 4), button],
                  )
                : hint,
          ),
          if (!large) ...<Widget>[const SizedBox(width: 4), button],
        ],
      ),
    );
  }
}
