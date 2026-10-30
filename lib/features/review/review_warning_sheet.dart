import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/review/card_fields.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';

/// What the reviewer picked in the warning picker: the id `warning` will
/// hold, and why.
typedef WarningChoice = ({String id, String why});

/// The name of the warning [option] gives the teach card: its note's kind,
/// "Other meanings" or "No warning".
String warningName(AppLocalizations l10n, WarningOption option) =>
    switch (option.kind) {
      NoteKind.pair => l10n.reviewWarningPair,
      NoteKind.homograph => l10n.reviewWarningHomograph,
      NoteKind.lookalike => l10n.reviewWarningLookalike,
      _ when option.id == WarningOption.senses => l10n.reviewWarningSenses,
      _ => l10n.reviewWarningNone,
    };

/// The icon of the warning [option].
IconData warningIcon(WarningOption option) => switch (option.kind) {
  NoteKind.pair => Icons.hearing,
  NoteKind.homograph => Icons.compare_arrows,
  NoteKind.lookalike => Icons.hearing_disabled,
  _ when option.id == WarningOption.senses => Icons.translate,
  _ => Icons.block,
};

/// Opens "Teach-card warning" (#508, #691): the warnings [card] has and
/// nothing else, to pick one from. Resolves to the pick with its why, or
/// null when the sheet is closed without one.
Future<WarningChoice?> showWarningSheet(
  BuildContext context, {
  required Card card,
  required LanguageInfo language,
  required String? current,
  String why = '',
}) => showModalBottomSheet<WarningChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      WarningSheet(card: card, language: language, current: current, why: why),
);

/// The body of [showWarningSheet]: the rule, a radio row for each warning
/// the card has, a Why field, and a tick that saves once something changed.
///
/// There is no Automatic row: it would take the `warning` back off the
/// card, and the review bot never removes one (owner, 2026-10-30, #508).
/// "Other meanings" is shown but cannot be picked on a card with none.
class WarningSheet extends StatefulWidget {
  const WarningSheet({
    super.key,
    required this.card,
    required this.language,
    required this.current,
    this.why = '',
  });

  final Card card;
  final LanguageInfo language;

  /// The warning chosen now: the card's, or the reviewer's own pick.
  final String? current;
  final String why;

  /// The row of the warning [id].
  static Key rowKey(String id) => ValueKey<String>('warning-$id');

  /// The Why field.
  static const Key whyKey = ValueKey<String>('warning-why');

  @override
  State<WarningSheet> createState() => _WarningSheetState();
}

class _WarningSheetState extends State<WarningSheet> {
  late String? _picked = widget.current;
  late final TextEditingController _why = TextEditingController(
    text: widget.why,
  );

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  bool get _changed =>
      _picked != null &&
      (_picked != widget.current || _why.text.trim() != widget.why.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = warningOptionsOf(widget.card);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: l10n.reviewSuggestDiscard,
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.reviewPartWarning,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _changed
                          ? () =>
                                Navigator.of(context)
                                    .pop((id: _picked!, why: _why.text.trim()))
                          : null,
                      tooltip: l10n.reviewSuggestSaveAll,
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                child: Text.rich(
                  quotingTarget(
                    widget.card.reading == null
                        ? l10n.reviewCardAboutNoReading(
                            widget.card.target,
                            widget.card.native,
                            widget.card.id,
                          )
                        : l10n.reviewCardAbout(
                            widget.card.target,
                            widget.card.reading!,
                            widget.card.native,
                            widget.card.id,
                          ),
                    <String>[widget.card.target],
                    widget.language,
                  ),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Text(
                            l10n.reviewWarningRule,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              RadioGroup<String>(
                groupValue: _picked,
                onChanged: (id) => setState(() => _picked = id),
                child: Column(
                  children: <Widget>[
                    for (final option in options)
                      RadioListTile<String>(
                        key: WarningSheet.rowKey(option.id),
                        value: option.id,
                        enabled: option.enabled,
                        secondary: Icon(warningIcon(option)),
                        title: Text(warningName(l10n, option)),
                        subtitle: Text(_sub(l10n, option)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
                child: TextField(
                  key: WarningSheet.whyKey,
                  controller: _why,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.reviewSuggestWhy,
                    border: AppRadii.fieldBorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What a row says under its name: the note, the other meanings, or what
  /// the choice does.
  String _sub(AppLocalizations l10n, WarningOption option) {
    if (option.id == WarningOption.none) return l10n.reviewWarningNoneSub;
    if (option.id == WarningOption.senses && !option.enabled) {
      return l10n.reviewWarningNoSenses;
    }
    return option.text;
  }
}
