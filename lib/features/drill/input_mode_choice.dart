import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/segmented.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';

/// Script or Latin letters, above a typed answer (#47). [onChanged] runs
/// before the mode changes, to clear what was typed in the other.
///
/// While `Feature.translitInput` is incoming the choice is shown dimmed,
/// with its badge.
class InputModeChoice extends StatelessWidget {
  const InputModeChoice({
    super.key,
    required this.session,
    required this.onChanged,
  });

  final DrillSession session;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = session.deck.language;
    final incoming = isIncoming(context, Feature.translitInput);
    return IncomingFeature(
      feature: Feature.translitInput,
      label: l10n.drillInputModeGroup,
      badge: IncomingBadgePlacement.below,
      child: Segmented<InputMode>(
        semanticLabel: l10n.drillInputModeGroup,
        height: 44,
        selected: session.transliterating
            ? InputMode.translit
            : InputMode.script,
        onSelected: incoming
            ? null
            : (mode) {
                onChanged();
                session.inputMode = mode;
              },
        options: <SegmentOption<InputMode>>[
          SegmentOption<InputMode>(
            value: InputMode.script,
            label: l10n.drillInputScript(language.name),
            leading: TargetText(
              session.deck.glyph,
              language: language,
              fontSize: 16,
            ),
          ),
          SegmentOption<InputMode>(
            value: InputMode.translit,
            label: l10n.drillInputTranslit,
            leading: const Icon(Icons.abc, size: 20),
          ),
        ],
      ),
    );
  }
}
