import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/unlocks.dart';
import '../../app/deck_catalog.dart';
import '../../core/decks/adult_gate.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/scheduling/skill_difficulty.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import '../drill/ipa_examples.dart';
import '../review/alike_warning.dart';
import '../review/review_words.dart';
import 'card_bases.dart';
import 'card_blocks.dart';
import 'card_facts.dart';
import 'card_notes.dart';
import 'checked_by_line.dart';
import 'ipa_info_dot.dart';
import 'path_model.dart' show isSentence;
import 'path_parts.dart' show joinParts, masteryName;
import 'wiktionary_links.dart';

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
const String rudeTag = adultTag;

/// Whether [card] is a rude word: tagged so, or in a deck tagged so.
bool isRude(Card card, DeckEntry? deck) => isRudeCard(card, deck?.deck);

/// Whether the learner has turned adult content on, in Settings' "Adult
/// content (18+)" (#96). Off, a rude word is hidden. Read it inside a
/// `ListenableBuilder` on the settings, so that switching it off hides the
/// word at once.
bool adultContentOn(AppState state) => state.settings.adultContent;

/// The word sheet: everything a card has, inline and unfolded, from a word's
/// row on a deck's or a unit's screen (owner, 2026-10-22, #691; it replaces
/// Inspect). Top to bottom: the word large, its reading, a speaker and its
/// IPA with an info dot, whose popup has each sound of the IPA, from the IPA
/// course, with its practice; the
/// meaning, its part of speech and gender, other meanings and accepted
/// answers; its picture; its notes; the base words of its forms; the
/// warnings, each with its title; the dictionary entry; every example; the
/// facts that name it; its tags; how hard it has been in each skill, for
/// the learner; and last its id, where the learner stands with it, and
/// Report.
///
/// Where a minimal-pair partner, a word that sounds almost the same (its
/// `pair` or a pair note's), is rude, it carries the warning the drill cards
/// carry, "Careful when speaking" ([AlikeWarning]), which names the rude
/// word only with adult content on (docs/plans/offensive-words.md). Any
/// other partner it names is a "Sounds like another word" block, a
/// lookalike or homograph note a "Looks like another word" block
/// ([SimilarBlock]).
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
    final ipa = ipaToShow(context, card.ipa, target: card.target);
    // With "IPA replaces transliteration" on, the IPA is the reading and its
    // small line goes (#697).
    final lines = readingLines(
      context,
      reading: card.reading,
      ipa: card.ipa,
      target: card.target,
    );
    final reading = lines.reading;
    final notes = proseNotes(card);
    final bases = basesOf(state, card, language);
    final rudeAlikes = rudeAlikesOf(state, card);
    final rudeIds = <String>{for (final a in rudeAlikes) a.partner.id};
    final similar = similarOf(state, card, except: rudeIds);
    final named = showRude ?? adultContentOn(state);
    final status = masteryName(
      l10n,
      state.recentAnswers.of(card.id),
      notOpen: isSentence(card) && !state.isTaught(card),
    );
    final line = joinParts(l10n, <String>[?card.pos, ?card.gender]);
    final checked = checkedByOf(state.decks, card).length;
    final facts = state.factsNaming(card, language);
    final dictionary = card.dictionary;
    final wiktionary = wiktionaryLinksFor(state, card, language);
    final difficulties = SkillDifficulty.of(card.id, state.progress.stateOf);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // One line: a word too wide for the sheet shrinks to fit.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: TargetText(
                    card.target,
                    language: language,
                    fontSize: 52,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.start,
                    card: card,
                  ),
                ),
                if (reading != null)
                  Text(
                    reading,
                    style: theme.textTheme.titleMedium!
                        .copyWith(color: scheme.onSurfaceVariant)
                        .forIpa(lines.swapped),
                  ),
                Row(
                  children: <Widget>[
                    if (state.hasVoice(language))
                      SpeakerIcon(
                        onPlay: () => state.speakCard(card, language),
                        label: l10n.drillPlay,
                      ),
                    if (lines.ipa case final line?) ...<Widget>[
                      Flexible(
                        child: IpaLine(line, textAlign: TextAlign.start),
                      ),
                      IpaInfoDot(card: card),
                    ],
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.native,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (card.altNative.isNotEmpty)
                  Text(
                    l10n.cardAlsoMeans(
                      card.altNative.join(l10n.commonListSeparator),
                    ),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (card.altTarget.isNotEmpty)
                  Text(
                    l10n.cardAlsoAccepted(
                      card.altTarget.join(l10n.commonListSeparator),
                    ),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (checked > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  CheckedByLine(count: checked),
                ],
              ],
            ),
            if (card.hasPicture) Center(child: CardPicture(card, size: 120)),
            for (final note in notes) NoteBlock(text: note, titled: true),
            if (bases.isNotEmpty) BaseLine(bases: bases, language: language),
            for (final alike in rudeAlikes)
              AlikeWarning(
                kind: alike.kind,
                named: named ? alike.partner : null,
                language: language,
                care: alike.care,
              ),
            for (final warning in similar)
              SimilarBlock(similar: warning, language: language),
            if (dictionary != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: <Widget>[
                  CardLabel(l10n.cardDictionaryHeading),
                  DictionaryView(
                    senses: dictionary.senses,
                    etymology: dictionary.etymology,
                    source: dictionary.source,
                  ),
                ],
              ),
            if (wiktionary.isNotEmpty)
              WiktionaryLinks(links: wiktionary, language: language),
            if (card.examples.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: <Widget>[
                  CardLabel(l10n.cardExamples),
                  // An IPA card shows every example, each marked as sounding
                  // as the card says or not, and each with its own voice
                  // (ADR-0041).
                  if (language.isIpa)
                    IpaExamples(card: card, language: language)
                  else
                    for (final example in card.examples)
                      ExampleBlock(example: example, language: language),
                ],
              ),
            // After the examples and notes (#546), and only when a fact names
            // the card.
            if (facts.isNotEmpty) CardFacts(facts: facts),
            if (card.tags.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: <Widget>[
                  CardLabel(l10n.cardTags),
                  CardTags(tags: card.tags),
                ],
              ),
            if (difficulties.isNotEmpty) _Difficulties(difficulties),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.wordSheetLine(card.id, status),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ReportButton.open(context, detail: card.id),
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  label: Text(l10n.cardReport),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How hard a card has been in each skill it has been answered in: a
/// heading, then a line a skill, "Hear: 7 of 10, harder" (FSRS's D,
/// docs/plans/difficulty-by-skill.md). Moved here from Inspect. Built only
/// for a card with at least one skill answered.
class _Difficulties extends StatelessWidget {
  const _Difficulties(this.difficulties);

  final List<SkillDifficulty> difficulties;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: <Widget>[
        CardLabel(l10n.cardDifficulty),
        for (final d in difficulties)
          Text(
            l10n.cardDifficultyIn(d.mode.name, d.shown, d.lean.name),
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}
