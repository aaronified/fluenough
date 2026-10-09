import 'package:flutter/material.dart';

import '../../app/language_offer.dart';
import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// One language in the language picker (#211, the approved mockup
/// `docs/mockups/language-picker.html`): its icon and names, how much of
/// its course is written toward B1, the learner's own progress when they
/// learn it, the languages it is taught from, its Alpha or Beta tag, and
/// with deck downloads whether it is on the phone.
///
/// The card's summary is one checkbox to a screen reader, with all of it
/// in its label. A chosen language that is new to the learner opens in
/// place: [expanded] holds its choices, each a control of its own.
class LanguageCard extends StatelessWidget {
  const LanguageCard({
    super.key,
    required this.language,
    required this.ticked,
    required this.onToggle,
    required this.spoken,
    this.progress,
    this.you,
    this.youWords,
    this.storage,
    this.query = '',
    this.expanded = const <Widget>[],
  });

  final CatalogLanguage language;
  final bool ticked;
  final VoidCallback onToggle;

  /// The languages the learner speaks, best known first: theirs are
  /// highlighted among those the course is taught from.
  final List<String> spoken;

  /// The course as the learner would take it, from its native language.
  final B1Progress? progress;

  /// The learner's own progress toward B1, 0–1, for a language they learn
  /// whose course has a B1 plan; else [youWords], the words they have
  /// learned. Both null for a language they do not learn.
  final double? you;
  final int? youWords;

  /// With deck downloads: whether it is on the phone, and its size there
  /// or what it would download.
  final ({bool onPhone, String size})? storage;

  /// The search, to mark in the names.
  final String query;

  /// The opened card's choices, under its summary.
  final List<Widget> expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = MergeSemantics(
      child: InkWell(
        onTap: onToggle,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 12),
          child: _Summary(card: this),
        ),
      ),
    );
    return Material(
      color: ticked ? scheme.surfaceContainerLow : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: ticked
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          summary,
          if (expanded.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Divider(height: 1),
                  for (final part in expanded) ...<Widget>[
                    const SizedBox(height: 16),
                    part,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.card});

  final LanguageCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = card.language;
    final small = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final progress = card.progress;
    final script = l10n.pickerScript(language.script ?? '');
    final stage = progress?.stage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Icon(language: language),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 4),
                  Text.rich(
                    _names(context, l10n, language, card.query),
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (script.isNotEmpty) Text(script, style: small),
                ],
              ),
            ),
            Checkbox(value: card.ticked, onChanged: (_) => card.onToggle()),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (progress != null && progress.hasPlan) ...<Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: l10n.pickerWritten(progress.percent),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (progress.grammarTopics > 0) ...<InlineSpan>[
                        TextSpan(text: l10n.pickerNameSeparator),
                        TextSpan(
                          text: l10n.pickerGrammarTopics(
                            progress.grammarWritten,
                            progress.grammarTopics,
                          ),
                        ),
                      ],
                    ],
                  ),
                  style: small.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 6),
                _Bar(value: progress.share, color: scheme.secondary),
              ] else if (progress != null)
                Text(
                  l10n.pickerCourseSize(progress.courseWords),
                  style: small.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (card.you case final you?) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  l10n.pickerYou(B1Progress.percentOf(you)),
                  style: small.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                _Bar(value: you, color: scheme.primary),
              ] else if (card.youWords case final words?) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  l10n.pickerYouWords(words),
                  style: small.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _TaughtFrom(
                language: language,
                spoken: card.spoken,
                stage: stage,
              ),
              if (!language.taughtFromSpoken(card.spoken) &&
                  language.natives.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(l10n.pickerNotYours, style: small),
              ],
              if (card.storage case final storage?) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(
                      storage.onPhone
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_download_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        storage.onPhone
                            ? l10n.pickerOnPhone(storage.size)
                            : l10n.pickerNotOnPhone(storage.size),
                        style: small,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Telugu · తెలుగు", the own name in its language, and the search marked
  /// in both.
  static TextSpan _names(
    BuildContext context,
    AppLocalizations l10n,
    CatalogLanguage language,
    String query,
  ) {
    final scheme = Theme.of(context).colorScheme;
    List<TextSpan> marked(String text, {Locale? locale}) {
      final match = LanguageSearch.find(text, query);
      if (match == null) {
        return <TextSpan>[TextSpan(text: text, locale: locale)];
      }
      return <TextSpan>[
        TextSpan(text: text.substring(0, match.start), locale: locale),
        TextSpan(
          text: text.substring(match.start, match.end),
          locale: locale,
          style: TextStyle(
            backgroundColor: scheme.primaryContainer,
            color: scheme.onPrimaryContainer,
          ),
        ),
        TextSpan(text: text.substring(match.end), locale: locale),
      ];
    }

    final own = language.ownName;
    return TextSpan(
      children: <TextSpan>[
        ...marked(language.name),
        if (own != null && own != language.name) ...<TextSpan>[
          TextSpan(text: l10n.pickerNameSeparator),
          ...marked(own, locale: Locale(language.code)),
        ],
      ],
    );
  }
}

/// The language's icon on a tile: the first letter of its own name.
class _Icon extends StatelessWidget {
  const _Icon({required this.language});

