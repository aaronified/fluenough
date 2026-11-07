import 'package:flutter/material.dart';

import '../../app/language_data_deletion.dart';
import '../../l10n/app_localizations.dart';

/// What the dialog gives back: the ticks, with the decks, which the sheet
/// removes itself.
typedef DeleteLanguageDataChoice = ({LanguageDataChoice data, bool decks});

/// The dialog of the red bin on a language's sheet (#861; mockup
/// `docs/mockups/languages-learning.html`): what will go, one tick for each,
/// the reviews with an optional range of days, and the language's name to be
/// typed before Delete is enabled. Gives null when cancelled.
Future<DeleteLanguageDataChoice?> showDeleteLanguageDataDialog(
  BuildContext context, {
  required String name,
  required DateTime today,
}) => showDialog<DeleteLanguageDataChoice>(
  context: context,
  builder: (_) => DeleteLanguageDataDialog(name: name, today: today),
);

class DeleteLanguageDataDialog extends StatefulWidget {
  const DeleteLanguageDataDialog({
    required this.name,
    required this.today,
    super.key,
  });

  /// The language's name, which must be typed exactly.
  final String name;

  /// Today, the last day a range can reach and where it starts.
  final DateTime today;

  @override
  State<DeleteLanguageDataDialog> createState() =>
      _DeleteLanguageDataDialogState();
}

class _DeleteLanguageDataDialogState extends State<DeleteLanguageDataDialog> {
  final TextEditingController _typed = TextEditingController();
  bool _reviews = false;
  bool _someDates = false;
  bool _placement = false;
  bool _settings = false;
  bool _decks = false;
  late DateTime _from = _day(widget.today);
  late DateTime _to = _day(widget.today);

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _rangeOk => !_reviews || !_someDates || !_from.isAfter(_to);

  bool get _anything => _reviews || _placement || _settings || _decks;

  bool get _canDelete => _typed.text == widget.name && _anything && _rangeOk;

  Future<void> _pick({required bool first}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: _day(widget.today),
    );
    if (picked == null || !mounted) return;
    setState(() => first ? _from = picked : _to = picked);
  }

  void _delete() => Navigator.of(context).pop((
    data: LanguageDataChoice(
      reviews: _reviews,
      from: _reviews && _someDates ? _from : null,
      to: _reviews && _someDates ? _to : null,
      placement: _placement,
      settings: _settings,
    ),
    decks: _decks,
  ));

  Widget _tick({
    required Key key,
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) => CheckboxListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    onChanged: (v) => setState(() => onChanged(v ?? false)),
    title: Text(title),
    subtitle: Text(subtitle),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    final name = widget.name;
    return AlertDialog(
      title: Text(l10n.languagesDeleteTitle(name)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.languagesDeleteBody),
          const SizedBox(height: 8),
          _tick(
            key: const ValueKey<String>('delete-reviews'),
            value: _reviews,
            title: l10n.languagesDeleteReviews,
            subtitle: l10n.languagesDeleteReviewsSub(name),
            onChanged: (v) => _reviews = v,
          ),
          if (_reviews)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 40, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      ChoiceChip(
                        key: const ValueKey<String>('delete-all-dates'),
                        label: Text(l10n.languagesDeleteAllDates),
                        selected: !_someDates,
                        onSelected: (_) => setState(() => _someDates = false),
                      ),
                      ChoiceChip(
                        key: const ValueKey<String>('delete-some-dates'),
                        label: Text(l10n.languagesDeleteSomeDates),
                        selected: _someDates,
                        onSelected: (_) => setState(() => _someDates = true),
                      ),
                    ],
                  ),
                  if (_someDates)
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        Semantics(
                          label: l10n.languagesDeleteFromLabel(
                            material.formatMediumDate(_from),
                          ),
                          excludeSemantics: true,
                          button: true,
                          child: TextButton(
                            key: const ValueKey<String>('delete-from'),
                            onPressed: () => _pick(first: true),
                            child: Text(
                              l10n.languagesDeleteFrom(
                                material.formatMediumDate(_from),
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          label: l10n.languagesDeleteToLabel(
                            material.formatMediumDate(_to),
                          ),
                          excludeSemantics: true,
                          button: true,
                          child: TextButton(
                            key: const ValueKey<String>('delete-to'),
                            onPressed: () => _pick(first: false),
                            child: Text(
                              l10n.languagesDeleteTo(
                                material.formatMediumDate(_to),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!_rangeOk)
                    Text(
                      l10n.languagesDeleteRangeOrder,
                      key: const ValueKey<String>('delete-range-order'),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: scheme.error,
                      ),
                    ),
                ],
              ),
            ),
          _tick(
            key: const ValueKey<String>('delete-placement'),
            value: _placement,
            title: l10n.languagesDeletePlacement,
            subtitle: l10n.languagesDeletePlacementSub(name),
            onChanged: (v) => _placement = v,
          ),
          _tick(
            key: const ValueKey<String>('delete-settings'),
            value: _settings,
            title: l10n.languagesDeleteSettings,
            subtitle: l10n.languagesDeleteSettingsSub(name),
            onChanged: (v) => _settings = v,
          ),
          _tick(
            key: const ValueKey<String>('delete-decks'),
            value: _decks,
            title: l10n.languagesDeleteDecks,
            subtitle: l10n.languagesDeleteDecksSub(name),
            onChanged: (v) => _decks = v,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.languagesDeleteBackupNote,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('delete-name'),
            controller: _typed,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.languagesDeleteType(name),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const ValueKey<String>('delete-confirm'),
          onPressed: _canDelete ? _delete : null,
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
