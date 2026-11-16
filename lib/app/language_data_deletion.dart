import '../core/data/review_erasure.dart';
import 'app_state.dart';
import 'backups.dart';

/// What the learner ticked in the delete dialog of a language's sheet
/// (#861). The decks are removed by the sheet, which also stops what is
/// being learned.
class LanguageDataChoice {
  const LanguageDataChoice({
    this.reviews = false,
    this.from,
    this.to,
    this.placement = false,
    this.settings = false,
  });

  /// The language's reviews, from the day [from] to the day [to], both
  /// included; every day when both are null.
  final bool reviews;
  final DateTime? from;
  final DateTime? to;

  /// What placement found, and the reviews it wrote.
  final bool placement;

  /// The language's own settings.
  final bool settings;

  bool get isEmpty => !reviews && !placement && !settings;
}

/// Deleting some of one language's data (#861; owner, 2026-10-26, 2026-11-07).
extension LanguageDataDeletion on AppState {
  /// Deletes what [choice] ticks for [code], and nothing of any other
  /// language. A backup of everything is kept first ([BackupKind.delete]):
  /// if it cannot be kept this throws and nothing has changed.
  ///
  /// Reviews and placement's credit go from the review log through the
  /// store ([ProgressStore.eraseReviews]), which rebuilds the language's
  /// states, drops its fits and tells every listener, so that what is read
  /// from the log (counts, streaks, hours, tag strength, recent answers, the
  /// day's queue and its budget) is worked out again. The study time kept
  /// beside the log in the same days goes with the reviews. Returns how
  /// many reviews went.
  Future<int> deleteLanguageData(String code, LanguageDataChoice choice) async {
    await progress.ready;
    await backups.keep(BackupKind.delete);
    var removed = 0;
    if (choice.reviews || choice.placement) {
      removed = await progress.eraseReviews(
        ReviewErasure(
          language: code,
          answers: choice.reviews,
          from: choice.from,
          to: choice.to,
          placement: choice.placement,
          placedAtSeconds: settings.placedAtOf(code),
        ),
      );
    }
    if (choice.reviews) {
      settings.clearStudyTime(code, from: choice.from, to: choice.to);
    }
    if (choice.placement) settings.clearPlacement(code);
    if (choice.settings) settings.clearLanguageSettings(code);
    // Today's last numbers were drawn from the reviews that are gone.
    settings.todaySummary = null;
    log.event('Language data deleted: $code, $removed reviews');
    return removed;
  }
}
