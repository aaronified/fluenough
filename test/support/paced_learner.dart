import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';

/// What a [pacedLearner]'s fit did to a skill.
enum Paced {
  /// No skill fitted yet.
  none,

  /// Hear fitted to a learner who remembers well: fewer reviews.
  fewer,

  /// Write fitted to a learner who forgets faster: more reviews.
  more,

  /// Recognition fitted, and barely moved: about the same.
  same,

  /// Hear fitted, but the fit lost to FSRS-6's defaults, which are kept
  /// and stored: fitted, yet nothing adjusted.
  lost;

  /// Whether some skill is adjusted: not before a fit, nor after one that
  /// lost.
  bool get adjusts => this != none && this != lost;
}

/// FSRS-6's defaults with w8, how much a right answer lengthens the gap,
/// moved [by]: up keeps words longer, down brings them back sooner.
List<double> w8By(double by) => <double>[
  for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + by : w,
];

/// The skill each [Paced] case fits, and the set it is fitted to.
final Map<Paced, (DrillMode, List<double>)> pacedFits =
    <Paced, (DrillMode, List<double>)>{
      Paced.fewer: (DrillMode.listening, w8By(0.6)),
      Paced.more: (DrillMode.production, w8By(-0.6)),
      Paced.same: (DrillMode.recognition, w8By(0.001)),
      Paced.lost: (DrillMode.listening, <double>[...Fsrs.w]),
    };

/// A Hindi learner whose first eight words were answered Good three days
/// ago in Recognition, Hear and Write, so that they are due again, with a
/// voice for Hindi; and [paced]'s skill fitted, or every skill in [also]
/// too. Loaded. Its paces are worked out by [paceRunner].
Future<AppState> pacedLearner(
  Paced paced, {
  Set<Paced> also = const <Paced>{},
  PaceRunner paceRunner = paceInPlace,
}) async {
  AppState build(MemoryProgress progress) => AppState.test(
    progress: progress,
    paceRunner: paceRunner,
    tts: FixedTtsEngine(const <String>{'hi'}),
    // Past the first launch, as AppState.test's own settings are.
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
    )..learningChosen = true,
  );
  final base = build(MemoryProgress());
  await base.load();
  final at = base.now().subtract(const Duration(days: 3));
  final progress = MemoryProgress();
  for (final card in base.deckById('hi-en-first-words')!.cards.take(8)) {
    for (final mode in <DrillMode>[
      DrillMode.recognition,
      DrillMode.listening,
      DrillMode.production,
    ]) {
      progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: mode,
        grade: 3,
        now: at,
      );
    }
  }
  for (final c in <Paced>{paced, ...also}) {
    final fit = pacedFits[c];
    if (fit == null) continue;
    await progress.putFitted(
      (language: 'hi', mode: fit.$1),
      FittedParameters(
        values: fit.$2,
        fittedAt: base.now(),
        reviewCount: 8,
        lossBefore: c == Paced.lost ? 0.3 : 0.4,
        lossAfter: c == Paced.lost ? 0.4 : 0.3,
      ),
    );
  }
  final state = build(progress);
  await state.load();
  return state;
}
