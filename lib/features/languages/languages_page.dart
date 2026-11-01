import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/language_skills.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../downloads/deck_update_controls.dart';
import '../downloads/download_text.dart';
import 'add_language_page.dart';
import 'language_skills_sheet.dart';
import 'language_views.dart';
import 'skill_widgets.dart';

/// The list's filter pills, in their order: Learning, Know, then the four
/// skills. A skill's pill matches a language where that skill is not Leave.
/// Gestures is shown only while a sign language is listed, and matches only
/// sign languages (owner, 2026-11-01).
enum LanguageFilter { learning, know, speak, hear, read, write, gesture }

/// "Languages" (#907, the mockup `languages-merged`, approved 2026-10-30):
/// the languages known and learned in one list. Each language shows its four
/// skills as read-only chips, Learning first, then Know; a tap opens its
/// sheet, where each skill's pill changes it. A language with every skill
/// Leave is not listed: it is back in the pool, found again with Add a
/// language.
class LanguagesPage extends StatefulWidget {
  const LanguagesPage({super.key, this.spokenList, this.initialQuery});

  /// A language's name to open Add a language at, its search holding it, as
  /// the deck search's shortcut to a course does (#918); null opens the list.
  final String? initialQuery;

  /// The languages of `assets/languages.yaml`, for a test; null reads them
  /// from the asset bundle.
  final List<SpokenLanguage>? spokenList;

  @override
  State<LanguagesPage> createState() => _LanguagesPageState();
}

class _LanguagesPageState extends State<LanguagesPage> {
  List<SpokenLanguage>? _all;
  bool _asked = false;
  bool _queryOpened = false;
  LanguageFilter? _filter;

  @override
  void initState() {
    super.initState();
    _all = widget.spokenList;
    if (_all != null) _openQuery();
    final downloads = AppScope.read(context).deckDownloads;
    if (downloads != null && downloads.index == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(downloads.refreshIndex()),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked || _all != null) return;
    _asked = true;
    DefaultAssetBundle.of(context)
        .loadString(spokenLanguagesAsset)
        .then(parseSpokenLanguages)
        .then((list) {
          if (!mounted) return;
          setState(() => _all = list);
          _openQuery();
        }, onError: (Object _) {});
  }

