import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/situations.dart';
import '../../core/models/situation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'situation_visuals.dart';

/// The popup behind the pencil on Today's Situations card (#1145; owner,
/// 2026-11-13: "kinda like how One UI have edit for the notification drawer
/// dropdown icons"). One grid of tiles, every situation of [language] with
/// the icon and colour it has on the card. The chosen ones come first, in
/// order, with their place on them; the rest are faded. A tap adds or
/// removes a tile, a long press drags a chosen tile to a new place. Today
/// shows the first [situationsOnCard] chosen. Done saves, per language.
Future<void> showSituationsEditor(BuildContext context, String language) =>
    showDialog<void>(
      context: context,
      builder: (context) => SituationsEditor(language: language),
    );

class SituationsEditor extends StatefulWidget {
  const SituationsEditor({super.key, required this.language});

  final String language;

  @override
  State<SituationsEditor> createState() => _SituationsEditorState();
}

class _SituationsEditorState extends State<SituationsEditor> {
  /// The ids chosen, in order.
  late List<String> _chosen;

  AppState get _state => AppScope.read(context);

  List<Situation> get _all =>
      _state.situationsOf(widget.language)?.situations ?? const <Situation>[];

  List<String> get _defaults => <String>[
    for (final s in _all.take(situationsOnCard)) s.id,
  ];

  @override
  void initState() {
    super.initState();
    _chosen = <String>[
      for (final s in _state.pickedSituations(widget.language)) s.id,
    ];
  }

  void _toggle(String id) {
    final on = !_chosen.contains(id);
    _state.haptics.toggle(on);
    setState(() => on ? _chosen.add(id) : _chosen.remove(id));
  }

  /// Moves [id] to the place of [before] in the chosen order.
  void _moveTo(String id, String before) {
    final to = _chosen.indexOf(before);
    if (id == before || to < 0 || !_chosen.remove(id)) return;
    setState(() => _chosen.insert(to, id));
  }

  void _shift(String id, int by) {
    final from = _chosen.indexOf(id);
    final to = from + by;
    if (from < 0 || to < 0 || to >= _chosen.length) return;
    setState(() => _chosen.insert(to, _chosen.removeAt(from)));
  }

  void _save() {
    // The default is stored as no choice, so that it follows the deck.
    _state.settings.setSituationsShown(
      widget.language,
      listEquals(_chosen, _defaults) ? null : _chosen,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spoken = _state.settings.spokenLanguages;
    final byId = <String, Situation>{for (final s in _all) s.id: s};
    final tiles = <Situation>[
      for (final id in _chosen)
        if (byId[id] case final s?) s,
      for (final s in _all)
        if (!_chosen.contains(s.id)) s,
    ];
    return AlertDialog(
      title: Text(l10n.situationsEditTitle),
      insetPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.situationsEditHelp(situationsOnCard),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 8.0;
                  const columns = 3;
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final s in tiles)
                        SizedBox(width: width, child: _tile(l10n, s, spoken)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => setState(() => _chosen = _defaults),
          child: Text(l10n.situationsEditReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          // At least one, or the card would be empty.
          onPressed: _chosen.isEmpty ? null : _save,
          child: Text(l10n.commonDone),
        ),
      ],
    );
  }

  Widget _tile(AppLocalizations l10n, Situation s, List<String> spoken) {
    final index = _chosen.indexOf(s.id);
    final on = index >= 0;
    final title = s.titleFor(spoken);
    final face = _TileFace(
      situation: s,
      title: title,
      position: on ? index + 1 : null,
      onTap: () => _toggle(s.id),
    );
    final semantic = Semantics(
      button: true,
      selected: on,
      label: on
          ? l10n.situationsEditShown(title, index + 1)
          : l10n.situationsEditHidden(title),
      excludeSemantics: true,
      onTap: () => _toggle(s.id),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (on && index > 0)
          CustomSemanticsAction(label: l10n.situationsEditEarlier): () =>
              _shift(s.id, -1),
        if (on && index < _chosen.length - 1)
          CustomSemanticsAction(label: l10n.situationsEditLater): () =>
              _shift(s.id, 1),
      },
      child: face,
    );
    if (!on) return Opacity(opacity: kFadedTile, child: semantic);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != s.id,
      onAcceptWithDetails: (details) => _moveTo(details.data, s.id),
      builder: (context, candidates, _) => LongPressDraggable<String>(
        data: s.id,
        feedback: SizedBox(
          width: 96,
          child: Material(
            color: Colors.transparent,
            child: _TileFace(
              situation: s,
              title: title,
              position: index + 1,
              onTap: null,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: kFadedTile, child: face),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: candidates.isEmpty
                ? null
                : Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: semantic,
        ),
      ),
    );
  }
}

/// How faded a tile that is not chosen is drawn.
const double kFadedTile = 0.38;

/// One tile: the situation's icon and name in its colours, and while it is
/// chosen its place in the order.
class _TileFace extends StatelessWidget {
  const _TileFace({
    required this.situation,
    required this.title,
    required this.position,
    required this.onTap,
  });

  final Situation situation;
  final String title;
  final int? position;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = situation.icon.situationColor(context);
    return Material(
      color: colors.container,
      borderRadius: BorderRadius.circular(AppRadii.field),
      // hint-ok: shows text
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.field),
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 6,
                vertical: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.onContainer.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      situation.icon.situationIcon,
                      color: colors.onContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (position case final place?)
              PositionedDirectional(
                top: 4,
                start: 6,
                child: Text(
                  '$place',
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: place <= situationsOnCard
                        ? colors.onContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
