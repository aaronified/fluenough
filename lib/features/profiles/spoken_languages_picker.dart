import 'package:flutter/material.dart';

import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
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

/// Languages you know (#53, #462, #490): one screen, used on the first
/// launch and in Settings, which add only the chrome around it.
///
/// From the top: a search, the chosen languages (best known first, the
/// order they were chosen in), a few top picks from the phone's language and
/// region, then every language grouped by family, folded by default.
/// Tapping a language opens a bottom sheet that answers the language and
/// whether its script is read in one tap (approved design:
/// `docs/mockups/languages-you-know.html`).
class SpokenLanguagesPicker extends StatefulWidget {
  const SpokenLanguagesPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.choices,
    this.header,
    this.footer,
    this.readsScript = const <String, bool>{},
    this.onScriptsChanged,
    this.locales,
  });

  static const String asset = 'assets/languages.yaml';

  /// The chosen codes, best known first.
  final List<String> initial;

  /// Called with the chosen codes, best known first, after every change.
  final ValueChanged<List<String>> onChanged;

  /// Null reads [asset].
  final List<SpokenLanguage>? choices;

  /// Whether the learner reads each language's scripts (#462, #551): by
  /// [SpokenLanguage.readKey], its own script under its code.
  final Map<String, bool> readsScript;

  /// Called with every answer, as [readsScript] keeps them, when a sheet
  /// answers.
  final ValueChanged<Map<String, bool>>? onScriptsChanged;

  /// The phone's languages, as (language, country), for the top picks. Null
  /// reads the platform's.
  final List<(String, String?)>? locales;

  /// Scrolls with the list, above it.
  final Widget? header;

  /// Scrolls with the list, below it.
  final Widget? footer;

  @override
  State<SpokenLanguagesPicker> createState() => _SpokenLanguagesPickerState();
}

class _SpokenLanguagesPickerState extends State<SpokenLanguagesPicker> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  List<SpokenLanguage>? _choices;
  List<String> _chosen = const <String>[];
  late Map<String, bool> _reads = <String, bool>{...widget.readsScript};

  /// The families open, by id. Every family starts folded.
  final Set<String> _open = <String>{};

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    if (widget.choices case final given?) _init(given);
  }

  @override
  void didUpdateWidget(SpokenLanguagesPicker old) {
    super.didUpdateWidget(old);
    if (_choices == null && widget.choices != null) _init(widget.choices!);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_choices != null || widget.choices != null) return;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPicker.asset)
        .then(parseSpokenLanguages)
        .then((choices) {
          if (mounted && _choices == null) setState(() => _init(choices));
        });
  }

  void _init(List<SpokenLanguage> choices) {
    final codes = {for (final c in choices) c.code};
    _choices = choices;
    _chosen = <String>[
      for (final code in widget.initial)
        if (codes.contains(code)) code,
    ];
  }

  SpokenLanguage _language(String code) =>
      _choices!.firstWhere((c) => c.code == code);

  /// Opens [language]'s sheet and applies the answer.
  Future<void> _ask(SpokenLanguage language) async {
    final reply = await showModalBottomSheet<KnownReply>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => KnownLanguageSheet(
        language: language,
        current: _chosen.contains(language.code)
            ? language.scriptsReadIn(_reads)
            : null,
        chosen: _chosen.contains(language.code),
      ),
    );
    if (reply == null || !mounted) return;
    setState(() {
      final others = <String, bool>{
        for (final e in _reads.entries)
          if (readKeyLanguage(e.key) != language.code) e.key: e.value,
      };
      if (reply.answer == KnownAnswer.remove) {
        _chosen = <String>[
          for (final c in _chosen)
            if (c != language.code) c,
        ];
        _reads = others;
      } else {
        if (!_chosen.contains(language.code)) {
          _chosen = <String>[..._chosen, language.code];
        }
        _reads = <String, bool>{
          ...others,
          ...language.readAnswers(reply.scripts),
        };
        widget.onScriptsChanged?.call(_reads);
      }
    });
    widget.onChanged(_chosen);
  }

  List<(String, String?)> _phoneLocales() =>
      widget.locales ??
      <(String, String?)>[
        for (final l in WidgetsBinding.instance.platformDispatcher.locales)
          (l.languageCode, l.countryCode),
      ];

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    if (choices == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final query = _search.text.trim();
    final families = <String>[];
    for (final c in choices) {
      final f = c.family ?? 'other';
      if (!families.contains(f)) families.add(f);
    }
    List<SpokenLanguage> inFamily(String f) => <SpokenLanguage>[
      for (final c in choices)
        if ((c.family ?? 'other') == f) c,
    ]..sort((a, b) => a.name.compareTo(b.name));

    final body = <Widget>[];
    if (query.isNotEmpty) {
      var any = false;
      for (final f in families) {
        final all = inFamily(f);
        final hits = <SpokenLanguage>[
          for (final c in all)
            if (c.matches(query)) c,
        ];
        if (hits.isEmpty) continue;
        any = true;
        body.add(
          PickerHeading(
            l10n.knownFamily(f),
            note: l10n.knownSearchMatches(hits.length, all.length),
          ),
        );
        body.addAll(<Widget>[for (final c in hits) _row(l10n, c)]);
      }
      if (!any) {
        body.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
            child: Text(
              l10n.knownSearchNone(query),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        );
      }
    } else {
      if (_chosen.isNotEmpty) {
        body
          ..add(
            PickerHeading(
              l10n.knownYourLanguages,
              note: l10n.knownYourLanguagesNote,
            ),
          )
          ..addAll(<Widget>[for (final c in _chosen) _row(l10n, _language(c))]);
      }
      final picks = topPicksFor(_phoneLocales(), choices);
      if (picks.isNotEmpty) {
        body
          ..add(PickerHeading(l10n.knownTopPicks))
          ..add(
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  for (final code in picks) _chip(_language(code)),
                ],
              ),
            ),
          );
      }
      body.add(PickerHeading(l10n.knownAllLanguages, note: l10n.knownByFamily));
      for (final f in families) {
        final languages = inFamily(f);
        final open = _open.contains(f);
        body.add(_familyRow(l10n, f, languages.length, open));
        if (open) {
          body.addAll(<Widget>[for (final c in languages) _row(l10n, c)]);
        }
      }
    }

    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView(
        controller: _scroll,
        children: <Widget>[
          ?widget.header,
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
            child: TextField(
              key: const ValueKey<String>('known-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.knownSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .clearButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: _search.clear,
                      ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
              ),
            ),
          ),
          ...body,
          ?widget.footer,
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _chip(SpokenLanguage language) {
    final on = _chosen.contains(language.code);
    return ActionChip(
      key: ValueKey<String>('pick-${language.code}'),
      avatar: on ? const Icon(Icons.check) : null,
      label: Text(language.name),
      onPressed: () => _ask(language),
    );
  }

  Widget _familyRow(AppLocalizations l10n, String id, int count, bool open) =>
      FamilyRow(
        id: id,
        count: count,
        open: open,
        onToggle: () => setState(() => open ? _open.remove(id) : _open.add(id)),
      );

  /// A language: English name and own name; once chosen, its answer.
  Widget _row(AppLocalizations l10n, SpokenLanguage language) {
    final theme = Theme.of(context);
    final on = _chosen.contains(language.code);
    final reads = language.scriptsReadIn(_reads);
    final same = language.ownName == language.name;
    return ListTile(
      key: ValueKey<String>('lang-${language.code}'),
      contentPadding: const EdgeInsetsDirectional.only(start: 24, end: 16),
      title: on && !same
          ? Text.rich(_ownNameMarked(l10n, language))
          : Text(language.name),
      subtitle: on
          ? (reads == null ? null : Text(_answer(l10n, language, reads)))
          : same
          ? null
          : Text.rich(
              TextSpan(text: language.ownName, locale: Locale(language.code)),
            ),
      trailing: Icon(
        on ? Icons.edit_outlined : Icons.add_circle_outline,
        color: on ? theme.colorScheme.primary : null,
      ),
      onTap: () => _ask(language),
    );
  }
}

