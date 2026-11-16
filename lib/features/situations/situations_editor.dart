import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/situations.dart';
import '../../core/models/situation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';
import 'fitted_label.dart';
import 'situation_visuals.dart';

/// The popup behind the pencil on Today's Situations card (#1145; owner,
/// 2026-11-13: "kinda like how One UI have edit for the notification drawer
/// dropdown icons"). Two sections, mockup `docs/mockups/situations-picker`:
/// "On Today" holds at most [situationsOnCard] filled tiles in their order
/// (a long press drags one to a new place, a tap removes it) and dashed
/// empty slots for what is left; "More situations" holds the rest as muted
/// tiles a tap adds, disabled while Today is full. Done saves, per language.
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
  /// The ids on Today, in order: never more than [situationsOnCard].
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
    // A list stored with more than six keeps its first six on Today; the
    // rest wait in More situations, so nothing is lost.
    _chosen = <String>[
      for (final s in _state.pickedSituations(widget.language)) s.id,
    ].take(situationsOnCard).toList();
  }

  bool get _full => _chosen.length >= situationsOnCard;

  void _toggle(String id) {
    final on = !_chosen.contains(id);
    // Never more than six on Today.
    if (on && _full) return;
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

  String get _languageName {
    for (final info in _state.languageChoices) {
      if (info.code == widget.language) return info.name;
    }
    return widget.language;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spoken = _state.settings.spokenLanguages;
    final byId = <String, Situation>{for (final s in _all) s.id: s};
    final on = <Situation>[for (final id in _chosen) ?byId[id]];
    final more = <Situation>[
      for (final s in _all)
        if (!_chosen.contains(s.id)) s,
    ];
    return AlertDialog(
      title: Text(l10n.situationsEditTitle),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, box) {
              final width = (box.maxWidth - _gap * (_columns - 1)) / _columns;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _LanguageChip(name: _languageName),
                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: l10n.situationsEditOnToday,
                    count: _chosen.length,
                    full: _full,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l10n.situationsEditReorder,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _grid(<Widget>[
                    for (var i = 0; i < on.length; i++)
                      _onTile(l10n, on[i], i, spoken, width),
                    for (var i = on.length; i < situationsOnCard; i++)
                      const _EmptySlot(),
                  ]),
                  const SizedBox(height: 16),
                  _SectionHeader(title: l10n.situationsEditMore),
                  const SizedBox(height: 8),
                  _grid(<Widget>[
                    for (final s in more) _moreTile(l10n, s, spoken, width),
                  ]),
                ],
              );
            },
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

  static const double _gap = 8;
  static const int _columns = 3;

  /// [cells] in rows of three, every cell as tall as the tallest of its row,
  /// so that an empty slot is the size of a filled tile.
  Widget _grid(List<Widget> cells) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (var start = 0; start < cells.length; start += _columns) ...<Widget>[
        if (start > 0) const SizedBox(height: _gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: <Widget>[
              for (var i = start; i < start + _columns; i++)
                Expanded(
                  child: i < cells.length ? cells[i] : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    ],
  );

  /// A tile on Today: a tap removes it, a long press drags it.
  Widget _onTile(
    AppLocalizations l10n,
    Situation s,
    int index,
    List<String> spoken,
    double width,
  ) {
    final title = s.titleFor(spoken);
    final face = _TileFace(
      situation: s,
      title: title,
      width: width,
      on: true,
      onTap: () => _toggle(s.id),
    );
    final semantic = Semantics(
      button: true,
      selected: true,
      label: l10n.situationsEditShown(title, index + 1),
      excludeSemantics: true,
      onTap: () => _toggle(s.id),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (index > 0)
          CustomSemanticsAction(label: l10n.situationsEditEarlier): () =>
              _shift(s.id, -1),
        if (index < _chosen.length - 1)
          CustomSemanticsAction(label: l10n.situationsEditLater): () =>
              _shift(s.id, 1),
      },
      child: face,
    );
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data != s.id && _chosen.contains(details.data),
      onAcceptWithDetails: (details) => _moveTo(details.data, s.id),
      builder: (context, candidates, _) => LongPressDraggable<String>(
        data: s.id,
        feedback: SizedBox(
          width: width,
          child: Material(
            color: Colors.transparent,
            // The overlay gives no height: the tile takes its own.
            child: IntrinsicHeight(
              child: _TileFace(
                situation: s,
                title: title,
                width: width,
                on: true,
                onTap: null,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: kIncomingOpacity, child: face),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: candidates.isEmpty
                ? null
                : Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: semantic,
        ),
      ),
    );
  }

  /// A tile under More situations: a tap adds it, unless Today is full, when
  /// it is disabled (no visible help; the screen reader is told).
  Widget _moreTile(
    AppLocalizations l10n,
    Situation s,
    List<String> spoken,
    double width,
  ) {
    final title = s.titleFor(spoken);
    final enabled = !_full;
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? l10n.situationsEditHidden(title)
          : l10n.situationsEditFull(title),
      excludeSemantics: true,
      onTap: enabled ? () => _toggle(s.id) : null,
      child: _TileFace(
        situation: s,
        title: title,
        width: width,
        on: false,
        onTap: enabled ? () => _toggle(s.id) : null,
      ),
    );
  }
}

