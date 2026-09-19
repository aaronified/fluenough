# ADR-0001: Build with Flutter

- **Status:** Accepted
- **Date:** 2026-09-19

## Context

Fluenough targets Android first, distributed through GitHub Releases and
potentially F-Droid. iOS is a possible future target.

The app's platform surface is unusually small: a UI, a local SQLite database,
and one text-to-speech call. It has no camera, no background services, no
complex native integration.

## Decision

Build with Flutter (Dart), targeting Android now with the iOS port left open.

## Consequences

**The code ports cheaply.** For an app this shape, well over 90% of the code
is shared between platforms. Flutter's weakness is apps needing deep native
surface area; this is close to a best case for it.

**The distribution does not port cheaply, and that is the real cost.** Android
allows direct APK distribution from GitHub and F-Droid listing. iOS has no
equivalent: shipping to iPhones requires an Apple Developer account at $99 per
year, App Store review or TestFlight, and macOS to build and sign. *Flutter
makes the port cheap; Apple's gate is what costs.* This was accepted knowingly.

**TTS is where the platforms diverge most**, which is unfortunate given it is a
core feature — iOS system voices cover meaningfully fewer languages than
Android's. See [ADR-0002](0002-system-tts.md).

**Dart is an additional language** to maintain fluency in, and the baseline APK
is larger than a native equivalent.

## Alternatives considered

- **Kotlin + Jetpack Compose, Android-only.** Best Android tooling and the
  simplest path for GitHub/F-Droid distribution. Rejected because reaching iOS
  later would mean a rewrite.
- **Compose Multiplatform.** Keeps everything in Kotlin and reaches iOS, with
  the same Apple economics. Rejected as less mature and less documented for
  iOS than Flutter today.
