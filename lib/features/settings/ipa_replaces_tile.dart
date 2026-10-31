import 'package:flutter/material.dart';

import '../../app/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';

/// Settings' "IPA replaces transliteration" row (#697), put right after the
/// IPA pronunciations row. It only means something while IPA is on, so with
/// IPA off it is greyed out and says why; the choice itself is kept.
GroupedTile ipaReplacesTile(AppLocalizations l10n, SettingsNotifier settings) {
  final ipaOn = settings.showIpa;
  return GroupedTile.toggle(
    leading: GroupedTile.noIcon,
    title: l10n.settingsIpaReplaces,
    subtitleOn: l10n.settingsIpaReplacesOn,
    subtitleOff: ipaOn
        ? l10n.settingsIpaReplacesOff
        : l10n.settingsIpaReplacesNeedsIpa,
    value: ipaOn && settings.ipaReplacesReading,
    onChanged: ipaOn ? (on) => settings.ipaReplacesReading = on : null,
  );
}
