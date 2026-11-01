import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_log.dart';
import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'app/routes.dart';
import 'app/shell_tab.dart';
import 'features/decks/decks_page.dart';
import 'features/downloads/deck_update_prompt.dart';
import 'features/fonts/font_check_prompt.dart';
import 'features/whats_new/whats_new_prompt.dart';
import 'features/downloads/download_page.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/placement/language_picker_page.dart';
import 'features/settings/settings_page.dart';
import 'features/splash/splash_gate.dart';
import 'features/splash/splash_progress.dart';
import 'features/stats/stats_page.dart';
import 'features/today/today_page.dart';
import 'l10n/app_localizations.dart';
import 'ui/theme.dart';
import 'ui/widgets/tab_pager.dart';

/// The app: [AppState] at the top, then [MaterialApp] with the interface
/// strings, the light and dark themes and the routes, opening on [AppShell].
///
/// Starts loading the catalog as it is first built, so a test only has to
/// pump it: `FluenoughApp(state: AppState.test())`. Then, for updates
/// (ADR-0017), deletes the download of one that has installed, and checks
/// for a newer one if the learner has switched that on and no check has
/// reached GitHub in the last day.
class FluenoughApp extends StatefulWidget {
  const FluenoughApp({
    super.key,
    required this.state,
    this.frame,
    this.splash = false,
  });

  final AppState state;

  /// Whether to cover the first moments of a cold start with the splash
  /// screen and its loading bar: at least two seconds, and until the review
  /// log, the catalog and Today's first numbers are ready. On for the real
  /// app (`main.dart`, `main_web.dart`); off in tests.
  final bool splash;

  /// Wraps everything under [MaterialApp], inside the text cap: the web
  /// build's phone-shaped frame (`webPhoneFrame`). Null on a phone.
  final TransitionBuilder? frame;

  @override
  State<FluenoughApp> createState() => _FluenoughAppState();
}

class _FluenoughAppState extends State<FluenoughApp>
    with WidgetsBindingObserver {
  /// Logs each screen opened (#162). Made once, as a navigator takes an
  /// observer only once.
  late final List<NavigatorObserver> _observers = <NavigatorObserver>[
    LogNavigatorObserver(widget.state.log),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The daily reminder is planned once the decks are read, as what is due
    // depends on them (#90).
    widget.state.load().whenComplete(widget.state.reminders.appResumed);
    widget.state.updates.atLaunch();
    if (widget.splash) _watchStartUp(_splash);
  }

  /// What the splash waits for: the review log read, the catalog read, and
  /// the first frame that shows it, which is where Today's numbers are first
  /// worked out (the same seams as `StartupMarks`, #857).
  final SplashProgress _splash = SplashProgress();
  bool _disposed = false;

  void _watchStartUp(SplashProgress splash) {
    final state = widget.state;
    // `ready` never throws; either way the wait is over.
    state.progress.ready.whenComplete(() {
      if (!_disposed) splash.complete(SplashStage.history);
    });
    void catalogReady() {
      if (state.status == CatalogStatus.loading) return;
      state.removeListener(catalogReady);
      splash.complete(SplashStage.catalog);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) splash.complete(SplashStage.today);
      });
      // A frame is certain even if nothing on screen listens to the catalog.
      WidgetsBinding.instance.scheduleFrame();
    }

    if (state.status != CatalogStatus.loading) {
      catalogReady();
    } else {
      state.addListener(catalogReady);
      _removeCatalogListener = () => state.removeListener(catalogReady);
    }
  }

  VoidCallback? _removeCatalogListener;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeCatalogListener?.call();
    _disposed = true;
    _splash.dispose();
    super.dispose();
  }

  /// The reminder is planned again whenever the app opens or is left, so
  /// that it follows what was answered and the phone's clock and time zone
  /// (#90); while the app is open, today's does not fire.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final reminders = widget.state.reminders;
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        reminders.appResumed();
        // Android's installer, if it was open, has been closed (#487).
        widget.state.updates.appResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        reminders.appPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// The text cap, then the splash over the app (inside the web frame, so
  /// that it covers the phone and not the page), then the web frame. The app
  /// stays mounted under the splash.
  Widget _builder(BuildContext context, Widget? child) {
    final capped = capTextScale(context, child);
    final covered = widget.splash
        ? SplashGate(progress: _splash, child: capped)
        : capped;
    return widget.frame == null ? covered : widget.frame!(context, covered);
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
          builder: _builder,
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
          child: FontCheckPrompt(
            // Shows what changed, once, on the first launch after an update
            // (#944).
            child: WhatsNewPrompt(
              child: Scaffold(
                body: TabPager(
                  tab: tab,
                  moving: AppScope.read(context).shellTabMoving,
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
