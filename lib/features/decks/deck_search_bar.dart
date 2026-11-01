import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/search/query.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';
import 'unit_search.dart' show SearchSuggestion, searchKindLabel;

/// A token's value as its chip and its menu show it.
String tokenValueLabel(
  AppLocalizations l10n,
  SearchToken token,
  String value, {
  Map<String, String> themeNames = const <String, String>{},
}) => switch (token) {
  SearchToken.kind => searchKindLabel(l10n, SearchKind.values.byName(value)),
  SearchToken.status => statusLabel(
    l10n,
    CardStatus.values.firstWhere((s) => s.slug == value),
  ),
  SearchToken.theme => themeNames[value] ?? value,
};

/// A status as its chip and the menu show it.
String statusLabel(AppLocalizations l10n, CardStatus status) =>
    switch (status) {
      CardStatus.notLearnt => l10n.searchStatusNotLearnt,
      CardStatus.learning => l10n.searchStatusLearning,
      CardStatus.learnt => l10n.searchStatusLearnt,
      CardStatus.forgetting => l10n.searchStatusForgetting,
      CardStatus.struggling => l10n.searchStatusStruggling,
      CardStatus.setAside => l10n.searchStatusSetAside,
    };

/// The short line under a status in the menu.
String statusLine(AppLocalizations l10n, CardStatus status) => switch (status) {
  CardStatus.notLearnt => l10n.searchStatusLineNotLearnt,
  CardStatus.learning => l10n.searchStatusLineLearning,
  CardStatus.learnt => l10n.searchStatusLineLearnt,
  CardStatus.forgetting => l10n.searchStatusLineForgetting,
  CardStatus.struggling => l10n.searchStatusLineStruggling,
  CardStatus.setAside => l10n.searchStatusLineSetAside,
};

/// The short line under a kind in the menu.
String kindLine(AppLocalizations l10n, SearchKind kind) => switch (kind) {
  SearchKind.words => l10n.searchKindLineWords,
  SearchKind.grammar => l10n.searchKindLineGrammar,
  SearchKind.script => l10n.searchKindLineScript,
  SearchKind.reading => l10n.searchKindLineReading,
};

/// The Decks tab's search bar (#527, the approved mockup): the search icon,
/// the token chips the search holds, the one text field, and an end button
/// that clears and then closes. The chips and the text share the lines: the
/// chips wrap when they do not fit, the text follows the last, and the bar
/// grows with them.
class DeckSearchBar extends StatelessWidget {
  const DeckSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.chips,
    required this.chipLabel,
    required this.editing,
    required this.onChanged,
    required this.onChipTap,
    required this.onChipRemove,
    required this.onBackspaceEmpty,
    required this.showEnd,
    required this.endTooltip,
    required this.onEnd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  /// The chips, in token order.
  final Map<SearchToken, String> chips;

  /// A chip's text, "kind: Grammar".
  final String Function(SearchToken token, String value) chipLabel;

  /// The chip whose value is being changed, outlined.
  final SearchToken? editing;

  final ValueChanged<String> onChanged;
  final ValueChanged<SearchToken> onChipTap;
  final ValueChanged<SearchToken> onChipRemove;

  /// Backspace pressed in an empty text: the last chip goes.
  final VoidCallback onBackspaceEmpty;

  final bool showEnd;
  final String endTooltip;
  final VoidCallback onEnd;

  static const double _barHeight = 56;

  /// The gap between two chips, and between the last chip and the text.
  static const double _gap = 6;

  /// The least room the text is given before it starts a line of its own.
  static const double _minField = 72;

  /// What a chip takes beyond its label: its padding, its ✕ and a margin
  /// for the sizes the framework picks (an estimate; a wrong one only moves
  /// the text to the next line or leaves it a little narrower).
  static const double _chipExtra = 56;

