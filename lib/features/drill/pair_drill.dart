import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/play_button.dart';
import '../../ui/widgets/target_text.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'pair_fixture.dart';

/// The minimal-pairs drill: hear one of two similar sounds and pick which,
/// then see whether it was right, what was heard, and the pair's contrast.
///
/// Design screen `drill-pair`. Built on fixture data shaped as #31 specifies,
/// `{a, b, contrast}` (see [MinimalPair]), and disabled until #31 gives it an
/// ADR, deck data and a device check. Nothing in a live session builds it:
/// there is no pair `DrillMode`. Behind `Feature.drillPair`: while incoming,
/// play and the two choices are disabled and marked.
///
/// The sound goes through `AppState.speak`, at the learner's rate. Choices
/// are not recorded, as there is no card to record them against.
class PairDrill extends StatefulWidget {
  const PairDrill({
    super.key,
    this.rounds = pairFixtureRounds,
    this.language = pairFixtureLanguage,
    this.deckName = pairFixtureDeckName,
    this.picked,
  });

  final List<PairRound> rounds;
  final LanguageInfo language;
  final String deckName;

  /// Already chosen on the first round, `a` or `b`: a gallery preset.
  final PairSide? picked;

  @override
  State<PairDrill> createState() => _PairDrillState();
}

/// Which of a pair's two sounds.
enum PairSide { a, b }

class _PairDrillState extends State<PairDrill> {
  int _index = 0;
  late PairSide? _picked = widget.picked;
  bool _playing = false;

  PairRound get _round => widget.rounds[_index];

  Future<void> _play() async {
    setState(() => _playing = true);
    try {
      await AppScope.read(context).speak(_round.heard.target, widget.language);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _next() {
    if (_index + 1 >= widget.rounds.length) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _index++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final incoming = isIncoming(context, Feature.drillPair);
    final round = _round;
    final heard = round.heard;
    final picked = _picked;
    final heardSide = round.playsB ? PairSide.b : PairSide.a;
    final right = picked == heardSide;

    final choices = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final side in PairSide.values) ...<Widget>[
          if (side == PairSide.b) const SizedBox(width: 12),
          Expanded(
            child: _PairOption(
              sound: side == PairSide.a ? round.pair.a : round.pair.b,
              language: widget.language,
              heard: picked != null && side == heardSide,
              missed: picked == side && !right,
              onPressed: picked != null || incoming
                  ? null
                  : () => setState(() => _picked = side),
            ),
          ),
        ],
      ],
    );

    return DrillFrame(
      skill: Skill.pair,
      deckName: widget.deckName,
      position: _index + 1,
      total: widget.rounds.length,
      progress: (_index + (picked == null ? 0 : 0.5)) / widget.rounds.length,
      onClose: () => Navigator.maybePop(context),
      card: <Widget>[
        Text(
          l10n.drillPairQuestion,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium!.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        PlayButton(
          size: 104,
          playing: _playing,
          onPressed: incoming ? null : _play,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: incoming
              ? IncomingFeature(
                  feature: Feature.drillPair,
                  label: l10n.skillPair,
                  badge: IncomingBadgePlacement.below,
                  child: choices,
                )
              : choices,
        ),
        if (picked != null)
          // The design's 300 wide on a phone's 318 card. Padding, not a
          // max-width box, which would misreport the intrinsic height the
          // frame measures.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 9),
            child: TargetText(
              round.pair.contrast,
              language: widget.language,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
      feedback: picked == null
          ? null
          : FeedbackBanner(
              kind: right ? FeedbackKind.correct : FeedbackKind.wrong,
              title: right
                  ? l10n.feedbackPairCorrect(heard.reading)
                  : l10n.feedbackPairWrong(heard.reading),
              detail: l10n.feedbackPairHeard(heard.target),
            ),
      actions: picked == null
          ? const <Widget>[]
          : <Widget>[
              FilledButton(
                onPressed: _next,
                style: AppButtonStyles.tall(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text(l10n.commonContinue)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, size: 22),
                  ],
                ),
              ),
            ],
    );
  }
}

/// One of the two choices: the glyph over its reading, 128 tall with 28 px
/// corners. Once chosen, the sound that was played turns `primaryContainer`
/// and a wrong pick turns `errorContainer`; the banner says the same in
/// words, so the colour never stands alone.
class _PairOption extends StatelessWidget {
  const _PairOption({
    required this.sound,
    required this.language,
    required this.heard,
    required this.missed,
    required this.onPressed,
  });

  final PairSound sound;
  final LanguageInfo language;

  /// This is the sound that was played, shown after choosing.
  final bool heard;

  /// This was picked, and it was not the sound played.
  final bool missed;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg, Color border) = heard
        ? (scheme.primaryContainer, scheme.onPrimaryContainer, scheme.primary)
        : missed
        ? (scheme.errorContainer, scheme.onErrorContainer, scheme.error)
        : (
            scheme.surfaceContainerLowest,
            scheme.onSurface,
            scheme.outlineVariant,
          );
    return OutlinedButton(
      onPressed: onPressed,
      // The same colours enabled or not: after choosing, the buttons are
      // disabled but still show the answer.
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStatePropertyAll(fg),
        side: WidgetStatePropertyAll(BorderSide(color: border, width: 2)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.group)),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 128)),
        padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.all(8)),
      ),
      child: Semantics(
        label: l10n.drillPairOption(sound.target, sound.reading),
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TargetText(
              sound.target,
              language: language,
              fontSize: 48,
              color: fg,
            ),
            const SizedBox(height: 4),
            Text(
              sound.reading,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium!.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gallery runs the drill with its feature switched on, so it shows what
/// the incoming drill will do.
const FeatureRegistry _pairOn = FeatureRegistry.only(<Feature>{
  ...Feature.available,
  Feature.drillPair,
});

AppState _pairState(AppState app) =>
    GalleryFixtures.state(app, features: _pairOn);

/// B4's gallery entries for minimal pairs. `drill/gallery_entries.dart`
/// already includes them. The design's state: asking, before a choice.
final List<GalleryEntry> pairGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-pair',
    section: GallerySection.drills,
    label: 'Minimal pairs', // ui-literal-ok: debug-only gallery
    note: 'Aspirated or not', // ui-literal-ok: debug-only gallery
    builder: (_) => const PairDrill(),
    state: _pairState,
  ),
];

/// More pair states than the design's Gallery lists. `test/gallery_test`
/// allows only the design's ids, so these are exported for B4's tests, and
/// for Phase 2 to splice into the gallery.
final List<GalleryEntry> pairGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-pair-right',
    section: GallerySection.drills,
    label: 'Minimal pairs, right', // ui-literal-ok: debug-only gallery
    note: 'Correct, with the contrast', // ui-literal-ok: debug-only gallery
    builder: (_) => const PairDrill(picked: PairSide.b),
    state: _pairState,
  ),
  GalleryEntry(
    id: 'drill-pair-wrong',
    section: GallerySection.drills,
    label: 'Minimal pairs, wrong', // ui-literal-ok: debug-only gallery
    note:
        'What you heard, and the contrast', // ui-literal-ok: debug-only gallery
    builder: (_) => const PairDrill(picked: PairSide.a),
    state: _pairState,
  ),
];
