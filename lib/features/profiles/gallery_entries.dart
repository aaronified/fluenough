import '../../app/app_state.dart';
import '../../app/features.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'new_profile_page.dart';
import 'pin_page.dart';
import 'profiles_page.dart';

/// Profiles and PIN lock switched on. Both are incoming in this version, so
/// the profile screens are reached only from the gallery.
const FeatureRegistry profilesFeatures = FeatureRegistry.only(<Feature>{
  ...Feature.available,
  Feature.profiles,
  Feature.pinLock,
});

/// The design's Aro (PIN 1234) and Mira on [app]'s catalog, with
/// [profilesFeatures] and [currentProfileId] current.
AppState profilesOn(AppState app, {String currentProfileId = 'aro'}) =>
    GalleryFixtures.state(
      app,
      features: profilesFeatures,
      currentProfileId: currentProfileId,
    );

/// Profiles and sign-in, as the design's Gallery lists them. Owned by B6.
final List<GalleryEntry> profilesGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'profiles',
    section: GallerySection.profiles,
    label: 'Profiles', // ui-literal-ok: debug-only gallery
    note:
        'Who is practising on this phone', // ui-literal-ok: debug-only gallery
    builder: (_) => const ProfilesPage(),
    state: profilesOn,
  ),
  GalleryEntry(
    id: 'pin',
    section: GallerySection.profiles,
    label: 'PIN', // ui-literal-ok: debug-only gallery
    note: 'Try 1234', // ui-literal-ok: debug-only gallery
    builder: (_) => const PinPage(profileId: 'aro'),
    state: profilesOn,
  ),
  GalleryEntry(
    id: 'pin-error',
    section: GallerySection.profiles,
    label: 'PIN, wrong', // ui-literal-ok: debug-only gallery
    note: 'Error state', // ui-literal-ok: debug-only gallery
    builder: (_) => const PinPage(profileId: 'aro', wrongPin: true),
    state: profilesOn,
  ),
  GalleryEntry(
    id: 'new-profile',
    section: GallerySection.profiles,
    label: 'New profile', // ui-literal-ok: debug-only gallery
    note: 'Shape, name, languages, optional PIN', // ui-literal-ok: debug-only gallery
    builder: (_) => const NewProfilePage(
      initialName: 'Dev', // ui-literal-ok: debug-only gallery
    ),
    state: profilesOn,
  ),
];

/// The same screens as this version ships them, with profiles and PIN lock
/// incoming: Add profile and the PIN switch disabled, Aro opening without
/// her PIN. `gallery_test` allows only the design's 26 ids, so these are
/// not in the gallery yet: Phase 2 splices them in. The profiles tests pump
/// each one.
final List<GalleryEntry> profilesGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'profiles-as-shipped',
    section: GallerySection.profiles,
    label: 'Profiles, as shipped', // ui-literal-ok: debug-only gallery
    note: 'Add profile incoming, no PIN asked', // ui-literal-ok: debug-only gallery
    builder: (_) => const ProfilesPage(),
  ),
  GalleryEntry(
    id: 'new-profile-as-shipped',
    section: GallerySection.profiles,
    label: 'New profile, as shipped', // ui-literal-ok: debug-only gallery
    note: 'PIN lock incoming', // ui-literal-ok: debug-only gallery
    builder: (_) => const NewProfilePage(),
  ),
];
