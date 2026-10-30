import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';

/// An IPA card's examples, all of them, each in its own language (ADR-0041):
/// the words where the card's letter is said with the card's sound, and the
/// words where the same letter is not, each marked as which it is, with the
/// word's IPA and a speaker that says it in its language's voice. Those in a
/// language the learner learns come first; a language the phone has no voice
/// for has no speaker, since the sound is optional.
class IpaExamples extends StatelessWidget {
  const IpaExamples({super.key, required this.card, required this.language});

  final Card card;

  /// The IPA, the card's own language.
  final LanguageInfo language;

  /// [examples] with those in a language in [learned] first, otherwise in
  /// the order written.
  static List<CardExample> ordered(
    List<CardExample> examples,
    Set<String> learned,
  ) => <CardExample>[
    for (final first in <bool>[true, false])
      for (final example in examples)
        if (learned.contains(example.language) == first) example,
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final examples = ordered(card.examples, state.learningCodes);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: <Widget>[
        for (final example in examples)
          _IpaExample(example: example, language: language),
      ],
    );
  }
}

class _IpaExample extends StatelessWidget {
  const _IpaExample({required this.example, required this.language});

  final CardExample example;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.read(context);
    final spoken = example.language == null
        ? null
        : state.languageByCode(example.language!);
    final sounds = example.sounds;
    final ipa = example.ipa;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.drillExample,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Both an icon and words: which is which is not told by
                  // colour alone.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        sounds
                            ? Icons.check_circle_outline
                            : Icons.highlight_off,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          sounds
                              ? l10n.ipaExampleSounds
                              : l10n.ipaExampleDoesNot,
                          style: theme.textTheme.labelLarge!.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TargetText.card(
                      example.target,
                      language: spoken ?? language,
                      fontSize: 18,
                      color: scheme.onSurface,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  if (ipa != null)
                    Text(
                      ipa.startsWith('[') && ipa.endsWith(']') ? ipa : '/$ipa/',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    example.native,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (spoken != null && state.hasVoice(spoken))
              SpeakerIcon(
                onPlay: () => state.speak(example.target, spoken),
                label: l10n.ipaExamplePlay(example.target),
              ),
          ],
        ),
      ),
    );
  }
}
