import 'package:flutter/material.dart';

import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';

/// What a learner answers on a language's sheet: reads its script, or
/// some of its scripts, speaks it only, or takes it out of the list.
enum KnownAnswer { reads, speaksOnly, remove }

/// The sheet's answer, with the scripts read (#551).
@immutable
class KnownReply {
  const KnownReply.reads(this.scripts) : answer = KnownAnswer.reads;
  const KnownReply.speaksOnly()
    : answer = KnownAnswer.speaksOnly,
      scripts = const <String>[];
  const KnownReply.remove()
    : answer = KnownAnswer.remove,
      scripts = const <String>[];

  final KnownAnswer answer;

  /// The scripts read, as `assets/languages.yaml` names them; empty unless
  /// [answer] is [KnownAnswer.reads].
  final List<String> scripts;
}

/// A language family's row, folded or open, with how many languages it
/// holds: Languages you know and Languages I'm learning (#626) group their
/// languages the same way.
class FamilyRow extends StatelessWidget {
  const FamilyRow({
    super.key,
    required this.id,
    required this.count,
    required this.open,
    required this.onToggle,
  });

  /// The family's id in `assets/languages.yaml`, or `other`.
  final String id;
  final int count;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = l10n.knownFamily(id);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: open
          ? l10n.knownFamilyExpanded(name, count)
          : l10n.knownFamilyCollapsed(name, count),
      onTap: onToggle,
      child: ListTile(
        key: ValueKey<String>('family-$id'),
        contentPadding: EdgeInsetsDirectional.only(
          start: PickerGutter.of(context),
          end: PickerGutter.of(context) - 8,
        ),
        title: Text(name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.knownFamilyCount(count),
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Icon(open ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}

/// A group's label on the 24 px line, with a note at its end.
class PickerHeading extends StatelessWidget {
  const PickerHeading(this.text, {super.key, this.note});

  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        PickerGutter.of(context),
        16,
        PickerGutter.of(context),
        4,
      ),
      // A wrap, not a row: at large text a note too long for the line goes
      // under the label instead of overflowing.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 12,
        runSpacing: 2,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              text,
              style: theme.textTheme.titleSmall!.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (note != null)
            Text(
              note!,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The bottom sheet that answers a language and its script in one tap.
///
/// The question and the "I can read it" answers are written in the
/// language's own script, whether or not a speaker has checked them
/// (owner, 2026-10-18), marked with its language so a screen reader reads
/// them in its voice. The English is under the question only, so a learner
/// who only speaks the language still understands what is asked; every
/// answer line is its own script alone (owner, 2026-11-01). The other answer
/// is English. Neither is called Yes or No. A language with no sentences of
/// its own yet asks in English, naming the script by its own name (#551).
///
/// An answer written in another script than the language's first, such as
/// Hindustani's in the Perso-Arabic script, is drawn right to left and marked
/// as Urdu ([SpokenLanguage.localeCodeFor]).
///
/// A language written in several scripts, such as Punjabi in Gurmukhi and
/// Shahmukhi, asks which of them are read (#551): one answer to tick per
/// script, and Done, or "I can only speak it" in one tap.
class KnownLanguageSheet extends StatefulWidget {
  const KnownLanguageSheet({
    super.key,
    required this.language,
    required this.current,
    required this.chosen,
  });

  final SpokenLanguage language;

  /// The answer given before: the scripts read, empty for "speaks only";
  /// null none.
  final List<String>? current;

  /// Whether the language is already in the list: it can then be removed.
  final bool chosen;

  @override
  State<KnownLanguageSheet> createState() => _KnownLanguageSheetState();
}

class _KnownLanguageSheetState extends State<KnownLanguageSheet> {
  /// The scripts ticked, for a language written in several.
  late final Set<String> _ticked = <String>{...?widget.current};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.language;
    final current = widget.current;
    final several = language.hasSeveralScripts;
    final own = !several && language.asksInOwnScript;
    String name(String? script) => l10n.scriptNameOr(script, language.name);
    final ownScripts = several && language.asksScriptsInOwnScript;
    // English is kept below an own-script text, so a learner who only
    // speaks the language still understands it. English itself has none.
    final below = language.code != 'en';
    final englishQuestion = several
        ? l10n.knownReadsWhichScripts(language.name)
        : l10n.knownReadsScript(name(language.script));
    final ownQuestion = several
        ? (ownScripts ? language.scriptsQuestion : null)
        : (own ? language.scriptQuestion : null);
    final englishRead = l10n.knownCanReadFallback(name(language.script));
    final ownRead = own ? language.scriptCanRead : null;
    void pop(KnownReply reply) => Navigator.of(context).pop(reply);
    Widget option({
      required Key key,
      required Widget text,
      required IconData icon,
      required bool selected,
      required KnownReply reply,
    }) => ListTile(
      key: key,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
      title: text,
      trailing: Icon(selected ? Icons.radio_button_checked : icon),
      selected: selected,
      onTap: () => pop(reply),
    );

    return MediaQuery(
      // The sheet's text grows at most one and a half times, so the question
      // and both answers stay in view at the largest text size.
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The language the sheet is about, as its list row names it,
              // read before the question.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      key: const ValueKey<String>('know-language'),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        24,
                        0,
                        24,
                        4,
                      ),
                      child: Text.rich(
                        language.ownName == language.name
                            ? TextSpan(text: language.name)
                            : _ownNameMarked(l10n, language),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // Texts no speaker has checked can be reported (owner,
                  // 2026-10-18: "Just a simple bug icon will suffice.").
                  if (language.scriptTextUnchecked)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: IconButton(
                        key: const ValueKey<String>('know-report'),
                        tooltip: l10n.knownReportMistake,
                        icon: const Icon(Icons.bug_report_outlined),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () => ReportButton.open(
                          context,
                          detail: knownReportDetail(language),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 4),
                child: Semantics(
                  header: true,
                  namesRoute: true,
                  child: _OwnAndEnglish(
                    own: ownQuestion,
                    english: englishQuestion,
                    showEnglish: below,
                    language: language,
                    ownStyle: theme.textTheme.titleMedium!,
                    englishStyle: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (several)
                for (final script in language.scripts)
                  CheckboxListTile(
                    key: ValueKey<String>('know-script-$script'),
                    minVerticalPadding: 0,
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 24,
                      end: 12,
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: _OwnAndEnglish(
                      own: language.canReadIn(script),
                      english: l10n.knownCanReadFallback(name(script)),
                      showEnglish: false,
                      language: language,
                      // Body size, set apart from the English by its colour:
                      // a larger own-script text pushed Done off screen at 1.4x.
                      ownStyle: theme.textTheme.bodyMedium!,
                      englishStyle: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _ticked.contains(script),
                    onChanged: (on) => setState(
                      () => on ?? false
                          ? _ticked.add(script)
                          : _ticked.remove(script),
                    ),
                  )
              else
                option(
                  key: const ValueKey<String>('know-read'),
                  text: _OwnAndEnglish(
                    own: ownRead,
                    english: englishRead,
                    showEnglish: false,
                    language: language,
                    ownStyle: theme.textTheme.bodyLarge!,
                    englishStyle: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  icon: Icons.menu_book_outlined,
                  selected: current?.isNotEmpty ?? false,
                  reply: KnownReply.reads(<String>[language.script ?? '']),
                ),
              option(
                key: const ValueKey<String>('know-speak'),
                text: Text(
                  l10n.knownSpeakOnly(language.name),
                  style: theme.textTheme.bodyLarge,
                ),
                icon: Icons.record_voice_over_outlined,
                selected: current?.isEmpty ?? false,
                reply: const KnownReply.speaksOnly(),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: widget.chosen
                            ? TextButton(
                                key: const ValueKey<String>('know-remove'),
                                onPressed: () => pop(const KnownReply.remove()),
                                child: Text(l10n.knownRemove(language.name)),
                              )
                            : null,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey<String>('know-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                    if (several) ...<Widget>[
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const ValueKey<String>('know-done'),
                        onPressed: _ticked.isEmpty
                            ? null
                            : () => pop(
                                KnownReply.reads(<String>[
                                  for (final s in language.scripts)
                                    if (_ticked.contains(s)) s,
                                ]),
                              ),
                        child: Text(l10n.knownScriptsDone),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a report of a language's own-script texts says, so a speaker can
/// say which is wrong and give the right wording: the language's code, and
/// each text with what it is. Not interface text.
String knownReportDetail(SpokenLanguage language) {
  final lines = <String>[
    'Languages you know: ${language.code}',
    if (language.hasSeveralScripts) ...<String>[
      'scripts question: ${language.scriptsQuestion}',
      for (final script in language.scripts)
        if (language.canReadIn(script) != null)
          'can read ($script): ${language.canReadIn(script)}',
    ] else ...<String>[
      'question: ${language.scriptQuestion}',
      'can read: ${language.scriptCanRead}',
    ],
  ];
  return lines.join('\n');
}

/// A text in a language's own script, marked as that language, with its
/// English under it in smaller text where [showEnglish]. With no own text it
/// is the English alone, in the main style. A text in the Perso-Arabic script
/// is drawn right to left, marked as Urdu.
class _OwnAndEnglish extends StatelessWidget {
  const _OwnAndEnglish({
    required this.own,
    required this.english,
    required this.showEnglish,
    required this.language,
    required this.ownStyle,
    required this.englishStyle,
  });

  final String? own;
  final String english;
  final bool showEnglish;
  final SpokenLanguage language;
  final TextStyle ownStyle;
  final TextStyle englishStyle;

  @override
  Widget build(BuildContext context) {
    final own = this.own;
    if (own == null) return Text(english, style: ownStyle);
    final rtl = SpokenLanguage.isRtlText(own);
    Widget text = Text.rich(
      TextSpan(text: own, locale: Locale(language.localeCodeFor(own))),
      style: ownStyle,
      textDirection: rtl ? TextDirection.rtl : null,
    );
    // Filling the line is what puts a right-to-left text at its right edge.
    if (rtl) text = SizedBox(width: double.infinity, child: text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        text,
        if (showEnglish) ...<Widget>[
          // Tight, so the sheet stays on screen at 1.4x text: a snugger line
          // height, not a smaller size.
          Text(english, style: englishStyle.copyWith(height: 1.2)),
        ],
      ],
    );
  }
}

/// "Bengali · বাংলা" with বাংলা marked as Bengali, so a screen reader reads
/// it in a Bengali voice. The token still sets the order.
TextSpan _ownNameMarked(AppLocalizations l10n, SpokenLanguage language) {
  final text = l10n.spokenOption(language.name, language.ownName);
  final at = text.lastIndexOf(language.ownName);
  if (at < 0) return TextSpan(text: text);
  return TextSpan(
    children: <TextSpan>[
      TextSpan(text: text.substring(0, at)),
      TextSpan(text: language.ownName, locale: Locale(language.code)),
      TextSpan(text: text.substring(at + language.ownName.length)),
    ],
  );
}

/// A note under the list: a 20 px icon on the 24 px line, its text on 72.
class PickerNote extends StatelessWidget {
  const PickerNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        PickerGutter.of(context),
        12,
        PickerGutter.of(context),
        4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: colour),
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// The side padding the picker's rows, headings and notes use, set by
/// [SpokenLanguagesPicker.gutter].
class PickerGutter extends InheritedWidget {
  const PickerGutter({super.key, required this.gutter, required super.child});

  /// Onboarding's 24 px line.
  static const double onboarding = 24;

  final double gutter;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PickerGutter>()?.gutter ??
      onboarding;

  @override
  bool updateShouldNotify(PickerGutter old) => gutter != old.gutter;
}
