import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/ipa_chart.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'hint.dart';

/// The app's own keyboard of IPA symbols, under a typed answer in the IPA
/// course (#836, owner, 2026-10-24: "Braille may need a keyboard and also a
/// font. Same for IPA."), as the braille keyboard is for braille: the phone's
/// keyboard has no way to type most of them, so the field is read-only and
/// this types into [controller] at the cursor, passing each change to
/// [onChanged].
///
/// One keyboard of four tabs by kind, vowels, consonants, other symbols and
/// marks, each a wrapping grid of keys, with backspace and space always in
/// reach. Only the symbols the course's answers use are on it, found from
/// the decks' own cards (`AppState.ipaAnswerTargets`, `ipaKeysFor`), so the
/// grid matches the decks; [symbols] gives them directly instead. A tab with
/// no symbol is not shown.
///
/// A long press on a key shows the symbol's name, and a screen reader hears
/// that name, never the bare glyph. A mark that goes on the letter before
/// it is drawn on a dotted circle. Every key is 48 logical pixels square at
/// least, and its symbol stays within it at the app's largest text, 1.4x.
class IpaKeyboard extends StatefulWidget {
  const IpaKeyboard({
    super.key,
    required this.controller,
    this.onChanged,
    this.enabled = true,
    this.symbols,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// False once the answer is in.
  final bool enabled;

  /// The keys to offer; null finds them from the IPA course's answers.
  final List<IpaSymbol>? symbols;

  /// The side of a key.
  static const double keySize = 48;

  /// The grid's height before it scrolls: four and a half rows, so that a
  /// longer tab shows there is more under it.
  static const double gridHeight = 4.5 * keySize + 4 * 8;

  @override
  State<IpaKeyboard> createState() => _IpaKeyboardState();
}

class _IpaKeyboardState extends State<IpaKeyboard> {
  IpaKind _tab = IpaKind.vowels;
  List<IpaSymbol>? _keys;

  List<IpaSymbol> get _all =>
      _keys ??
      (_keys =
          widget.symbols ??
          ipaKeysFor(
            AppScope.maybeRead(context)?.ipaAnswerTargets() ?? const <String>[],
          ));

  @override
  void didUpdateWidget(IpaKeyboard old) {
    super.didUpdateWidget(old);
    if (old.symbols != widget.symbols) _keys = null;
  }

  /// Puts [text] in place of the selection, or at the cursor; at the end
  /// where the field has no cursor yet.
  void _insert(String text) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final next = value.text.replaceRange(start, end, text);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    widget.onChanged?.call(next);
  }

  /// Deletes the selection, or the symbol before the cursor: one code
  /// point, so a mark goes before the letter it was on.
  void _backspace() {
    final value = widget.controller.value;
    final selection = value.selection;
    if (value.text.isEmpty) return;
    var start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    if (start == end) {
      if (start == 0) return;
      start--;
      // A character past U+FFFF is two code units.
      final unit = value.text.codeUnitAt(start);
      if (start > 0 &&
          unit >= 0xDC00 &&
          unit <= 0xDFFF &&
          value.text.codeUnitAt(start - 1) >= 0xD800 &&
          value.text.codeUnitAt(start - 1) <= 0xDBFF) {
        start--;
      }
    }
    final next = value.text.replaceRange(start, end, '');
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start),
    );
    widget.onChanged?.call(next);
  }

  String _tabName(AppLocalizations l10n, IpaKind kind) => switch (kind) {
    IpaKind.vowels => l10n.ipaTabVowels,
    IpaKind.consonants => l10n.ipaTabConsonants,
    IpaKind.other => l10n.ipaTabOther,
    IpaKind.marks => l10n.ipaTabMarks,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = widget.enabled;
    final all = _all;
    final kinds = <IpaKind>[
      for (final kind in IpaKind.values)
        if (all.any((s) => s.kind == kind)) kind,
    ];
    final tab = kinds.contains(_tab)
        ? _tab
        : (kinds.isEmpty ? _tab : kinds.first);
    final keys = <IpaSymbol>[
      for (final s in all)
        if (s.kind == tab) s,
    ];
    return Semantics(
      container: true,
      label: l10n.ipaKeyboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final kind in kinds)
                ChoiceChip(
                  key: ValueKey<String>('ipa-tab-${kind.name}'),
                  label: Text(_tabName(l10n, kind)),
                  selected: kind == tab,
                  onSelected: (_) => setState(() => _tab = kind),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: IpaKeyboard.gridHeight,
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final symbol in keys)
                      _IpaKey(
                        symbol: symbol,
                        onTap: enabled ? () => _insert(symbol.symbol) : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              IconButton.outlined(
                onPressed: enabled ? _backspace : null,
                tooltip: l10n.ipaBackspace,
                constraints: BoxConstraints.tight(const Size(56, 56)),
                icon: const Icon(Icons.backspace_outlined),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Hint(
                  message: l10n.ipaSpace,
                  child: OutlinedButton(
                    onPressed: enabled ? () => _insert(' ') : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Icon(Icons.space_bar),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One symbol's key: the symbol, on a dotted circle where it is a mark that
/// goes on the letter before it. A long press shows its name.
class _IpaKey extends StatelessWidget {
  const _IpaKey({required this.symbol, required this.onTap});

  final IpaSymbol symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final name = symbol.name ?? symbol.symbol;
    final shown = symbol.combining ? '◌${symbol.symbol}' : symbol.symbol;
    return Hint(
      message: name,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: name,
        onTap: onTap,
        excludeSemantics: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: scheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              side: BorderSide(color: scheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey<String>('ipa-key-${symbol.symbol}'),
              onTap: onTap,
              child: SizedBox.square(
                dimension: IpaKeyboard.keySize,
                child: Center(
                  // A fixed key: the symbol shrinks to stay inside it at the
                  // app's largest text rather than clip.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(4),
                      child: Text(
                        shown,
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: AppSizes.maxTextScale),
                        style: theme.textTheme.titleLarge!.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
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
