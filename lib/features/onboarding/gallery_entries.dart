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
    id: 'onboarding-spoken',
    section: GallerySection.profiles,
    label:
        'First launch: languages you know', // ui-literal-ok: debug-only gallery
    note: 'Nothing ticked: Continue waits', // ui-literal-ok: debug-only gallery
    builder: (_) => const OnboardingFlow(startAt: 'spoken'),
  ),
  GalleryEntry(
    id: 'onboarding-spoken-ranked',
    section: GallerySection.profiles,
    label:
        'First launch: languages, ranked', // ui-literal-ok: debug-only gallery
    note: 'Bengali 1, English 2, with the drag hint', // ui-literal-ok: debug-only gallery
    builder: (_) =>
        const OnboardingFlow(startAt: 'spoken', spoken: <String>['bn', 'en']),
  ),
];
