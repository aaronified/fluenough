import 'package:flutter/material.dart' hide Card;

import '../../app/app_state.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/target_text.dart';
import 'card_notes.dart';

/// The blocks a card is made of, shared by the word sheet and the teach card
/// (#691): the note, the three kinds of similarity warning, an example, the
/// dictionary entry and the tags. The sheet shows each block with its title;
/// the teach card shows them without (owner, 2026-10-22: "No need for headers
/// in the 'other meanings or sounds like another word' cards").

/// The card with [id], from any deck: a partner a note names.
Card? findCard(AppState state, String id) {
  for (final entry in state.decks) {
    for (final other in entry.cards) {
      if (other.id == id) {
        return other;
      }
    }
  }
  return null;
}

/// How a card is like another word, or another meaning.
enum SimilarKind {
  /// Sounds almost the same: one close sound differs. The ear icon.
  sound,

  /// Looks the same or almost, but is another word, so it is said or written
  /// differently. The ear-off icon (owner, 2026-10-22).
  look,

  /// The same word has other meanings. The translate icon.
  meanings,
}

/// One similarity warning: a [kind], and what it says.
typedef Similar = ({
  SimilarKind kind,
  Card? partner,
  String? text,
  List<String> meanings,
});

/// The similarity warnings of [card], in the order the sheet lists them:
/// each word it sounds like (a rude one, which has its own warning, is left
/// out as [except] names it), each it looks like, then its other meanings.
List<Similar> similarOf(
  AppState state,
  Card card, {
  Set<String> except = const <String>{},
}) {
  final out = <Similar>[];
  for (final pair in pairsOf(card)) {
    if (except.contains(pair.id)) {
      continue;
    }
    final partner = findCard(state, pair.id);
    if (partner == null) {
      continue;
    }
    out.add((
      kind: SimilarKind.sound,
      partner: partner,
      text: pair.care,
      meanings: const <String>[],
    ));
  }
  for (final look in lookalikesOf(card)) {
    final id = look.id;
    if (id != null && except.contains(id)) {
      continue;
    }
    final partner = id == null ? null : findCard(state, id);
    if (partner == null && look.text == null) {
      continue;
    }
    out.add((
      kind: SimilarKind.look,
      partner: partner,
      text: look.text,
      meanings: const <String>[],
    ));
  }
  // Its other meanings: the layer's `alt_native` and the card's `senses`,
  // which `warning: "senses"` names (DECK-FORMAT.md), each once.
  final meanings = <String>[
    ...card.altNative,
    for (final sense in card.senses)
      if (sense.native != card.native && !card.altNative.contains(sense.native))
        sense.native,
  ];
  if (meanings.isNotEmpty) {
    out.add((
      kind: SimilarKind.meanings,
      partner: null,
      text: null,
      meanings: meanings,
    ));
  }
  return out;
}

/// A block of the card: an icon, an optional title and its content, on a
/// rounded panel.
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.titleColor,
    required this.child,
    this.title,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color titleColor;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A card's note, styled like the similarity warning with an exclamation
/// icon (owner, 2026-10-20), on a neutral panel. With [titled], "Note" over
/// it, as on the sheet; with [maxLines], cut short, as on the teach card.
class NoteBlock extends StatelessWidget {
  const NoteBlock({
    super.key,
    required this.text,
    this.titled = false,
    this.maxLines,
  });

