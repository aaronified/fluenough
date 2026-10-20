import 'package:flutter/material.dart';

import '../../core/models/braille.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// The app's own braille keyboard, under a typed answer in a braille course
/// (owner, 2026-10-20: "Braille will need a keyboard too"; ADR-0043).
///
/// Six dots in the Perkins layout, as the cell has them and as a Perkins
/// brailler and Android's TalkBack braille keyboard put them: 1, 2 and 3
/// down the left, 4, 5 and 6 down the right. A tap raises a dot or lowers
/// it; the cell they make shows between the two columns; "Enter cell" adds
/// it to [controller] at the cursor, as its Unicode braille character, and
/// lowers the dots. Space adds a space, and the backspace key deletes what
/// is before the cursor. Each change is passed to [onChanged].
///
/// A raised dot is filled and a lowered one hollow, so its state is never
/// told by colour alone; a screen reader hears "Dot 1" and whether it is
/// on. Every key is at least 56 logical pixels square.
class BrailleKeyboard extends StatefulWidget {
  const BrailleKeyboard({
    super.key,
    required this.controller,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// False once the answer is in.
  final bool enabled;

  /// The size of a dot's key.
  static const double dotSize = 64;

  @override
  State<BrailleKeyboard> createState() => _BrailleKeyboardState();
}

class _BrailleKeyboardState extends State<BrailleKeyboard> {
  /// The dots raised, 1 to 6.
  final Set<int> _dots = <int>{};

  void _toggle(int dot) => setState(() {
    if (!_dots.remove(dot)) _dots.add(dot);
  });

  void _enterCell() {
    if (_dots.isEmpty) return;
    final cell = brailleCell(_dots);
    setState(_dots.clear);
    _replace(cell);
  }

  /// Puts [text] in place of the selection, or at the cursor; at the end
  /// where the field has no cursor yet.
  void _replace(String text) {
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

  void _backspace() {
    final value = widget.controller.value;
    final selection = value.selection;
    if (value.text.isEmpty) return;
    var start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    if (start == end) {
      if (start == 0) return;
      // Every braille cell, and a space, is one UTF-16 code unit.
      start--;
    }
    final next = value.text.replaceRange(start, end, '');
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start),
    );
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.enabled;
    final dots = (_dots.toList()..sort());
    Widget column(List<int> numbers) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (i, dot) in numbers.indexed) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          _DotKey(
            dot: dot,
            raised: _dots.contains(dot),
            onTap: enabled ? () => _toggle(dot) : null,
          ),
        ],
      ],
    );
    const keySize = Size(56, 56);
    return Semantics(
      container: true,
      label: l10n.brailleKeyboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              column(const <int>[1, 2, 3]),
              const SizedBox(width: 16),
              // The cell the raised dots make, as it will be entered.
              Semantics(
                liveRegion: true,
                label: dots.isEmpty
                    ? l10n.brailleCellEmpty
                    : l10n.brailleCellDots(dots.join('-')),
                child: ExcludeSemantics(
                  child: Container(
                    width: 88,
                    height: BrailleKeyboard.dotSize * 3 + 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      brailleCell(_dots),
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 56,
                        height: 1,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              column(const <int>[4, 5, 6]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              IconButton.outlined(
                onPressed: enabled ? _backspace : null,
                tooltip: l10n.brailleBackspace,
                constraints: BoxConstraints.tight(keySize),
                icon: const Icon(Icons.backspace_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: enabled ? () => _replace(' ') : null,
                tooltip: l10n.brailleSpace,
                constraints: BoxConstraints.tight(keySize),
                icon: const Icon(Icons.space_bar),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: enabled && _dots.isNotEmpty ? _enterCell : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 56),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12,
                    ),
                  ),
                  child: Text(
                    l10n.brailleEnterCell,
                    textAlign: TextAlign.center,
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

/// One dot's key: its number in a circle, filled while it is raised and
/// hollow while it is not.
class _DotKey extends StatelessWidget {
  const _DotKey({required this.dot, required this.raised, this.onTap});

  final int dot;
  final bool raised;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fill = raised ? scheme.primary : scheme.surfaceContainerLowest;
    final ink = raised ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      toggled: raised,
      enabled: enabled,
      label: l10n.brailleDot(dot),
      // The number drawn in the key is the label already; the tap is kept.
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: fill,
          shape: CircleBorder(
            side: BorderSide(
              color: raised ? scheme.primary : scheme.outline,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('braille-dot-$dot'),
            onTap: onTap,
            child: SizedBox.square(
              dimension: BrailleKeyboard.dotSize,
              child: Center(
                child: Text(
                  '$dot',
                  // The key is a fixed size: its number stays within it at
                  // the app's largest text, 1.4x.
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: AppSizes.maxTextScale),
                  style: Theme.of(context).textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
