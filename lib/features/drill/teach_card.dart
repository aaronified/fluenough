import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_bases.dart' show baseFinder;
import '../decks/card_blocks.dart';
import '../decks/card_notes.dart' show proseNoteList;
import '../decks/ipa_symbols.dart';
import '../decks/path_parts.dart' show joinParts;
import '../decks/word_sheet.dart' show adultContentOn;
import '../review/alike_warning.dart';
import '../review/review_words.dart';
import 'ipa_examples.dart';
import 'one_note.dart';
import 'pair_compare.dart';
import 'taught_details.dart' show TaughtExample, TaughtReading;

/// The teach card (#691; redrawn owner, 2026-10-29, docs/mockups/teach-screen):
/// a word taught for the first time, laid out as the review's answer screen
/// is, so that the two read as one family.
///
/// In the body, which scrolls when the content is taller than the screen (a
/// soft fade at the foot says there is more):
///
/// - the pill row: "New word" or "New phrase" and the deck's name, as the
///   review's skill pill and deck name sit;
/// - one [DrillCard], as tall as its content, its children centred 12 apart:
///   the word (its reading first, or the script with its reading under it),
///   the speaker ([audio]) and the IPA on one row, the IPA a button that
///   opens the pronunciation popup; the meaning at 28 sp with a dictionary
///   icon, which opens the dictionary popup, the part of speech under it and
///   the picture, a small tile, beside it; every note in full; the warning
///   the card names ([teachWarningOf]); up to three examples in the review's
///   inner box; and a short table of the word's forms.
///
/// There is no button and nothing is recorded: a swipe or the end-edge
/// chevron goes on (`TeachSwipe`).
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
    this.deckName,
  });

  final Card card;
  final LanguageInfo language;

  /// How the word's reading shows.
  final TaughtReading reading;

  /// The speaker beside the IPA, a 56 px button; null where the phone has no
  /// voice for the language.
  final Widget? audio;

  /// The deck's name, beside the pill; none without it.
  final String? deckName;

  /// How many examples the card shows.
  static const int maxExamples = 3;

  /// How many forms its table shows.
  static const int maxForms = 3;

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
    final ipa = ipaToShow(context, card.ipa, target: card.target);
    // With "IPA replaces transliteration" on, the IPA is the reading (#697).
    final readingText = readingLines(
      context,
      reading: card.reading,
      ipa: card.ipa,
      target: card.target,
    ).reading;
    final isPhrase = card.pos == 'phrase';
    final line = joinParts(l10n, <String>[
      if (!isPhrase) ?card.pos,
      ?card.gender,
    ]);
    final (:rude, :similar) = teachWarningOf(state, card);
    final named = adultContentOn(state);
    // The Compare button (#423) goes in the sound-alike block, or under the
    // card's other warning; a card told to show none shows none.
    final compare = card.warning == 'none' ? null : pairPartnerOf(state, card);
    final soundBlock =
        compare != null &&
        rude.isEmpty &&
        similar?.kind == SimilarKind.sound &&
        similar?.partner?.id == compare.partner.id;
    final find = baseFinder(
      state,
      language: language.code,
      native: state.deckOf(card)?.deck.native.code,
    );
    final forms = <_TeachForm>[];
    for (final f in card.forms) {
      if (forms.length == maxForms) break;
      var word = f.word;
      var formReading = f.reading;
      final ref = f.ref;
      if (word == null && ref != null) {
        final other = find(ref);
        word = other?.target;
        formReading = other?.reading;
      }
      if (word == null || word.trim().isEmpty) continue;
      forms.add(
        _TeachForm(
          word: word,
          reading: formReading,
          label: _formLabel(l10n, f.kind),
          text: f.text,
        ),
      );
    }

    final Widget word;
    if (readingText != null && reading == TaughtReading.first) {
      word = ReadingFirst(
        reading: readingText,
        target: card.target,
        language: language,
        fontSize: 48,
      );
    } else {
      word = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TargetText.hero(card.target, language: language, card: card),
          if (readingText != null)
            Text(
              readingText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                fontSize: 18,
                height: 24 / 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }

    final meaning = Padding(
      padding: const EdgeInsetsDirectional.only(top: 4),
      child: Semantics(
        button: true,
        label: l10n.teachDictionaryLabel(card.native),
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          // hint-ok: shows text
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.field),
            onTap: () => showDictionary(context, card, language),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: <Widget>[
                if (card.hasPicture)
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.field),
                    ),
                    child: CardPicture(card, size: 32),
                  ),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              card.native,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.menu_book_outlined,
                            size: 22,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                      if (line.isNotEmpty)
                        Text(
                          line,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return _TeachScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: _NewPill(
                  label: isPhrase ? l10n.teachNewPhrase : l10n.teachNewWord,
                ),
              ),
              if (deckName != null) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deckName!,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          DrillCard(
            children: <Widget>[
              word,
              if (audio != null || ipa != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: <Widget>[
                    ?audio,
                    if (ipa != null)
                      Flexible(
                        child: _IpaButton(
                          ipa: ipa,
                          onPressed: () => showPronunciation(context, card),
                        ),
                      ),
                  ],
                ),
              meaning,
              // Padding, not a max-width box, as the review's notes are.
              if (proseNoteList(card).isNotEmpty)
                OneNote(card: card, notes: proseNoteList(card)),
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
                  action: soundBlock
                      ? PairCompareButton(
                          card: card,
                          partner: compare.partner,
                          language: language,
                        )
                      : null,
                ),
              if (compare != null && !soundBlock)
                PairCompareButton(
                  card: card,
                  partner: compare.partner,
                  language: language,
                ),
              if (card.examples.isNotEmpty && language.isIpa)
                IpaExamples(card: card, language: language)
              else
                for (final example in card.examples.take(maxExamples))
                  TaughtExample(
                    example: example,
                    language: language,
                    showReading: true,
                  ),
              if (forms.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: _FormsTable(forms: forms, language: language),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _formLabel(AppLocalizations l10n, String? kind) =>
      switch (kind) {
        'plural' => l10n.teachFormPlural,
        'oblique' => l10n.teachFormOblique,
        'oblique-plural' => l10n.teachFormObliquePlural,
        'feminine' => l10n.teachFormFeminine,
        'masculine' => l10n.teachFormMasculine,
        _ => null,
      };
}

/// The body of the teach card: it scrolls when the content is taller than the
/// screen, with a soft fade at its foot while there is more below.
class _TeachScroll extends StatefulWidget {
  const _TeachScroll({required this.child});

  final Widget child;

  @override
  State<_TeachScroll> createState() => _TeachScrollState();
}

class _TeachScrollState extends State<_TeachScroll> {
  bool _more = false;

  bool _update(ScrollMetrics metrics) {
    final more = metrics.extentAfter > 1;
    if (more != _more && mounted) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _update(n.metrics),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
              child: widget.child,
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              height: 28,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _more ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[surface.withValues(alpha: 0), surface],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New word" or "New phrase": the pill of a teach card, drawn as the
/// review's skill pill is, on the tertiary container, with a star.
class _NewPill extends StatelessWidget {
  const _NewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.star, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.start,
              style: theme.textTheme.labelLarge!.copyWith(
                color: scheme.onTertiaryContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The IPA, with a dotted underline, which opens the pronunciation popup.
class _IpaButton extends StatelessWidget {
  const _IpaButton({required this.ipa, required this.onPressed});

  final String ipa;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: l10n.teachPronunciationLabel(ipa),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                child: Text(
                  l10n.wordSheetIpa(ipa),
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontSize: 16,
                    color: color,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: color,
                    fontFamilyFallback: IpaLine.fontFallback,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the forms table: the form, its reading, its label and its line.
class _TeachForm {
  const _TeachForm({
    required this.word,
    required this.reading,
    required this.label,
    required this.text,
  });

  final String word;
  final String? reading;
  final String? label;
  final String? text;
}

/// A word's forms in the review's inner box: each row the form with its
/// reading, and what the form is and means.
class _FormsTable extends StatelessWidget {
  const _FormsTable({required this.forms, required this.language});

  final List<_TeachForm> forms;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 2,
        ),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < forms.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            TargetText.card(
                              forms[i].word,
                              language: language,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: scheme.onSurface,
                              textAlign: TextAlign.start,
                            ),
                            if (forms[i].reading case final r?)
                              Text(r, style: small),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (forms[i].label case final label?)
                              Text(
                                label,
                                style: small.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (forms[i].text case final text?)
                              Text(
                                text,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
