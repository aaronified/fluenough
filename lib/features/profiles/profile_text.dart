import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/profile.dart';
import '../../l10n/app_localizations.dart';

/// How the profile screens name a profile: its own name, or "You" for the
/// unnamed default. Names are the learner's own words and never translated.
String profileName(AppLocalizations l10n, Profile profile) {
  final name = profile.name?.trim();
  return name == null || name.isEmpty ? l10n.commonUnnamedProfile : name;
}

/// The languages [profile] learns, by the names their deck files give them,
/// in catalog order: "Spanish, Japanese".
///
/// Only languages with a loaded deck are named, since a language's name comes
/// from its deck (a profile may keep a code, like `hi`, whose decks are not
/// on this phone). None gives "Nothing yet".
String profileLanguages(
  AppLocalizations l10n,
  AppState state,
  Profile profile,
) {
  final names = <String>[
    for (final language in state.languages)
      if (profile.learns(language.code)) language.name,
  ];
  return names.isEmpty
      ? l10n.profilesLearningNothing
      : names.join(l10n.commonListSeparator);
}

/// Whether opening [profile] asks for its PIN. A profile keeps its PIN while
/// `Feature.pinLock` is incoming, but opens without it, as the design has it.
bool opensWithPin(AppState state, Profile profile) =>
    profile.isLocked && state.features.isAvailable(Feature.pinLock);
