import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/decks/deck_detail_page.dart';
import '../features/decks/import_page.dart';
import '../features/drill/drill_page.dart';
import '../features/gallery/gallery_page.dart';
import '../features/placement/learn_languages_page.dart';
import '../features/profiles/new_profile_page.dart';
import '../features/profiles/pin_page.dart';
import '../features/profiles/profiles_page.dart';
import '../features/profiles/spoken_languages_page.dart';
import '../features/script/script_guide_page.dart';
import '../features/settings/appearance_page.dart';
import '../features/settings/voices_page.dart';
import '../features/stats/leeches_page.dart';
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

  /// Add a deck.
  static const String import = '/import';

  /// A drill session. Argument: a [DrillRequest].
  static const String drill = '/drill';

  /// The session summary. Argument: a [SessionResult].
  static const String summary = '/summary';

  /// Leeches. Argument: a language code, a [String], for that language's
  /// only; none for every language.
  static const String leeches = '/leeches';
  static const String appearance = '/appearance';
  static const String spokenLanguages = '/spoken-languages';
  static const String learnLanguages = '/learn-languages';
  static const String voices = '/voices';

  /// A script's guide. Argument: the language code, a [String].
  static const String scriptGuide = '/script-guide';
  static const String profiles = '/profiles';

  /// A profile's PIN. Argument: the profile id, a [String].
  static const String pin = '/pin';

  static const String newProfile = '/new-profile';

  /// Every screen and state, like the design's Gallery. Debug builds only.
  static const String gallery = '/gallery';

  /// The page for [settings], or null for an unknown name or a wrong
  /// argument, which Flutter reports.
  static Route<void>? onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget? page = switch (settings.name) {
      deck when args is String => DeckDetailPage(deckId: args),
      import => const ImportPage(),
      drill when args is DrillRequest => DrillPage(request: args),
      summary when args is SessionResult => SummaryPage(result: args),
      leeches => LeechesPage(language: args is String ? args : null),
      appearance => const AppearancePage(),
      spokenLanguages => const SpokenLanguagesPage(),
      learnLanguages => const LearnLanguagesPage(),
      voices => const VoicesPage(),
      scriptGuide when args is String => ScriptGuidePage(languageCode: args),
      profiles => const ProfilesPage(),
      pin when args is String => PinPage(profileId: args),
      newProfile => const NewProfilePage(),
      gallery when kDebugMode => const GalleryPage(),
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

  static Future<void> openAppearance(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.appearance);

  static Future<void> openSpokenLanguages(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.spokenLanguages);

  static Future<void> openLearnLanguages(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.learnLanguages);

  static Future<void> openVoices(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.voices);

  /// How [languageCode]'s script works (#30): a script deck's Tips.
  static Future<void> openScriptGuide(
    BuildContext context,
    String languageCode,
  ) =>
      Navigator.of(context)
          .pushNamed(AppRoutes.scriptGuide, arguments: languageCode);

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
