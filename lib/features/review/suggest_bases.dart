import 'package:flutter/material.dart' hide Card;

import '../../app/app_state.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_bases.dart';
import '../decks/card_notes.dart';

/// The pieces of "Suggest a change" for base words and a new word for the
/// card (#476, docs/mockups/reviewer-mode.html, section 2): a base's
/// fields, the panel a new word opens, and the "Check" tag on the parts
/// that hung on the old word. The sheet keeps their state.

/// One of [card]'s base words, as the sheet shows it: the word of the
/// target it explains, the base as the deck gives it, and what its line
/// says, a base by ref with the form, reading and meaning of the card it
/// names when that card is on the phone.
typedef CardBaseShown = ({String word, BaseForm form, ShownBase shown});

/// [card]'s base words, every one, in order: written in full, or by ref.
/// A ref to the card itself is left out.
List<CardBaseShown> basesShown(Card card, Card? Function(String id) find) =>
    <CardBaseShown>[
      for (final b in card.bases)
        if (b.base case final base? when base.trim().isNotEmpty)
          (
            word: b.word,
            form: BaseForm(base: base, reading: b.reading, meaning: b.meaning),
            shown: (
              word: b.word,
              base: base,
              reading: b.reading,
              meaning: b.meaning,
              inline: true,
              ref: null,
            ),
          )
        else if (b.ref case final ref? when ref != card.id)
          (
            word: b.word,
            form: BaseForm(ref: ref),
            shown: switch (find(ref)) {
              final taught? => (
                word: b.word,
                base: taught.target,
                reading: taught.reading,
                meaning: taught.native,
                inline: false,
                ref: ref,
              ),
              null => (
                word: b.word,
                base: ref,
                reading: null,
                meaning: null,
                inline: false,
                ref: ref,
              ),
            },
          ),
    ];

/// The card of [language] other than [except] whose word is [form], the
/// one a base of that form can be linked to; from a deck taught from
/// [native] first. Null when none is on the phone.
Card? cardForForm(
  AppState state,
  String form, {
  required String language,
  required String except,
  String? native,
}) {
  final want = form.trim();
  if (want.isEmpty) return null;
  Card? other;
  for (final entry in state.decks) {
    if (entry.language.code != language) continue;
    for (final c in entry.cards) {
      if (c.id == except || c.target.trim() != want) continue;
      if (native == null || entry.deck.native.code == native) return c;
      other ??= c;
    }
  }
  return other;
}