/// A chosen language's answer, under it: the scripts read, by their own
/// names, or "Can only speak".
String _answer(
  AppLocalizations l10n,
  SpokenLanguage language,
  List<String> reads,
) {
  String name(String script) => l10n.scriptNameOr(script, language.name);
  return switch (reads) {
    [] => l10n.knownAnswerSpeak(language.name),
    [final one] => l10n.knownAnswerRead(name(one)),
    _ => l10n.knownAnswerReadSeveral(
      reads.map(name).join(l10n.commonListSeparator),
    ),
  };
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
        contentPadding: const EdgeInsetsDirectional.only(start: 24, end: 16),
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
      padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: theme.textTheme.titleSmall!.copyWith(
                  color: theme.colorScheme.primary,
                ),
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
/// The question and the "I can read it" answer are written in the
/// language's own script, whether or not a speaker has checked them
/// (owner, 2026-10-18), marked with its language so a screen reader reads
/// them in its voice, with the English under each, so a learner who only
/// speaks the language still understands. The other answer is English.
/// Neither is called Yes or No. A language with no sentences of its own yet
/// asks in English, naming the script by its own name (#551).
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
    final locale = Locale(language.code);
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
                    locale: locale,
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
                      showEnglish: below,
                      locale: locale,
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
                    showEnglish: below,
                    locale: locale,
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
/// English under it in smaller text. With no own text it is the English
/// alone, in the main style.
class _OwnAndEnglish extends StatelessWidget {
  const _OwnAndEnglish({
    required this.own,
    required this.english,
    required this.showEnglish,
    required this.locale,
    required this.ownStyle,
    required this.englishStyle,
  });

  final String? own;
  final String english;
  final bool showEnglish;
  final Locale locale;
  final TextStyle ownStyle;
  final TextStyle englishStyle;

  @override
  Widget build(BuildContext context) {
    final own = this.own;
    if (own == null) return Text(english, style: ownStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(text: own, locale: locale),
          style: ownStyle,
        ),
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
      padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 4),
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
