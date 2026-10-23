import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/feedback/report.dart';
import '../features/decks/deck_detail_page.dart';
import '../features/decks/import_page.dart';
import '../features/decks/unit_page.dart';
import '../features/drill/drill_page.dart';
import '../features/gallery/gallery_page.dart';
import '../features/placement/language_picker_page.dart';
import '../features/profiles/new_profile_page.dart';
import '../features/profiles/pin_page.dart';
import '../features/profiles/profiles_page.dart';
import '../features/profiles/spoken_languages_page.dart';
import '../features/report/report_page.dart';
import '../features/review/offensive_review_page.dart';
import '../features/review/review_page.dart';
import '../features/review/reviewed_not_sent_page.dart';
import '../features/review/reviewed_sent_page.dart';
import '../features/review/waiting_page.dart';
import '../features/script/script_guide_page.dart';
import '../features/settings/app_log_page.dart';
import '../features/settings/activities_page.dart';
import '../features/settings/appearance_page.dart';
import '../features/settings/languages_page.dart';
import '../features/settings/profiles_privacy_page.dart';
import '../features/settings/reminders_page.dart';
import '../features/settings/reviewing_page.dart';
import '../features/settings/updates_page.dart';
import '../features/settings/your_data_page.dart';
import '../features/settings/your_decks_page.dart';
import '../features/settings/release_notes_page.dart';
import '../features/settings/sources_page.dart';
import '../features/settings/voices_page.dart';
import '../features/stats/all_tags_page.dart';
import '../features/stats/over_time_page.dart';
import '../features/stats/how_you_learn_page.dart';
import '../features/stats/leeches_page.dart';
import '../features/stats/stats_numbers.dart';
import '../features/summary/summary_page.dart';
import 'app_scope.dart';
import 'session.dart';
import 'shell_tab.dart';

/// Every screen pushed over the shell, by name, with the argument it takes.
///
/// The four tabs are not routes: they live in the shell (`AppShell` in
/// `lib/app.dart`) and are switched with [AppNavigator.selectTab].
///
/// Navigate with [AppNavigator] rather than with these names, so that the
/// argument's type is checked where the call is made.
abstract final class AppRoutes {
  /// A deck's screen. Argument: the deck id, a [String].
  static const String deck = '/deck';

  /// A unit of a course's path. Argument: the id of a deck in it, a
  /// [String].
  static const String unit = '/unit';

  /// Add a deck.
  static const String import = '/import';

  /// A drill session. Argument: a [DrillRequest].
  static const String drill = '/drill';

  /// The session summary. Argument: a [SessionResult].
  static const String summary = '/summary';

  /// Leeches. Argument: a language code, a [String], for that language's
  /// only; none for every language.
  static const String leeches = '/leeches';

  /// Every tag with its bar and a Practise button. Argument: the
  /// [StatsRange] counted.
  static const String allTags = '/all-tags';

  /// The charts over time that the Progress star opens.
  static const String progressOverTime = '/progress-over-time';

  /// How you learn: each skill's pace beside how it started. Argument: a
  /// language code, a [String], for that language's only; none for every
  /// language learned.
  static const String howYouLearn = '/how-you-learn';

  /// Look and language: the appearance page, with the app language.
  static const String appearance = '/appearance';

  /// The pages the Settings tab lists, one per row (docs/mockups/
  /// settings.html).
  static const String settingsLanguages = '/settings/languages';
  static const String settingsActivities = '/settings/activities';
  static const String settingsReviewing = '/settings/reviewing';
  static const String settingsDecks = '/settings/decks';
  static const String settingsReminders = '/settings/reminders';
  static const String settingsData = '/settings/data';
  static const String settingsUpdates = '/settings/updates';

  /// Profiles and privacy, opened from the profile card.
  static const String settingsProfiles = '/settings/profiles';
  static const String spokenLanguages = '/spoken-languages';
  static const String learnLanguages = '/learn-languages';
  static const String voices = '/voices';

  /// Settings' "What's new": each release's notes, from GitHub.
  static const String releaseNotes = '/release-notes';

  /// Where the decks' texts come from, opened from Settings.
  static const String sources = '/sources';

  /// The app's own log (#162), opened from Settings and from a report.
  static const String appLog = '/app-log';

