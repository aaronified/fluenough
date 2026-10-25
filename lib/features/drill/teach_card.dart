import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_blocks.dart';
import '../decks/card_notes.dart';
import '../decks/ipa_symbols.dart';
import '../decks/path_parts.dart' show joinParts;
import '../decks/word_sheet.dart' show adultContentOn;
import '../review/alike_warning.dart';
import '../review/review_words.dart';
import 'ipa_examples.dart';
import 'taught_details.dart' show TaughtReading;

/// The teach card (#691, owner, 2026-10-22): a word on one screen, with no
/// scrolling, in lessons and, later, the guided walkthrough (#694). The word
/// sheet is the same card with everything unfolded.
///
/// Top to bottom, spaced evenly down the screen:
///
/// - the word large on one line, shrunk to fit a long one, with its reading,
///   its speaker ([audio]) and its IPA, which is a button that opens the
///   pronunciation popup (each symbol of the word, from the IPA course,
///   with its practice); and the picture, a square tile beside the word;
/// - the meaning at the full width, which is the dictionary button: it opens
///   the dictionary popup (the senses, the etymology and the examples) and
///   shows the part of speech and gender under it;
/// - one note, with an exclamation icon;
/// - one warning, with no title: the one the card's `warning` names, or,
///   without it, a rude word it is like (always), else the first of the word
///   it sounds like, the word it looks like or its other meanings
///   ([teachWarningOf]). The word sheet shows them all, titled.
///
/// A language learned without its alphabet shows the reading first, as the
/// card always has ([TaughtReading]).
class TeachCard extends StatelessWidget {
  const TeachCard({
    super.key,
    required this.card,
    required this.language,
    required this.reading,
    this.audio,
  });

  final Card card;
  final LanguageInfo language;

  /// How the word's reading shows.
  final TaughtReading reading;

  /// The speaker beside the IPA, a 48 px button; null where the phone has no
  /// voice for the language.
  final Widget? audio;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    // Live: the IPA follows IPA pronunciations, and a rude word is named
    // only while adult content is on.
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final readingText = card.reading;
    final ipa = ipaToShow(context, card.ipa, target: card.target);
    final line = joinParts(l10n, <String>[?card.pos, ?card.gender]);
    final note = proseNotes(card).firstOrNull;
    final (:rude, :similar) = teachWarningOf(state, card);
    final named = adultContentOn(state);

