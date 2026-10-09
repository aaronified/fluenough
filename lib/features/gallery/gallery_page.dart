import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../ui/theme.dart';
import '../decks/gallery_entries.dart';
import '../drill/gallery_entries.dart';
import '../drill/grammar_drill.dart';
import '../drill/pair_drill.dart';
import '../onboarding/gallery_entries.dart';
import '../placement/gallery_entries.dart';
import '../profiles/gallery_entries.dart';
import '../script/gallery_entries.dart';
import '../settings/gallery_entries.dart';
import '../stats/gallery_entries.dart';
import '../summary/gallery_entries.dart';
import '../today/gallery_entries.dart';
import 'fixtures.dart';
import 'gallery_entry.dart';

// Everything in this file is debug-only (AppRoutes.gallery is registered only
// when kDebugMode), so its labels are literals, each marked for the gate.

/// Every feature's entries, in the design's order, each feature's design
/// screens followed by the other states it exports. A builder adds entries
/// to their own feature's lists, never here.
List<GalleryEntry> get allGalleryEntries => <GalleryEntry>[
  ...onboardingGalleryEntries,
  ...profilesGalleryEntries,
  ...profilesGalleryStates,
  ...placementGalleryEntries,
  ...todayGalleryEntries,
  ...todayGalleryStates,
  ...decksGalleryEntries,
  ...scriptGalleryEntries,
  ...drillGalleryEntries,
  ...grammarGalleryStates,
  ...pairGalleryStates,
  ...summaryGalleryEntries,
  ...summaryGalleryStates,
  ...statsGalleryEntries,
  ...statsGalleryStates,
  ...settingsGalleryEntries,
  ...settingsGalleryStates,
];

/// The design's "Dark theme" section: these screens again, dark.
const List<String> darkGalleryIds = <String>[
  'profiles',
  'today',
  'decks',
  'decks-a1-earned',
  'unit',
  'deck',
  'drill-production-accent',
  'stats',
  'appearance',
];

/// The whole app on fixture data: the design's "Full app" prototype.
final GalleryEntry fullAppEntry = GalleryEntry(
  id: 'app',
  section: GallerySection.profiles,
  label: 'Full app', // ui-literal-ok: debug-only gallery
  note: 'The shell on fixture data. Tap through', // ui-literal-ok: debug-only gallery
  builder: (_) => const AppShell(),
);

/// Every screen and state, like the design's Gallery.dc.html. Debug builds
/// only: reach it from the link at the foot of Settings.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = allGalleryEntries;
    final byId = <String, GalleryEntry>{for (final e in entries) e.id: e};
    final theme = Theme.of(context);

    Widget tile(GalleryEntry e, {bool dark = false}) => ListTile(
      title: Text(e.label),
      subtitle: Text('${e.id} · ${e.note}'),
      trailing: Icon(dark ? Icons.dark_mode_outlined : Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GalleryPreview(entry: e, dark: dark),
        ),
      ),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium!.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screens'), // ui-literal-ok: debug-only gallery
      ),
      body: ListView(
        children: <Widget>[
          heading('Prototype'), // ui-literal-ok: debug-only gallery
          tile(fullAppEntry),
          for (final section in GallerySection.values) ...<Widget>[
            heading(section.title),
            for (final e in entries)
              if (e.section == section) tile(e),
          ],
          heading('Dark theme'), // ui-literal-ok: debug-only gallery
          for (final id in darkGalleryIds)
            if (byId[id] != null) tile(byId[id]!, dark: true),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// One entry, full screen, on its own state and theme, in its own
/// navigator so that anything it pushes stays inside the preview.
class GalleryPreview extends StatefulWidget {
  const GalleryPreview({super.key, required this.entry, this.dark = false});

  final GalleryEntry entry;
  final bool dark;

  @override
  State<GalleryPreview> createState() => _GalleryPreviewState();
}

class _GalleryPreviewState extends State<GalleryPreview> {
  AppState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) return;
    final app = AppScope.read(context);
    final make = widget.entry.state ?? GalleryFixtures.state;
    _state = make(app)..load();
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state!;
    return AppScope(
      state: state,
      child: Theme(
        data: widget.dark ? AppTheme.dark() : AppTheme.light(),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 40,
            title: Text(widget.entry.label),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Navigator(
            onGenerateRoute: (settings) =>
                settings.name == Navigator.defaultRouteName
                ? MaterialPageRoute<void>(builder: widget.entry.builder)
                : AppRoutes.onGenerateRoute(settings),
          ),
        ),
      ),
    );
  }
}
