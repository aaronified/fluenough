import 'package:flutter/material.dart';

import '../../core/models/deck.dart';
import '../theme.dart';

/// The typed-answer field: a label above, then a 64 px field with a 2 px
/// `primary` border and 20 px corners, text at 22 px.
///
/// Types in [language]'s direction — right to left for an Urdu deck — unless
/// [latin] is set, for transliteration, which is always left to right.
/// Autocorrect, suggestions and capitalisation are off: they would "fix" a
/// learner's answer into something they did not type.
///
/// The label and the field are one screen-reader node.
class AnswerField extends StatelessWidget {
  const AnswerField({
    super.key,
    required this.controller,
    required this.label,
    required this.language,
    this.latin = false,
    this.digits = false,
    this.focusNode,
    this.autofocus = true,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// "Type it in Hindi script", "Type what you hear"…
  final String label;

  final LanguageInfo language;

  /// Transliteration: Latin letters, left to right.
  final bool latin;

  /// A number in digits: the number keyboard, left to right.
  final bool digits;

  final FocusNode? focusNode;
  final bool autofocus;

  /// False once the answer is in.
  final bool enabled;

  final ValueChanged<String>? onChanged;

  /// Enter submits, as the design's Check does.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rtl = language.rtl && !latin && !digits;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: TextAlign.start,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            keyboardType: digits ? TextInputType.number : null,
            style: TextStyle(
              fontSize: 22,
              color: scheme.onSurface,
              height: rtl ? TargetSizes.rtlHeight : TargetSizes.ltrHeight,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              disabledBorder: border.copyWith(
                borderSide: BorderSide(color: scheme.outlineVariant, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
