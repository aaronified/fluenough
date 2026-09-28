import '../gallery/gallery_entry.dart';
import 'new_profile_page.dart';
import 'pin_page.dart';
import 'profiles_page.dart';

/// Profiles and sign-in, as the design's Gallery lists them. Owned by B6.
///
/// Each entry runs on `GalleryFixtures.state(app)` unless it gives a `state`:
/// the design's Aro (PIN 1234) and Mira, twelve days of history.
final List<GalleryEntry> profilesGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'profiles',
    section: GallerySection.profiles,
    label: 'Profiles', // ui-literal-ok: debug-only gallery
    note:
        'Who is practising on this phone', // ui-literal-ok: debug-only gallery
    builder: (_) => const ProfilesPage(),
  ),
  GalleryEntry(
    id: 'pin',
    section: GallerySection.profiles,
    label: 'PIN', // ui-literal-ok: debug-only gallery
    note: 'Try 1234', // ui-literal-ok: debug-only gallery
    builder: (_) => const PinPage(profileId: 'aro'),
  ),
  GalleryEntry(
    id: 'pin-error',
    section: GallerySection.profiles,
    label: 'PIN, wrong', // ui-literal-ok: debug-only gallery
    note: 'Error state', // ui-literal-ok: debug-only gallery
    builder: (_) => const PinPage(profileId: 'aro'),
  ),
  GalleryEntry(
    id: 'new-profile',
    section: GallerySection.profiles,
    label: 'New profile', // ui-literal-ok: debug-only gallery
    note: 'Shape, name, languages, optional PIN', // ui-literal-ok: debug-only gallery
    builder: (_) => const NewProfilePage(),
  ),
];