/// The small "Check" tag on a part that hung on the card's old word.
class CheckTag extends StatelessWidget {
  const CheckTag({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 8, 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: <Widget>[
          Icon(Icons.flag_outlined, size: 18, color: scheme.onSurfaceVariant),
          Text(
            l10n.reviewCheckTag,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A checkbox with its label, the whole row its 48 dp target, the label
/// wrapping as it must.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color,
  });

  final InlineSpan label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// The label's colour, on a coloured panel; the theme's otherwise.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: Text.rich(
                    label,
                    style: theme.textTheme.bodyLarge!.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The fields of a base word being changed or added: its form, reading and
/// meaning; when the form is another card's word, a row that links that
/// card ([link]), the base then given by ref; and why.
class BaseFields extends StatelessWidget {
  const BaseFields({
    super.key,
    required this.keyOf,
    required this.form,
    required this.reading,
    required this.meaning,
    required this.why,
    required this.language,
    required this.match,
    required this.link,
    required this.onLink,
    required this.onChanged,
  });

  /// The key of each field, by its name: form, reading, meaning, why, link.
  final Key Function(String field) keyOf;
  final TextEditingController form;
  final TextEditingController reading;
  final TextEditingController meaning;
  final TextEditingController why;
  final LanguageInfo language;

  /// The card whose word the form is, or null.
  final Card? match;
  final bool link;
  final ValueChanged<bool> onLink;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final match = this.match;
    TextField field(
      String name,
      TextEditingController controller,
      String label, {
      int maxLines = 2,
    }) => TextField(
      key: keyOf(name),
      controller: controller,
      minLines: 1,
      maxLines: maxLines,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        border: AppRadii.fieldBorder,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[
        field('form', form, l10n.reviewBaseForm),
        field('reading', reading, l10n.reviewPartReading),
        field('meaning', meaning, l10n.reviewPartMeaning),
        if (match != null)
          CheckRow(
            key: keyOf('link'),
            value: link,
            onChanged: onLink,
            label: quotingTarget(
              switch (match.reading) {
                final r? => l10n.reviewBaseLink(
                  match.target,
                  r,
                  match.native,
                  match.id,
                ),
                null => l10n.reviewBaseLinkNoReading(
                  match.target,
                  match.native,
                  match.id,
                ),
              },
              <String>[match.target],
              language,
            ),
          ),
        field('why', why, l10n.reviewSuggestWhy, maxLines: 3),
      ],
    );
  }
}

/// The panel under the Word box while a new word is suggested (#476): the
/// card keeps its id and meaning, and what hung on the old word is listed,
/// with a way to replace the bases and to keep the old word as an
/// accepted answer. In the tertiary container.
class IdentityPanel extends StatelessWidget {
  const IdentityPanel({
    super.key,
    required this.card,
    required this.language,
    required this.bases,
    required this.onReplace,
    required this.keepAlt,
    required this.onKeepAlt,
  });

  final Card card;
  final LanguageInfo language;

  /// The card's bases still on it, as their line says each.
  final List<ShownBase> bases;

  /// Null once every base is marked removed.
  final VoidCallback? onReplace;
  final bool keepAlt;
  final ValueChanged<bool> onKeepAlt;

  static const Key replaceKey = ValueKey<String>('identity-replace');
  static const Key keepAltKey = ValueKey<String>('identity-keep-alt');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = scheme.onTertiaryContainer;
    final body = theme.textTheme.bodyMedium!.copyWith(color: on);
    final label = theme.textTheme.labelLarge!.copyWith(color: on);
    final button = TextButton.styleFrom(
      foregroundColor: on,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
    );
    Widget row(IconData icon, String? name, List<Widget> children) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: <Widget>[
          Icon(icon, color: on),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (name != null) Text(name, style: label),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
    final none = Text(l10n.reviewIdentityNone, style: body);
    final baseList = bases.isEmpty
        ? ''
        : bases
              .map((b) => baseText(l10n, b, reading: true))
              .reduce(l10n.cardBasesJoin);
    return Semantics(
      container: true,
      label: l10n.reviewIdentityTitle,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 8),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: <Widget>[
                Icon(Icons.change_circle_outlined, color: on),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.reviewIdentityTitle,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: on,
                          ),
                        ),
                      ),
                      Text(
                        l10n.reviewIdentityKeeps(card.id, card.native),
                        style: body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            row(Icons.account_tree_outlined, l10n.reviewSuggestBases, <Widget>[
              if (bases.isEmpty)
                none
              else ...<Widget>[
                Text.rich(
                  quotingTarget(
                    l10n.reviewIdentityBases(bases.length, baseList),
                    <String>[for (final b in bases) b.base],
                    language,
                  ),
                  style: body,
                ),
                if (onReplace != null)
                  TextButton(
                    key: replaceKey,
                    style: button,
                    onPressed: onReplace,
                    child: Text(l10n.reviewIdentityReplace),
                  ),
              ],
            ]),
            row(Icons.hearing_outlined, l10n.reviewPartAlt, <Widget>[
              CheckRow(
                key: keepAltKey,
                value: keepAlt,
                onChanged: onKeepAlt,
                color: on,
                label: quotingTarget(
                  l10n.reviewIdentityKeepAlt(card.target),
                  <String>[card.target],
                  language,
                ),
              ),
            ]),
            row(Icons.sticky_note_2_outlined, l10n.reviewPartNotes, <Widget>[
              if (notesText(card) == null)
                none
              else
                Text(l10n.reviewIdentityCheckThem, style: body),
            ]),
            row(Icons.format_quote_outlined, l10n.reviewPartExample, <Widget>[
              if (card.examples.isEmpty)
                none
              else
                Text(l10n.reviewIdentityCheckIt, style: body),
            ]),
            row(Icons.info_outline, null, <Widget>[
              Text(
                l10n.reviewIdentityFollow,
                style: theme.textTheme.bodySmall!.copyWith(color: on),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