    final Widget word;
    if (readingText != null && reading == TaughtReading.first) {
      word = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: ReadingFirst(
          reading: readingText,
          target: card.target,
          language: language,
          fontSize: 52,
        ),
      );
    } else {
      word = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // One line: a word too wide for its place shrinks to fit.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: TargetText.card(
              card.target,
              language: language,
              fontSize: 52,
              fontWeight: FontWeight.w500,
              textAlign: TextAlign.start,
              card: card,
            ),
          ),
          if (readingText != null)
            Text(
              readingText,
              style: theme.textTheme.titleMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }

    final hero = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              word,
              if (audio != null || ipa != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 10),
                  child: Row(
                    children: <Widget>[
                      ?audio,
                      if (audio != null && ipa != null)
                        const SizedBox(width: 8),
                      if (ipa != null)
                        Flexible(
                          child: _IpaButton(
                            ipa: ipa,
                            onPressed: () => showPronunciation(context, card),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (card.hasPicture) ...<Widget>[
          const SizedBox(width: 16),
          Container(
            width: 104,
            height: 104,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CardPicture(card, size: 64),
          ),
        ],
      ],
    );

    final meaning = Semantics(
      button: true,
      label: l10n.teachDictionaryLabel(card.native),
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDictionary(context, card, language),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // One line, at the full width: a long meaning shrinks.
                      // A whole sentence, as the IPA course's cards have for
                      // a meaning, wraps instead.
                      if (card.native.length > 28)
                        Text(
                          card.native,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            card.native,
                            style: theme.textTheme.headlineSmall!.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (line.isNotEmpty)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.menu_book_outlined, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // Laid out to the screen's height. It scrolls only when large text
        // makes the content taller than that, rather than cutting a note.
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? constraints.maxHeight - 8
                : 0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: <Widget>[
              hero,
              meaning,
              if (note != null) NoteBlock(text: note, maxLines: 4),
              for (final alike in rude)
                AlikeWarning(
                  kind: alike.kind,
                  named: named ? alike.partner : null,
                  language: language,
                  care: alike.care,
                ),
              if (rude.isEmpty && similar != null)
                SimilarBlock(
                  similar: similar,
                  language: language,
                  titled: false,
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The IPA as an outlined pill, which opens the pronunciation popup.
class _IpaButton extends StatelessWidget {
  const _IpaButton({required this.ipa, required this.onPressed});

  final String ipa;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
        foregroundColor: theme.colorScheme.onSurface,
      ),
      child: Semantics(
        label: l10n.teachPronunciationLabel(ipa),
        excludeSemantics: true,
        child: Text(
          l10n.wordSheetIpa(ipa),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
            fontFamilyFallback: IpaLine.fontFallback,
          ),
        ),
      ),
    );
  }
}

/// A popup over the teach card: a title, a line under it, a body that
/// scrolls, and Close.
class _Popup extends StatelessWidget {
  const _Popup({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final Widget title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: title,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              subtitle,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

/// The pronunciation popup of [card]: each symbol of its IPA, from the IPA
/// course, with its description, a word that has it, a speaker and Practise
/// (owner, 2026-10-22).
Future<void> showPronunciation(BuildContext context, Card card) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (_) => _Popup(
      title: Text(l10n.teachPronunciationTitle),
      subtitle: l10n.teachPronunciationBody,
      body: IpaSymbols(card: card),
    ),
  );
}

/// The dictionary popup of [card]: its senses, its etymology and its
/// examples (owner, 2026-10-22). The senses are the Wiktionary entry the
/// deck's layer gives, else the card's own meaning and other meanings.
Future<void> showDictionary(
  BuildContext context,
  Card card,
  LanguageInfo language,
) {
  final l10n = AppLocalizations.of(context)!;
  final dictionary = card.dictionary;
  return showDialog<void>(
    context: context,
    builder: (_) => _Popup(
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: TargetText(
          card.target,
          language: language,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          textAlign: TextAlign.start,
        ),
      ),
      subtitle: l10n.teachDictionaryBody,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: <Widget>[
          DictionaryView(
            senses:
                dictionary?.senses ?? <String>[card.native, ...card.altNative],
            etymology: dictionary?.etymology,
            source: dictionary?.source,
          ),
          if (card.examples.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: <Widget>[
                CardLabel(l10n.cardExamples),
                if (language.isIpa)
                  IpaExamples(card: card, language: language)
                else
                  for (final example in card.examples)
                    ExampleBlock(example: example, language: language),
              ],
            ),
        ],
      ),
    ),
  );
}

/// The warning the teach card shows for [card] (#691, owner, 2026-10-23: "Deck
/// field picks it"): a rude word it is like, or another [Similar] warning.
///
/// A card with a [Card.warning] shows what it names: the id of one of its
/// pair, homograph or lookalike notes, `senses` for its other meanings, or
/// `none` for nothing. A name that matches nothing the card has shows
/// nothing. A card without the key keeps the fixed order: every rude word it
/// is like, else the first word it sounds like, the first it looks like, then
/// its other meanings.
({List<RudeAlike> rude, Similar? similar}) teachWarningOf(
  AppState state,
  Card card,
) {
  const none = (rude: <RudeAlike>[], similar: null);
  final rude = rudeAlikesOf(state, card);
  final named = card.warning;
  if (named == null) {
    return (
      rude: rude,
      similar: rude.isNotEmpty ? null : similarOf(state, card).firstOrNull,
    );
  }
  final all = similarOf(
    state,
    card,
    except: <String>{for (final r in rude) r.partner.id},
  );
  if (named == 'none') return none;
  if (named == 'senses') {
    return (
      rude: const <RudeAlike>[],
      similar: all.where((s) => s.kind == SimilarKind.meanings).firstOrNull,
    );
  }
  final note = card.notes
      .where(
        (n) =>
            n.id == named &&
            (n.kind == NoteKind.pair ||
                n.kind == NoteKind.homograph ||
                n.kind == NoteKind.lookalike),
      )
      .firstOrNull;
  if (note == null) return none;
  if (note.kind == NoteKind.pair) {
    final rudeOne = rude.where((r) => r.partner.id == note.ref).firstOrNull;
    if (rudeOne != null) {
      return (rude: <RudeAlike>[rudeOne], similar: null);
    }
    return (
      rude: const <RudeAlike>[],
      similar: all
          .where(
            (s) => s.kind == SimilarKind.sound && s.partner?.id == note.ref,
          )
          .firstOrNull,
    );
  }
  final text = note.text.trim().isEmpty ? null : note.text.trim();
  return (
    rude: const <RudeAlike>[],
    similar: all
        .where(
          (s) =>
              s.kind == SimilarKind.look &&
              (note.ref == null ? s.text == text : s.partner?.id == note.ref),
        )
        .firstOrNull,
  );
}