  /// A script's guide. Argument: the language code, a [String].
  static const String scriptGuide = '/script-guide';
  static const String profiles = '/profiles';

  /// A profile's PIN. Argument: the profile id, a [String].
  static const String pin = '/pin';

  static const String newProfile = '/new-profile';

  /// Every screen and state, like the design's Gallery. Debug builds only.
  static const String gallery = '/gallery';

  /// A report from the screen under it (ADR-0021). Argument: a
  /// [ReportRequest].
  static const String report = '/report';

  /// Reviewing a unit's cards (docs/plans/deck-browser.md). Argument: the
  /// id of a deck in the unit, a [String].
  static const String review = '/review';

  /// What waits for review in the reviewer's languages.
  static const String waitingForReview = '/waiting-for-review';

  /// The reviews kept on this phone, not sent yet, grouped by deck (#471).
  static const String reviewedNotSent = '/reviewed-not-sent';

  /// What became of the suggestions the reviewer sent (#471).
  static const String reviewedSent = '/reviewed-sent';

  /// A language's offensive words, reviewed apart and only on purpose
  /// (docs/plans/deck-browser.md). Argument: the language's code, a
  /// [String].
  static const String offensiveReview = '/offensive-review';

  /// The page for [settings], or null for an unknown name or a wrong
  /// argument, which Flutter reports.
  static Route<void>? onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget? page = switch (settings.name) {
      deck when args is String => DeckDetailPage(deckId: args),
      unit when args is String => UnitPage(deckId: args),
      import => const ImportPage(),
      drill when args is DrillRequest => DrillPage(request: args),
      summary when args is SessionResult => SummaryPage(result: args),
      leeches => LeechesPage(language: args is String ? args : null),
      allTags when args is StatsRange => AllTagsPage(range: args),
      progressOverTime => const OverTimePage(),
      howYouLearn => HowYouLearnPage(language: args is String ? args : null),
      appearance => const AppearancePage(),
      settingsLanguages => const LanguagesSettingsPage(),
      settingsActivities => const ActivitiesPage(),
      settingsReviewing => const ReviewingPage(),
      settingsDecks => const YourDecksPage(),
      settingsReminders => const RemindersPage(),
      settingsData => const YourDataPage(),
      settingsUpdates => const UpdatesPage(),
      settingsProfiles => const ProfilesPrivacyPage(),
      spokenLanguages => const SpokenLanguagesPage(),
      learnLanguages => const LanguagePickerPage(),
      voices => const VoicesPage(),
      releaseNotes => const ReleaseNotesPage(),
      sources => const SourcesPage(),
      appLog => const AppLogPage(),
      scriptGuide when args is String => ScriptGuidePage(guideKey: args),
      profiles => const ProfilesPage(),
      pin when args is String => PinPage(profileId: args),
      newProfile => const NewProfilePage(),
      gallery when kDebugMode => const GalleryPage(),
      report when args is ReportRequest => ReportPage(request: args),
      review when args is String => ReviewPage(deckId: args),
      waitingForReview => const WaitingForReviewPage(),
      reviewedNotSent => const ReviewedNotSentPage(),
      reviewedSent => const ReviewedSentPage(),
      offensiveReview when args is String => OffensiveReviewPage(
        language: args,
      ),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }
}

/// Typed navigation. Every call uses the nearest [Navigator], so the same
/// code works inside the gallery's previews.
abstract final class AppNavigator {
  static Future<void> openDeck(BuildContext context, String deckId) =>
      Navigator.of(context).pushNamed(AppRoutes.deck, arguments: deckId);

  /// The unit of its course's path that [deckId] is in.
  static Future<void> openUnit(BuildContext context, String deckId) =>
      Navigator.of(context).pushNamed(AppRoutes.unit, arguments: deckId);

  /// A report from the screen [request] was raised on.
  static Future<void> openReport(BuildContext context, ReportRequest request) =>
      Navigator.of(context).pushNamed(AppRoutes.report, arguments: request);

  /// Reviewing the unit of its course's path that [deckId] is in.
  static Future<void> openReview(BuildContext context, String deckId) =>
      Navigator.of(context).pushNamed(AppRoutes.review, arguments: deckId);

