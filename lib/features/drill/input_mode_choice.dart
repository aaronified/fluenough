import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
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
      child: Segmented<String>(
        semanticLabel: l10n.drillInputModeGroup,
        // The 48dp tap target, which 44 fell short of at small text.
        height: 48,
        selected: session.transliterating ? _translit : session.inputScript,
        onSelected: incoming
            ? null
            : (choice) {
                onChanged();
                if (choice == _translit) {
                  session.inputMode = InputMode.translit;
                } else {
                  session.chooseScript(choice);
                }
              },
        options: <SegmentOption<String>>[
          // One option for each script learned (#623).
          for (final script in session.writeScripts)
            SegmentOption<String>(
              value: script,
              label: l10n.drillInputScript(
                l10n.scriptNameOr(script, language.name),
              ),
              leading: TargetText(
                _glyph(script),
                language: language.inScript(script),
                fontSize: 16,
              ),
            ),
          SegmentOption<String>(
            value: _translit,
            label: l10n.drillInputTranslit,
            leading: const Icon(Icons.abc, size: 20),
          ),
        ],
      ),
    );
  }

  /// The id of the Latin-letters option, among the scripts' ids.
  static const String _translit = 'translit';

  /// One letter in [script]: the current card's, else the deck's.
  String _glyph(String script) {
    if (script == session.deck.language.script) return session.deck.glyph;
    final spelling = session.item.card.targetIn(
      script,
      firstScript: session.deck.language.script,
    );
    final trimmed = spelling?.trim() ?? '';
    return trimmed.isEmpty ? session.deck.glyph : trimmed.characters.first;
  }
}
