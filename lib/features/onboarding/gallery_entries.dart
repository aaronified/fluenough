import '../gallery/gallery_entry.dart';
import 'onboarding_flow.dart';
import 'tour_step.dart';

/// The first launch (#118), each screen in its own state. They run on the
/// gallery's fixture state, whose settings hold no spoken language, as on a
/// new install.
final List<GalleryEntry> onboardingGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'onboarding-welcome',
    section: GallerySection.profiles,
    label: 'First launch: welcome', // ui-literal-ok: debug-only gallery
    note: 'Mark, name, what it does, Get started', // ui-literal-ok: debug-only gallery
    builder: (_) => const OnboardingFlow(),
  ),
  for (final (i, slide) in tourSlides.indexed)
    GalleryEntry(
      id: 'onboarding-tour-${slide.id}',
      section: GallerySection.profiles,
      label: 'First launch: tour, slide ${i + 1}', // ui-literal-ok: debug-only gallery
      note: 'Swipe or Next; Back; Skip', // ui-literal-ok: debug-only gallery
      builder: (_) => OnboardingFlow(startAt: 'tour', page: i),
    ),
  GalleryEntry(
    id: 'onboarding-sound',
    section: GallerySection.profiles,
    label: 'First launch: microphone and sound check', // ui-literal-ok: debug-only gallery
    note: 'Record two seconds, play back, did you hear it? (#89)', // ui-literal-ok: debug-only gallery
    builder: (_) => const OnboardingFlow(startAt: 'sound'),
  ),
  GalleryEntry(
    id: 'onboarding-languages-intro',
    section: GallerySection.profiles,
    label: 'First launch: what Know and Learn mean', // ui-literal-ok: debug-only gallery
    note: 'The pills explained; Skip or Choose my languages', // ui-literal-ok: debug-only gallery
    builder: (_) => const OnboardingFlow(startAt: 'languages-intro'),
  ),
  GalleryEntry(
    id: 'onboarding-languages',
    section: GallerySection.profiles,
    label: 'First launch: languages you know and learn', // ui-literal-ok: debug-only gallery
    note: 'Only English, known: Next waits for another language', // ui-literal-ok: debug-only gallery
    builder: (_) => const OnboardingFlow(startAt: 'languages'),
  ),
];
