import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';
import '../gallery/gallery_link.dart';

/// The Settings tab: the profile card, learning, sound, look and language,
/// reminder and privacy, your data, and the footer.
///
/// Design screen `settings`. A Phase 0 stub that shows only its title and the
/// debug gallery's link; B5 replaces the body, keeping the class name, and
/// keeps a [GalleryLink] at the foot (it draws nothing in a release build).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            TabHeader(title: l10n.settingsTitle),
            const GalleryLink(),
          ],
        ),
      ),
    );
  }
}
