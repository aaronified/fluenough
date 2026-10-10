import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/target_text.dart';
import '../review/alike_warning.dart';
import '../review/review_words.dart';
import 'card_bases.dart';
import 'card_notes.dart';
import 'card_top_line.dart';
import 'checked_by_line.dart';
import 'path_model.dart' show isSentence;
import 'path_parts.dart' show masteryName;
import 'word_mastery.dart';

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

/// Whether the learner has turned adult content on, in Settings' "Adult
/// content (18+)" (#96). Off, a rude word is hidden. Read it inside a
/// `ListenableBuilder` on the settings, so that switching it off hides the
/// word at once.
bool adultContentOn(AppState state) => state.settings.adultContent;

/// The card of a word on a unit's screen: a top line with its id, part of
/// speech and where the learner stands with it, a speaker and the bug icon;
/// then its picture, the word and its reading, how it is said in the IPA,
/// its meaning, its notes, its base words ([BaseLine]) and its first
/// example.
///
/// Where a minimal-pair partner, a word that sounds almost the same (its
/// `pair` or a pair note's), is rude, it carries the warning the drill cards carry, "Careful when
/// speaking" ([AlikeWarning]), which names the rude word only with adult
/// content on (docs/plans/offensive-words.md). Any other partner it names,
/// as "Sounds like another word". A pair note's text goes with its
/// partner.
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
  /// on. For tests and the gallery.
  final bool? showRude;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Adult content is a setting: off again, the word hides at once.
    listenable: AppScope.of(context).settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final reading = card.reading;
    final ipa = card.ipa;
    final notes = shownNotes(card);
    final example = card.examples.firstOrNull;
    final bases = basesOf(state, card, language);
    final rudeAlikes = rudeAlikesOf(state, card);
    final rudeIds = <String>{for (final a in rudeAlikes) a.partner.id};
    final partners = <({Card card, String? care})>[
      for (final pair in pairsOf(card))
        if (!rudeIds.contains(pair.id))
          if (_find(state, pair.id) case final found?)
            (card: found, care: pair.care),
    ];
    final named = showRude ?? adultContentOn(state);
    final status = masteryName(
      l10n,
      RecentAnswers(state.progress.log).of(card.id),
      notOpen: isSentence(card) && !state.isTaught(card),
    );
    final pos = card.pos;
    final checked = checkedByOf(state.decks, card).length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CardTopLine(
              text: pos == null
                  ? l10n.wordSheetLine(card.id, status)
                  : l10n.wordSheetLinePos(card.id, pos, status),
              card: card,
              language: language,
              report: card.id,
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
            if (checked > 0) ...<Widget>[
              const SizedBox(height: 8),
              CheckedByLine(count: checked),
            ],
            for (final note in notes) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (bases.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              BaseLine(bases: bases, language: language),
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
            for (final alike in rudeAlikes) ...<Widget>[
              const SizedBox(height: 16),
              AlikeWarning(
                kind: alike.kind,
                named: named ? alike.partner : null,
                language: language,
                care: alike.care,
              ),
            ],
            for (final partner in partners) ...<Widget>[
              const SizedBox(height: 16),
              _SoundsLike(
                partner: partner.card,
                language: language,
                care: partner.care,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The card with [id], from any deck: a partner [card] names.
  static Card? _find(AppState state, String id) {
    for (final entry in state.decks) {
      for (final other in entry.cards) {
        if (other.id == id) return other;
      }
    }
    return null;
  }
}

/// "Sounds almost like కలం (kalam), pen. Take care when you say it.": a
/// partner that is not rude. A rude one has [AlikeWarning] instead.
class _SoundsLike extends StatelessWidget {
  const _SoundsLike({required this.partner, required this.language, this.care});

  final Card partner;
  final LanguageInfo language;

  /// The pair note's own text, if it has one.
  final String? care;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = partner.reading;
    final named = reading == null
        ? l10n.wordSheetSoundsLikeNoReading(partner.target, partner.native)
        : l10n.wordSheetSoundsLike(partner.target, reading, partner.native);
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
                    quotingTarget(named, <String>[partner.target], language),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  if (care case final care?)
                    Text(
                      care,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