  final String text;
  final bool titled;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: _Block(
        icon: Icons.error,
        iconColor: scheme.primary,
        background: scheme.surfaceContainerHigh,
        titleColor: scheme.onSurfaceVariant,
        title: titled ? l10n.cardNoteTitle : null,
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// One similarity warning of a card, on the tertiary panel: ear-on for a
/// word that sounds almost the same, ear-off for one that looks the same,
/// translate for the card's other meanings. [titled] puts its title over it,
/// as the sheet does; [maxLines] cuts it short, as the teach card does.
class SimilarBlock extends StatelessWidget {
  const SimilarBlock({
    super.key,
    required this.similar,
    required this.language,
    this.titled = true,
    this.maxLines,
  });

  final Similar similar;

  /// The deck's language, for the words the warning quotes.
  final LanguageInfo language;
  final bool titled;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onTertiaryContainer,
    );
    final (icon, title) = switch (similar.kind) {
      SimilarKind.sound => (Icons.hearing, l10n.wordSheetSoundsLikeTitle),
      SimilarKind.look => (Icons.hearing_disabled, l10n.cardLooksLikeTitle),
      SimilarKind.meanings => (Icons.translate, l10n.cardOtherMeaningsTitle),
    };
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final partner = similar.partner;
    final text = similar.text;
    final named = partner == null ? null : _named(l10n, partner);
    final Widget body;
    switch (similar.kind) {
      case SimilarKind.sound:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (named != null)
              Text.rich(
                quotingTarget(named, <String>[partner!.target], language),
                maxLines: maxLines,
                overflow: overflow,
                style: style,
              ),
            if (text != null)
              Text(text, maxLines: maxLines, overflow: overflow, style: style),
          ],
        );
      case SimilarKind.look:
        body = text != null
            ? Text(text, maxLines: maxLines, overflow: overflow, style: style)
            : Text.rich(
                quotingTarget(named!, <String>[partner!.target], language),
                maxLines: maxLines,
                overflow: overflow,
                style: style,
              );
      case SimilarKind.meanings:
        body = Text(
          l10n.cardOtherMeaningsText(
            similar.meanings.join(l10n.commonListSeparator),
          ),
          maxLines: maxLines,
          overflow: overflow,
          style: style,
        );
    }
    return MergeSemantics(
      child: _Block(
        icon: icon,
        iconColor: scheme.onTertiaryContainer,
        background: scheme.tertiaryContainer,
        titleColor: scheme.onTertiaryContainer,
        title: titled ? title : null,
        child: body,
      ),
    );
  }

  /// "काल (kāl), time", or without the reading.
  static String _named(AppLocalizations l10n, Card partner) {
    final reading = partner.reading;
    return reading == null
        ? l10n.cardPartnerNoReading(partner.target, partner.native)
        : l10n.cardPartner(partner.target, reading, partner.native);
  }
}

/// A heading over a section of the sheet, such as "Examples".
class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.labelLarge!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// An example sentence with a rule down its start edge: the sentence in the
/// deck's script, its reading and IPA, and its translation.
class ExampleBlock extends StatelessWidget {
  const ExampleBlock({
    super.key,
    required this.example,
    required this.language,
  });

  final CardExample example;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = example.reading;
    return Semantics(
      container: true,
      label: l10n.drillExample,
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 14, top: 2, bottom: 2),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: scheme.primary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TargetText(
              example.target,
              language: language,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: scheme.onSurface,
              textAlign: TextAlign.start,
            ),
            if (reading != null)
              Text(
                reading,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (ipaToShow(context, example.ipa, target: example.target)
                case final ipa?)
              IpaLine(ipa, textAlign: TextAlign.start),
            Text(example.native, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// A short dictionary entry: numbered senses, the etymology and, where the
/// entry has one, the page it came from, for the CC BY-SA credit.
class DictionaryView extends StatelessWidget {
  const DictionaryView({
    super.key,
    required this.senses,
    this.etymology,
    this.source,
  });

  final List<String> senses;
  final String? etymology;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final etymology = this.etymology;
    final source = this.source;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (i, sense) in senses.indexed)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}.', style: theme.textTheme.bodyMedium),
                ),
                Expanded(child: Text(sense, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        if (etymology != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: Text(
              l10n.cardDictionaryEtymology(etymology),
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (source != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Text(
              l10n.cardDictionaryCredit(source),
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// A card's tags, as small rounded labels.
class CardTags extends StatelessWidget {
  const CardTags({super.key, required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final tag in tags)
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text(
              tag,
              style: theme.textTheme.labelMedium!.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}
