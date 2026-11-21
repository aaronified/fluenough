import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import '../../core/models/card.dart';
import '../../core/review/facet_text.dart';
import '../../core/review/facets.dart';
import '../../core/review/fix_text.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'facet_labels.dart';

/// Opens the tags sheet of one facet of [card] (ADR-0058, decisions 5 and
/// 13; docs/mockups/reviewer-ux.html, frames 2a to 2c): the facet's name as
/// the title, the pointer tags that fit it with its own first, and for a
/// text facet the replacement field, prefilled with the current text.
///
/// Resolves to the answer, a flag with the tags chosen and the replacement
/// when it differs from the current text; or null when the scrim is tapped,
/// which cancels. [current] is the reviewer's earlier flag on the facet, to
/// start from. [languageName] names the keyboard the hint mentions.
Future<FacetAnswer?> showFacetTagsSheet(
  BuildContext context, {
  required Card card,
  required Facet facet,
  required String languageName,
  FacetAnswer? current,
}) => showModalBottomSheet<FacetAnswer>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FacetTagsSheet(
    card: card,
    facet: facet,
    languageName: languageName,
    current: current,
  ),
);

/// The body of [showFacetTagsSheet].
class FacetTagsSheet extends StatefulWidget {
  const FacetTagsSheet({
    super.key,
    required this.card,
    required this.facet,
    required this.languageName,
    this.current,
  });

  final Card card;
  final Facet facet;
  final String languageName;
  final FacetAnswer? current;

  /// The chip of the pointer [tag].
  static Key tagKey(PointerTag tag) => ValueKey<String>('tag-${tag.wire}');

  /// The chip of the candidate [text].
  static Key candidateKey(String text) => ValueKey<String>('candidate-$text');

  static const Key fieldKey = ValueKey<String>('tags-fix');
  static const Key pasteKey = ValueKey<String>('tags-paste');
  static const Key hintKey = ValueKey<String>('tags-keyboard-hint');
  static const Key saveKey = ValueKey<String>('tags-save');

  @override
  State<FacetTagsSheet> createState() => _FacetTagsSheetState();
}

class _FacetTagsSheetState extends State<FacetTagsSheet> {
  late final Set<PointerTag> _tags;
  late final TextEditingController _fix;

  String? get _now => facetTextOf(widget.card, widget.facet);

  @override
  void initState() {
    super.initState();
    final earlier = widget.current;
    _tags = <PointerTag>{
      if (earlier != null && earlier.isFlagged)
        ...earlier.tags
      else
        ownTagOf(widget.facet),
    };
    _fix = TextEditingController(
      text: earlier?.hasReplacement == true ? earlier!.replacement : _now,
    );
  }

  @override
  void dispose() {
    _fix.dispose();
    super.dispose();
  }

  void _toggle(PointerTag tag) => setState(() {
    if (!_tags.remove(tag)) _tags.add(tag);
  });

  void _put(String text) => setState(() {
    _fix.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.isNotEmpty && mounted) _put(text);
    } on Object {
      // A phone that gives no clipboard leaves the field as it is.
    }
  }

  void _save() {
    final text = _fix.text.trim();
    final now = _now;
    final changed =
        isTextFacet(widget.facet) &&
        text.isNotEmpty &&
        (now == null || !sameFixText(text, now));
    Navigator.of(context)
        .pop(FacetAnswer.flagged(_tags, replacement: changed ? text : null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final facet = widget.facet;
    final text = isTextFacet(facet);
    final candidates = text
        ? candidatesFor(widget.card, facet)
        : const <String>[];
    final reading = text ? readingBesideOf(widget.card, facet) : null;
    final showHint =
        (facet == Facet.word || facet == Facet.example) &&
        needsScriptKeyboard(_now ?? '');
    final multiline = facet == Facet.note || facet == Facet.example;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                facetTitle(l10n, facet),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final tag in tagsFor(facet))
                  FilterChip(
                    key: FacetTagsSheet.tagKey(tag),
                    label: Text(pointerTagLabel(l10n, tag)),
                    selected: _tags.contains(tag),
                    onSelected: (_) => _toggle(tag),
                  ),
              ],
            ),
            if (candidates.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  for (final c in candidates)
                    ChoiceChip(
                      key: FacetTagsSheet.candidateKey(c),
                      label: Text(c),
                      selected: sameFixText(_fix.text, c),
                      onSelected: (_) => _put(c),
                    ),
                ],
              ),
            ],
            if (text) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 8,
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      label: l10n.reviewTagsFix,
                      child: TextField(
                        key: FacetTagsSheet.fieldKey,
                        controller: _fix,
                        minLines: multiline ? 3 : 1,
                        maxLines: multiline ? 6 : 1,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                          ),
                          suffixIcon: IconButton(
                            key: FacetTagsSheet.pasteKey,
                            onPressed: _paste,
                            tooltip: l10n.reviewTagsPaste,
                            icon: const Icon(Icons.content_paste),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (reading != null)
                    Text(
                      reading,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
            if (showHint)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  key: FacetTagsSheet.hintKey,
                  spacing: 6,
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Text(
                        l10n.reviewTagsKeyboardHint(widget.languageName),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: FacetTagsSheet.saveKey,
              onPressed: _tags.isEmpty ? null : _save,
              child: Text(l10n.reviewTagsSave),
            ),
          ],
        ),
      ),
    );
  }
}
