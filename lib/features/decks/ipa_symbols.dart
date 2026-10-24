import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/speaker.dart';
import '../drill/sounds_of_word.dart';

/// How a word is said, symbol by symbol (owner, 2026-10-22): one row for each
/// sound of the word's IPA, in the order they appear, taken from the IPA
/// course, with what the sound is, a word that has it, a speaker for that
/// word and a Practise button that opens that sound's practice in the course.
///
/// Where the IPA course is not on the phone, a line says so and offers to add
/// it. Nothing at all for a card with no IPA, or while IPA pronunciations is
/// off in Settings.
class IpaSymbols extends StatelessWidget {
  const IpaSymbols({super.key, required this.card});

  final Card card;

  @override
  Widget build(BuildContext context) {
    final ipa = ipaToShow(context, card.ipa, target: card.target);
    if (ipa == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final text = ipa.replaceAll(RegExp(r'[/\[\]\s.]'), '');
    final symbols = <Card>[...state.soundsOfWord(card)];
    symbols.sort((a, b) => text.indexOf(a.target) - text.indexOf(b.target));
    if (symbols.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.ipaSymbolsNone, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          OutlinedButton(
            style: AppButtonStyles.compact(context),
            onPressed: () => openSoundsOfWord(context, card),
            child: Text(l10n.ipaSymbolsAdd),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (i, symbol) in symbols.indexed) ...<Widget>[
          if (i > 0) const Divider(height: 1),
          _SymbolRow(symbol: symbol),
        ],
      ],
    );
  }
}

class _SymbolRow extends StatelessWidget {
  const _SymbolRow({required this.symbol});

  final Card symbol;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final example = symbol.examples.where((e) => e.sounds).firstOrNull;
    final code = example?.language;
    final spoken = code == null ? null : state.languageByCode(code);
    final heard = example == null || spoken == null || !state.hasVoice(spoken)
        ? null
        : (word: example.target, language: spoken);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              symbol.target,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.titleLarge!.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w500,
                fontFamilyFallback: IpaLine.fontFallback,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(symbol.native, style: theme.textTheme.bodyMedium),
                if (example != null)
                  Text(
                    l10n.ipaSymbolExample(example.target, example.native),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                Row(
                  children: <Widget>[
                    if (heard != null)
                      SpeakerIcon(
                        onPlay: () => state.speak(heard.word, heard.language),
                        label: l10n.ipaExamplePlay(heard.word),
                      ),
                    OutlinedButton(
                      style: AppButtonStyles.compact(context),
                      onPressed: () => openSoundPractice(context, symbol),
                      child: Text(l10n.ipaSymbolPractise),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
