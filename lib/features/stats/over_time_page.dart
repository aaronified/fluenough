import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/progress/mastery.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/pace_parts.dart';
import '../../ui/widgets/report_button.dart';
import 'progress_mastery.dart';
import 'skill_lines.dart';

/// Where the star leads (#678): two charts over the last twelve weeks, each
/// with one line per skill. "Mastery over time" is known ÷ the B1 total,
/// which ends at the star's filled shape; "Taught over time" is known ÷
/// taught, which ends at its outline, a skill with nothing taught staying at
/// 0. A line is told apart by colour, dash and marker. Below them, How you
/// learn opens that page.
///
/// Counts the language the bar shows, or every language with All on.
class OverTimePage extends StatelessWidget {
  const OverTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.progressOverTimeTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: state.progress,
          builder: (context, _) {
            final series = ProgressMastery.of(
              state,
              state.progressLanguage,
            ).overTime();
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
              children: <Widget>[
                _ChartCard(
                  title: l10n.progressMasteryChart,
                  subtitle: l10n.progressMasteryChartSub,
                  series: series,
                  value: (m) => m.fill,
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: l10n.progressTaughtChart,
                  subtitle: l10n.progressTaughtChartSub,
                  series: series,
                  // Nothing taught stays at 0.
                  value: (m) => m.outline ?? 0,
                  dashWhenUntaught: true,
                ),
                const SizedBox(height: 16),
                PaceStrip(
                  title: l10n.howYouLearnTitle,
                  onTap: () => AppNavigator.openHowYouLearn(
                    context,
                    language: state.progressLanguage,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.series,
    required this.value,
    this.dashWhenUntaught = false,
  });

  final String title;
  final String subtitle;

  /// The star's numbers each week, oldest first.
  final List<Mastery> series;
  final double Function(SkillScore) value;

  /// Whether a skill with nothing taught reads as a dash in the legend.
  final bool dashWhenUntaught;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = series.last;
    final lines = <MasterySkill, List<double>>{
      for (final skill in kStarSkills)
        skill: <double>[for (final m in series) value(m[skill])],
    };
    String current(MasterySkill skill) =>
        dashWhenUntaught && now[skill].taught == 0
        ? '–' // ui-literal-ok: a dash for "nothing taught" is not language
        : l10n.commonPercent(lines[skill]!.last);
    final values = <String>[
      for (final skill in kStarSkills)
        l10n.progressChartSkillValue(
          masterySkillLabel(l10n, skill),
          current(skill),
        ),
    ].join(l10n.commonListSeparator);

    return Container(
      padding: const EdgeInsetsDirectional.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            image: true,
            label: l10n.progressChartSemantics(title, values),
            excludeSemantics: true,
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _LinesPainter(
                  lines: lines,
                  brightness: theme.brightness,
                  grid: scheme.outlineVariant,
                  ink: scheme.onSurfaceVariant,
                  surface: scheme.surfaceContainerLow,
                  textStyle: theme.textTheme.bodySmall!,
                  textScaler: MediaQuery.textScalerOf(context),
                  weeks: <(int, String)>[
                    (0, l10n.progressWeeksAgo(series.length)),
                    (
                      (series.length - 1) ~/ 3,
                      l10n.progressWeeksAgo(
                        series.length - 1 - (series.length - 1) ~/ 3,
                      ),
                    ),
                    (
                      (series.length - 1) * 2 ~/ 3,
                      l10n.progressWeeksAgo(
                        series.length - 1 - (series.length - 1) * 2 ~/ 3,
                      ),
                    ),
                    (series.length - 1, l10n.progressNow),
                  ],
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                for (final skill in kStarSkills)
                  _LegendItem(
                    skill: skill,
                    value: current(skill),
                    brightness: theme.brightness,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.skill,
    required this.value,
    required this.brightness,
  });

  final MasterySkill skill;
  final String value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = SkillLineStyle.all[skill]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CustomPaint(
          size: const Size(26, 10),
          painter: _SamplePainter(
            style: style,
            brightness: brightness,
            surface: scheme.surfaceContainerLow,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          masterySkillLabel(l10n, skill),
          style: theme.textTheme.bodySmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall!.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SamplePainter extends CustomPainter {
  const _SamplePainter({
    required this.style,
    required this.brightness,
    required this.surface,
  });

  final SkillLineStyle style;
  final Brightness brightness;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final colour = style.colour(brightness);
    final y = size.height / 2;
    strokeDashed(
      canvas,
      Path()
        ..moveTo(1, y)
        ..lineTo(size.width - 1, y),
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
      style.dash,
    );
    paintLineMarker(
      canvas,
      Offset(size.width / 2, y),
      style.marker,
      colour,
      surface,
    );
  }

  @override
  bool shouldRepaint(_SamplePainter old) =>
      old.style != style || old.brightness != brightness;
}

class _LinesPainter extends CustomPainter {
  const _LinesPainter({
    required this.lines,
    required this.brightness,
    required this.grid,
    required this.ink,
    required this.surface,
    required this.textStyle,
    required this.textScaler,
    required this.weeks,
  });

  final Map<MasterySkill, List<double>> lines;
  final Brightness brightness;
  final Color grid;
  final Color ink;
  final Color surface;
  final TextStyle textStyle;
  final TextScaler textScaler;

  /// The time axis's labels: a point's index and its text.
  final List<(int, String)> weeks;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: textStyle.copyWith(color: ink),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final left = _text('100').width + 8;
    final bottom = _text('0').height + 8;
    const top = 8.0;
    const right = 8.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    final points = lines.values.first.length;
    double x(int i) => left + width * i / (points - 1);
    double y(double v) => top + height * (1 - v.clamp(0.0, 1.0));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in const <double>[0, 0.25, 0.5, 0.75, 1]) {
      canvas.drawLine(
        Offset(left, y(v)),
        Offset(size.width - right, y(v)),
        gridPaint,
      );
      final label = _text('${(v * 100).round()}');
      label.paint(
        canvas,
        Offset(left - 6 - label.width, y(v) - label.height / 2),
      );
    }
    for (final (i, text) in weeks) {
      final label = _text(text);
      final dx = (x(i) - label.width / 2).clamp(
        left,
        size.width - right - label.width,
      );
      label.paint(canvas, Offset(dx, size.height - label.height));
    }
    for (final skill in kStarSkills) {
      final style = SkillLineStyle.all[skill]!;
      final colour = style.colour(brightness);
      final values = lines[skill]!;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        if (i == 0) {
          path.moveTo(x(i), y(values[i]));
        } else {
          path.lineTo(x(i), y(values[i]));
        }
      }
      strokeDashed(
        canvas,
        path,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
        style.dash,
      );
      // Markers at the weeks the axis names, so each label sits under one.
      for (final i in <int>{
        0,
        (values.length - 1) ~/ 3,
        (values.length - 1) * 2 ~/ 3,
      }) {
        paintLineMarker(
          canvas,
          Offset(x(i), y(values[i])),
          style.marker,
          colour,
          surface,
        );
      }
      paintLineMarker(
        canvas,
        Offset(x(values.length - 1), y(values.last)),
        style.marker,
        colour,
        surface,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.lines != lines ||
      old.brightness != brightness ||
      old.textScaler != textScaler;
}