/// The learner's language the situations belong to (they are per language).
class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.translate, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's title, and for On Today the counter ("4 of 6"), which turns
/// solid at six.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.full = false});

  final String title;
  final int? count;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = count;
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (n != null)
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: full ? scheme.primary : scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(
                l10n.situationsEditCount(n, situationsOnCard),
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: full ? scheme.onPrimary : scheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A free place on Today: a dashed outline as big as a filled tile.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.textScalerOf(
            context,
          ).scale(situationTileMinHeight),
        ),
        child: CustomPaint(
          painter: _DashedBorder(color: scheme.outline),
          child: Center(
            child: Icon(
              Icons.add,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - 2 * inset,
            size.height - 2 * inset,
          ),
          const Radius.circular(AppRadii.chip),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 10) {
        canvas.drawPath(metric.extractPath(at, at + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// One tile. On Today ([on]) it is filled in the situation's colours with an
/// x; under More it is muted: the surface, a thin outline, the icon alone in
/// the situation's colour and a + (mockup `situations-picker`). The icon sits
/// at the top; the name is centred in the space below it.
class _TileFace extends StatelessWidget {
  const _TileFace({
    required this.situation,
    required this.title,
    required this.width,
    required this.on,
    required this.onTap,
  });

  final Situation situation;
  final String title;
  final double width;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = situation.icon.situationColor(context);
    final disabled = !on && onTap == null;
    final Color ink = on
        ? colors.onContainer
        : disabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    final iconColor = on
        ? colors.onContainer
        : disabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
        : situation.icon.situationAccent(context);
    final radius = BorderRadius.circular(AppRadii.chip);
    return Material(
      color: on ? colors.container : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: on ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
      ),
      // The surface under a muted tile, so that it reads as a plain tile.
      child: Ink(
        decoration: BoxDecoration(
          color: on || disabled ? null : scheme.surface,
          borderRadius: radius,
        ),
        // hint-ok: shows text
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(
                context,
              ).scale(situationTileMinHeight),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 12, bottom: 8),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: on
                              ? colors.onContainer.withValues(alpha: 0.12)
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          situation.icon.situationIcon,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Center(
                          child: FittedLabel(
                            text: title,
                            width: width,
                            color: ink,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!disabled)
                  PositionedDirectional(
                    top: 3,
                    end: 3,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on
                            ? colors.onContainer.withValues(alpha: 0.16)
                            : null,
                        border: on ? null : Border.all(color: scheme.outline),
                      ),
                      child: Icon(
                        on ? Icons.close : Icons.add,
                        size: 16,
                        color: on
                            ? colors.onContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
