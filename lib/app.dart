import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'app/routes.dart';
import 'app/shell_tab.dart';
import 'features/decks/decks_page.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/placement/learn_languages_page.dart';
import 'features/settings/settings_page.dart';
import 'features/stats/stats_page.dart';
import 'features/today/today_page.dart';
import 'l10n/app_localizations.dart';
import 'ui/theme.dart';
import 'ui/widgets/report_capture.dart';

/// The app: [AppState] at the top, then [MaterialApp] with the interface
/// strings, the light and dark themes and the routes, opening on [AppShell].
///
/// Starts loading the catalog as it is first built, so a test only has to
/// pump it: `FluenoughApp(state: AppState.test())`. Then, for updates
/// (ADR-0017), deletes the download of one that has installed, and checks
/// for a newer one if the learner has switched that on and no check has
/// reached GitHub in the last day.
class FluenoughApp extends StatefulWidget {
  const FluenoughApp({super.key, required this.state});

  final AppState state;

  @override
  State<FluenoughApp> createState() => _FluenoughAppState();
}

class _FluenoughAppState extends State<FluenoughApp> {
  @override
  void initState() {
    super.initState();
    widget.state.load();
    widget.state.updates.atLaunch();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.state.settings;
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(
            seed: settings.seed,
            highContrast: settings.highContrast,
          ),
          darkTheme: AppTheme.dark(
            seed: settings.seed,
            highContrast: settings.highContrast,
          ),
          themeMode: settings.themeMode,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // Around every screen, so that the bug icon can take a picture of
          // the one it is tapped on (ADR-0021).
          builder: ReportCapture.wrap,
          // The first launch: welcome, tour and the languages the learner
          // speaks (#118, #53), then which they want to learn, and placement
          // (#117). Each answer saved rebuilds this on settings. An install
          // from before #117 is asked the second once.
          home: settings.spokenLanguages.isEmpty
              ? const OnboardingFlow()
              : !settings.learningChosen
              ? const LearnLanguagesPage(firstRun: true)
              : const AppShell(),
        ),
      ),
    );
  }
}

/// The four tabs and the navigation bar under them: Today, Decks, Progress,
/// Settings.
///
/// Which tab shows is `AppState.shellTab`, so a page pushed over the shell
/// can switch it (`AppNavigator.selectTab`). Every tab stays built while
/// another shows, keeping its scroll position. Back on any tab but Today
/// returns to Today. Settings carries a dot while a newer version is out.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tab = AppScope.read(context).shellTab;
    return ValueListenableBuilder<ShellTab>(
      valueListenable: tab,
      builder: (context, current, _) => PopScope(
        canPop: current == ShellTab.today,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) tab.value = ShellTab.today;
        },
        child: Scaffold(
          body: IndexedStack(
            index: current.index,
            children: const <Widget>[
              TodayPage(),
              DecksPage(),
              StatsPage(),
              SettingsPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: current.index,
            onDestinationSelected: (i) => tab.value = ShellTab.values[i],
            destinations: <Widget>[
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l10n.navToday,
              ),
              NavigationDestination(
                icon: const Icon(Icons.style_outlined),
                selectedIcon: const Icon(Icons.style),
                label: l10n.navDecks,
              ),
              NavigationDestination(
                icon: const Icon(Icons.insert_chart_outlined),
                selectedIcon: const Icon(Icons.insert_chart),
                label: l10n.navProgress,
              ),
              NavigationDestination(
                icon: const _SettingsIcon(Icons.settings_outlined),
                selectedIcon: const _SettingsIcon(Icons.settings),
                label: l10n.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Settings tab's [icon], with a dot while a newer version is out
/// (ADR-0017), which a screen reader hears with the tab's name.
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final available = state.updates.updateAvailable;
        return Semantics(
          label: available
              ? AppLocalizations.of(context)!.navSettingsUpdate
              : null,
          child: Badge(isLabelVisible: available, child: Icon(icon)),
        );
      },
    );
  }
}
