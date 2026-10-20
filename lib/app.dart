import 'package:flutter/gestures.dart' show kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_log.dart';
import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'app/routes.dart';
import 'app/shell_tab.dart';
import 'features/decks/decks_page.dart';
import 'features/downloads/deck_update_prompt.dart';
import 'features/downloads/download_page.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/placement/language_picker_page.dart';
import 'features/settings/settings_page.dart';
import 'features/stats/stats_page.dart';
import 'features/today/today_page.dart';
import 'l10n/app_localizations.dart';
import 'ui/theme.dart';

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
  /// Logs each screen opened (#162). Made once, as a navigator takes an
  /// observer only once.
  late final List<NavigatorObserver> _observers = <NavigatorObserver>[
    LogNavigatorObserver(widget.state.log),
  ];

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
            pureBlack: settings.pureBlack,
          ),
          themeMode: settings.themeMode,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          navigatorObservers: _observers,
          builder: capTextScale,
          // The first launch: welcome, tour and the languages the learner
          // speaks (#118, #53), then which they want to learn, their first
          // decks downloaded (#210), and placement (#117). Each answer saved
          // rebuilds this on settings. An install from before #117 is asked
          // the second once.
          home: settings.spokenLanguages.isEmpty
              ? const OnboardingFlow()
              : !settings.learningChosen
              ? const LanguagePickerPage(firstRun: true)
              : const _Home(),
        ),
      ),
    );
  }
}

/// Caps the phone's text size at [AppSizes.maxTextScale] for everything
/// under [MaterialApp]: every screen, sheet, dialog and the tab bar (#505).
/// [MaterialApp.builder] for the app, and for the tests' harness.
Widget capTextScale(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppSizes.maxTextScale,
      child: child ?? const SizedBox.shrink(),
    );

/// The app once the first launch is done: [AppShell], or, while a language
/// the learner learns has none of its first decks on the phone, the page
/// that downloads them (#210), as after updating from a version that
/// bundled its decks. Decided once the catalog is read, so that it never
/// shows for a moment at launch.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final missing = state.missingLanguages;
    return missing.isEmpty
        ? const AppShell()
        : DownloadPage(
            key: ValueKey<String>(missing.join()),
            languages: missing,
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
        // Asks whether to download a deck update the daily check found.
        child: DeckUpdatePrompt(
          child: Scaffold(
            body: _TabSwipe(
              tab: tab,
              child: IndexedStack(
                index: current.index,
                children: const <Widget>[
                  TodayPage(),
                  DecksPage(),
                  StatsPage(),
                  SettingsPage(),
                ],
              ),
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
      ),
    );
  }
}

/// A sideways swipe on the tab's page moves to the next or previous tab,
/// stopping at the ends (#683). It is a horizontal drag: a drag that passes
/// the touch slop mostly upright goes to the page's scroll instead, and a
/// horizontal drag inside the page, such as the language bar's, wins over
/// this one because it is nearer the finger.
class _TabSwipe extends StatefulWidget {
  const _TabSwipe({required this.tab, required this.child});

  final ValueNotifier<ShellTab> tab;
  final Widget child;

  @override
  State<_TabSwipe> createState() => _TabSwipeState();
}

class _TabSwipeState extends State<_TabSwipe> {
  double _dx = 0;

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final width = context.size?.width ?? 0;
    final double toward;
    if (velocity.abs() >= kMinFlingVelocity) {
      toward = velocity;
    } else if (width > 0 && _dx.abs() >= width / 4) {
      toward = _dx;
    } else {
      return;
    }
    // A swipe left shows what is to the right: the next tab, or in a right
    // to left layout the previous one.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final step = (toward < 0) != rtl ? 1 : -1;
    final next = widget.tab.value.index + step;
    if (next < 0 || next >= ShellTab.values.length) return;
    widget.tab.value = ShellTab.values[next];
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragStart: (_) => _dx = 0,
    onHorizontalDragUpdate: (details) => _dx += details.primaryDelta ?? 0,
    onHorizontalDragEnd: _end,
    child: widget.child,
  );
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
