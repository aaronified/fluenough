import 'dart:ui' show Locale;

import '../core/widget/home_widget_summary.dart';
import '../l10n/app_localizations.dart';

/// The home-screen widget's text in [locale], or in English where the app
/// has no such language. The widget is stored when no screen is there to ask
/// for the locale, so it reads it from the phone, as the reminder does.
HomeWidgetTexts homeWidgetTextsFor(Locale locale) {
  final l10n = lookupAppLocalizations(
    AppLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
  );
  return HomeWidgetTexts(
    due: l10n.homeWidgetDue,
    allDone: l10n.homeWidgetAllDone,
    streak: l10n.homeWidgetStreak,
    open: l10n.homeWidgetOpen,
  );
}
