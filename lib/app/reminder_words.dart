import 'dart:ui' show Locale;

import '../l10n/app_localizations.dart';
import 'reminder_service.dart';

/// The daily reminder's text in [locale], or in English where the app has no
/// such language. A notification is built with no screen to ask for the
/// locale, so it reads it from the phone.
ReminderWords reminderWordsFor(Locale locale) {
  final l10n = lookupAppLocalizations(
    AppLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
  );
  return ReminderWords(
    title: l10n.reminderNotificationTitle,
    body: l10n.reminderNotificationBody,
    channelName: l10n.reminderChannelName,
    channelDescription: l10n.reminderChannelDescription,
  );
}