  /// The width of the text field when [width] holds the chips [labels]:
  /// what is left of the last line, or the whole line when less than
  /// [_minField] is left.
  double _fieldWidth(
    BuildContext context,
    Iterable<String> labels,
    double width,
  ) {
    if (labels.isEmpty || !width.isFinite) return width;
    final style =
        Theme.of(context).chipTheme.labelStyle ??
        Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var used = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final chip = (painter.width + _chipExtra).clamp(0.0, width);
      painter.dispose();
      if (used > 0 && used + chip > width) used = 0;
      used += chip + _gap;
    }
    final left = width - used;
    return left >= _minField ? left : width;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      // A pill: half the bar's height, a formula and not a token.
      borderRadius: BorderRadius.circular(_barHeight / 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _barHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
          child: Row(
            children: <Widget>[
              Icon(Icons.search, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final labels = <SearchToken, String>{
                      for (final token in SearchToken.values)
                        if (chips[token] case final value?)
                          token: chipLabel(token, value),
                    };
                    final field = _fieldWidth(context, labels.values, width);
                    return Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: 4,
                      ),
                      // The chips and the text share the lines: the text
                      // follows the last chip, or starts the next line when
                      // too little is left (mockup, section 4).
                      child: Wrap(
                        spacing: _gap,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          for (final entry in labels.entries)
                            Semantics(
                              label: l10n.searchChipChange(entry.value),
                              child: InputChip(
                                label: Text(entry.value),
                                side: editing == entry.key
                                    ? BorderSide(
                                        color: scheme.primary,
                                        width: 2,
                                      )
                                    : null,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onChipTap(entry.key),
                                onDeleted: () => onChipRemove(entry.key),
                                deleteButtonTooltipMessage: l10n
                                    .searchChipRemove(entry.value),
                              ),
                            ),
                          SizedBox(
                            width: field,
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.backspace &&
                                    controller.text.isEmpty &&
                                    chips.isNotEmpty) {
                                  onBackspaceEmpty();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                onChanged: onChanged,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: chips.isEmpty ? hint : null,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding:
                                      const EdgeInsetsDirectional.symmetric(
                                        vertical: 12,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (showEnd)
                IconButton(
                  tooltip: endTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onEnd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the search's menu.
class SearchMenuItem {
  const SearchMenuItem({required this.title, this.line, required this.onTap});

  final String title;
  final String? line;
  final VoidCallback onTap;
}

/// The menu under the bar: the tokens an empty bar offers, or the values of
/// a token, as a dropdown combobox does (mockup sections 1 and 4). It shows
/// about eight rows and scrolls.
class SearchMenu extends StatelessWidget {
  const SearchMenu({super.key, this.header, required this.items});

  final String? header;
  final List<SearchMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (header != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
                child: Text(
                  header!,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 8 * 64),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final item in items)
                    ListTile(
                      title: Text(item.title),
                      subtitle: item.line == null ? null : Text(item.line!),
                      onTap: item.onTap,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The suggestions above the results: each a completion of what is typed,
/// the typed part plain and the rest bold. A tap searches it; the arrow
/// puts it in the bar to go on typing.
class SuggestionRows extends StatelessWidget {
  const SuggestionRows({
    super.key,
    required this.typed,
    required this.suggestions,
    required this.onUse,
    required this.onEdit,
  });

  final String typed;
  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onUse;
  final ValueChanged<SearchSuggestion> onEdit;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = typed.trimRight();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Column(
        children: <Widget>[
          for (final s in suggestions)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.chip),
              onTap: () => onUse(s),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 8),
                    Icon(Icons.search, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: l10n.searchSuggestionUse(s.text),
                        excludeSemantics: true,
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: s.text.substring(
                                  0,
                                  base.length.clamp(0, s.text.length),
                                ),
                              ),
                              TextSpan(
                                text: s.text.substring(
                                  base.length.clamp(0, s.text.length),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    LabelledIconButton(
                      label: l10n.searchSuggestionEdit(s.text),
                      hint: l10n.hintEdit,
                      icon: const Icon(Icons.north_west),
                      onPressed: () => onEdit(s),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
