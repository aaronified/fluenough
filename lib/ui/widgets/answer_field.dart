import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/decks/script_fonts.dart';
import '../../core/models/deck.dart';
import '../card_text_scale.dart';
import '../theme.dart';
import 'braille_keyboard.dart';

/// The typed-answer field: a label above, then a 64 px field with a 2 px
/// `primary` border and 20 px corners, text at 22 px. Text in [language]'s
/// script is drawn at that times the learner's card text size, as the card's
/// own target text is; transliteration and digits stay at 22.
///
/// Types in [language]'s direction — right to left for an Urdu deck — unless
/// [latin] is set, for transliteration, which is always left to right.
/// Autocorrect, suggestions and capitalisation are off: they would "fix" a
/// learner's answer into something they did not type.
///
/// The label and the field are one screen-reader node.
///
/// A language the phone has no keyboard for names the app's own
/// ([LanguageInfo.keyboard]): braille's six dots (ADR-0043). It is drawn
/// under the field in place of the phone's, which the field then never
/// opens. Transliteration and digits keep the phone's.
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
    final settings = AppScope.of(context).settings;
    final script = !latin && !digits;
    final rtl = language.rightToLeft && script;
    final keyboard = script ? language.keyboard : null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.field),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );
    final field = MergeSemantics(
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
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => TextField(
              controller: controller,
              focusNode: focusNode,
              // Owner, 2026-10-20: "Make sure that the fields which need
              // the keyboard will not trigger the normal keyboard." Not
              // focused of itself, read-only and with no input type, the
              // field never asks the phone for its keyboard: not on focus,
              // nor on a tap, nor on the next card.
              autofocus: autofocus && keyboard == null,
              enabled: enabled,
              // The app's own keyboard types into it: the phone's stays shut.
              readOnly: keyboard != null,
              showCursor: keyboard != null ? true : null,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.start,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              keyboardType: keyboard != null
                  ? TextInputType.none
                  : digits
                  ? TextInputType.number
                  : null,
              style: TextStyle(
                // Braille cells are drawn with their shadow dots (#835).
                fontFamily: keyboard == ScriptKeyboard.braille
                    ? brailleFontFamily
                    : null,
                fontSize: script ? 22 * cardTextScaleOf(context, settings) : 22,
                color: scheme.onSurface,
                height: rtl ? TargetSizes.rtlHeight : TargetSizes.ltrHeight,
                leadingDistribution: rtl ? TextLeadingDistribution.even : null,
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
                  borderSide: BorderSide(
                    color: scheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return switch (keyboard) {
      null => field,
      ScriptKeyboard.braille => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          field,
          const SizedBox(height: 16),
          BrailleKeyboard(
            controller: controller,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ],
      ),
    };
  }
}
