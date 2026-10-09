import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';

/// Opens [card]'s card in a sheet over a unit's screen.
Future<void> showWordSheet(
  BuildContext context, {
  required Card card,
  required LanguageInfo language,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => WordSheet(card: card, language: language),
);

/// The tag that marks a rude card: one an `audience: adult` deck would hold
/// (#96, docs/plans/offensive-words.md). No bundled card carries it yet.
const String rudeTag = 'offensive';

/// Whether [card] is a rude word: tagged so, or in a deck tagged so.
bool isRude(Card card, DeckEntry? deck) =>
    card.tags.contains(rudeTag) || (deck?.deck.tags.contains(rudeTag) ?? false);

/// Whether the learner has turned adult content on. There is no such
/// setting yet (#96): until there is, a rude word is always hidden.
bool adultContentOn(AppState state) => false;

/// The card of a word on a unit's screen: its picture, the word and its
/// reading, how it is said in the IPA, its meaning, its note and its first
/// example. Where it has a minimal-pair partner, a word that sounds almost
/// the same, it warns of it; a rude partner is not named unless adult
/// content is on (docs/plans/offensive-words.md).
class WordSheet extends StatelessWidget {
  const WordSheet({
    super.key,
    required this.card,
    required this.language,
    this.showRude,
  });

  final Card card;
  final LanguageInfo language;

  /// Whether a rude partner is named; by default, whether adult content is
  /// on. For tests.
  final bool? showRude;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final reading = card.reading;
    final ipa = card.ipa;
    final notes = card.notes;
    final example = card.examples.firstOrNull;
    final partner = _partner(state);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ReportButton(detail: card.id),
            ),
            if (card.picture != null) ...<Widget>[
              Center(child: CardPicture(card, size: 88)),
              const SizedBox(height: 12),
            ],
            TargetText(card.target, language: language, fontSize: 44),
            if (reading != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                reading,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (ipa != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                l10n.wordSheetIpa(ipa),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              card.native,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (notes != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                notes,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (example != null) ...<Widget>[
              const SizedBox(height: 16),
              Semantics(
                container: true,
                label: l10n.drillExample,
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Column(
                    children: <Widget>[
                      TargetText(
                        example.target,
                        language: language,
                        fontSize: 17,
                        color: scheme.onSurface,
                      ),
                      if (example.reading case final r?)
                        Text(
                          r,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        example.native,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (partner != null) ...<Widget>[
              const SizedBox(height: 16),
              _SoundsLike(
                partner: partner,
                language: language,
                rude: isRude(partner, state.deckOf(partner)),
                showRude: showRude ?? adultContentOn(state),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The card [card] names as its minimal-pair partner, from any deck.
  Card? _partner(AppState state) {
    final id = card.pair;
    if (id == null) return null;
    for (final entry in state.decks) {
      for (final other in entry.cards) {
        if (other.id == id) return other;
      }
    }
    return null;
  }
}

/// "Sounds almost like కలం (kalam), pen. Take care when you say it." Or for a
/// rude word with adult content off, the warning without the word.
class _SoundsLike extends StatelessWidget {
  const _SoundsLike({
    required this.partner,
    required this.language,
    required this.rude,
    required this.showRude,
  });

  final Card partner;
  final LanguageInfo language;
  final bool rude;
  final bool showRude;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = partner.reading;
    final named = reading == null
        ? l10n.wordSheetSoundsLikeNoReading(partner.target, partner.native)
        : l10n.wordSheetSoundsLike(partner.target, reading, partner.native);
    final hidden = rude && !showRude;
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
              Icons.hearing_outlined,
              size: 22,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.wordSheetSoundsLikeTitle,
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    hidden
                        ? TextSpan(text: l10n.wordSheetSoundsRude)
                        : quotingTarget(named, <String>[
                            partner.target,
                          ], language),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  if (rude && showRude) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      l10n.wordSheetSoundsRude,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