  final CatalogLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.all(6),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Text(
          language.icon ?? language.code,
          locale: Locale(language.code),
          style: theme.textTheme.titleLarge!.copyWith(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A thin rounded bar, 0–1. Its figure is in the text above it, so a screen
/// reader is not told it twice.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        color: color,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    ),
  );
}

/// "Taught from" and a chip per native language, the learner's own filled,
/// and the course's Alpha or Beta tag at the end.
class _TaughtFrom extends StatelessWidget {
  const _TaughtFrom({
    required this.language,
    required this.spoken,
    required this.stage,
  });

  final CatalogLanguage language;
  final List<String> spoken;
  final CourseStage? stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final natives = language.nativesInOrder(spoken);
    final tag = switch (stage) {
      CourseStage.alpha => (l10n.pickerAlpha, l10n.pickerAlphaLabel),
      CourseStage.beta => (l10n.pickerBeta, l10n.pickerBetaLabel),
      _ => null,
    };
    final chips = natives.isEmpty
        ? const SizedBox.shrink()
        : Semantics(
            label: l10n.pickerTaughtFromLine(
              natives.map((n) => n.name).join(l10n.commonListSeparator),
            ),
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    l10n.pickerTaughtFrom,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  for (final native in natives)
                    _Chip(
                      text: native.name,
                      mine: spoken.contains(native.code),
                    ),
                ],
              ),
            ),
          );
    if (tag == null) return chips;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: chips),
        const SizedBox(width: 8),
        Semantics(
          label: tag.$2,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.innerRow),
              ),
              child: Text(
                tag.$1,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: mine ? scheme.secondaryContainer : null,
        border: mine ? null : Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadii.innerRow),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge!.copyWith(
          color: mine ? scheme.onSecondaryContainer : scheme.onSurface,
        ),
      ),
    );
  }
}

/// "Learn the Kannada script", on by default, with the first letters and
/// their readings so the learner sees what it means. Off is Latin letters
/// only: the script decks are left out (ADR-0023).
class ScriptChoice extends StatelessWidget {
  const ScriptChoice({
    super.key,
    required this.language,
    required this.on,
    required this.onChanged,
    this.preview,
  });

  final CatalogLanguage language;
  final bool on;
  final ValueChanged<bool> onChanged;

  /// From the decks on the phone: how many decks, and the first letters.
  final ({int decks, List<ScriptLetter> letters})? preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = this.preview;
    final letters = on ? preview?.letters ?? const <ScriptLetter>[] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MergeSemantics(
          child: InkWell(
            onTap: () => onChanged(!on),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.pickerLearnScript(language.name),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !on
                            ? l10n.pickerScriptOff
                            : preview == null
                            ? l10n.pickerScriptDecksSome
                            : l10n.pickerScriptDecks(preview.decks),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: on, onChanged: onChanged),
              ],
            ),
          ),
        ),
        if (letters != null && letters.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                l10n.pickerStartWith,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final letter in letters)
                Semantics(
                  label: letter.reading == null
                      ? letter.letter
                      : l10n.pickerLetter(letter.letter, letter.reading!),
                  child: ExcludeSemantics(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 44),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            letter.letter,
                            locale: Locale(language.code),
                            style: theme.textTheme.titleLarge,
                          ),
                          if (letter.reading case final reading?)
                            Text(reading, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Which of the learner's languages a course is taught from, when more than
/// one teaches it (owner, 2026-10-09): up to three side by side, beyond
/// that a list in a sheet, each with its coverage, in the learner's order.
class NativeChoiceField extends StatelessWidget {
  const NativeChoiceField({
    super.key,
    required this.language,
    required this.options,
    required this.chosen,
    required this.onChosen,
  });

  /// The most that sit side by side.
  static const int sideBySide = 3;

  final CatalogLanguage language;

  /// The learner's languages it is taught from, best known first.
  final List<CatalogNative> options;
  final String chosen;
  final ValueChanged<String> onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final heading = Text(
      l10n.pickerTaughtFrom,
      style: theme.textTheme.titleSmall,
    );
    if (options.length <= sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          heading,
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              for (final option in options)
                ButtonSegment<String>(
                  value: option.code,
                  label: Text(option.name),
                ),
            ],
            selected: <String>{chosen},
            onSelectionChanged: (picked) => onChosen(picked.single),
          ),
        ],
      );
    }
    final current = options.firstWhere(
      (o) => o.code == chosen,
      orElse: () => options.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        heading,
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsetsDirectional.zero,
          title: Text(current.name),
          subtitle: Text(coverage(l10n, current.progress)),
          trailing: TextButton(
            onPressed: () => _openSheet(context),
            child: Text(l10n.pickerChangeNative),
          ),
          onTap: () => _openSheet(context),
        ),
      ],
    );
  }

  /// How much of B1 a native language's decks have: "62% of B1 written",
  /// or the course's size without a plan.
  static String coverage(AppLocalizations l10n, B1Progress progress) =>
      progress.hasPlan
      ? l10n.pickerWritten(progress.percent)
      : l10n.pickerCourseSize(progress.courseWords);

  Future<void> _openSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: chosen,
          onChanged: (code) => Navigator.of(context).pop(code),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.pickerLearnFrom(language.name),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              for (final option in options)
                RadioListTile<String>(
                  value: option.code,
                  title: Text(option.name),
                  subtitle: Text(coverage(l10n, option.progress)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChosen(picked);
  }
}

/// A notice inside an opened card: an icon and a line.
class CardNotice extends StatelessWidget {
  const CardNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
