import '../../app/app_state.dart';
import '../../app/profile.dart';
import '../../app/session.dart';
import '../../core/grading/self_grade.dart';
import '../gallery/fixtures.dart';

// Today's states for the gallery and the tests, all on the real bundled
// decks and on reviews recorded through `AppState.record`: no card id is
// ever written here.

/// Answers every item in today's session, correctly, at the state's current
/// time, then the new skills of its words that answering brings, until none
/// is left: what Today looks like once the day's work is done. The catalog
/// must be loaded, and the voices checked if listening should count.
void finishToday(AppState state) {
  const today = DrillRequest.today();
  while (state.buildSession(today).isNotEmpty) {
    for (final item in state.buildSession(today).items) {
      state.record(item, SelfGrade.good.toSm2Grade());
    }
  }
}

/// A learner on their first day: the unnamed default profile, no history.
AppState todayFreshState(AppState app) => GalleryFixtures.state(
  app,
  history: false,
  profiles: const <Profile>[Profile.defaultProfile],
  currentProfileId: Profile.defaultProfile.id,
);

/// Aro, twelve days into a streak, with today's session already done.
///
/// The gallery loads a state after building it, so the session is answered
/// once the catalog has loaded and every voice has been checked, which is
/// when `AppState` last notifies.
AppState todayAllDoneState(AppState app) {
  final state = GalleryFixtures.state(app);
  void finish() {
    final checked =
        state.status == CatalogStatus.ready &&
        state.languages.every(
          (l) => state.voiceStatus(l) != VoiceStatus.checking,
        );
    if (!checked) return;
    state.removeListener(finish);
    finishToday(state);
  }

  state.addListener(finish);
  return state;
}

/// Mira, who learns Marathi, which the fixture phone has no voice for.
AppState todayNoVoiceState(AppState app) =>
    GalleryFixtures.state(app, currentProfileId: GalleryFixtures.mira.id);
