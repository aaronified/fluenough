import 'package:flutter/material.dart';

import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';

/// The languages a learner speaks, ticked and ranked (#53), as one
/// reorderable list: the first launch's question and the Settings screen.
///
/// Every row keeps one geometry, ticked or not: the checkbox's box on the
/// 24 px line, the name on 72. A ticked row adds its rank and a drag handle
/// at the end, so ticking never moves a name.
class SpokenLanguagesPicker extends StatefulWidget {
  const SpokenLanguagesPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.choices,
    this.header,
    this.footer,
  });

  static const String asset = 'assets/languages.yaml';

  /// The ticked codes, best known first.
  final List<String> initial;

  /// Called with the ticked codes, best known first, after every change.
  final ValueChanged<List<String>> onChanged;

  /// Null reads [asset].
  final List<SpokenLanguage>? choices;

  /// Scrolls with the list, above it.
  final Widget? header;

  /// Scrolls with the list, below it and the rank hint.
  final Widget? footer;

  @override
  State<SpokenLanguagesPicker> createState() => _SpokenLanguagesPickerState();
}

class _SpokenLanguagesPickerState extends State<SpokenLanguagesPicker> {
  List<SpokenLanguage>? _choices;
  List<String> _order = const <String>[];
  Set<String> _ticked = const <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.choices case final given?) _init(given);
  }

  @override
  void didUpdateWidget(SpokenLanguagesPicker old) {
    super.didUpdateWidget(old);
    if (_choices == null && widget.choices != null) _init(widget.choices!);
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
    final current = widget.initial;
    final codes = [for (final c in choices) c.code];
    _choices = choices;
    _ticked = {
      for (final code in current)
        if (codes.contains(code)) code,
    };
    _order = [
      for (final code in current)
        if (codes.contains(code)) code,
      for (final code in codes)
        if (!current.contains(code)) code,
    ];
  }

  List<String> get _ranked => [
    for (final code in _order)
      if (_ticked.contains(code)) code,
  ];

  void _change(void Function() change) {
    setState(change);
    widget.onChanged(_ranked);
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    if (choices == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = AppLocalizations.of(context)!;
    final ranked = _ranked;
    final still = MediaQuery.disableAnimationsOf(context);
    final hint = ranked.length < 2
        ? const SizedBox(width: double.infinity)
        : Semantics(
            liveRegion: true,
            child: PickerNote(
              icon: Icons.drag_handle,
              text: MediaQuery.accessibleNavigationOf(context)
                  ? l10n.spokenRankHintActions
                  : l10n.spokenRankHint,
            ),
          );
    return ReorderableListView(
      header: widget.header,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Not AnimatedSize at Duration.zero: it asserts.
          if (still)
            hint
          else
            AnimatedSize(
              duration: Durations.medium1,
              curve: Easing.emphasizedDecelerate,
              alignment: AlignmentDirectional.topStart,
              child: hint,
            ),
          ?widget.footer,
          const SizedBox(height: 16),
        ],
      ),
      onReorderItem: (from, to) => _change(() {
        final order = List<String>.of(_order);
        order.insert(to, order.removeAt(from));
        _order = order;
      }),
      children: <Widget>[
        for (final (i, code) in _order.indexed)
          _row(
            context,
            choices.firstWhere((c) => c.code == code),
            rank: ranked.indexOf(code) + 1,
            of: ranked.length,
            index: i,
          ),
      ],
    );
  }

  /// [rank] is 1-based; 0 when not ticked.
  Widget _row(
    BuildContext context,
    SpokenLanguage language, {
    required int rank,
    required int of,
    required int index,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ticked = rank > 0;
    return CheckboxListTile(
      key: ValueKey<String>(language.code),
      controlAffinity: ListTileControlAffinity.leading,
      // The checkbox is shrink-wrapped to 40 px with its 18 px box centred:
      // 13 + 11 puts the box on the 24 px line, and 13 + 40 + 19 puts every
      // name on 72. test/features/profiles/spoken_languages_page_test.dart
      // holds both.
      contentPadding: const EdgeInsetsDirectional.only(start: 13, end: 8),
      horizontalTitleGap: 19,
      value: ticked,
      onChanged: (on) => _change(() {
        final next = Set<String>.of(_ticked);
        on == true ? next.add(language.code) : next.remove(language.code);
        _ticked = next;
      }),
      title: Text.rich(_ownNameMarked(l10n, language)),
      secondary: !ticked
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  label: l10n.spokenRankSemantics(rank, of),
                  child: ExcludeSemantics(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 8,
                      ),
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: scheme.primary,
                      ),
                      // Factors of 1: centred, but only as tall as the digit.
                      child: Align(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          l10n.spokenRank(rank),
                          style: theme.textTheme.labelLarge!.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  // A tap on the handle must not untick the row.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () {},
                    child: SizedBox.square(
                      dimension: 48,
                      child: Icon(
                        Icons.drag_handle,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
