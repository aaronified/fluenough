import 'package:flutter/material.dart';

import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'mode_pill.dart';
import 'wave_progress.dart';

/// The layout every drill shares, from the design's drill screen:
///
/// 1. A 64 px header: close button, the progress wave, "3/8".
/// 2. A scrolling body: the skill's pill and the deck's name, then the
///    [card] — a 40 px-cornered `surfaceContainerHigh` panel at least 300 px
///    tall that grows to fill the space — then [belowCard], where the answer
///    field and keyboard hint go.
/// 3. A fixed foot: [feedback] above [actions].
///
/// Recognition, production and listening (B1) and grammar and minimal pairs
/// (B4) each fill the slots; nothing here knows about a mode's rules.
///
/// The card's content is centred and should be a list of widgets; the frame
/// spaces them 12 apart. Do not put a `LayoutBuilder` in [card] or
/// [belowCard]: the body measures their intrinsic height to let the card fill
/// the screen.
class DrillFrame extends StatelessWidget {
  const DrillFrame({
    super.key,
    required this.skill,
    required this.deckName,
    required this.position,
    required this.total,
    required this.onClose,
    required this.card,
    this.progress,
    this.belowCard,
    this.feedback,
    this.actions = const <Widget>[],
  });

  final Skill skill;

  /// The deck's name, from the deck file.
  final String deckName;

  /// The current card, 1-based, and how many the session has.
  final int position;
  final int total;

  /// How far through the session the wave shows, 0–1. Defaults to the cards
  /// finished, `(position - 1) / total`; the design adds half a card once the
  /// current one is answered.
  final double? progress;

  final VoidCallback onClose;

  /// What goes on the card, top to bottom.
  final List<Widget> card;

  /// Under the card: the answer field, the input choice, the keyboard hint.
  final List<Widget>? belowCard;

  /// A `FeedbackBanner`, once the answer is in.
  final Widget? feedback;

  /// The buttons at the foot, stacked 10 apart: "Show answer", the rating
  /// row, "Don't know" and "Check", "Continue".
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = total == 0 ? 0.0 : (position - 1) / total;
    final below = belowCard;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 16, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: onClose,
                      tooltip: l10n.drillEndSession,
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: WaveProgress(
                        value: progress ?? done,
                        semanticsLabel: l10n.drillProgressLabel,
                        semanticsValue: l10n.drillPosition(position, total),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Text(
                        l10n.drillPositionShort(position, total),
                        style: theme.textTheme.labelLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      4,
                      16,
                      16,
                    ),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              // Flexible, so that a long skill name in a
                              // large text scale wraps inside the pill
                              // rather than pushing the row off the screen.
                              Flexible(child: ModePill(skill: skill)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  deckName,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: DrillCard(children: card)),
                          if (below != null)
                            for (final widget in below) ...<Widget>[
                              const SizedBox(height: 16),
                              widget,
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (feedback != null) ...<Widget>[
                    feedback!,
                    if (actions.isNotEmpty) const SizedBox(height: 10),
                  ],
                  for (var i = 0; i < actions.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 10),
                    actions[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The drill's card: at least 300 tall, 40 px corners, `surfaceContainerHigh`,
/// its children centred and 12 apart. [DrillFrame] puts one in; use it on its
/// own only in a preview.
class DrillCard extends StatelessWidget {
  const DrillCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 300),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.drillCard),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 28,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}
