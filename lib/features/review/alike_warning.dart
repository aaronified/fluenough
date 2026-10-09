import 'package:flutter/material.dart' hide Card;

import '../../app/app_state.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/word_sheet.dart' show adultContentOn;
import 'review_words.dart';

/// The warning on a word like a rude one (docs/plans/offensive-words.md):
/// "Careful when speaking" for a sound-alike, "Careful when writing" for a
/// look-alike, and a care note where a reviewer wrote one. The rude word is
/// named only with adult content on, as [named]; otherwise the warning
/// says it is hidden.
///
/// A drill shows it once the word is shown or answered, never before, so
/// that it gives nothing away.
class AlikeWarning extends StatelessWidget {
  const AlikeWarning({
    super.key,
    required this.kind,
    this.named,
    this.language,
    this.care,
  });

  final AlikeKind kind;

  /// The rude word, its reading and meaning, to name: null hides it.
  final Card? named;

  /// [named]'s language, so that a screen reader reads it in it.
  final LanguageInfo? language;

  /// What to take care of, at most 40 letters, or null.
  final String? care;

  /// The warnings for [card], for a drill or a card: one per rude word it
  /// is like, naming them only with adult content on. Empty for most cards.
  static List<Widget> forCard(
    AppState state,
    Card card,
    LanguageInfo language,
  ) {
    final adult = adultContentOn(state);
    return <Widget>[
      for (final pair in rudeAlikesOf(state, card))
        AlikeWarning(
          kind: pair.kind,
          named: adult ? pair.partner : null,
          language: language,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onTertiaryContainer,
    );
    final named = this.named;
    final care = this.care;
    final speaking = kind == AlikeKind.sound;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: <Widget>[
                  Text(
                    speaking
                        ? l10n.alikeCarefulSpeaking
                        : l10n.alikeCarefulWriting,
                    style: style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    speaking ? l10n.alikeSpeakingRude : l10n.alikeWritingRude,
                    style: style,
                  ),
                  if (care != null && care.isNotEmpty) Text(care, style: style),
                  if (named != null && language != null)
                    Text.rich(
                      quotingTarget(_name(l10n, named), <String>[
                        named.target,
                      ], language!),
                      style: style,
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 2),
                          child: Icon(
                            Icons.visibility_off_outlined,
                            size: 16,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.alikeHidden,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _name(AppLocalizations l10n, Card word) {
    final reading = word.reading;
    return switch ((kind, reading)) {
      (AlikeKind.sound, null) => l10n.reviewAlikeSoundsNoReading(word.target),
      (AlikeKind.sound, final r?) => l10n.reviewAlikeSounds(word.target, r),
      (AlikeKind.look, null) => l10n.reviewAlikeLooksNoReading(word.target),
      (AlikeKind.look, final r?) => l10n.reviewAlikeLooks(word.target, r),
    };
  }
}