  /// Opens Add a language at [LanguagesPage.initialQuery], once, when the
  /// languages are known (#918).
  void _openQuery() {
    final query = widget.initialQuery;
    if (_queryOpened || query == null || query.trim().isEmpty) return;
    _queryOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final all = _all;
      if (mounted && all != null) _add(AppScope.read(context), all, query);
    });
  }

  Map<String, String> _names(List<SpokenLanguage> all) => <String, String>{
    for (final l in all) l.code: l.name,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final all = _all;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languagesTitle),
        actions: <Widget>[
          if (all != null)
            ListenableBuilder(
              listenable: state.settings,
              builder: (context, _) => _held(state, all).isEmpty
                  ? const SizedBox.shrink()
                  : LabelledIconButton(
                      label: l10n.languagesAdd,
                      hint: l10n.hintAdd,
                      onPressed: () => _add(state, all),
                      icon: const Icon(Icons.add),
                    ),
            ),
          const ReportButton(),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: all == null
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: Listenable.merge(<Listenable?>[
                  state.settings,
                  state.deckDownloads,
                ]),
                builder: (context, _) => _body(context, state, all),
              ),
      ),
    );
  }

  /// The languages with a skill that is not Leave, Learning first.
  List<(LanguageView, LanguageSkills)> _held(
    AppState state,
    List<SpokenLanguage> all,
  ) {
    final views = languageViews(state, all);
    final held = <(LanguageView, LanguageSkills)>[
      for (final v in views)
        if (!state.skillsOf(v.language).isAllLeave)
          (v, state.skillsOf(v.language)),
    ];
    final learning = state.learningCodes.toList();
    final spoken = state.settings.spokenLanguages;
    int rank(LanguageView v, LanguageSkills s) {
      final i = s.anyLearn ? learning.indexOf(v.code) : spoken.indexOf(v.code);
      return i < 0 ? 1 << 20 : i;
    }

    held.sort((a, b) {
      if (a.$2.anyLearn != b.$2.anyLearn) return a.$2.anyLearn ? -1 : 1;
      final byRank = rank(a.$1, a.$2).compareTo(rank(b.$1, b.$2));
      return byRank != 0 ? byRank : a.$1.name.compareTo(b.$1.name);
    });
    return held;
  }

  bool _matches(
    AppState state,
    LanguageView view,
    LanguageSkills skills,
    LanguageFilter? filter,
  ) {
    if (filter == null) return true;
    final shape = state.skillShape(view.language);
    return switch (filter) {
      LanguageFilter.learning => skills.anyLearn,
      LanguageFilter.know => skills.count(SkillState.know, shape) > 0,
      // The pills' levels: Hear and Speak speak, any Spoken level hears; Read
      // and Write likewise for a script.
      LanguageFilter.speak =>
        !view.language.isSign &&
            (skills.spokenLevel == SpokenLevel.hearSpeak ||
                skills.spokenLevel == SpokenLevel.learn),
      LanguageFilter.hear =>
        !view.language.isSign && skills.spokenLevel != SpokenLevel.leave,
      LanguageFilter.gesture =>
        view.language.isSign &&
            skills.stateOf(const SkillKey(SkillKind.gesture)) !=
                SkillState.leave,
      LanguageFilter.read =>
        !view.language.isSign &&
            state
                .skillScripts(view.language)
                .any((s) => skills.scriptLevelOf(s) != ScriptLevel.leave),
      LanguageFilter.write =>
        !view.language.isSign &&
            state
                .skillScripts(view.language)
                .any(
                  (s) =>
                      skills.scriptLevelOf(s) == ScriptLevel.readWrite ||
                      skills.scriptLevelOf(s) == ScriptLevel.learn,
                ),
    };
  }

  Widget _body(BuildContext context, AppState state, List<SpokenLanguage> all) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final held = _held(state, all);
    final hasSign = held.any((h) => h.$1.language.isSign);
    final filter = _filter == LanguageFilter.gesture && !hasSign
        ? null
        : _filter;
    if (held.isEmpty) {
      return EmptyState(
        icon: Icons.translate,
        title: l10n.languagesEmptyTitle,
        body: l10n.languagesEmptyBody,
        action: FilledButton.icon(
          onPressed: () => _add(state, all),
          icon: const Icon(Icons.add),
          label: Text(l10n.languagesAdd),
        ),
      );
    }
    final shown = <(LanguageView, LanguageSkills)>[
      for (final h in held)
        if (_matches(state, h.$1, h.$2, filter)) h,
    ];
    final learning = <(LanguageView, LanguageSkills)>[
      for (final h in shown)
        if (h.$2.anyLearn) h,
    ];
    final know = <(LanguageView, LanguageSkills)>[
      for (final h in shown)
        if (!h.$2.anyLearn) h,
    ];
    final downloads = state.deckDownloads;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: <Widget>[
        if (learning.isNotEmpty && downloads != null)
          DeckUpdateControls(downloads: downloads, names: _names(all)),
        const _Key(),
        _FilterRow(
          selected: filter,
          showGesture: hasSign,
          onChanged: (f) => setState(() => _filter = f),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 24),
            child: Text(
              l10n.languagesNoMatch,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (learning.isNotEmpty) ...<Widget>[
          LanguageSection(text: l10n.languagesSectionLearning(learning.length)),
          for (final h in learning)
            LanguageRow(
              key: ValueKey<String>('language-${h.$1.code}'),
              view: h.$1,
              skills: h.$2,
              onTap: () => _open(state, all, h.$1),
            ),
        ],
        if (know.isNotEmpty) ...<Widget>[
          LanguageSection(text: l10n.languagesSectionKnow(know.length)),
          for (final h in know)
            LanguageRow(
              key: ValueKey<String>('language-${h.$1.code}'),
              view: h.$1,
              skills: h.$2,
              onTap: () => _open(state, all, h.$1),
            ),
        ],
        const SizedBox(height: 8),
        // hint-ok: shows text
        InkWell(
          key: const ValueKey<String>('languages-add-row'),
          onTap: () => _add(state, all),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.languagesAdd,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(
    AppState state,
    List<SpokenLanguage> all,
    LanguageView view,
  ) => showLanguageSkills(context, state, all, view);

  Future<void> _add(
    AppState state,
    List<SpokenLanguage> all, [
    String? query,
  ]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/languages/add'),
      builder: (_) => AddLanguagePage(spokenList: all, initialQuery: query),
    ),
  );
}

/// The key above the list: what each mark means.
class _Key extends StatelessWidget {
  const _Key();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final modes = ModeColors.of(context);
    Widget entry(
      SkillMark mark,
      String text, {
      List<SkillKind> extra = const <SkillKind>[],
    }) {
      final colors = pillColors(modes, mark);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CustomPaint(
            foregroundPainter: mark == SkillMark.leave
                ? DashedOutline(colors.onContainer, AppRadii.control)
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.container,
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: mark == SkillMark.learn
                    ? Border.all(color: colors.onContainer, width: 1.5)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final kind in extra)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 2),
                        child: Icon(
                          kind.icon,
                          size: 16,
                          color: colors.onContainer,
                        ),
                      ),
                    SkillMarkGlyph(mark: mark, colors: colors),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      );
    }

    return Semantics(
      container: true,
      label: l10n.languagesKeyLabel,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: <Widget>[
            entry(SkillMark.know, l10n.languagesStateKnow),
            entry(
              SkillMark.knowBoth,
              l10n.languagesKeyBoth,
              extra: <SkillKind>[SkillKind.write, SkillKind.speak],
            ),
            entry(SkillMark.knowCovered, l10n.languagesKeyLevel),
            entry(
              SkillMark.learn,
              l10n.languagesStateLearn,
              extra: <SkillKind>[SkillKind.read, SkillKind.write],
            ),
            entry(SkillMark.leave, l10n.languagesStateLeave),
          ],
        ),
      ),
    );
  }
}