  /// What waits for review in the reviewer's languages.
  static Future<void> openWaitingForReview(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.waitingForReview);

  /// The reviews not sent yet, by deck.
  static Future<void> openReviewedNotSent(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.reviewedNotSent);

  /// What became of the suggestions sent.
  static Future<void> openReviewedSent(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.reviewedSent);

  /// [language]'s Offensive words review, which explains why the words
  /// are there and asks the reviewer's age before showing any.
  static Future<void> openOffensiveReview(
    BuildContext context,
    String language,
  ) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.offensiveReview, arguments: language);

  static Future<void> openImport(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.import);

  /// Starts a session. The drill page builds its queue from [request].
  static Future<void> startDrill(BuildContext context, DrillRequest request) =>
      Navigator.of(context).pushNamed(AppRoutes.drill, arguments: request);

  /// Replaces the summary with another session: the next language's, which
  /// the summary offers, so finished summaries do not pile up behind it.
  static Future<void> nextDrill(BuildContext context, DrillRequest request) =>
      Navigator.of(context)
          .pushReplacementNamed(AppRoutes.drill, arguments: request);

  /// Replaces the drill with its summary, so that back from the summary does
  /// not return to a finished session.
  static Future<void> showSummary(BuildContext context, SessionResult result) =>
      Navigator.of(context)
          .pushReplacementNamed(AppRoutes.summary, arguments: result);

  /// Leeches, in [language] only when given.
  static Future<void> openLeeches(BuildContext context, {String? language}) =>
      Navigator.of(context).pushNamed(AppRoutes.leeches, arguments: language);

  /// The All tags page, counting [range].
  static Future<void> openAllTags(BuildContext context, StatsRange range) =>
      Navigator.of(context).pushNamed(AppRoutes.allTags, arguments: range);

  /// The charts over time, opened from the Progress star.
  static Future<void> openOverTime(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.progressOverTime);

  /// How you learn, in [language] only when given. With [replacing], in
  /// place of the route on top, such as the sheet that links to it.
  static Future<void> openHowYouLearn(
    BuildContext context, {
    String? language,
    bool replacing = false,
  }) => replacing
      ? Navigator.of(context)
            .popAndPushNamed(AppRoutes.howYouLearn, arguments: language)
      : Navigator.of(context)
            .pushNamed(AppRoutes.howYouLearn, arguments: language);

  static Future<void> openAppearance(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.appearance);

  /// One of the pages the Settings tab lists, by its route name.
  static Future<void> openSettingsPage(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);

  static Future<void> openSpokenLanguages(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.spokenLanguages);

  static Future<void> openLearnLanguages(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.learnLanguages);

  static Future<void> openVoices(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.voices);

  /// What changed in each release, which the page fetches from GitHub.
  static Future<void> openReleaseNotes(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.releaseNotes);

  static Future<void> openSources(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.sources);

  /// The app's own log, a line an entry.
  static Future<void> openAppLog(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.appLog);

  /// How a script works (#30): a script deck's Tips. [key] is the guide's
  /// `ScriptGuide.key`.
  static Future<void> openScriptGuide(BuildContext context, String key) =>
      Navigator.of(context).pushNamed(AppRoutes.scriptGuide, arguments: key);

  static Future<void> openProfiles(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.profiles);

  static Future<void> openPin(BuildContext context, String profileId) =>
      Navigator.of(context).pushNamed(AppRoutes.pin, arguments: profileId);

  static Future<void> openNewProfile(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.newProfile);

  /// The debug gallery. Does nothing in a release build.
  static Future<void> openGallery(BuildContext context) async {
    if (!kDebugMode) return;
    await Navigator.of(context).pushNamed(AppRoutes.gallery);
  }

  /// Switches the shell to [tab]. Works from a page pushed over the shell.
  static void selectTab(BuildContext context, ShellTab tab) =>
      AppScope.read(context).shellTab.value = tab;

  /// Pops back to the shell, then shows [tab] if given: the summary's
  /// "Done", a finished profile switch.
  static void backToShell(BuildContext context, {ShellTab? tab}) {
    final state = AppScope.read(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (tab != null) state.shellTab.value = tab;
  }
}