/// The filter pills: one row that scrolls sideways, faded at both edges.
/// One at a time; tapping the chosen one clears it.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.showGesture,
    required this.onChanged,
  });

  final LanguageFilter? selected;
  final bool showGesture;
  final ValueChanged<LanguageFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String text(LanguageFilter f) => switch (f) {
      LanguageFilter.learning => l10n.languagesFilterLearning,
      LanguageFilter.know => l10n.languagesStateKnow,
      LanguageFilter.speak => l10n.languagesSkillSpeak,
      LanguageFilter.hear => l10n.languagesSkillHear,
      LanguageFilter.read => l10n.languagesSkillRead,
      LanguageFilter.write => l10n.languagesSkillWrite,
      LanguageFilter.gesture => l10n.languagesGestures,
    };
    IconData icon(LanguageFilter f) => switch (f) {
      LanguageFilter.learning => Icons.school_outlined,
      LanguageFilter.know => Icons.check,
      LanguageFilter.speak => SkillKind.speak.icon,
      LanguageFilter.hear => SkillKind.hear.icon,
      LanguageFilter.read => SkillKind.read.icon,
      LanguageFilter.write => SkillKind.write.icon,
      LanguageFilter.gesture => SkillKind.gesture.icon,
    };
    return Semantics(
      container: true,
      label: l10n.languagesFilterLabel,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: <Color>[
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: <double>[0, 0.04, 0.96, 1],
        ).createShader(rect),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (final f in LanguageFilter.values)
                if (f != LanguageFilter.gesture || showGesture)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      key: ValueKey<String>('filter-${f.name}'),
                      showCheckmark: false,
                      avatar: Icon(icon(f), size: 18),
                      label: Text(text(f)),
                      selected: selected == f,
                      onSelected: (_) => onChanged(selected == f ? null : f),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading of the list, "Learning · 2" or "Know · 3". Public for the first
/// launch, which lists the languages the same way.
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.titleSmall!.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One language of the list: its tile and names, the dialect where it is
/// spoken, its four skills as read-only chips (one for each script of Read
/// and Write), and for a language learned its minutes a day and size.
class LanguageRow extends StatelessWidget {
  const LanguageRow({
    super.key,
    required this.view,
    required this.skills,
    required this.onTap,
  });

  final LanguageView view;
  final LanguageSkills skills;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final downloads = state.deckDownloads;
    final scripts = state.skillScripts(view.language);
    final found = state.levelFound(view.code);
    final learns = skills.anyLearn;
    final speaks =
        !view.language.isSign && skills.spokenLevel != SpokenLevel.leave;
    final hasDecks = downloads?.hasDecks(view.code) ?? false;
    final progress = downloads?.progressOf(view.code);
    final pending =
        hasDecks &&
        !learns &&
        state.settings.languageSkillsOf(view.code) != null;
    final dialect = !view.language.scriptOnly && speaks
        ? dialectOf(l10n, view.language)
        : null;
    final size = downloads == null ? 0 : downloads.sizeOnPhone(view.code);
    // hint-ok: shows text
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: learns
                            ? scheme.primaryContainer
                            : scheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        view.glyph,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1,
                          color: learns
                              ? scheme.onPrimaryContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          view.title,
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dialect != null)
                          Text(
                            dialect,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 48),
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                children: <Widget>[
                  if (view.language.isSign) _gestureChip(context, found),
                  if (!view.language.isSign && !view.language.scriptOnly)
                    _spokenChip(context, found),
                  for (final script in scripts)
                    _scriptChip(context, script, found),
                ],
              ),
            ),
            if (progress != null && learns)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: 6),
                child: LinearProgressIndicator(
                  value: progress.total == 0
                      ? null
                      : progress.done / progress.total,
                ),
              )
            else if (learns)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: 4),
                child: Wrap(
                  spacing: 12,
                  children: <Widget>[
                    _Meta(
                      icon: Icons.timer_outlined,
                      text: l10n.minutesValue(
                        state.settings.dailyMinutesFor(view.code),
                      ),
                    ),
                    if (size > 0)
                      _Meta(
                        icon: Icons.smartphone,
                        text: formatSize(l10n, size),
                      ),
                  ],
                ),
              ),
            if (learns && downloads?.failureOf(view.code) != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        downloadFailureText(
                          l10n,
                          downloads!.failureOf(view.code),
                        ),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          unawaited(state.downloadLanguage(view.code)),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            if (pending)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: 4),
                child: Text(
                  l10n.languagesDecksRemoved,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _covered(SkillState know, bool found) =>
      know == SkillState.know &&
      levelCovers(
        levelFound: found,
        taught: view.canLearn,
        english: view.code == englishCode,
      );

  /// The one chip of a sign language's Gestures skill: its own icon, with the
  /// tick once known.
  Widget _gestureChip(BuildContext context, bool found) {
    final l10n = AppLocalizations.of(context)!;
    final st = skills.stateOf(const SkillKey(SkillKind.gesture));
    final covered = _covered(st, found);
    final name = l10n.languagesSkillGestures;
    return SkillBadge(
      kind: SkillKind.gesture,
      mark: markOf(st, covered: covered),
      name: name,
    );
  }

  /// The one chip of Speak and Hear: the ear alone at Hear, with the
  /// microphone at Hear and Speak.
  Widget _spokenChip(BuildContext context, bool found) {
    final l10n = AppLocalizations.of(context)!;
    final level = skills.spokenLevel;
    final covered = _covered(
      level.isKnow ? SkillState.know : SkillState.leave,
      found,
    );
    final name = l10n.languagesSkillSpoken;
    return SkillBadge(
      kind: SkillKind.hear,
      combined: true,
      mark: spokenMarkOf(level, covered: covered),
      name: name,
      richIcons: true,
    );
  }

  /// The one chip of a script's Read and Write: the eye alone at Read, with the
  /// keyboard at Read and Write.
  Widget _scriptChip(BuildContext context, String script, bool found) {
    final l10n = AppLocalizations.of(context)!;
    final level = skills.scriptLevelOf(script);
    final covered = _covered(
      level.isKnow ? SkillState.know : SkillState.leave,
      found,
    );
    final name = scriptPillName(l10n, script, view.name);
    return SkillBadge(
      kind: SkillKind.read,
      mark: scriptMarkOf(level, covered: covered),
      name: name,
      combined: true,
      richIcons: true,
      glyph: scriptGlyph(script, l10n.scriptNameOr(script, view.name)),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodyMedium!.copyWith(color: color)),
      ],
    );
  }
}
